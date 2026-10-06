defmodule QlariusWeb.TiqitComponentsTest do
  # Reads the refund window from global variables, so it needs the DB sandbox.
  use QlariusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Qlarius.ContentSharing.ShareInvitation
  alias Qlarius.ContentSharing.WillCallTiqit
  alias Qlarius.Creators.Creator
  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.Tiqit
  alias QlariusWeb.TiqitComponents

  defp piece(creator_name \\ "Tammy's Tasty Tips") do
    creator = %Creator{name: creator_name}

    catalog = %Catalog{
      name: "Tammy's Tasty Tips",
      piece_type: :episode,
      group_type: :season,
      creator: creator
    }

    group = %ContentGroup{title: "Season 1", catalog: catalog}
    %ContentPiece{id: 41, title: "Grilled Cheese", content_group: group}
  end

  defp tiqit(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    struct(
      %Tiqit{
        id: 7,
        purchased_at: DateTime.add(now, -3, :day),
        expires_at: DateTime.add(now, 2, :day),
        price: Decimal.new("0.10"),
        preserved: false,
        content_piece_id: 41,
        content_piece: piece()
      },
      attrs
    )
  end

  defp render_tiqit(tiqit),
    do: render_component(&TiqitComponents.tiqit_detail_card/1, tiqit: tiqit)

  describe "tiqit card status line" do
    test "an active tiqit counts down to expiry, with Open as the main stub action" do
      html = render_tiqit(tiqit(%{}))

      assert html =~ ~s(data-status="active")
      assert html =~ "tiqit-status__dot is-live"
      assert html =~ "<b>Active</b>"
      assert html =~ "expires in"
      assert html =~ ~r/Bought \w{3} \d+/
      assert html =~ "$0.10"
      assert html =~ ~s(href="/content/41")
      assert html =~ "tiqit-stub-btn--open is-primary"
      refute html =~ "Go to"
    end

    test "an expired tiqit that isn't kept is Fleeting, counting down to AutoFleet" do
      now = DateTime.utc_now()
      html = render_tiqit(tiqit(%{expires_at: DateTime.add(now, -1, :hour)}))

      assert html =~ "tiqit-status__dot is-warn"
      assert html =~ "<b>Fleeting</b>"
      assert html =~ "auto-fleets in"
      refute html =~ "expires in"
      # Open is quieter once access has lapsed
      assert html =~ "tiqit-stub-btn--open"
      refute html =~ "is-primary"
    end

    test "a kept expired tiqit says when it expired and won't AutoFleet" do
      expired = DateTime.add(DateTime.utc_now(), -2, :day)
      html = render_tiqit(tiqit(%{expires_at: expired, preserved: true}))

      assert html =~ "tiqit-status__dot is-muted"
      assert html =~ "<b>Kept</b>"
      assert html =~ "expired"
      refute html =~ "auto-fleets"
    end

    test "a lifetime tiqit has no countdown" do
      html = render_tiqit(tiqit(%{expires_at: nil}))

      assert html =~ "lifetime access"
      refute html =~ "expires in"
    end
  end

  describe "tiqit card stub" do
    test "⋯ on the stub line opens the actions in a panel below it" do
      html = render_tiqit(tiqit(%{}))
      doc = LazyHTML.from_fragment(html)

      button = LazyHTML.query(doc, ".tiqit-stub .tiqit-more-btn")
      assert LazyHTML.attribute(button, "aria-controls") == ["tiqit-more-tiqit-7"]
      assert LazyHTML.attribute(button, "aria-expanded") == ["false"]

      # The panel follows the stub line, starts closed and out of the tab order
      panel = LazyHTML.query(doc, ".tiqit-stub + #tiqit-more-tiqit-7.tiqit-more[inert]")
      assert LazyHTML.text(panel) =~ "Purchased"
      assert LazyHTML.text(panel) =~ "Fleet"

      refute html =~ "hero-chevron-down"
    end
  end

  describe "tiqit card header" do
    test "the source line drops a repeated name and keeps the full path in its title" do
      html = render_tiqit(tiqit(%{}))

      # creator and catalog share a name, so the line reads creator › group
      assert html =~ "Tammy&#39;s Tasty Tips › Season 1"
      assert html =~ ~s(title="Tammy&#39;s Tasty Tips › Season 1")
      assert html =~ "Episode"
      assert html =~ "line-clamp-2"
    end

    test "three distinct names keep the first and last on the line" do
      tiqit = tiqit(%{content_piece: piece("Team Coco")})
      html = render_tiqit(tiqit)

      assert html =~ ~r/>\s*Team Coco › Season 1\s*</
      assert html =~ ~s(title="Team Coco › Tammy&#39;s Tasty Tips › Season 1")
    end
  end

  describe "gift card" do
    defp gift(status, invitation \\ nil) do
      %WillCallTiqit{
        id: 3,
        amount: Decimal.new("0.29"),
        will_call_status: status,
        inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
        content_piece_id: 41,
        content_piece: piece(),
        share_invitation_id: invitation && 9,
        share_invitation: invitation
      }
    end

    test "a claimed gift shows one Gifted line and its amount on the stub, with no fold" do
      html = render_component(&TiqitComponents.tiqit_detail_card/1, gift: gift("picked_up"))

      assert html =~ "tiqit-status__dot is-done"
      assert html =~ "<b>Gifted</b>"
      assert html =~ "claimed"
      assert html =~ "$0.29"
      assert html =~ "prepaid"
      refute html =~ "tiqit-more"
    end

    test "the recipient's read-only view keeps a neutral dot and its claim countdown tail" do
      invitation = %ShareInvitation{gift_expires_at: DateTime.add(DateTime.utc_now(), 1, :day)}

      html =
        render_component(&TiqitComponents.tiqit_detail_card/1,
          gift: gift("at_will_call", invitation),
          gift_read_only: true
        )

      assert html =~ "tiqit-status__dot is-muted"
      assert html =~ "awaiting pickup"
      assert html =~ "Claim window ends in"
      refute html =~ "tiqit-stub"
    end
  end
end
