defmodule QlariusWeb.Components.SponsterAnnouncerBarTest do
  use QlariusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "wide and narrow tracks use one height and the bounce image" do
    html =
      render_component(&QlariusWeb.Components.SponsterAnnouncerBar.sponster_announcer_bar/1, %{
        anon_display: :promo,
        promo_wide_slides: ["https://example.com/wide.png"],
        promo_narrow_slides: ["https://example.com/narrow.png"],
        promo_max_height: 96,
        promo_bounce_url: "/images/custom-bounce.png"
      })

    assert html =~ "https://example.com/wide.png"
    assert html =~ "https://example.com/narrow.png"
    assert html =~ "height: 96px"
    assert html =~ "/images/custom-bounce.png"
    assert html =~ "md:hidden"
    assert html =~ "max-md:hidden"
    assert html =~ "object-bottom"
  end

  test "a missing sequence keeps the built-in banners and the quarter" do
    html =
      render_component(&QlariusWeb.Components.SponsterAnnouncerBar.sponster_announcer_bar/1, %{
        anon_display: :promo
      })

    assert html =~ "DontReadThis_640.png"
    assert html =~ "LifeSponsored_640.png"
    assert html =~ "SellYourAttention_640.png"
    assert html =~ "/images/sponster_us_quarter.png"
    assert html =~ "height: 80px"
  end
end
