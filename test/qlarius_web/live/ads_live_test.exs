defmodule QlariusWeb.AdsLiveTest do
  use QlariusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Qlarius.Accounts
  alias Qlarius.Repo
  alias Qlarius.YouData.Traits.Trait
  alias QlariusWeb.Components.AdsComponents

  describe "/ads with no offers" do
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

      {:ok, %{user: user}} =
        Accounts.register_new_user(%{
          alias: "ads-lv-#{System.unique_integer([:positive])}",
          date_of_birth: ~D[1990-01-01],
          sex_trait_id: 200_001,
          age_trait_id: 200_093
        })

      %{conn: log_in_user(conn, user)}
    end

    test "renders the board with both panes and empty states that point to the Builder", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/ads")
      html = render(view)

      assert html =~ ~s(id="ads-board")
      assert html =~ ~s(data-both="false")
      assert html =~ "ads-pane--three_tap"
      assert html =~ "ads-pane--video"
      assert html =~ "No 3-Tap ads available"
      assert html =~ "No video ads available"
      assert html =~ ~s(href="/me_file_builder")
      refute html =~ "ads-board__tabs"
    end
  end

  describe "ThreeTapStackComponent layout" do
    test "the default stack is one centred column" do
      html =
        render_component(QlariusWeb.ThreeTapStackComponent,
          id: "stack",
          active_offers: [],
          current_scope: nil
        )

      assert html =~ "w-fit mx-auto"
      refute html =~ "three-tap-grid"
    end

    test "layout grid flows the same cards into columns" do
      html =
        render_component(QlariusWeb.ThreeTapStackComponent,
          id: "grid",
          active_offers: [],
          current_scope: nil,
          layout: "grid"
        )

      assert html =~ "three-tap-grid"
      # Cards keep their fixed size
      assert html =~ "width: 347px; height: 152px;"
    end
  end

  describe "video_offer_list_item/1" do
    @offer %{
      id: 7,
      offer_amt: Decimal.new("0.30"),
      matching_tags_snapshot: nil,
      media_run: %{media_piece: %{duration: 30, ad_category: %{ad_label: "Food/Restaurant"}}}
    }

    test "app_row lays the row out for /ads with the same click target" do
      html =
        render_component(&AdsComponents.video_offer_list_item/1,
          offer: @offer,
          rate: Decimal.new("0.01"),
          completed: false,
          app_row: true
        )

      assert html =~ "video-app-row"
      assert html =~ ~s(phx-click="open_video_ad")
      assert html =~ ~s(phx-value-offer_id="7")
      assert html =~ "Food/Restaurant"
      assert html =~ "$0.30"
    end

    test "a finished app row matches the 3-tap finished phase" do
      html =
        render_component(&AdsComponents.video_offer_list_item/1,
          offer: @offer,
          rate: Decimal.new("0.01"),
          completed: true,
          app_row: true
        )

      assert html =~ "Attention Paid™"
      assert html =~ "video-app-row__check"
      refute html =~ ~s(phx-click="open_video_ad")
    end

    test "widgets keep the original row" do
      html =
        render_component(&AdsComponents.video_offer_list_item/1,
          offer: @offer,
          rate: Decimal.new("0.01"),
          completed: false
        )

      refute html =~ "video-app-row"
      assert html =~ "h-[120px]"
      assert html =~ ~s(phx-click="open_video_ad")
    end
  end
end
