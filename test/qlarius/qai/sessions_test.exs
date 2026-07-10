defmodule Qlarius.Qai.SessionsTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.Qai.Sessions
  alias Qlarius.Qai.{Message, Session}
  alias Qlarius.YouData.MeFiles.MeFile

  defp insert_me_file!, do: Repo.insert!(%MeFile{})

  defp expire!(session, seconds_ago \\ 60) do
    past = DateTime.add(DateTime.utc_now(), -seconds_ago, :second)

    session
    |> Ecto.Changeset.change(expires_at: DateTime.truncate(past, :second))
    |> Repo.update!()
  end

  describe "session lifecycle" do
    test "new sessions are fleeting with a full window on the clock" do
      me_file = insert_me_file!()
      {:ok, session} = Sessions.create_session(me_file.id)

      refute Session.preserved?(session)
      window = Sessions.fleeting_hours() * 3600
      remaining = DateTime.diff(session.expires_at, DateTime.utc_now())
      assert remaining > window - 60 and remaining <= window
    end

    test "preserve nulls the clock; fleet restarts it" do
      me_file = insert_me_file!()
      {:ok, session} = Sessions.create_session(me_file.id)

      {:ok, preserved} = Sessions.preserve_session(session)
      assert Session.preserved?(preserved)
      assert preserved.preserved_at

      {:ok, fleeted} = Sessions.fleet_session(preserved)
      refute Session.preserved?(fleeted)
      assert fleeted.preserved_at == nil
    end

    test "reads are scoped to the MeFile and exclude expired sessions" do
      me_file = insert_me_file!()
      other = insert_me_file!()
      {:ok, session} = Sessions.create_session(me_file.id)
      {:ok, expired} = Sessions.create_session(me_file.id)
      expire!(expired)

      assert [%{id: id}] = Sessions.list_sessions(me_file.id)
      assert id == session.id
      assert Sessions.get_session(session.id, me_file.id)
      assert Sessions.get_session(expired.id, me_file.id) == nil
      assert Sessions.get_session(session.id, other.id) == nil
    end

    test "titles are trimmed and capped" do
      me_file = insert_me_file!()
      {:ok, session} = Sessions.create_session(me_file.id)

      {:ok, titled} = Sessions.set_title(session, "  " <> String.duplicate("t", 300))
      assert String.length(titled.title) == Session.title_max_length()
    end
  end

  describe "messages" do
    test "appending a message restarts the fleet clock" do
      me_file = insert_me_file!()
      {:ok, session} = Sessions.create_session(me_file.id)
      stale = DateTime.add(DateTime.utc_now(), 60, :second) |> DateTime.truncate(:second)
      session = session |> Ecto.Changeset.change(expires_at: stale) |> Repo.update!()

      {:ok, _} = Sessions.add_message(session, "user", "hello")

      reloaded = Repo.get!(Session, session.id)
      assert DateTime.compare(reloaded.expires_at, stale) == :gt
    end

    test "appending to a preserved session leaves it preserved" do
      me_file = insert_me_file!()
      {:ok, session} = Sessions.create_session(me_file.id)
      {:ok, preserved} = Sessions.preserve_session(session)

      {:ok, _} = Sessions.add_message(preserved, "user", "hello")
      assert Repo.get!(Session, session.id).expires_at == nil
    end

    test "assistant messages start empty and finalize with model and stopped flag" do
      me_file = insert_me_file!()
      {:ok, session} = Sessions.create_session(me_file.id)

      {:ok, draft} = Sessions.add_message(session, "assistant", "", model: "cheap")
      assert draft.content == ""
      assert draft.model == "cheap"

      {:ok, final} = Sessions.finalize_message(draft, "partial answer", stopped: true)
      assert final.content == "partial answer"
      assert final.stopped
    end

    test "messages list in turn order; regenerate drops only the trailing assistant turn" do
      me_file = insert_me_file!()
      {:ok, session} = Sessions.create_session(me_file.id)

      {:ok, _} = Sessions.add_message(session, "user", "q1")
      {:ok, _} = Sessions.add_message(session, "assistant", "a1")
      {:ok, _} = Sessions.add_message(session, "user", "q2")
      {:ok, _} = Sessions.add_message(session, "assistant", "a2")

      assert ["q1", "a1", "q2", "a2"] =
               Sessions.list_messages(session.id) |> Enum.map(& &1.content)

      :ok = Sessions.delete_last_assistant_message(session.id)

      assert ["q1", "a1", "q2"] =
               Sessions.list_messages(session.id) |> Enum.map(& &1.content)
    end

    test "invalid roles are rejected" do
      me_file = insert_me_file!()
      {:ok, session} = Sessions.create_session(me_file.id)

      assert {:error, changeset} = Sessions.add_message(session, "system", "nope")
      assert %{role: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "sweep_expired/1" do
    test "hard-deletes expired sessions and their messages, sparing live and preserved ones" do
      me_file = insert_me_file!()

      {:ok, live} = Sessions.create_session(me_file.id)
      {:ok, preserved} = Sessions.create_session(me_file.id)
      {:ok, preserved} = Sessions.preserve_session(preserved)
      {:ok, expired} = Sessions.create_session(me_file.id)
      {:ok, _} = Sessions.add_message(expired, "user", "gone with the session")
      expired = expire!(expired)

      assert 1 = Sessions.sweep_expired()

      assert Repo.get(Session, expired.id) == nil
      assert Sessions.list_messages(expired.id) == []
      assert Repo.get(Session, live.id)
      assert Repo.get(Session, preserved.id)
    end

    test "the worker runs the sweep" do
      me_file = insert_me_file!()
      {:ok, expired} = Sessions.create_session(me_file.id)
      expire!(expired)

      assert :ok = Qlarius.Jobs.SweepExpiredQaiSessionsWorker.perform(%Oban.Job{})
      assert Repo.get(Session, expired.id) == nil
    end
  end

  test "messages require an existing session" do
    changeset =
      Message.changeset(%Message{}, %{qai_session_id: 999_999_999, role: "user", content: "x"})

    assert {:error, changeset} = Repo.insert(changeset)
    assert %{qai_session_id: ["does not exist"]} = errors_on(changeset)
  end
end
