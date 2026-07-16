defmodule QlariusWeb.Admin.QaiEconomicsLiveTest do
  use QlariusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Qlarius.Qai.Sessions
  alias Qlarius.Repo

  setup %{conn: conn} do
    {:ok, %{user: user}} =
      Qlarius.Accounts.register_new_user(%{
        alias: "qai-econ-admin-#{System.unique_integer([:positive])}"
      })

    user = user |> Ecto.Changeset.change(role: "admin") |> Repo.update!()

    %{conn: log_in_user(conn, user), user: user}
  end

  test "renders KPIs and pricing scenario from measured usage", %{conn: conn, user: user} do
    me_file = Qlarius.Accounts.get_me_file_by_user_id(user.id)
    {:ok, session} = Sessions.create_session(me_file.id)

    {:ok, draft} = Sessions.add_message(session, "assistant", "", model: "claude-sonnet-4-6")

    {:ok, _} =
      Sessions.finalize_message(draft, "hello",
        usage: %{
          "input_tokens" => 1000,
          "output_tokens" => 500,
          "cache_read_input_tokens" => 2000,
          "cache_creation_input_tokens" => 1000
        }
      )

    {:ok, view, html} = live(conn, ~p"/admin/qai_economics")

    assert html =~ "Qai Economics"
    assert html =~ "Pricing Scenario"
    assert html =~ "claude-sonnet-4-6"
    # 2000 cache reads of 4000 context tokens.
    assert html =~ "50%"

    # Scenario inputs recompute without crashing.
    html =
      view
      |> element("form[phx-change=set_scenario]")
      |> render_change(%{"price" => "0.50", "frontier_input" => "6.0"})

    assert html =~ "$0.50"

    # Window switch reloads data.
    assert view |> element("button[phx-value-days='7']") |> render_click() =~ "Qai Economics"
  end

  test "non-admin users are refused", %{conn: _conn} do
    {:ok, %{user: normal}} =
      Qlarius.Accounts.register_new_user(%{
        alias: "qai-econ-user-#{System.unique_integer([:positive])}"
      })

    conn = log_in_user(build_conn(), normal)
    assert {:error, {status, _}} = live(conn, ~p"/admin/qai_economics")
    assert status in [:redirect, :live_redirect]
  end
end
