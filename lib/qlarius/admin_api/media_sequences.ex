defmodule Qlarius.AdminApi.MediaSequences do
  import Ecto.Query

  alias Qlarius.AdminApi.{Idempotent, PtpDefaults}
  alias Qlarius.Repo
  alias Qlarius.Sponster.Ads.MediaPiece
  alias Qlarius.Sponster.Campaigns.{Campaign, MediaSequence, MediaSequences}

  @fields ~w(title description)

  def list(params) do
    from(s in MediaSequence, order_by: [desc: s.id], preload: [media_runs: :media_piece])
    |> then(fn query ->
      case params["marketer_id"] do
        id when id in [nil, ""] -> query
        id -> where(query, [s], s.marketer_id == ^int(id))
      end
    end)
    |> Repo.all()
  end

  def fetch(id) do
    case Repo.get(MediaSequence, id) do
      nil -> {:error, :not_found}
      sequence -> {:ok, Repo.preload(sequence, media_runs: :media_piece)}
    end
  end

  def create(params, opts) do
    with {:ok, piece} <- piece(params) do
      {values, defaults} = PtpDefaults.resolve(params)

      Idempotent.create(MediaSequence, params,
        fields: @fields,
        dry_run: opts[:dry_run],
        on_existing: params["on_existing"],
        owned?: &(&1.marketer_id == piece.marketer_id),
        preview: fn attrs -> preview(attrs, piece, values) end,
        insert: fn attrs -> insert(attrs, piece, values) end,
        update: fn sequence, attrs ->
          MediaSequences
          |> then(fn _ -> MediaSequence.changeset(sequence, attrs) |> Repo.update() end)
        end
      )
      |> case do
        {:ok, result} -> {:ok, Map.put(result, :defaults_used, defaults)}
        other -> other
      end
    end
  end

  def delete(sequence, opts) do
    count =
      Repo.aggregate(from(c in Campaign, where: c.media_sequence_id == ^sequence.id), :count)

    cond do
      count > 0 ->
        {:error, {:has_dependents, %{campaigns: count}}}

      opts[:dry_run] ->
        {:ok, %{result: "would_delete", removes: %{media_sequence: sequence.id}}}

      true ->
        Repo.delete_all(
          from(r in Qlarius.Sponster.Campaigns.MediaRun,
            where: r.media_sequence_id == ^sequence.id
          )
        )

        with {:ok, _} <- Repo.delete(sequence) do
          {:ok, %{result: "deleted", removes: %{media_sequence: sequence.id}}}
        end
    end
  end

  defp piece(%{"media_piece_id" => id, "marketer_id" => marketer_id}) do
    marketer_id = int(marketer_id)

    case Repo.get(MediaPiece, int(id)) do
      %MediaPiece{active: true, marketer_id: ^marketer_id} = piece ->
        {:ok, piece}

      %MediaPiece{marketer_id: mid} when mid != marketer_id ->
        {:error, :media_piece_wrong_marketer}

      %MediaPiece{} ->
        {:error, :media_piece_inactive}

      nil ->
        {:error, :not_found}
    end
  end

  defp piece(_), do: {:error, :media_piece_required}

  defp preview(attrs, piece, values) do
    attrs =
      Map.merge(attrs, %{
        "marketer_id" => piece.marketer_id,
        "title" => attrs["title"] || piece.title
      })

    case MediaSequence.changeset(%MediaSequence{}, attrs) do
      %{valid?: true} = changeset ->
        sequence = Ecto.Changeset.apply_changes(changeset)

        run = %Qlarius.Sponster.Campaigns.MediaRun{
          media_piece_id: piece.id,
          marketer_id: piece.marketer_id,
          frequency: int(values["frequency"]),
          frequency_buffer_hours: int(values["frequency_buffer_hours"]),
          maximum_banner_count: int(values["maximum_banner_count"]),
          banner_retry_buffer_hours: int(values["banner_retry_buffer_hours"])
        }

        {:ok, %{sequence | media_runs: [run]}}

      changeset ->
        {:error, changeset}
    end
  end

  defp insert(attrs, piece, values) do
    run_attrs =
      values
      |> Map.put("media_piece_id", piece.id)
      |> Map.put("title", attrs["title"] || piece.title)
      |> Map.put("description", attrs["description"])

    case MediaSequences.create_media_sequence_with_run(piece.marketer_id, run_attrs) do
      {:ok, sequence} ->
        sequence = Repo.preload(sequence, [media_runs: :media_piece], force: true)

        if attrs["api_ref"] do
          {:ok, sequence} =
            sequence |> MediaSequence.changeset(%{"api_ref" => attrs["api_ref"]}) |> Repo.update()

          {:ok, sequence}
        else
          {:ok, sequence}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp int(id) when is_integer(id), do: id

  defp int(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp int(_), do: nil
end
