defmodule Qlarius.Qai.Sessions do
  @moduledoc """
  Qai chat session lifecycle: fleeting by default, preserve opt-in.

  Every session-touching write (create, message append, rename) restarts the
  fleet clock unless the session is preserved, so a conversation only expires
  after a full fleeting window of inactivity. Reads exclude expired sessions
  even before the hourly sweep hard-deletes them, so an expired chat never
  reappears in the UI between sweeps.
  """

  import Ecto.Query

  alias Qlarius.Qai.{Message, Session}
  alias Qlarius.Repo

  @fleeting_hours 24

  def fleeting_hours do
    Application.get_env(:qlarius, :qai, [])
    |> Keyword.get(:fleeting_hours, @fleeting_hours)
  end

  ## Sessions

  def create_session(me_file_id, attrs \\ %{}) do
    attrs =
      attrs
      |> Map.new()
      |> Map.put(:me_file_id, me_file_id)
      |> Map.put_new(:expires_at, next_expiry())

    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Fetches a live (non-expired) session scoped to the MeFile, or nil."
  def get_session(id, me_file_id) do
    live_sessions(me_file_id)
    |> where([s], s.id == ^id)
    |> Repo.one()
  end

  def list_sessions(me_file_id) do
    live_sessions(me_file_id)
    |> order_by([s], desc: s.updated_at, desc: s.id)
    |> Repo.all()
  end

  @doc "Restarts the fleet clock (no-op for preserved sessions)."
  def touch_session(%Session{expires_at: nil} = session), do: {:ok, session}

  def touch_session(%Session{} = session) do
    session
    |> Session.changeset(%{expires_at: next_expiry()})
    |> Repo.update()
  end

  @doc "Opts the session out of fleeting; it persists until deleted."
  def preserve_session(%Session{} = session) do
    session
    |> Session.changeset(%{expires_at: nil, preserved_at: now()})
    |> Repo.update()
  end

  @doc "Returns a preserved session to fleeting with a fresh clock."
  def fleet_session(%Session{} = session) do
    session
    |> Session.changeset(%{expires_at: next_expiry(), preserved_at: nil})
    |> Repo.update()
  end

  def set_title(%Session{} = session, title) do
    session
    |> Session.changeset(%{title: title})
    |> Repo.update()
  end

  def delete_session(%Session{} = session), do: Repo.delete(session)

  ## Messages

  @doc """
  Appends a turn and restarts the session's fleet clock. Assistant messages
  start empty (`content` defaults to "") and are finalized when the stream
  ends via `finalize_message/3`.
  """
  def add_message(%Session{} = session, role, content \\ "", opts \\ []) do
    %Message{}
    |> Message.changeset(%{
      qai_session_id: session.id,
      role: role,
      content: content,
      model: Keyword.get(opts, :model)
    })
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        {:ok, _} = touch_session(session)
        {:ok, message}

      error ->
        error
    end
  end

  @doc """
  Writes the streamed content once at stream end; `stopped: true` if cut off.
  `:usage` (provider token counts) and `:model` (the id that actually served
  the turn) are recorded when the stream completed normally.
  """
  def finalize_message(%Message{} = message, content, opts \\ []) do
    attrs =
      %{content: content, stopped: Keyword.get(opts, :stopped, false)}
      |> maybe_put(:usage, Keyword.get(opts, :usage))
      |> maybe_put(:model, Keyword.get(opts, :model))

    message
    |> Message.changeset(attrs)
    |> Repo.update()
  end

  defp maybe_put(attrs, _key, nil), do: attrs
  defp maybe_put(attrs, key, value), do: Map.put(attrs, key, value)

  def list_messages(session_id) do
    Message
    |> where([m], m.qai_session_id == ^session_id)
    |> order_by([m], asc: m.id)
    |> Repo.all()
  end

  @doc "Deletes the trailing assistant message (regenerate). Returns :ok either way."
  def delete_last_assistant_message(session_id) do
    Message
    |> where([m], m.qai_session_id == ^session_id and m.role == "assistant")
    |> order_by([m], desc: m.id)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> :ok
      message -> with {:ok, _} <- Repo.delete(message), do: :ok
    end
  end

  ## Sweep

  @doc """
  Hard-deletes every expired session; messages go with them via the FK
  cascade. Returns the number of sessions removed.
  """
  def sweep_expired(now \\ nil) do
    now = now || now()

    {count, _} =
      Session
      |> where([s], not is_nil(s.expires_at) and s.expires_at <= ^now)
      |> Repo.delete_all()

    count
  end

  defp live_sessions(me_file_id) do
    now = now()

    Session
    |> where([s], s.me_file_id == ^me_file_id)
    |> where([s], is_nil(s.expires_at) or s.expires_at > ^now)
  end

  defp next_expiry, do: DateTime.add(now(), fleeting_hours() * 3600, :second)

  defp now, do: DateTime.truncate(DateTime.utc_now(), :second)
end
