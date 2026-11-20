defmodule QlariusWeb.Widgets.EmbedRoutesThemeTest do
  use QlariusWeb.ConnCase, async: true

  alias Qlarius.Accounts
  alias Qlarius.Creators
  alias Qlarius.Repo
  alias Qlarius.Sponster.Recipients
  alias Qlarius.Tiqit.Arcade.{Catalog, ContentGroup, ContentPiece}

  setup do
    {:ok, creator} =
      Creators.create_creator(%{"name" => "Theme routes #{System.unique_integer([:positive])}"})

    {:ok, %{user: owner}} =
      Accounts.register_new_user(%{
        alias: "theme-routes-owner-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    {:ok, recipient} =
      Recipients.create_recipient(%{
        "user_id" => owner.id,
        "name" => creator.name,
        "site_url" => "https://theme.example",
        "recipient_type_id" => 1,
        "split_code" => Ecto.UUID.generate(),
        "target_amount" => "0.00",
        "creator_id" => creator.id,
        "is_primary" => true
      })

    catalog =
      %Catalog{creator_id: creator.id}
      |> Catalog.changeset(%{
        "name" => "Routes#{System.unique_integer([:positive])}",
        "url" => "https://theme.example/#{System.unique_integer([:positive])}",
        "type" => "catalog",
        "group_type" => "section",
        "piece_type" => "article"
      })
      |> Repo.insert!()

    group =
      %ContentGroup{catalog_id: catalog.id}
      |> ContentGroup.changeset(%{"title" => "Theme group"})
      |> Repo.insert!()

    piece =
      %ContentPiece{content_group_id: group.id}
      |> ContentPiece.changeset(%{"title" => "Theme piece", "date_published" => ~D[2026-01-01]})
      |> Repo.insert!()

    %{creator: creator, recipient: recipient, catalog: catalog, group: group, piece: piece}
  end

  test "ads drawer, tip jar, and arqade widget routes pin creator theme (light/dark) and system uses widget-system",
       %{creator: creator, recipient: recipient, catalog: catalog, group: group, piece: piece} do
    {:ok, creator} =
      Creators.update_creator(creator, %{
        "ad_strip_theme" => "dark",
        "tip_jar_theme" => "light",
        "arqade_theme" => "dark"
      })

    ads = get(build_conn(), "/widgets/ads_ext/#{recipient.split_code}")
    assert html_response(ads, 200) =~ ~s(data-theme="dark")
    assert html_response(ads, 200) =~ ~s(data-theme-mode="widget")

    tip = get(build_conn(), "/widgets/insta_tip?split_code=#{recipient.split_code}")
    assert html_response(tip, 200) =~ ~s(data-theme="light")
    assert html_response(tip, 200) =~ ~s(data-theme-mode="widget")

    creator_page = get(build_conn(), "/widgets/arqade/creator/#{creator.id}")
    assert html_response(creator_page, 200) =~ ~s(data-theme="dark")
    assert html_response(creator_page, 200) =~ ~s(data-theme-mode="widget")

    catalog_page = get(build_conn(), "/widgets/arqade/catalog/#{catalog.id}")
    assert html_response(catalog_page, 200) =~ ~s(data-theme="dark")
    assert html_response(catalog_page, 200) =~ ~s(data-theme-mode="widget")

    group_page = get(build_conn(), "/widgets/arqade/group/#{group.id}")
    assert html_response(group_page, 200) =~ ~s(data-theme="dark")
    assert html_response(group_page, 200) =~ ~s(data-theme-mode="widget")

    piece_page = get(build_conn(), "/widgets/arqade/#{piece.id}")
    assert html_response(piece_page, 200) =~ ~s(data-theme="dark")
    assert html_response(piece_page, 200) =~ ~s(data-theme-mode="widget")

    {:ok, _creator} =
      Creators.update_creator(creator, %{
        "ad_strip_theme" => "system",
        "tip_jar_theme" => "system",
        "arqade_theme" => "system"
      })

    ads_system = get(build_conn(), "/widgets/ads_ext/#{recipient.split_code}")
    html = html_response(ads_system, 200)
    assert html =~ ~s(data-theme-mode="widget-system")
    refute html =~ ~s(data-theme="light")
    refute html =~ ~s(data-theme="dark")

    tip_system = get(build_conn(), "/widgets/insta_tip?split_code=#{recipient.split_code}")
    html = html_response(tip_system, 200)
    assert html =~ ~s(data-theme-mode="widget-system")
    refute html =~ ~s(data-theme="light")
    refute html =~ ~s(data-theme="dark")

    catalog_system = get(build_conn(), "/widgets/arqade/catalog/#{catalog.id}")
    html = html_response(catalog_system, 200)
    assert html =~ ~s(data-theme-mode="widget-system")
    refute html =~ ~s(data-theme="light")
    refute html =~ ~s(data-theme="dark")
  end

  test "explicit force_theme wins on embed routes", %{creator: creator, recipient: recipient} do
    {:ok, _creator} = Creators.update_creator(creator, %{"ad_strip_theme" => "dark"})

    forced =
      get(build_conn(), "/widgets/ads_ext/#{recipient.split_code}?force_theme=light")

    forced_html = html_response(forced, 200)
    assert forced_html =~ ~s(data-theme="light")
    refute forced_html =~ ~s(data-theme="dark")
  end

  test "non creator-scoped widget routes default to widget-system (but allow force_theme)",
       _context do
    discovery = get(build_conn(), "/widgets/arqade")
    html = html_response(discovery, 200)
    assert html =~ ~s(data-theme-mode="widget-system")
    refute html =~ ~s(data-theme="light")
    refute html =~ ~s(data-theme="dark")

    discovery_forced = get(build_conn(), "/widgets/arqade?force_theme=light")
    forced_html = html_response(discovery_forced, 200)
    assert forced_html =~ ~s(data-theme="light")
    assert forced_html =~ ~s(data-theme-mode="widget")

    wallet = get(build_conn(), "/widgets/wallet")
    wallet_html = html_response(wallet, 200)
    assert wallet_html =~ ~s(data-theme-mode="widget-system")
    refute wallet_html =~ ~s(data-theme="light")
    refute wallet_html =~ ~s(data-theme="dark")
  end
end
