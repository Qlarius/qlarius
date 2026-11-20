defmodule Qlarius.Widgets.ThemeTest do
  use QlariusWeb.ConnCase, async: true

  alias Qlarius.Accounts.{AdminApiTokens, User}
  alias Qlarius.Creators
  alias Qlarius.Creators.Creator
  alias Qlarius.Repo
  alias Qlarius.Sponster.Recipients
  alias Qlarius.Tiqit.Arcade.{Catalog, ContentGroup, ContentPiece}
  alias Qlarius.Widgets.Theme

  setup do
    {:ok, creator} =
      Creators.create_creator(%{"name" => "Theme #{System.unique_integer([:positive])}"})

    catalog =
      %Catalog{creator_id: creator.id}
      |> Catalog.changeset(%{
        "name" => "Theme catalog",
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

    {:ok, %{user: owner}} =
      Qlarius.Accounts.register_new_user(%{
        alias: "theme-owner-#{System.unique_integer([:positive])}",
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

    %{creator: creator, group: group, piece: piece, recipient: recipient, catalog: catalog}
  end

  test "system is the default and a pin falls back to light only when a color is required", %{
    group: group,
    piece: piece,
    recipient: recipient
  } do
    assert Theme.for_group(group.id, nil) == "system"
    assert Theme.for_piece(piece.id, nil) == "system"
    assert Theme.for_piece(to_string(piece.id), "nope") == "system"
    assert Theme.for_recipient(recipient, :ad_strip_theme, nil) == "system"
    assert Theme.for_recipient(nil, :tip_jar_theme, nil) == "system"
    assert Theme.pin("system") == nil
    assert Theme.pin("dark") == "dark"
    assert Theme.concrete("system") == "light"
    assert Theme.concrete("dark") == "dark"
    assert Theme.widget_attr("/widgets", "system") == nil
    assert Theme.widget_attr("", "dark") == nil
  end

  test "explicit theme wins, then the group, then the creator", %{
    creator: creator,
    group: group,
    piece: piece,
    recipient: recipient,
    catalog: catalog
  } do
    {:ok, creator} =
      Creators.update_creator(creator, %{
        "ad_strip_theme" => "dark",
        "tip_jar_theme" => "light",
        "arqade_theme" => "dark"
      })

    assert Theme.for_group(group.id, nil) == "dark"
    assert Theme.for_piece(piece.id, nil) == "dark"
    assert Theme.for_catalog(catalog.id, nil) == "dark"
    assert Theme.for_group(group.id, "light") == "light"
    assert Theme.for_recipient(recipient, :ad_strip_theme, nil) == "dark"
    assert Theme.for_recipient(recipient, :tip_jar_theme, "dark") == "dark"
    assert Theme.for_recipient(%Qlarius.Sponster.Recipient{}, :ad_strip_theme, nil) == "system"

    {:ok, group} =
      group
      |> ContentGroup.changeset(%{"arqade_theme" => "light"})
      |> Repo.update()

    assert Theme.for_group(group.id, nil) == "light"
    assert Theme.for_piece(piece.id, "dark") == "dark"

    {:ok, group} =
      group
      |> ContentGroup.changeset(%{"arqade_theme" => ""})
      |> Repo.update()

    assert group.arqade_theme == nil
    assert Theme.for_group(group.id, nil) == "dark"

    {:ok, group} =
      group
      |> ContentGroup.changeset(%{"arqade_theme" => "system"})
      |> Repo.update()

    assert Theme.for_group(group.id, nil) == "system"
    assert creator.arqade_theme == "dark"
  end

  test "a blank creator theme becomes system and an unknown theme is rejected", %{
    creator: creator
  } do
    {:ok, creator} = Creators.update_creator(creator, %{"ad_strip_theme" => ""})
    assert creator.ad_strip_theme == "system"

    changeset = Creator.changeset(creator, %{"tip_jar_theme" => "blue"})
    refute changeset.valid?
  end

  test "a widget page pins the creator theme and an explicit force_theme wins", %{
    creator: creator,
    recipient: recipient,
    group: group
  } do
    {:ok, creator} =
      Creators.update_creator(creator, %{
        "ad_strip_theme" => "dark",
        "tip_jar_theme" => "dark",
        "arqade_theme" => "dark"
      })

    tip = get(build_conn(), "/widgets/insta_tip?split_code=#{recipient.split_code}")
    assert html_response(tip, 200) =~ ~s(data-theme="dark")
    assert html_response(tip, 200) =~ ~s(data-theme-mode="widget")

    forced =
      get(
        build_conn(),
        "/widgets/insta_tip?split_code=#{recipient.split_code}&force_theme=light"
      )

    forced_html = html_response(forced, 200)
    assert forced_html =~ ~s(data-theme="light")
    refute forced_html =~ ~s(data-theme="dark")

    ads = get(build_conn(), "/widgets/ads_ext/#{recipient.split_code}")
    assert html_response(ads, 200) =~ ~s(data-theme-mode="widget")

    arcade = get(build_conn(), "/widgets/arqade/group/#{group.id}")
    assert html_response(arcade, 200) =~ ~s(data-theme="dark")

    {:ok, _} = Creators.update_creator(creator, %{"tip_jar_theme" => "system"})

    system = get(build_conn(), "/widgets/insta_tip?split_code=#{recipient.split_code}")
    system_html = html_response(system, 200)
    assert system_html =~ ~s(data-theme-mode="widget-system")
    refute system_html =~ ~s(data-theme="light")
    refute system_html =~ ~s(data-theme="dark")
  end

  test "admin API reads and writes widget themes", %{creator: creator, group: group} do
    admin =
      %User{}
      |> User.registration_changeset(%{
        "alias" => "theme-api-#{System.unique_integer([:positive])}"
      })
      |> Ecto.Changeset.put_change(:role, "admin")
      |> Repo.insert!()

    {:ok, _token, raw} = AdminApiTokens.issue(admin, "themes")

    patched =
      build_conn()
      |> put_req_header("authorization", "Bearer #{raw}")
      |> patch(~p"/api/admin/creators/#{creator.id}", %{
        "ad_strip_theme" => "dark",
        "tip_jar_theme" => "light",
        "arqade_theme" => "system"
      })
      |> json_response(200)

    assert patched["creator"]["ad_strip_theme"] == "dark"
    assert patched["creator"]["tip_jar_theme"] == "light"
    assert patched["creator"]["arqade_theme"] == "system"

    shown =
      build_conn()
      |> put_req_header("authorization", "Bearer #{raw}")
      |> get(~p"/api/admin/creators/#{creator.id}")
      |> json_response(200)

    assert shown["creator"]["ad_strip_theme"] == "dark"

    group_body =
      build_conn()
      |> put_req_header("authorization", "Bearer #{raw}")
      |> patch(~p"/api/admin/content_groups/#{group.id}", %{"arqade_theme" => "light"})
      |> json_response(200)

    assert group_body["content_group"]["arqade_theme"] == "light"

    cleared =
      build_conn()
      |> put_req_header("authorization", "Bearer #{raw}")
      |> patch(~p"/api/admin/content_groups/#{group.id}", %{"arqade_theme" => ""})
      |> json_response(200)

    assert cleared["content_group"]["arqade_theme"] == nil

    rejected =
      build_conn()
      |> put_req_header("authorization", "Bearer #{raw}")
      |> patch(~p"/api/admin/creators/#{creator.id}", %{"arqade_theme" => "blue"})

    assert json_response(rejected, 422)
  end
end
