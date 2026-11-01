defmodule QlariusWeb.Api.Admin.CreatorApiTest do
  use QlariusWeb.ConnCase, async: false

  import Ecto.Query
  import Qlarius.ContentImportHelpers

  alias Qlarius.Accounts.{AdminApiTokens, User}
  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.{Catalog, ContentGroup, ContentPiece}

  setup do
    admin =
      %User{}
      |> User.registration_changeset(%{
        "alias" => "creator-api-#{System.unique_integer([:positive])}"
      })
      |> Ecto.Changeset.put_change(:role, "admin")
      |> Repo.insert!()

    {:ok, _token, raw} = AdminApiTokens.issue(admin, "creators")
    %{token: raw, admin: admin}
  end

  defp authed(token), do: build_conn() |> put_req_header("authorization", "Bearer #{token}")

  defp post_json(token, path, params),
    do: token |> authed() |> post(path, params) |> json_response(200)

  defp post_created(token, path, params),
    do: token |> authed() |> post(path, params) |> json_response(201)

  test "creates a publisher, catalog, group, and pieces once per api_ref", %{
    token: token,
    admin: admin
  } do
    created =
      post_created(token, ~p"/api/admin/creators", %{
        api_ref: "pub-2610-north_shore.creator",
        name: "North Shore",
        bio: "Harbor stories.",
        recipient: %{
          site_url: "https://northshore.example",
          description: "A publisher",
          message: "Thanks for reading.",
          recipient_type_id: 1
        }
      })

    assert created["result"] == "created"
    assert created["matched"] == false
    creator_id = created["creator"]["id"]
    recipient = created["creator"]["recipient"]
    assert recipient["recipient_type_id"] == 1
    assert recipient["split_code"]
    assert recipient["site_url"] == "https://northshore.example"
    assert recipient["user_id"] == admin.id
    assert recipient["approval_date"]

    listed = token |> authed() |> get(~p"/api/admin/creators") |> json_response(200)
    listed_creator = Enum.find(listed["creators"], &(&1["id"] == creator_id))
    assert listed_creator["api_ref"] == "pub-2610-north_shore.creator"
    assert listed_creator["recipient"]["id"] == recipient["id"]
    assert listed_creator["catalogs"] == []

    again =
      post_json(token, ~p"/api/admin/creators", %{
        api_ref: "pub-2610-north_shore.creator",
        name: "North Shore",
        recipient: %{site_url: "https://northshore.example", recipient_type_id: 1}
      })

    assert again["result"] == "matched"
    assert again["matched"] == true
    assert again["creator"]["id"] == creator_id

    assert Repo.aggregate(
             from(c in Qlarius.Creators.Creator,
               where: c.api_ref == "pub-2610-north_shore.creator"
             ),
             :count
           ) == 1

    catalog =
      post_created(token, ~p"/api/admin/creators/#{creator_id}/catalogs", %{
        api_ref: "pub-2610-north_shore.catalog",
        name: "North Shore",
        url: "https://northshore.example",
        type: "catalog",
        group_type: "show",
        piece_type: "episode"
      })

    catalog_id = catalog["catalog"]["id"]

    matched_catalog =
      post_json(token, ~p"/api/admin/creators/#{creator_id}/catalogs", %{
        api_ref: "pub-2610-north_shore.catalog",
        name: "North Shore",
        url: "https://northshore.example",
        type: "catalog",
        group_type: "show",
        piece_type: "episode"
      })

    assert matched_catalog["result"] == "matched"
    assert matched_catalog["catalog"]["id"] == catalog_id

    group =
      post_created(token, ~p"/api/admin/catalogs/#{catalog_id}/content_groups", %{
        api_ref: "pub-2610-north_shore.group",
        title: "Season One"
      })

    group_id = group["content_group"]["id"]
    assert group["content_group"]["feed_auto_sync"] == false

    pieces =
      for {ref, title} <- [
            {"pub-2610-north_shore.ep1", "One"},
            {"pub-2610-north_shore.ep2", "Two"},
            {"pub-2610-north_shore.ep3", "Three"}
          ] do
        post_created(token, ~p"/api/admin/content_groups/#{group_id}/pieces", %{
          api_ref: ref,
          title: title,
          date_published: "2024-04-03"
        })
      end

    ids = Enum.map(pieces, & &1["content_piece"]["id"])
    assert length(Enum.uniq(ids)) == 3

    again_piece =
      post_json(token, ~p"/api/admin/content_groups/#{group_id}/pieces", %{
        api_ref: "pub-2610-north_shore.ep1",
        title: "One",
        date_published: "2024-04-03"
      })

    assert again_piece["result"] == "matched"
    assert Repo.aggregate(ContentPiece, :count, :id) >= 3

    classes =
      token
      |> authed()
      |> get(~p"/api/admin/tiqit_classes?catalog_id=#{catalog_id}")
      |> json_response(200)

    assert classes["count"] > 0

    piece_classes =
      token
      |> authed()
      |> get(~p"/api/admin/tiqit_classes?content_piece_id=#{hd(ids)}")
      |> json_response(200)

    assert piece_classes["count"] > 0

    priced =
      token
      |> authed()
      |> patch(~p"/api/admin/content_pieces/#{hd(ids)}", %{price_default: "1.00"})
      |> json_response(422)

    assert priced["error"] == "price_not_writable"

    embeds =
      token
      |> authed()
      |> get(~p"/api/admin/creators/#{creator_id}/embeds")
      |> json_response(200)

    assert embeds["embeds"]["split_code"] == recipient["split_code"]
    assert embeds["embeds"]["scripts"]["sponster"] == "/sponster-tipjar-widget-ext-script.js"
    assert embeds["embeds"]["scripts"]["arqade"] == "/tiqit-arqade-widget-script.js"

    assert embeds["embeds"]["widgets"]["sponster_bar"] ==
             "/widgets/ads_ext/#{recipient["split_code"]}"

    assert embeds["embeds"]["widgets"]["creator"] == "/widgets/arqade/creator/#{creator_id}"

    assert embeds["embeds"]["widgets"]["catalogs"] |> hd() |> Map.get("path") =~
             "/widgets/arqade/catalog/"

    [first, second, third] = ids

    patched =
      token
      |> authed()
      |> patch(~p"/api/admin/content_pieces/#{first}", %{description: "Hand edited."})
      |> json_response(200)

    assert patched["content_piece"]["description"] == "Hand edited."

    reordered =
      token
      |> authed()
      |> post(~p"/api/admin/content_groups/#{group_id}/pieces/reorder", %{
        piece_ids: [third, first, second]
      })
      |> json_response(200)

    assert reordered["result"] == "reordered"

    archived =
      token
      |> authed()
      |> post(~p"/api/admin/content_pieces/#{first}/archive")
      |> json_response(200)

    assert archived["content_piece"]["archived_at"]

    deleted =
      token
      |> authed()
      |> delete(~p"/api/admin/content_pieces/#{first}")
      |> json_response(409)

    assert deleted["error"] == "has_dependents"

    catalog_delete =
      token
      |> authed()
      |> delete(~p"/api/admin/catalogs/#{catalog_id}?dry_run=true")
      |> json_response(409)

    assert catalog_delete["error"] == "has_dependents"
    assert catalog_delete["dependents"]["content_groups"] >= 1
    assert Repo.get(Catalog, catalog_id)
  end

  test "rss dry run reports kept, dropped, and cleaned, and sync keeps an edit", %{token: token} do
    stub_feed()

    creator =
      post_created(token, ~p"/api/admin/creators", %{
        api_ref: "pub-2610-true_crime.creator",
        name: "True Crime",
        recipient: %{site_url: "https://crime.example"}
      })

    catalog =
      post_created(token, ~p"/api/admin/creators/#{creator["creator"]["id"]}/catalogs", %{
        api_ref: "pub-2610-true_crime.catalog",
        name: "True Crime",
        url: "https://crime.example",
        type: "catalog",
        group_type: "show",
        piece_type: "episode"
      })

    params = %{
      api_ref: "pub-2610-true_crime.group",
      feed_url: feed_url(),
      catalog_id: catalog["catalog"]["id"],
      season: 3,
      strip_patterns: ["Where it began."],
      drop_patterns: ["Trial"],
      dry_run: true
    }

    before_groups = Repo.aggregate(ContentGroup, :count, :id)
    preview = post_json(token, ~p"/api/admin/content_groups/rss_imports", params)
    assert preview["dry_run"] == true
    assert preview["kept"] >= 1
    assert preview["dropped"] >= 1
    assert preview["cleaned"] >= 1
    assert Repo.aggregate(ContentGroup, :count, :id) == before_groups

    imported =
      token
      |> authed()
      |> post(~p"/api/admin/content_groups/rss_imports", Map.delete(params, :dry_run))
      |> json_response(200)

    group_id = imported["content_group"]["id"]
    piece = Repo.get_by!(ContentPiece, content_group_id: group_id, external_id: "tm-s3-e1")
    refute piece.description =~ "Where it began."
    refute Repo.get_by(ContentPiece, content_group_id: group_id, external_id: "tm-s3-e2")

    {:ok, _} =
      piece
      |> Ecto.Changeset.change(%{description: "Hand edited."})
      |> Repo.update()

    synced =
      token
      |> authed()
      |> post(~p"/api/admin/content_groups/#{group_id}/sync", %{})
      |> json_response(200)

    assert synced["dry_run"] == false
    assert Repo.get!(ContentPiece, piece.id).description == "Hand edited."
  end

  test "youtube import does not duplicate, and a missing key is 503", %{token: token} do
    previous = Application.get_env(:qlarius, :youtube)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:qlarius, :youtube, previous),
        else: Application.delete_env(:qlarius, :youtube)
    end)

    Application.put_env(:qlarius, :youtube, [])

    missing =
      token
      |> authed()
      |> get(~p"/api/admin/youtube/preview", %{
        "input" => "https://www.youtube.com/playlist?list=PLtestplaylist1"
      })
      |> json_response(503)

    assert missing["error"] == "youtube_unavailable"

    Application.put_env(:qlarius, :youtube,
      api_key: "test-key",
      req_options: [plug: {Req.Test, Qlarius.Youtube.Client}]
    )

    Req.Test.stub(Qlarius.Youtube.Client, fn conn ->
      body =
        case conn.request_path do
          "/youtube/v3/playlists" ->
            %{"items" => [%{"snippet" => %{"title" => "Harbor", "description" => "Clips"}}]}

          "/youtube/v3/playlistItems" ->
            %{
              "items" => [
                %{
                  "snippet" => %{"title" => "Clip", "description" => "A clip", "position" => 0},
                  "contentDetails" => %{"videoId" => "abcdefghijk"}
                }
              ]
            }

          "/youtube/v3/videos" ->
            %{
              "items" => [
                %{
                  "id" => "abcdefghijk",
                  "contentDetails" => %{"duration" => "PT1M"},
                  "snippet" => %{
                    "description" => "A clip",
                    "publishedAt" => "2024-04-03T00:00:00Z"
                  }
                }
              ]
            }
        end

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(body))
    end)

    creator =
      post_created(token, ~p"/api/admin/creators", %{
        api_ref: "pub-2610-harbor.creator",
        name: "Harbor",
        recipient: %{site_url: "https://harbor.example"}
      })

    catalog =
      post_created(token, ~p"/api/admin/creators/#{creator["creator"]["id"]}/catalogs", %{
        api_ref: "pub-2610-harbor.catalog",
        name: "Harbor",
        url: "https://harbor.example",
        type: "catalog",
        group_type: "show",
        piece_type: "episode"
      })

    body = %{
      api_ref: "pub-2610-harbor.group",
      catalog_id: catalog["catalog"]["id"],
      input: "https://www.youtube.com/playlist?list=PLtestplaylist1"
    }

    imported = post_created(token, ~p"/api/admin/content_groups/youtube_imports", body)
    assert imported["content_group"]["feed_auto_sync"] == false
    assert imported["pieces"] |> Enum.map(& &1["result"]) == ["created"]

    again = post_json(token, ~p"/api/admin/content_groups/youtube_imports", body)
    assert again["result"] == "matched"
    assert again["pieces"] |> Enum.map(& &1["result"]) == ["matched"]

    assert Repo.aggregate(
             from(g in ContentGroup, where: g.api_ref == "pub-2610-harbor.group"),
             :count
           ) == 1

    assert Repo.aggregate(from(p in ContentPiece, where: p.external_id == "abcdefghijk"), :count) ==
             1
  end

  test "the creators guide is listed", %{token: token} do
    body =
      token
      |> authed()
      |> get(~p"/api/admin/agent_guide?topic=creators&format=json")
      |> json_response(200)

    assert body["topics"] == ["overview", "creators"]
    assert body["guide"] =~ "strip_patterns"
    assert body["guide"] =~ "Cities West Media"
    assert body["guide"] =~ "PHOENIX Magazine"
    assert body["guide"] =~ "Phoenix Home & Garden"
    assert Enum.any?(body["endpoints"], &(&1["path"] == "/api/admin/creators/:id/embeds"))
    assert Enum.any?(body["endpoints"], &(&1["path"] == "/api/admin/creators/:id/recipients"))
  end

  test "dry run and create keep the nested recipient as the primary", %{token: token} do
    payload = %{
      api_ref: "cities-west.creator",
      name: "Cities West Media",
      recipient: %{
        api_ref: "cities-west.phoenix-magazine",
        name: "PHOENIX Magazine",
        site_url: "https://phoenixmag.com",
        recipient_type_id: 1
      }
    }

    preview = post_json(token, ~p"/api/admin/creators", Map.put(payload, :dry_run, true))
    assert preview["result"] == "would_create"
    assert preview["creator"]["recipient"]["api_ref"] == "cities-west.phoenix-magazine"
    assert preview["creator"]["recipient"]["is_primary"] == true
    assert preview["creator"]["recipient"]["name"] == "PHOENIX Magazine"
    assert preview["creator"]["recipient"]["site_url"] == "https://phoenixmag.com"

    preview_recipient = hd(preview["creator"]["recipients"])
    assert preview_recipient["api_ref"] == "cities-west.phoenix-magazine"
    assert preview_recipient["is_primary"] == true

    created = post_created(token, ~p"/api/admin/creators", payload)
    recipient = created["creator"]["recipient"]
    assert recipient["api_ref"] == "cities-west.phoenix-magazine"
    assert recipient["is_primary"] == true
    assert hd(created["creator"]["recipients"])["id"] == recipient["id"]

    creator = Repo.get!(Qlarius.Creators.Creator, created["creator"]["id"])
    assert creator.recipient_id == recipient["id"]

    saved = Repo.get!(Qlarius.Sponster.Recipient, recipient["id"])
    assert saved.api_ref == "cities-west.phoenix-magazine"
    assert saved.is_primary
    assert saved.creator_id == creator.id

    again = post_json(token, ~p"/api/admin/creators", payload)
    assert again["result"] == "matched"
    assert again["creator"]["id"] == creator.id
    assert again["creator"]["recipient"]["id"] == recipient["id"]
    assert again["creator"]["recipient"]["api_ref"] == "cities-west.phoenix-magazine"
    assert again["creator"]["recipient"]["is_primary"] == true

    conflict =
      token
      |> authed()
      |> post(~p"/api/admin/creators", %{
        api_ref: "cities-west.other",
        name: "Other Media",
        recipient: %{
          api_ref: "cities-west.phoenix-magazine",
          name: "PHOENIX Magazine",
          site_url: "https://phoenixmag.com"
        }
      })

    assert json_response(conflict, 422)["error"] == "api_ref_conflict"

    sister =
      post_created(token, ~p"/api/admin/creators/#{creator.id}/recipients", %{
        api_ref: "cities-west.phg",
        name: "Phoenix Home & Garden",
        site_url: "https://phgmag.com"
      })

    assert sister["recipient"]["is_primary"] == false
    assert sister["recipient"]["api_ref"] == "cities-west.phg"
  end

  test "adds a sister recipient, keeps api_ref idempotent, and maps catalogs", %{
    token: token,
    admin: admin
  } do
    created =
      post_created(token, ~p"/api/admin/creators", %{
        api_ref: "cities-west.creator",
        name: "Cities West Media",
        recipient: %{
          api_ref: "cities-west.phoenix-magazine",
          name: "PHOENIX Magazine",
          site_url: "https://phoenixmag.com"
        }
      })

    creator_id = created["creator"]["id"]
    primary = created["creator"]["recipient"]
    assert primary["is_primary"] == true
    assert primary["name"] == "PHOENIX Magazine"
    assert hd(created["creator"]["recipients"])["id"] == primary["id"]

    second =
      post_created(token, ~p"/api/admin/creators/#{creator_id}/recipients", %{
        api_ref: "cities-west.phg",
        name: "Phoenix Home & Garden",
        site_url: "https://phgmag.com"
      })

    assert second["result"] == "created"
    assert second["recipient"]["is_primary"] == false
    assert second["recipient"]["user_id"] == admin.id
    assert second["recipient"]["split_code"]
    assert second["recipient"]["approval_date"]
    refute second["recipient"]["split_code"] == primary["split_code"]

    again =
      post_json(token, ~p"/api/admin/creators/#{creator_id}/recipients", %{
        api_ref: "cities-west.phg",
        name: "Phoenix Home & Garden",
        site_url: "https://phgmag.com"
      })

    assert again["result"] == "matched"
    assert again["recipient"]["id"] == second["recipient"]["id"]

    priced =
      token
      |> authed()
      |> post(~p"/api/admin/creators/#{creator_id}/recipients", %{
        api_ref: "cities-west.priced",
        name: "Priced",
        site_url: "https://priced.example",
        price: "1.00"
      })

    assert json_response(priced, 422)["error"] == "price_not_writable"

    phg_catalog =
      post_created(token, ~p"/api/admin/creators/#{creator_id}/catalogs", %{
        api_ref: "cities-west.phg.catalog",
        name: "Home & Garden",
        url: "https://phgmag.com",
        type: "catalog",
        group_type: "section",
        piece_type: "article",
        recipient_id: second["recipient"]["id"]
      })

    assert phg_catalog["catalog"]["recipient_id"] == second["recipient"]["id"]

    phoenix_catalog =
      post_created(token, ~p"/api/admin/creators/#{creator_id}/catalogs", %{
        api_ref: "cities-west.phoenix.catalog",
        name: "PHOENIX Magazine",
        url: "https://phoenixmag.com",
        type: "catalog",
        group_type: "section",
        piece_type: "article"
      })

    assert phoenix_catalog["catalog"]["recipient_id"] == primary["id"]

    standalone =
      post_created(token, ~p"/api/admin/recipients", %{
        api_ref: "cities-west.standalone",
        name: "Standalone",
        site_url: "https://standalone.example"
      })

    rejected =
      token
      |> authed()
      |> post(~p"/api/admin/creators/#{creator_id}/catalogs", %{
        api_ref: "cities-west.bad-catalog",
        name: "Wrong recipient",
        url: "https://example.com/wrong",
        type: "catalog",
        group_type: "section",
        piece_type: "article",
        recipient_id: standalone["recipient"]["id"]
      })

    assert json_response(rejected, 422)["error"] == "invalid"

    embeds =
      token
      |> authed()
      |> get(~p"/api/admin/creators/#{creator_id}/embeds")
      |> json_response(200)

    assert embeds["embeds"]["split_code"] == primary["split_code"]

    assert embeds["embeds"]["widgets"]["sponster_bar"] ==
             "/widgets/ads_ext/#{primary["split_code"]}"

    phg =
      Enum.find(embeds["embeds"]["recipients"], &(&1["id"] == second["recipient"]["id"]))

    assert phg["split_code"] == second["recipient"]["split_code"]
    assert phg["sponster_bar"] == "/widgets/ads_ext/#{phg["split_code"]}"
    assert phg["insta_tip"] == "/widgets/insta_tip?split_code=#{phg["split_code"]}"
    assert Enum.any?(phg["catalogs"], &(&1["id"] == phg_catalog["catalog"]["id"]))

    listed = token |> authed() |> get(~p"/api/admin/creators") |> json_response(200)
    row = Enum.find(listed["creators"], &(&1["id"] == creator_id))
    assert row["recipient"]["id"] == primary["id"]

    assert Enum.map(row["recipients"], & &1["id"]) |> Enum.sort() ==
             Enum.sort([primary["id"], second["recipient"]["id"]])

    primary_delete =
      token
      |> authed()
      |> delete(~p"/api/admin/creators/#{creator_id}/recipients/#{primary["id"]}")

    assert json_response(primary_delete, 422)["error"] == "primary_recipient"

    removed =
      token
      |> authed()
      |> delete(~p"/api/admin/creators/#{creator_id}/recipients/#{second["recipient"]["id"]}")

    assert json_response(removed, 409)["error"] == "has_dependents"
  end

  test "patches a recipient graphic_url and exposes it as an absolute URL (including in embeds)",
       %{
         token: token,
         admin: admin
       } do
    use_tmp_uploads()

    png =
      Base.decode64!(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMB/edn9V8AAAAASUVORK5CYII="
      )

    Req.Test.stub(Qlarius.Tiqit.Arcade.ImportHttp, fn conn ->
      case conn.request_path do
        "/brand.png" ->
          conn
          |> Plug.Conn.put_resp_content_type("image/png")
          |> Plug.Conn.send_resp(200, png)

        _ ->
          Plug.Conn.send_resp(conn, 404, "")
      end
    end)

    created =
      post_created(token, ~p"/api/admin/creators", %{
        api_ref: "pub-graphic-url.creator",
        name: "Graphic URL Creator",
        recipient: %{
          site_url: "https://graphic-url.example",
          recipient_type_id: 1
        }
      })

    creator_id = created["creator"]["id"]
    recipient = created["creator"]["recipient"]
    recipient_id = recipient["id"]
    assert recipient["user_id"] == admin.id

    patched =
      token
      |> authed()
      |> patch(~p"/api/admin/creators/#{creator_id}/recipients/#{recipient_id}", %{
        graphic_url: "https://images.example.com/brand.png"
      })
      |> json_response(200)

    assert patched["result"] == "updated"
    assert patched["recipient"]["id"] == recipient_id
    assert is_binary(patched["recipient"]["graphic_url"])
    assert %URI{scheme: scheme, host: host} = URI.parse(patched["recipient"]["graphic_url"])
    assert scheme in ["http", "https"]
    assert is_binary(host) and host != ""

    embeds =
      token
      |> authed()
      |> get(~p"/api/admin/creators/#{creator_id}/embeds")
      |> json_response(200)

    assert embeds["embeds"]["graphic_url"] == patched["recipient"]["graphic_url"]

    embed_recipient =
      Enum.find(embeds["embeds"]["recipients"], &(&1["id"] == recipient_id))

    assert embed_recipient["graphic_url"] == patched["recipient"]["graphic_url"]
  end
end
