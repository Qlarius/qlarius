defmodule QlariusWeb.Admin.QaiOracleLiveTest do
  use QlariusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Qlarius.MeCPFixtures

  alias Qlarius.MeCP.Oracle
  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFile

  setup %{conn: conn} do
    {:ok, %{user: user}} =
      Qlarius.Accounts.register_new_user(%{
        alias: "qai-oracle-admin-#{System.unique_integer([:positive])}"
      })

    user = user |> Ecto.Changeset.change(role: "admin") |> Repo.update!()

    %{conn: log_in_user(conn, user)}
  end

  test "shows activity and gaps raised by enough people, and switches windows", %{conn: conn} do
    ctx = seed!(%{tier: 2, scope: %{}})

    grants = [
      ctx.grant
      | for(_ <- 1..2, do: insert_grant!(Repo.insert!(%MeFile{}), ctx.client, %{tier: 2}))
    ]

    for grant <- grants, do: {:ok, _} = Oracle.search_traits(grant, "anime conventions")
    # One person alone: counted, but not shown
    {:ok, _} = Oracle.search_traits(ctx.grant, "sailing lessons")
    {:ok, _} = Oracle.ask(ctx.grant, {:has_trait, ctx.housing.id})

    {:ok, view, html} = live(conn, ~p"/admin/qai_oracle")

    assert html =~ "Qai Oracle"
    assert html =~ "Taxonomy Gaps"
    assert html =~ "anime conventions"
    refute html =~ "sailing lessons"
    assert html =~ "1 more below 3 people"
    assert html =~ "Most-Asked Traits"
    assert html =~ "Housing"
    assert html =~ "Test Client"

    html = view |> element("button[phx-value-days='7']") |> render_click()
    assert html =~ "anime conventions"

    # People filter: All shows one-person subjects; 10+ hides the 3-person one
    html = view |> element("button[phx-value-min='1']") |> render_click()
    assert html =~ "sailing lessons"
    assert html =~ "anime conventions"
    assert html =~ "all subjects"

    html = view |> element("button[phx-value-min='10']") |> render_click()
    refute html =~ "anime conventions"
    assert html =~ "Nothing raised by 10+ people in this window"

    html = view |> element("button[phx-value-min='3']") |> render_click()
    assert html =~ "anime conventions"
    refute html =~ "sailing lessons"
  end

  test "non-admins are sent away", %{conn: _conn} do
    {:ok, %{user: user}} =
      Qlarius.Accounts.register_new_user(%{alias: "not-admin-#{System.unique_integer([:positive])}"})

    conn = log_in_user(build_conn(), user)
    assert {:error, {:redirect, _}} = live(conn, ~p"/admin/qai_oracle")
  end
end
