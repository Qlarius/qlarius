defmodule QlariusWeb.Plugs.EnsureSessionSyncIdTest do
  use QlariusWeb.ConnCase, async: true

  alias QlariusWeb.Plugs.EnsureSessionSyncId

  @uuid "7b2f9c1e-4d3a-4f6b-9e8c-1a2b3c4d5e6f"

  defp run(conn, opts), do: EnsureSessionSyncId.call(conn, EnsureSessionSyncId.init(opts))

  defp bare(query \\ "") do
    build_conn(:get, "/widgets/arqade?" <> query)
    |> Plug.Conn.fetch_query_params()
    |> init_test_session(%{})
  end

  test "generates an id when the session has none" do
    conn = run(bare(), [])
    id = get_session(conn, :session_sync_id)
    assert {:ok, _} = Ecto.UUID.cast(id)
    assert conn.assigns.session_sync_id == id
  end

  test "keeps an existing session id" do
    conn =
      bare("sync_id=#{@uuid}")
      |> put_session(:session_sync_id, "existing")
      |> run(accept_query: true)

    assert get_session(conn, :session_sync_id) == "existing"
    assert conn.assigns.session_sync_id == "existing"
  end

  test "adopts a UUID sync_id query param on widget routes" do
    conn = run(bare("sync_id=#{String.upcase(@uuid)}"), accept_query: true)
    assert get_session(conn, :session_sync_id) == @uuid
    assert conn.assigns.session_sync_id == @uuid
  end

  test "ignores a malformed sync_id query param" do
    conn = run(bare("sync_id=not-a-uuid"), accept_query: true)
    id = get_session(conn, :session_sync_id)
    assert id != "not-a-uuid"
    assert {:ok, _} = Ecto.UUID.cast(id)
  end

  test "ignores the query param unless accept_query is set" do
    conn = run(bare("sync_id=#{@uuid}"), [])
    assert get_session(conn, :session_sync_id) != @uuid
  end

  test "the widgets pipeline adopts the loader's sync_id end to end", %{conn: conn} do
    conn = get(conn, "/widgets/arqade?sync_id=#{@uuid}")
    assert html_response(conn, 200)
    assert get_session(conn, :session_sync_id) == @uuid
  end
end
