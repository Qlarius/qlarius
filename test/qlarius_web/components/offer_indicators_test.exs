defmodule QlariusWeb.OfferIndicatorsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias QlariusWeb.Components.AdsComponents

  @zip_snapshot [["Home Zip Code", ["60614"]]]

  defp render_indicators(offer, ad_category, size \\ :md) do
    render_component(&AdsComponents.offer_indicators/1,
      offer: offer,
      ad_category: ad_category,
      size: size
    )
  end

  defp offer(attrs), do: Map.merge(%{matching_tags_snapshot: nil, is_payable: false}, attrs)

  defp category(attrs), do: Map.merge(%{age_gated: false, age_min: nil}, attrs)

  test "zip-targeted offer shows only the map pin" do
    html = render_indicators(offer(%{matching_tags_snapshot: @zip_snapshot}), category(%{}))

    assert html =~ "hero-map-pin-solid"
    refute html =~ ~s(data-indicator="age")
    refute html =~ ~s(data-indicator="payable")
  end

  test "18+ category shows an 18+ badge" do
    html = render_indicators(offer(%{}), category(%{age_gated: true, age_min: 18}))

    assert html =~ ~s(data-indicator="age")
    assert html =~ "18+"
    assert html =~ ~s(title="Ages 18 and up")
    refute html =~ "hero-map-pin-solid"
  end

  test "21+ category shows a 21+ badge" do
    html = render_indicators(offer(%{}), category(%{age_gated: true, age_min: 21}))

    assert html =~ "21+"
    assert html =~ ~s(title="Ages 21 and up")
  end

  test "payable offer shows the green $ badge" do
    html = render_indicators(offer(%{is_payable: true}), category(%{}))

    assert html =~ ~s(data-indicator="payable")
    assert html =~ "bg-green-600"
    refute html =~ ~s(data-indicator="age")
  end

  test "all three indicators render together at the small size" do
    html =
      render_indicators(
        offer(%{matching_tags_snapshot: @zip_snapshot, is_payable: true}),
        category(%{age_gated: true, age_min: 21}),
        :sm
      )

    assert html =~ "hero-map-pin-solid"
    assert html =~ "21+"
    assert html =~ ~s(data-indicator="payable")
    assert html =~ "size-4"
  end

  test "renders nothing when no indicator applies" do
    html = render_indicators(offer(%{}), category(%{age_min: nil}))

    refute html =~ "data-offer-indicators"
  end

  test "an ungated category with a stray age_min shows no badge" do
    html = render_indicators(offer(%{}), category(%{age_gated: false, age_min: 21}))

    refute html =~ ~s(data-indicator="age")
  end
end
