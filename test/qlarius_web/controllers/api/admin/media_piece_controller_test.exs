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

  defp banner(filename \\ "banner.png") do
    path = Path.join(System.tmp_dir!(), "banner-#{System.unique_integer([:positive])}.png")
    File.write!(path, @png)

    %Plug.Upload{path: path, filename: filename, content_type: "image/png"}
  end

  defp stored_banners(stem) do
    dir =
      Path.join([
        :code.priv_dir(:qlarius),
        "static",
        "uploads",
        "media_pieces",
        "banners",
        "three_tap_banners"
      ])

    case File.ls(dir) do
      {:ok, names} -> Enum.filter(names, &String.starts_with?(&1, stem))
      _ -> []
    end
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

  test "rejects a 3-tap title or body that will not fit the panel", %{token: token} = ctx do
    long_title = String.duplicate("A", MediaPiece.three_tap_title_max() + 1)

    body =
      token
      |> authed()
      |> post(~p"/api/admin/media_pieces", params(ctx, %{title: long_title}))
      |> json_response(422)

    assert body["error"] == "invalid"
    assert body["errors"]["title"]

    long_body = String.duplicate("a", MediaPiece.three_tap_body_max() + 1)

    body =
      token
      |> authed()
      |> post(~p"/api/admin/media_pieces", params(ctx, %{body_copy: long_body}))
      |> json_response(422)

    assert body["errors"]["body_copy"]
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

  test "names the banner from the api_ref and a real file name", %{token: token} = ctx do
    n = System.unique_integer([:positive])
    ref = "ptp-2610-joes_tacos-phx.ad-#{n}"

    created =
      token
      |> authed()
      |> post(
        ~p"/api/admin/media_pieces",
        params(ctx, %{api_ref: ref, banner_image: banner("Summer Sale.PNG")})
      )
      |> json_response(201)

    assert created["media_piece"]["banner_image"] =~
             ~r/^ptp-2610-joes_tacos-phx-ad-#{n}-summer-sale-[0-9a-f]{8}\.png$/
  end

  test "a file named banner.png is stored under the api_ref", %{token: token} = ctx do
    n = System.unique_integer([:positive])
    ref = "ptp-2610-joes_tacos-phx.ad-#{n}"

    created =
      token
      |> authed()
      |> post(~p"/api/admin/media_pieces", params(ctx, %{api_ref: ref}))
      |> json_response(201)

    assert created["media_piece"]["banner_image"] =~
             ~r/^ptp-2610-joes_tacos-phx-ad-#{n}-[0-9a-f]{8}\.png$/
  end

  test "dry run does not write the banner file", %{token: token} = ctx do
    n = System.unique_integer([:positive])
    stem = "dry-piece-#{n}"

    preview =
      token
      |> authed()
      |> post(
        ~p"/api/admin/media_pieces",
        params(ctx, %{dry_run: true, banner_image: banner("#{stem}.png")})
      )
      |> json_response(200)

    assert preview["result"] == "would_create"
    assert stored_banners("#{stem}-") == []
  end

  test "a storage failure is returned instead of a cast error" do
    message = "No free media file name for banner.png after 20 tries"

    body =
      build_conn()
      |> QlariusWeb.Api.Admin.Responder.error({:upload_failed, :banner_image, message})
      |> json_response(422)

    assert body["error"] == "invalid"
    assert body["message"] == message
    assert body["errors"]["banner_image"] == [message]
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
