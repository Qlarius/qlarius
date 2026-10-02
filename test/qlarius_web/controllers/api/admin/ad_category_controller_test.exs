defmodule QlariusWeb.Api.Admin.AdCategoryControllerTest do
  use QlariusWeb.ConnCase, async: false

  import Qlarius.AdCategoryFixtures

  alias Qlarius.Accounts.{AdminApiTokens, User}
  alias Qlarius.Repo
  alias Qlarius.Sponster.Ads.{AdCategories, AdCategory, MediaPiece}

  @guide "/api/admin/agent_guide"

  setup do
    Repo.delete_all(AdCategory)

    admin =
      %User{}
      |> User.registration_changeset(%{
        "alias" => "api-admin-#{System.unique_integer([:positive])}"
      })
      |> Ecto.Changeset.put_change(:role, "admin")
      |> Repo.insert!()

    {:ok, _token, raw} = AdminApiTokens.issue(admin, "test")
    %{token: raw}
  end

  test "refuses a missing token" do
    conn = get(build_conn(), ~p"/api/admin/ad_categories")
    assert %{"error" => "unauthorized", "guide" => @guide} = json_response(conn, 401)
  end

  test "lists rows grouped by category with counts and filters", %{token: token} do
    a = row_fixture(category_id: "SP01", ad_label: "Shoes", sort_order: 10)
    row_fixture(category_id: "SP02", ad_label: "Soap", sort_order: 20, cohort: "261002-aaaa")
    media_piece_fixture(a)

    body = token |> authed() |> get(~p"/api/admin/ad_categories") |> json_response(200)
    assert body["count"] == 2
    assert body["attribution"] =~ "CC BY 3.0"

    assert [
             %{"category_id" => "SP01", "rows" => [%{"media_pieces_count" => 1}]},
             %{"category_id" => "SP02"}
           ] =
             body["categories"]

    body =
      token
      |> authed()
      |> get(~p"/api/admin/ad_categories?cohort=261002-aaaa")
      |> json_response(200)

    assert [%{"category_id" => "SP02"}] = body["categories"]

    body = token |> authed() |> get(~p"/api/admin/ad_categories?q=shoe") |> json_response(200)
    assert [%{"rows" => [%{"ad_label" => "Shoes"}]}] = body["categories"]
  end

  test "lists cohorts", %{token: token} do
    row_fixture(cohort: "261002-aaaa")
    body = token |> authed() |> get(~p"/api/admin/ad_categories/cohorts") |> json_response(200)
    assert [%{"cohort" => "261002-aaaa", "count" => 1}] = body["cohorts"]
  end

  test "creates rows in existing and new categories", %{token: token} do
    row_fixture(row_id: "SP28-01", category_id: "SP28")

    body =
      token
      |> authed()
      |> post(~p"/api/admin/ad_categories", %{category_id: "SP28", ad_label: "Outlet Malls"})
      |> json_response(201)

    assert %{"row" => %{"row_id" => "SP28-02"}, "cohort" => cohort} = body
    assert cohort =~ ~r/^\d{6}-[a-z0-9]{4}$/

    body =
      token
      |> authed()
      |> post(~p"/api/admin/ad_categories", %{
        new_category: %{category_name: "Space", category_label: "Space Travel"},
        ad_label: "Rocket Rides",
        cohort: "261002-zzzz"
      })
      |> json_response(201)

    assert %{
             "row" => %{"row_id" => "SP29-01", "category_id" => "SP29"},
             "cohort" => "261002-zzzz"
           } =
             body

    conn =
      token
      |> authed()
      |> post(~p"/api/admin/ad_categories", %{category_id: "SP99", ad_label: "X"})

    assert %{"error" => "unknown_category"} = json_response(conn, 422)
  end

  test "edits a row and refuses key changes", %{token: token} do
    row = row_fixture(row_id: "SP03-01", category_id: "SP03")

    body =
      token
      |> authed()
      |> patch(~p"/api/admin/ad_categories/SP03-01", %{ad_label: "Pharmacies", active: false})
      |> json_response(200)

    assert %{"row" => %{"ad_label" => "Pharmacies", "active" => false}} = body

    conn =
      token |> authed() |> patch(~p"/api/admin/ad_categories/SP03-01", %{category_id: "SP04"})

    assert %{"error" => "immutable_key"} = json_response(conn, 422)

    conn = token |> authed() |> patch(~p"/api/admin/ad_categories/SP03-01", %{age_gated: true})
    assert %{"error" => "invalid", "errors" => %{"age_min" => _}} = json_response(conn, 422)

    conn = token |> authed() |> patch(~p"/api/admin/ad_categories/NOPE-01", %{ad_label: "X"})
    assert %{"error" => "not_found"} = json_response(conn, 404)

    assert Repo.get!(AdCategory, row.id).category_id == "SP03"
  end

  test "renames a category", %{token: token} do
    row_fixture(category_id: "SP05")

    body =
      token
      |> authed()
      |> patch(~p"/api/admin/ad_categories/categories/SP05", %{category_label: "Outdoors"})
      |> json_response(200)

    assert %{"category_id" => "SP05", "updated" => 1} = body
  end

  test "imports rows with dry_run and reports invalid rows", %{token: token} do
    rows = [
      %{
        row_id: "SP06-01",
        category_id: "SP06",
        category_name: "Food & Grocery",
        category_label: "Groceries",
        ad_label: "Supermarkets",
        age_gated: "0",
        sort_order: "10"
      }
    ]

    body =
      token
      |> authed()
      |> post(~p"/api/admin/ad_categories/import", %{rows: rows, dry_run: true})
      |> json_response(200)

    assert %{"inserted" => 1, "dry_run" => true} = body
    assert Repo.aggregate(AdCategory, :count) == 0

    body =
      token
      |> authed()
      |> post(~p"/api/admin/ad_categories/import", %{rows: rows, cohort: "261002-eeee"})
      |> json_response(200)

    assert %{"inserted" => 1, "cohort" => "261002-eeee"} = body

    bad = [Map.put(hd(rows), :ad_label, "")]
    conn = token |> authed() |> post(~p"/api/admin/ad_categories/import", %{rows: bad})

    assert %{"error" => "invalid_rows", "errors" => [%{"row_id" => "SP06-01"}]} =
             json_response(conn, 422)

    conn =
      token |> authed() |> post(~p"/api/admin/ad_categories/import", %{rows: rows, cohort: "bad"})

    assert %{"error" => "invalid_cohort"} = json_response(conn, 422)
  end

  test "moves rows to a cohort", %{token: token} do
    row = row_fixture()

    body =
      token
      |> authed()
      |> post(~p"/api/admin/ad_categories/cohort", %{row_ids: [row.row_id], cohort: "261002-ffff"})
      |> json_response(200)

    assert %{"updated" => 1} = body

    conn =
      token |> authed() |> post(~p"/api/admin/ad_categories/cohort", %{cohort: "261002-ffff"})

    assert %{"error" => "selector_required"} = json_response(conn, 422)
  end

  test "remaps media pieces", %{token: token} do
    from = row_fixture()
    to = row_fixture()
    closed = row_fixture(active: false)
    piece = media_piece_fixture(from)

    conn =
      token
      |> authed()
      |> post(~p"/api/admin/ad_categories/remap", %{
        mappings: [%{from_row_id: from.row_id, to_row_id: closed.row_id}]
      })

    assert %{"error" => "row_inactive"} = json_response(conn, 422)

    body =
      token
      |> authed()
      |> post(~p"/api/admin/ad_categories/remap", %{
        mappings: [%{from_row_id: from.row_id, to_row_id: to.row_id}]
      })
      |> json_response(200)

    assert %{"moved" => 1} = body
    assert Repo.get!(MediaPiece, piece.id).ad_category_id == to.id

    conn = token |> authed() |> post(~p"/api/admin/ad_categories/remap", %{})
    assert %{"error" => "invalid_remap"} = json_response(conn, 422)
  end

  test "prunes and deletes unused rows only", %{token: token} do
    used = row_fixture(category_id: "SP09")
    unused = row_fixture(category_id: "SP09")
    media_piece_fixture(used)

    body =
      token
      |> authed()
      |> post(~p"/api/admin/ad_categories/prune", %{category_id: "SP09", dry_run: true})
      |> json_response(200)

    assert %{"count" => 1, "deleted" => [deleted], "dry_run" => true} = body
    assert deleted == unused.row_id

    conn = token |> authed() |> post(~p"/api/admin/ad_categories/prune", %{})
    assert %{"error" => "selector_required"} = json_response(conn, 422)

    conn = token |> authed() |> delete(~p"/api/admin/ad_categories/#{used.row_id}")
    assert %{"error" => "in_use", "media_pieces_count" => 1} = json_response(conn, 409)

    conn = token |> authed() |> delete(~p"/api/admin/ad_categories/#{unused.row_id}")
    assert %{"deleted" => _} = json_response(conn, 200)
    refute AdCategories.get_by_row_id(unused.row_id)
  end

  test "the agent guide serves the ad_categories topic", %{token: token} do
    conn = token |> authed() |> get(~p"/api/admin/agent_guide?topic=ad_categories")
    body = response(conn, 200)
    assert body =~ "Managing the Sponster ad taxonomy"
    assert body =~ "CC BY 3.0"
    refute body =~ "\u2014"
  end

  defp authed(token) do
    build_conn()
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_header("content-type", "application/json")
  end
end
