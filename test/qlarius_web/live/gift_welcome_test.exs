defmodule QlariusWeb.GiftWelcomeTest do
  use QlariusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Qlarius.Accounts
  alias Qlarius.Accounts.Scope
  alias Qlarius.ContentSharing
  alias Qlarius.Creators
  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.{Catalog, ContentGroup, ContentPiece, TiqitClass}
  alias Qlarius.YouData.Traits.Trait

  @iphone_safari "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 " <>
                   "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

  setup %{conn: conn} do
    trait = fn attrs ->
      Repo.insert!(
        struct(
          Trait,
          Map.merge(%{input_type: "text", display_order: 1, modified_by: 0, added_by: 0}, attrs)
        )
      )
    end

    trait.(%{id: 1, trait_name: "Sex"})
    trait.(%{id: 93, trait_name: "Age"})
    trait.(%{id: 200_001, parent_trait_id: 1, trait_name: "Male"})
    trait.(%{id: 200_093, parent_trait_id: 93, trait_name: "25-34"})

    {:ok, creator} =
      Creators.create_creator(%{
        "name" => "Welcome Creator #{System.unique_integer([:positive])}"
      })

    catalog =
      %Catalog{creator_id: creator.id}
      |> Catalog.changeset(%{
        name: "Welcome Catalog",
        url: "https://example.com/#{System.unique_integer([:positive])}",
        type: :catalog,
        group_type: :show,
        piece_type: :episode
      })
      |> Repo.insert!()

    group =
      %ContentGroup{catalog_id: catalog.id}
      |> ContentGroup.changeset(%{title: "Welcome Show"})
      |> Repo.insert!()

    %ContentPiece{content_group_id: group.id}
    |> ContentPiece.changeset(%{title: "Pilot", date_published: ~D[2025-01-01]})
    |> Repo.insert!()

    tiqit_class =
      %TiqitClass{content_group_id: group.id}
      |> TiqitClass.changeset(%{price: Decimal.new("1.00"), duration_hours: 24})
      |> Repo.insert!()

    user = register_user!()

    %{conn: log_in_user(conn, user), user: user, group: group, tiqit_class: tiqit_class}
  end

  describe "in-app tiqit page" do
    test "shows the welcome card only with welcome=gift", %{conn: conn, group: group} do
      {:ok, view, _html} = live(conn, ~p"/arqade/group/#{group.id}?welcome=gift")
      assert has_element?(view, "#gift-welcome-card", "Your tiqit is ready")
      assert has_element?(view, ~s(#gift-welcome-wallet[href="/ads?welcome=gift"]))

      view |> element("#gift-welcome-watch") |> render_click()
      refute has_element?(view, "#gift-welcome-card")

      {:ok, view, _html} = live(conn, ~p"/arqade/group/#{group.id}")
      refute has_element?(view, "#gift-welcome-card")
    end

    test "a phone browser with welcome=gift stays on the page and gets the install banner", %{
      conn: conn,
      group: group
    } do
      conn = put_req_header(conn, "user-agent", @iphone_safari)

      {:ok, view, _html} = live(conn, ~p"/arqade/group/#{group.id}?welcome=gift")
      refute has_element?(view, "#pwa-install-banner")

      render_hook(view, "check_pwa_state", %{
        "is_ios" => true,
        "is_android" => false,
        "is_pwa" => false
      })

      assert has_element?(view, "#pwa-install-banner")

      render_click(view, "show_ios_guide", %{})
      assert render(view) =~ "Select &quot;Add to Home Screen&quot;"

      render_click(view, "dismiss_install_banner", %{})
      refute has_element?(view, "#pwa-install-banner")
    end

    test "a phone browser without welcome=gift is still sent to /hi", %{conn: conn, group: group} do
      conn = put_req_header(conn, "user-agent", @iphone_safari)

      assert {:error, {:live_redirect, %{to: "/hi"}}} = live(conn, ~p"/arqade/group/#{group.id}")
    end
  end

  describe "Home" do
    test "shows a recently claimed gift with a Watch link", %{
      conn: conn,
      user: user,
      group: group,
      tiqit_class: tiqit_class
    } do
      {:ok, %{will_call: will_call}} =
        ContentSharing.create_gift(Scope.for_user(register_user!()), %{
          tiqit_class_id: tiqit_class.id,
          content_group_id: group.id
        })

      {:ok, _} = ContentSharing.redeem_gift(will_call, Scope.for_user(user))

      {:ok, view, _html} = live(conn, ~p"/home")
      render_async(view)

      assert has_element?(view, "#home-received-gift", "Welcome Show")

      assert has_element?(
               view,
               ~s(#home-received-gift a[href="/arqade/group/#{group.id}"]),
               "Watch"
             )
    end

    test "has no gift card without a claimed gift", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/home")
      render_async(view)

      refute has_element?(view, "#home-received-gift")
    end
  end

  defp register_user! do
    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "gift-welcome-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01],
        sex_trait_id: 200_001,
        age_trait_id: 200_093
      })

    user
  end
end
