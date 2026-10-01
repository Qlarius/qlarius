defmodule QlariusWeb.Api.Admin.ContentGroupControllerTest do
  use QlariusWeb.ConnCase, async: false

  import Ecto.Query
  import Qlarius.ContentImportHelpers

  alias Qlarius.Accounts.AdminApiTokens
  alias Qlarius.Accounts.User
  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.{ContentGroup, ContentPiece}

  @guide "/api/admin/agent_guide"

  setup do
    stub_feed()
    admin = user("admin")
    {:ok, _token, raw} = AdminApiTokens.issue(admin, "test")
    %{admin: admin, token: raw, catalog: podcast_catalog_fixture()}
  end

  describe "auth" do
    test "refuses a missing token and points at the guide" do
      conn = get(build_conn(), ~p"/api/admin/creators")
      assert %{"error" => "unauthorized", "guide" => @guide} = json_response(conn, 401)
    end

    test "refuses a non-admin token and points at the guide", %{admin: admin, token: token} do
      admin |> Ecto.Changeset.change(role: "user") |> Repo.update!()

      conn = get(authed(token), ~p"/api/admin/creators")
      assert %{"error" => "forbidden", "guide" => @guide} = json_response(conn, 403)
    end
  end

  describe "discovery" do
    test "lists creators with catalogs and groups with piece counts", %{
      token: token,
      catalog: catalog
    } do
      group = content_group_fixture(catalog, %{title: "Existing"})

      creators = authed(token) |> get(~p"/api/admin/creators") |> json_response(200)
      creator = Enum.find(creators["creators"], &(&1["id"] == catalog.creator_id))
      assert [%{"id" => catalog_id}] = creator["catalogs"]
      assert catalog_id == catalog.id

      groups =
        authed(token)
        |> get(~p"/api/admin/content_groups?catalog_id=#{catalog.id}")
        |> json_response(200)

      assert [%{"id" => id, "piece_count" => 0}] = groups["content_groups"]
      assert id == group.id
    end
  end

  describe "packs" do
    test "creates a group with audio and youtube pieces", %{token: token, catalog: catalog} do
      body = post_pack(token, pack(catalog))

      assert body["counts"] == %{"created" => 2, "updated" => 0, "unchanged" => 0, "skipped" => 0}
      assert body["content_group"]["title"] == "Shane and Sally"
      assert body["content_group"]["source_provider"] == "api_pack"

      [audio, video] = pieces(body["content_group"]["id"])
      assert audio.media_type == "audio"
      assert audio.file_url == "https://audio.example.com/e1.mp3"
      assert audio.external_id == "ep-1"
      assert audio.length == 3069
      assert video.media_type == "youtube"
      assert video.youtube_id == "abc123def45"
      assert video.external_id == "abc123def45"
      assert video.source_provider == "youtube"
    end

    test "a repeated update refreshes pieces without duplicating them", %{
      token: token,
      catalog: catalog
    } do
      created = post_pack(token, pack(catalog))
      group_id = created["content_group"]["id"]

      update =
        pack(catalog)
        |> Map.merge(%{"mode" => "update", "content_group" => %{"id" => group_id}})
        |> put_in(["pieces", Access.at(0), "title"], "Episode 1 (remastered)")

      body = post_pack(token, update)
      assert body["counts"] == %{"created" => 0, "updated" => 1, "unchanged" => 1, "skipped" => 0}

      again = post_pack(token, update)
      assert again["counts"]["unchanged"] == 2

      assert [%{title: "Episode 1 (remastered)"}, _] = pieces(group_id)
    end

    test "stores piece art only when it is unique to the piece", %{
      token: token,
      catalog: catalog
    } do
      use_tmp_uploads()
      stub_feed(nil, images: true)

      audio = fn n -> %{"type" => "audio", "url" => "https://audio.example.com/#{n}.mp3"} end

      body =
        post_pack(token, %{
          "mode" => "create",
          "catalog_id" => catalog.id,
          "content_group" => %{
            "title" => "Art",
            "image_url" => "https://cdn.example.com/show.jpg"
          },
          "pieces" => [
            %{
              "title" => "Own",
              "image_url" => "https://cdn.example.com/own.jpg",
              "media" => audio.(1)
            },
            %{
              "title" => "Show",
              "image_url" => "https://cdn.example.com/show.jpg",
              "media" => audio.(2)
            },
            %{
              "title" => "Shared A",
              "image_url" => "https://cdn.example.com/s.jpg",
              "media" => audio.(3)
            },
            %{
              "title" => "Shared B",
              "image_url" => "https://cdn.example.com/s.jpg",
              "media" => audio.(4)
            }
          ]
        })

      assert body["warnings"] == []

      assert [own, nil, nil, nil] =
               body["content_group"]["id"] |> pieces() |> Enum.map(& &1.image)

      assert own
    end

    test "on_existing skip leaves matched pieces alone", %{token: token, catalog: catalog} do
      group_id = post_pack(token, pack(catalog))["content_group"]["id"]

      body =
        post_pack(
          token,
          pack(catalog)
          |> Map.merge(%{
            "mode" => "update",
            "on_existing" => "skip",
            "content_group" => %{"id" => group_id}
          })
        )

      assert body["counts"]["skipped"] == 2
    end

    test "a dry run reports the plan and writes nothing", %{token: token, catalog: catalog} do
      body = post_pack(token, Map.put(pack(catalog), "dry_run", true))

      assert body["dry_run"] == true
      assert body["counts"]["created"] == 2
      refute Repo.exists?(from g in ContentGroup, where: g.catalog_id == ^catalog.id)
    end

    test "missing media and non-https audio are 422 with piece indexes", %{
      token: token,
      catalog: catalog
    } do
      bad =
        Map.put(pack(catalog), "pieces", [
          %{"title" => "No media"},
          %{
            "title" => "Plain http",
            "media" => %{"type" => "audio", "url" => "http://x.com/a.mp3"}
          }
        ])

      conn = authed(token) |> post(~p"/api/admin/content_groups/packs", Jason.encode!(bad))
      body = json_response(conn, 422)

      assert body["error"] == "invalid_pack"
      assert body["guide"] == @guide
      assert %{"index" => 0, "message" => "media is required"} in body["errors"]
      assert Enum.any?(body["errors"], &(&1["index"] == 1 and &1["message"] =~ "https"))
    end

    test "an unknown catalog is 422", %{token: token, catalog: catalog} do
      bad = Map.put(pack(catalog), "catalog_id", -1)
      conn = authed(token) |> post(~p"/api/admin/content_groups/packs", Jason.encode!(bad))
      assert %{"error" => "catalog_not_found", "guide" => @guide} = json_response(conn, 422)
    end
  end

  describe "rss" do
    test "previews a feed", %{token: token} do
      body =
        authed(token)
        |> get(~p"/api/admin/rss/preview?#{[feed_url: feed_url()]}")
        |> json_response(200)

      assert body["channel"]["title"] == "Texas Monthly True Crime"
      assert [%{"season" => 3}, %{"season" => 2}] = body["seasons"]
      assert Enum.any?(body["items"], &(&1["audio_url"] == "https://audio.example.com/s3-e1.mp3"))
    end

    test "imports a season and syncs it", %{token: token, catalog: catalog} do
      body =
        authed(token)
        |> post(
          ~p"/api/admin/content_groups/rss_imports",
          Jason.encode!(%{
            "feed_url" => feed_url(),
            "catalog_id" => catalog.id,
            "season" => 3,
            "group_title" => "Shane and Sally"
          })
        )
        |> json_response(200)

      assert body["counts"]["created"] == 3
      group_id = body["content_group"]["id"]

      synced =
        authed(token)
        |> post(~p"/api/admin/content_groups/#{group_id}/sync", "{}")
        |> json_response(200)

      assert synced["counts"]["created"] == 0
      assert length(pieces(group_id)) == 3
    end

    test "sync with reorder puts the group in episode order", %{token: token, catalog: catalog} do
      group_id =
        authed(token)
        |> post(
          ~p"/api/admin/content_groups/rss_imports",
          Jason.encode!(%{"feed_url" => feed_url(), "catalog_id" => catalog.id, "season" => 3})
        )
        |> json_response(200)
        |> get_in(["content_group", "id"])

      [trailer | _] = pieces(group_id)

      Repo.update_all(from(p in ContentPiece, where: p.id == ^trailer.id),
        set: [display_order: 99]
      )

      body =
        authed(token)
        |> post(~p"/api/admin/content_groups/#{group_id}/sync", Jason.encode!(%{reorder: true}))
        |> json_response(200)

      assert body["reordered"] == true
      assert hd(pieces(group_id)).id == trailer.id
    end

    test "sync on a group without a feed is 422", %{token: token, catalog: catalog} do
      group = content_group_fixture(catalog)

      conn = authed(token) |> post(~p"/api/admin/content_groups/#{group.id}/sync", "{}")
      assert %{"error" => "no_feed_url"} = json_response(conn, 422)
    end
  end

  describe "agent guide" do
    test "returns markdown by default", %{token: token} do
      conn = authed(token) |> get(~p"/api/admin/agent_guide")

      body = response(conn, 200)
      assert [content_type] = get_resp_header(conn, "content-type")
      assert content_type =~ "text/markdown"
      assert body =~ "Authorization: Bearer"
      assert body =~ "/api/admin/content_groups/packs"
    end

    test "returns JSON with topics and endpoints", %{token: token} do
      body =
        authed(token)
        |> get(~p"/api/admin/agent_guide?format=json&topic=content_groups")
        |> json_response(200)

      assert body["topics"] == ["overview", "content_groups"]
      assert body["guide"] =~ "rss_imports"
      assert is_list(body["endpoints"])
    end

    test "an unknown topic is 404", %{token: token} do
      conn = authed(token) |> get(~p"/api/admin/agent_guide?topic=recipes")
      assert %{"error" => "unknown_topic"} = json_response(conn, 404)
    end
  end

  defp pack(catalog) do
    %{
      "mode" => "create",
      "catalog_id" => catalog.id,
      "content_group" => %{"title" => "Shane and Sally", "description" => "A true crime show."},
      "pieces" => [
        %{
          "title" => "Episode 1",
          "external_id" => "ep-1",
          "date_published" => "2024-04-03",
          "length_seconds" => 3069,
          "media" => %{"type" => "audio", "url" => "https://audio.example.com/e1.mp3"}
        },
        %{
          "title" => "Bonus video",
          "media" => %{"type" => "youtube", "youtube_id" => "abc123def45"}
        }
      ]
    }
  end

  defp post_pack(token, pack) do
    authed(token)
    |> post(~p"/api/admin/content_groups/packs", Jason.encode!(pack))
    |> json_response(200)
  end

  defp pieces(group_id) do
    Repo.all(
      from p in ContentPiece,
        where: p.content_group_id == ^group_id,
        order_by: [asc: p.display_order, asc: p.id]
    )
  end

  defp authed(token) do
    build_conn()
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_header("content-type", "application/json")
  end

  defp user(role) do
    %User{}
    |> User.registration_changeset(%{
      "alias" => "api-#{role}-#{System.unique_integer([:positive])}"
    })
    |> Ecto.Changeset.put_change(:role, role)
    |> Repo.insert!()
  end
end
