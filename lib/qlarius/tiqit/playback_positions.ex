defmodule Qlarius.Tiqit.PlaybackPositions do
  @moduledoc """
  One listen position per tiqit per content piece.

  Rows are deleted when the tiqit fleets or is undone. A later purchase
  is a new tiqit and starts at the beginning.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.Tiqit
  alias Qlarius.Tiqit.PlaybackPosition
  alias QlariusWeb.Endpoint

  @token_salt "content_playback"
  @token_max_age 30 * 24 * 60 * 60
  @reasons ~w(tick pause hide ended restart)

  def sign_token(me_file_id, tiqit_id, piece_id)
      when is_integer(me_file_id) and is_integer(tiqit_id) and is_integer(piece_id) do
    Phoenix.Token.sign(Endpoint, @token_salt, %{
      "me_file_id" => me_file_id,
      "tiqit_id" => tiqit_id,
      "piece_id" => piece_id
    })
  end

  def resume(tiqit_id, piece_id) when is_integer(tiqit_id) and is_integer(piece_id) do
    case Repo.get_by(PlaybackPosition, tiqit_id: tiqit_id, content_piece_id: piece_id) do
      %PlaybackPosition{completed_at: %DateTime{}} ->
        nil

      %PlaybackPosition{position_seconds: seconds} when is_integer(seconds) and seconds >= 5 ->
        seconds

      _ ->
        nil
    end
  end

  def resume(_, _), do: nil

  def save(me_file_id, params) when is_integer(me_file_id) and is_map(params) do
    with {:ok, attrs} <- cast_save(params),
         {:ok, tiqit} <- active_tiqit(me_file_id, attrs.tiqit_id),
         :ok <- covers_piece?(tiqit, attrs.piece_id) do
      write(tiqit.id, attrs)
    end
  end

  def save(_me_file_id, _params), do: {:error, :unauthorized}

  def save_from_token(params) when is_map(params) do
    with {:ok, me_file_id, tiqit_id, piece_id} <- verify_token(params["token"] || params[:token]),
         {:ok, attrs} <- cast_save(params),
         true <- attrs.tiqit_id == tiqit_id and attrs.piece_id == piece_id,
         :ok <- save(me_file_id, params) do
      :ok
    else
      false -> {:error, :unauthorized}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_for_tiqit(tiqit_id) when is_integer(tiqit_id) do
    Repo.delete_all(from p in PlaybackPosition, where: p.tiqit_id == ^tiqit_id)
  end

  def format_clock(seconds) when is_integer(seconds) and seconds >= 0 do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    rest = rem(seconds, 60)

    if hours > 0 do
      "#{hours}:#{pad(minutes)}:#{pad(rest)}"
    else
      "#{minutes}:#{pad(rest)}"
    end
  end

  defp verify_token(token) when is_binary(token) do
    case Phoenix.Token.verify(Endpoint, @token_salt, token, max_age: @token_max_age) do
      {:ok, %{"me_file_id" => me_file_id, "tiqit_id" => tiqit_id, "piece_id" => piece_id}}
      when is_integer(me_file_id) and is_integer(tiqit_id) and is_integer(piece_id) ->
        {:ok, me_file_id, tiqit_id, piece_id}

      _ ->
        {:error, :unauthorized}
    end
  end

  defp verify_token(_), do: {:error, :unauthorized}

  defp cast_save(params) do
    tiqit_id = integer(params["tiqit_id"] || params[:tiqit_id])
    piece_id = integer(params["content_piece_id"] || params[:content_piece_id])
    position = integer(params["position_seconds"] || params[:position_seconds])
    duration = integer(params["duration_seconds"] || params[:duration_seconds]) || 0
    reason = params["reason"] || params[:reason]

    if tiqit_id && piece_id && position && position >= 0 && reason in @reasons do
      {:ok,
       %{
         tiqit_id: tiqit_id,
         piece_id: piece_id,
         position: position,
         duration: duration,
         reason: reason
       }}
    else
      {:error, :invalid}
    end
  end

  defp active_tiqit(me_file_id, tiqit_id) do
    now = DateTime.utc_now()

    case Repo.one(
           from t in Tiqit,
             where: t.id == ^tiqit_id,
             where: t.me_file_id == ^me_file_id,
             where: is_nil(t.disconnected_at) and is_nil(t.undone_at),
             where: is_nil(t.expires_at) or t.expires_at > ^now
         ) do
      %Tiqit{} = tiqit -> {:ok, tiqit}
      nil -> {:error, :unauthorized}
    end
  end

  defp covers_piece?(%Tiqit{} = tiqit, piece_id) do
    case Repo.get(ContentPiece, piece_id) |> Repo.preload(:content_group) do
      %ContentPiece{} = piece ->
        group_id = piece.content_group_id
        catalog_id = piece.content_group && piece.content_group.catalog_id

        covered? =
          tiqit.content_piece_id == piece.id or
            (piece.exclude_from_group_access != true and tiqit.content_group_id == group_id) or
            (piece.exclude_from_catalog_access != true and not is_nil(catalog_id) and
               tiqit.catalog_id == catalog_id)

        if covered?, do: :ok, else: {:error, :unauthorized}

      _ ->
        {:error, :unauthorized}
    end
  end

  defp write(tiqit_id, attrs) do
    existing = Repo.get_by(PlaybackPosition, tiqit_id: tiqit_id, content_piece_id: attrs.piece_id)

    case classify(existing, attrs) do
      :ignore ->
        :ok

      fields ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        %PlaybackPosition{}
        |> PlaybackPosition.changeset(
          Map.merge(fields, %{tiqit_id: tiqit_id, content_piece_id: attrs.piece_id})
        )
        |> Repo.insert(
          on_conflict: [set: Map.to_list(Map.put(fields, :updated_at, now))],
          conflict_target: [:tiqit_id, :content_piece_id]
        )
        |> case do
          {:ok, _} -> :ok
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  defp classify(_existing, %{reason: "restart"}) do
    %{position_seconds: 0, duration_seconds: nil, completed_at: nil}
  end

  defp classify(existing, %{position: position, duration: duration, reason: reason}) do
    cond do
      finished?(position, duration) ->
        %{
          position_seconds: 0,
          duration_seconds: duration,
          completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }

      position < 5 ->
        :ignore

      reason == "tick" and not moved?(existing, position) ->
        :ignore

      true ->
        %{
          position_seconds: position,
          duration_seconds: blank_duration(duration),
          completed_at: nil
        }
    end
  end

  defp finished?(position, duration) when is_integer(duration) and duration > 0 do
    position / duration >= 0.95 or duration - position < 15
  end

  defp finished?(_, _), do: false

  defp moved?(nil, _position), do: true

  defp moved?(%PlaybackPosition{position_seconds: current}, position) do
    abs(position - current) >= 10
  end

  defp blank_duration(duration) when is_integer(duration) and duration > 0, do: duration
  defp blank_duration(_), do: nil

  defp integer(value) when is_integer(value) and value >= 0, do: value

  defp integer(value) when is_float(value) and value >= 0, do: trunc(value)

  defp integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {int, ""} when int >= 0 -> int
      _ -> nil
    end
  end

  defp integer(_), do: nil

  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")
end
