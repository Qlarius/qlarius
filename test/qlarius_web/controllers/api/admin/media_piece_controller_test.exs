defmodule QlariusWeb.Api.Admin.MediaPieceControllerTest do
  use QlariusWeb.ConnCase, async: false

  import Qlarius.AdCategoryFixtures

  alias Qlarius.Accounts.{AdminApiTokens, User}
  alias Qlarius.Repo
  alias Qlarius.Sponster.Ads.MediaPiece

  @png <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8,
         2, 0, 0, 0, 144, 119, 83, 222, 0, 0, 0, 12, 73, 68, 65, 84, 8, 215, 99, 248, 255, 255,
         63, 0, 5, 254, 2, 254, 167, 53, 129, 132, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130>>

  setup do
    ensure_three_tap_type!()

    admin =
      %User{}
      |> User.registration_changeset(%{
        "alias" => "api-admin-#{System.unique_integer([:positive])}"
      })
      |> Ecto.Changeset.put_change(:role, "admin")
      |> Repo.insert!()

    {:ok, _token, raw} = AdminApiTokens.issue(admin, "test")
    %{token: raw, row: row_fixture(), marketer: marketer_fixture()}
  end

  defp authed(token), do: build_conn() |> put_req_header("authorization", "Bearer #{token}")

  defp banner do
    path = Path.join(System.tmp_dir!(), "banner-#{System.unique_integer([:positive])}.png")
    File.write!(path, @png)

    %Plug.Upload{path: path, filename: "banner.png", content_type: "image/png"}
  end

  defp params(ctx, extra) do
    Map.merge(
      %{
        api_ref: "ptp-2610-joes_tacos-phx.ad-#{System.unique_integer([:positive])}",
        marketer_id: ctx.marketer.id,
        media_piece_type_id: 1,
        ad_category_row_id: ctx.row.row_id,
        title: "Joe's Tacos banner",
        display_url: "joestacos.example",
        jump_url: "https://joestacos.example",
        active: true,
        banner_image: banner()
      },
      extra
    )
  end

  test "requires an api_ref and an image", %{token: token} = ctx do
    body =
      token
      |> authed()
      |> post(~p"/api/admin/media_pieces", Map.delete(params(ctx, %{}), :api_ref))
      |> json_response(422)

    assert body["error"] == "api_ref_required"

    body =
      token
      |> authed()
      |> post(~p"/api/admin/media_pieces", Map.delete(params(ctx, %{}), :banner_image))
      |> json_response(422)

    assert body["error"] == "image_required"
  end

  test "rejects an inactive ad category and a video type", %{token: token} = ctx do
    inactive = row_fixture(active: false)

    body =
      token
      |> authed()
      |> post(~p"/api/admin/media_pieces", params(ctx, %{ad_category_row_id: inactive.row_id}))
      |> json_response(422)

    assert body["error"] == "row_inactive"

    body =
      token
      |> authed()
      |> post(~p"/api/admin/media_pieces", params(ctx, %{media_piece_type_id: 2}))
      |> json_response(422)

    assert body["error"] in ["media_piece_type_not_writable", "media_piece_type_not_found"]
  end

  test "dry run writes nothing, then create matches on the same api_ref", %{token: token} = ctx do
    attrs = params(ctx, %{api_ref: "ptp-2610-joes_tacos-phx.ad"})

    preview =
      token
      |> authed()
      |> post(~p"/api/admin/media_pieces", Map.put(attrs, :dry_run, true))
      |> json_response(200)

    assert preview["result"] == "would_create"
    refute Repo.get_by(MediaPiece, api_ref: "ptp-2610-joes_tacos-phx.ad")

    created = token |> authed() |> post(~p"/api/admin/media_pieces", attrs) |> json_response(201)
    assert created["result"] == "created"
    assert created["media_piece"]["ad_category_row_id"] == ctx.row.row_id
    assert created["media_piece"]["banner_image"] =~ ".png"

    again = token |> authed() |> post(~p"/api/admin/media_pieces", attrs) |> json_response(200)
    assert again["matched"] == true
    assert again["media_piece"]["id"] == created["media_piece"]["id"]
  end

  test "lists by marketer and category and deletes an unused piece", %{token: token} = ctx do
    created =
      token
      |> authed()
      |> post(~p"/api/admin/media_pieces", params(ctx, %{}))
      |> json_response(201)

    id = created["media_piece"]["id"]

    body =
      token
      |> authed()
      |> get(~p"/api/admin/media_pieces?marketer_id=#{ctx.marketer.id}&row_id=#{ctx.row.row_id}")
      |> json_response(200)

    assert Enum.any?(body["media_pieces"], &(&1["id"] == id))

    body =
      token
      |> authed()
      |> delete(~p"/api/admin/media_pieces/#{id}?dry_run=true")
      |> json_response(200)

    assert body["result"] == "would_delete"
    assert Repo.get(MediaPiece, id)

    body = token |> authed() |> delete(~p"/api/admin/media_pieces/#{id}") |> json_response(200)
    assert body["result"] == "deleted"
    refute Repo.get(MediaPiece, id)
  end
end
