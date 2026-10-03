defmodule QlariusWeb.Api.Admin.CampaignBuildControllerTest do
  use QlariusWeb.ConnCase, async: false

  alias Qlarius.Accounts.{AdminApiTokens, User}
  alias Qlarius.AdCategoryFixtures
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.Campaign
  alias Qlarius.TargetingFixtures

  @png <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8,
         2, 0, 0, 0, 144, 119, 83, 222, 0, 0, 0, 12, 73, 68, 65, 84, 8, 215, 99, 248, 255, 255,
         63, 0, 5, 254, 2, 254, 167, 53, 129, 132, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130>>

  setup do
    admin =
      %User{}
      |> User.registration_changeset(%{
        "alias" => "api-admin-#{System.unique_integer([:positive])}"
      })
      |> Ecto.Changeset.put_change(:role, "admin")
      |> Repo.insert!()

    {:ok, _token, raw} = AdminApiTokens.issue(admin, "test")
    AdCategoryFixtures.ensure_three_tap_type!()

    %{token: raw, row: AdCategoryFixtures.row_fixture(), n: System.unique_integer([:positive])}
  end

  defp authed(token), do: build_conn() |> put_req_header("authorization", "Bearer #{token}")

  defp banner do
    path = Path.join(System.tmp_dir!(), "banner-#{System.unique_integer([:positive])}.png")
    File.write!(path, @png)
    %Plug.Upload{path: path, filename: "banner.png", content_type: "image/png"}
  end

  test "builds trait groups, a target, a sequence, and a throttled PTP campaign", %{
    token: token,
    row: row,
    n: n
  } do
    parent = TargetingFixtures.parent_trait_fixture()
    food = TargetingFixtures.trait_fixture(parent, "Food #{n}")
    local = TargetingFixtures.trait_fixture(parent, "Local #{n}")
    conn = authed(token)
    ref = "ptp-2610-brand#{n}-phx"
    marketer = marketer_id(conn, ref)

    group =
      conn
      |> post(~p"/api/admin/trait_groups", %{
        api_ref: "#{ref}.tg-food",
        title: "Food",
        marketer_id: marketer,
        parent_trait_id: parent.id,
        trait_ids: [food.id],
        dry_run: true
      })
      |> json_response(200)

    assert group["result"] == "would_create"

    created =
      conn
      |> post(~p"/api/admin/trait_groups", %{
        api_ref: "#{ref}.tg-food",
        title: "Food",
        marketer_id: marketer,
        parent_trait_id: parent.id,
        trait_ids: [food.id]
      })
      |> json_response(201)

    assert created["trait_group"]["trait_ids"] == [food.id]

    again =
      conn
      |> post(~p"/api/admin/trait_groups", %{
        api_ref: "#{ref}.tg-food",
        title: "Food",
        marketer_id: marketer,
        parent_trait_id: parent.id,
        trait_ids: [food.id]
      })
      |> json_response(200)

    assert again["result"] == "matched"
    assert again["matched"] == true

    place =
      conn
      |> post(~p"/api/admin/trait_groups", %{
        api_ref: "#{ref}.tg-place",
        title: "Place",
        marketer_id: marketer,
        parent_trait_id: parent.id,
        trait_ids: [local.id]
      })
      |> json_response(201)

    food_id = created["trait_group"]["id"]
    place_id = place["trait_group"]["id"]

    preview =
      conn
      |> post(~p"/api/admin/targets/builds", %{
        api_ref: "#{ref}.target",
        marketer_id: marketer,
        title: "Phoenix",
        bullseye: [food_id, place_id],
        drop_order: [food_id],
        dry_run: true
      })
      |> json_response(200)

    assert preview["result"] == "would_create"
    assert length(preview["bands"]) == 2
    assert hd(preview["bands"])["reach_note"] =~ "Near-zero"

    target =
      conn
      |> post(~p"/api/admin/targets/builds", %{
        api_ref: "#{ref}.target",
        marketer_id: marketer,
        title: "Phoenix",
        bullseye: [food_id, place_id],
        drop_order: [food_id]
      })
      |> json_response(201)

    assert length(target["target"]["bands"]) == 2
    assert hd(target["target"]["bands"])["label"] == "Bullseye"

    piece = media_piece(conn, ref, marketer, row)

    sequence =
      conn
      |> post(~p"/api/admin/media_sequences", %{
        api_ref: "#{ref}.seq",
        marketer_id: marketer,
        media_piece_id: piece,
        title: "Joe sequence"
      })
      |> json_response(201)

    assert "frequency" in sequence["defaults_used"]
    assert hd(sequence["media_sequence"]["runs"])["frequency"] == 3
    assert hd(sequence["media_sequence"]["runs"])["frequency_buffer_hours"] == 96

    bids =
      conn
      |> post(~p"/api/admin/campaigns/bid_preview", %{
        marketer_id: marketer,
        target_id: target["target"]["id"],
        media_sequence_id: sequence["media_sequence"]["id"]
      })
      |> json_response(200)

    assert Enum.map(bids["bids"], & &1["offer_amt"]) == ["0.11", "0.10"]

    campaign =
      conn
      |> post(~p"/api/admin/campaigns", %{
        api_ref: "#{ref}.campaign",
        marketer_id: marketer,
        target_id: target["target"]["id"],
        media_sequence_id: sequence["media_sequence"]["id"],
        title: "Joe PTP",
        is_ptp: true
      })
      |> json_response(201)

    assert campaign["record"]["is_ptp"] == true
    assert campaign["record"]["is_payable"] == false
    assert campaign["record"]["is_throttled"] == true
    assert campaign["record"]["status"] == "draft"

    refused =
      conn
      |> post(~p"/api/admin/campaigns/#{campaign["record"]["id"]}/launch", %{})
      |> json_response(422)

    assert refused["error"] == "confirm_required"

    launched =
      conn
      |> post(~p"/api/admin/campaigns/#{campaign["record"]["id"]}/launch", %{confirm: true})
      |> json_response(200)

    assert launched["result"] == "launched"

    blocked =
      conn
      |> delete(~p"/api/admin/campaigns/#{campaign["record"]["id"]}?dry_run=true")
      |> json_response(409)

    assert blocked["error"] == "launched"
  end

  test "a PTP build dry run writes nothing and a rerun matches", %{token: token, row: row, n: n} do
    parent = TargetingFixtures.parent_trait_fixture()
    trait = TargetingFixtures.trait_fixture(parent)
    before = Repo.aggregate(Campaign, :count)
    base = "ptp-2610-brand#{n}-nat"
    conn = authed(token)

    params = %{
      api_ref_base: base,
      marketer: %{business_name: "Brand #{n}", business_url: "https://brand#{n}.example"},
      media_piece: %{
        title: "Banner",
        media_piece_type_id: 1,
        ad_category_row_id: row.row_id,
        display_url: "brand.example",
        jump_url: "https://brand.example/go",
        banner_image: banner()
      },
      trait_groups: [%{title: "Fans", parent_trait_id: parent.id, trait_ids: [trait.id]}],
      target: %{title: "National", drop_order: []},
      sequence: %{title: "Run"},
      campaign: %{title: "Pump"}
    }

    dry =
      conn
      |> post(~p"/api/admin/ptp_campaigns/builds", Map.put(params, :dry_run, true))
      |> json_response(200)

    assert dry["result"] == "would_create"
    assert Repo.aggregate(Campaign, :count) == before
    assert dry["api_refs"]["campaign"] == base <> ".campaign"

    created =
      conn
      |> post(
        ~p"/api/admin/ptp_campaigns/builds",
        Map.put(params, :banner_image, banner())
        |> put_in([:media_piece, :banner_image], banner())
      )
      |> json_response(201)

    assert created["result"] == "created"
    assert created["campaign_id"]
    campaign = Repo.get!(Campaign, created["campaign_id"])
    assert campaign.is_ptp
    assert campaign.is_throttled
    refute campaign.is_payable
    assert is_nil(campaign.launched_at)

    matched =
      conn
      |> post(
        ~p"/api/admin/ptp_campaigns/builds",
        put_in(params, [:media_piece, :banner_image], banner())
      )
      |> json_response(200)

    assert matched["result"] == "matched"
    assert matched["campaign_id"] == created["campaign_id"]
  end

  test "a multipart PTP build accepts a JSON payload beside the banner file", %{
    token: token,
    row: row,
    n: n
  } do
    parent = TargetingFixtures.parent_trait_fixture()
    first = TargetingFixtures.trait_fixture(parent, "First #{n}")
    second = TargetingFixtures.trait_fixture(parent, "Second #{n}")
    base = "ptp-2610-brand#{n}-file"
    conn = authed(token)

    payload =
      Jason.encode!(%{
        api_ref_base: base,
        dry_run: true,
        marketer: %{business_name: "Brand #{n}", business_url: "https://brand#{n}.example"},
        media_piece: %{
          title: "Banner",
          media_piece_type_id: 1,
          ad_category_row_id: row.row_id,
          display_url: "brand.example",
          jump_url: "https://brand.example/go"
        },
        trait_groups: [
          %{title: "Fans", parent_trait_id: parent.id, trait_ids: [first.id, second.id]},
          %{title: "Local", parent_trait_id: parent.id, trait_ids: [second.id]}
        ],
        target: %{title: "Both", drop_order: [0]},
        sequence: %{title: "Run"},
        campaign: %{title: "Pump"}
      })

    dry =
      conn
      |> post(~p"/api/admin/ptp_campaigns/builds", %{
        "payload" => payload,
        "banner_image" => banner()
      })
      |> json_response(200)

    assert dry["result"] == "would_create"
    assert dry["api_refs"]["trait_groups"] == ["#{base}.tg-1", "#{base}.tg-2"]

    bad =
      conn
      |> post(~p"/api/admin/ptp_campaigns/builds", %{"payload" => "{", "banner_image" => banner()})
      |> json_response(422)

    assert bad["error"] == "invalid_payload"
  end

  test "index-keyed trait groups are lists and a trait error is JSON", %{
    token: token,
    row: row,
    n: n
  } do
    parent = TargetingFixtures.parent_trait_fixture()
    first = TargetingFixtures.trait_fixture(parent, "Indexed #{n}")
    second = TargetingFixtures.trait_fixture(parent, "Other #{n}")
    base = "ptp-2610-brand#{n}-idx"
    conn = authed(token)

    dry =
      conn
      |> post(~p"/api/admin/ptp_campaigns/builds", %{
        "api_ref_base" => base,
        "dry_run" => "true",
        "marketer" => %{"business_name" => "Brand #{n}"},
        "media_piece" => %{
          "title" => "Banner",
          "media_piece_type_id" => "1",
          "ad_category_row_id" => row.row_id,
          "display_url" => "brand.example",
          "jump_url" => "https://brand.example/go",
          "banner_image" => banner()
        },
        "trait_groups" => %{
          "0" => %{
            "title" => "Fans",
            "parent_trait_id" => to_string(parent.id),
            "trait_ids" => %{"0" => to_string(first.id), "1" => to_string(second.id)}
          },
          "1" => %{
            "title" => "Local",
            "parent_trait_id" => to_string(parent.id),
            "trait_ids" => %{"0" => to_string(second.id)}
          }
        },
        "target" => %{"title" => "Both", "drop_order" => %{"0" => "0"}},
        "sequence" => %{"title" => "Run"},
        "campaign" => %{"title" => "Pump"}
      })
      |> json_response(200)

    assert dry["result"] == "would_create"
    assert length(dry["api_refs"]["trait_groups"]) == 2

    refused =
      conn
      |> post(~p"/api/admin/ptp_campaigns/builds", %{
        "api_ref_base" => base <> "b",
        "marketer" => %{"business_name" => "Brand #{n}"},
        "media_piece" => %{
          "title" => "Banner",
          "media_piece_type_id" => 1,
          "ad_category_row_id" => row.row_id,
          "display_url" => "brand.example",
          "jump_url" => "https://brand.example/go",
          "banner_image" => banner()
        },
        "trait_groups" => [
          %{"title" => "Bad", "parent_trait_id" => parent.id, "trait_ids" => [parent.id]}
        ],
        "target" => %{"title" => "None"},
        "campaign" => %{"title" => "Pump"}
      })
      |> json_response(422)

    assert refused["error"] == "traits_not_children"
  end

  test "a sequence is refused without a media piece and a dry run still shows the run", %{
    token: token,
    row: row,
    n: n
  } do
    conn = authed(token)
    ref = "ptp-2610-brand#{n}-seq"
    marketer = marketer_id(conn, ref)
    before = Repo.aggregate(Qlarius.Sponster.Campaigns.MediaSequence, :count)

    missing =
      conn
      |> post(~p"/api/admin/media_sequences", %{
        api_ref: "#{ref}.seq",
        marketer_id: marketer,
        title: "No ad"
      })
      |> json_response(422)

    assert missing["error"] == "media_piece_required"
    assert Repo.aggregate(Qlarius.Sponster.Campaigns.MediaSequence, :count) == before

    piece = media_piece(conn, ref, marketer, row)

    dry =
      conn
      |> post(~p"/api/admin/media_sequences", %{
        api_ref: "#{ref}.seq",
        marketer_id: marketer,
        media_piece_id: piece,
        title: "With ad",
        dry_run: true
      })
      |> json_response(200)

    assert dry["result"] == "would_create"
    assert hd(dry["media_sequence"]["runs"])["media_piece_id"] == piece
    assert Repo.aggregate(Qlarius.Sponster.Campaigns.MediaSequence, :count) == before
  end

  test "coverage report and zip lookup reject bad input", %{token: token} do
    conn = authed(token)

    report =
      conn
      |> get(~p"/api/admin/reports/ptp_coverage?month=2026-10")
      |> json_response(200)

    assert report["month"] == "2026-10"
    assert report["per_user"]["median"] == 0

    bad =
      conn
      |> get(~p"/api/admin/reports/ptp_coverage?month=October")
      |> json_response(422)

    assert bad["error"] == "invalid_month"

    zips =
      conn
      |> get(~p"/api/admin/zip_codes?q=8")
      |> json_response(422)

    assert zips["error"] == "zip_query_too_short"
  end

  test "zip lookup defaults to Home Zip Code and can take another parent", %{token: token, n: n} do
    zip = "85" <> (rem(n, 1000) |> Integer.to_string() |> String.pad_leading(3, "0"))
    work = TargetingFixtures.zip_parent_fixture("Work Zip Code")
    work_zip = TargetingFixtures.zip_code_fixture(work, zip, "Work")
    conn = authed(token)

    missing =
      conn
      |> get(~p"/api/admin/zip_codes?q=#{zip}")
      |> json_response(422)

    assert missing["error"] == "zip_parent_not_found"

    home = TargetingFixtures.zip_parent_fixture("Home Zip Code")
    home_zip = TargetingFixtures.zip_code_fixture(home, zip, "Home")

    found =
      conn
      |> get(~p"/api/admin/zip_codes?q=#{zip}")
      |> json_response(200)

    assert found["parent_trait_id"] == home.id
    assert found["parent_trait_name"] == "Home Zip Code"
    assert Enum.map(found["zip_codes"], & &1["id"]) == [home_zip.id]

    other =
      conn
      |> get(~p"/api/admin/zip_codes?q=#{zip}&parent_trait_id=#{work.id}")
      |> json_response(200)

    assert other["parent_trait_id"] == work.id
    assert other["parent_trait_name"] == "Work Zip Code"
    assert Enum.map(other["zip_codes"], & &1["id"]) == [work_zip.id]
  end

  defp marketer_id(conn, ref) do
    body =
      conn
      |> post(~p"/api/admin/marketers", %{
        api_ref: "#{ref}.marketer",
        business_name: "Brand"
      })
      |> json_response(201)

    body["marketer"]["id"]
  end

  defp media_piece(conn, ref, marketer_id, row) do
    body =
      conn
      |> post(~p"/api/admin/media_pieces", %{
        api_ref: "#{ref}.ad",
        marketer_id: marketer_id,
        title: "Banner",
        media_piece_type_id: 1,
        ad_category_row_id: row.row_id,
        display_url: "brand.example",
        jump_url: "https://brand.example/go",
        banner_image: banner()
      })
      |> json_response(201)

    body["media_piece"]["id"]
  end
end
