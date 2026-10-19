defmodule QlariusWeb.LayoutsMaybeMobileSlotsTest do
  use QlariusWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias Qlarius.Accounts.Scope
  alias QlariusWeb.Layouts

  defp stub_scope do
    %Scope{
      user: %{alias: "Test User"},
      home_zip: "00000",
      wallet_balance: Decimal.new("0.00"),
      available_to_tip: Decimal.new("0.00"),
      offered_amount: Decimal.new("0.00"),
      ads_count: 0,
      pending_referral_clicks_count: 0,
      trait_count: 0,
      tag_count: 0,
      active_tiqit_count: 0
    }
  end

  test "when wrapped, :modals and :floating_actions render outside .slide-panels" do
    html =
      render_component(fn assigns ->
        ~H"""
        <Layouts.maybe_mobile wrap={true} title="Test" flash={%{}} current_scope={stub_scope()}>
          <:modals>
            <div id="modal-marker">modal</div>
          </:modals>
          <:floating_actions>
            <div id="fab-marker">fab</div>
          </:floating_actions>
          <div id="page-marker">page</div>
        </Layouts.maybe_mobile>
        """
      end)

    doc = LazyHTML.from_fragment(html)

    refute Enum.empty?(LazyHTML.query(doc, "#page-marker"))
    refute Enum.empty?(LazyHTML.query(doc, "#modal-marker"))
    refute Enum.empty?(LazyHTML.query(doc, "#fab-marker"))

    assert Enum.empty?(LazyHTML.query(doc, ".slide-panels #modal-marker"))
    assert Enum.empty?(LazyHTML.query(doc, ".slide-panels #fab-marker"))
  end

  test "when not wrapped, :modals and :floating_actions still render" do
    html =
      render_component(fn assigns ->
        ~H"""
        <Layouts.maybe_mobile wrap={false} title="Test" flash={%{}} current_scope={stub_scope()}>
          <:modals>
            <div id="modal-marker">modal</div>
          </:modals>
          <:floating_actions>
            <div id="fab-marker">fab</div>
          </:floating_actions>
          <div id="page-marker">page</div>
        </Layouts.maybe_mobile>
        """
      end)

    assert html =~ ~s(id="page-marker")
    assert html =~ ~s(id="modal-marker")
    assert html =~ ~s(id="fab-marker")
  end
end

defmodule QlariusWeb.Widgets.Arcade.ArqadePageWrapSlotsTest do
  use QlariusWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias Qlarius.Accounts.Scope

  defp stub_scope do
    %Scope{
      user: %{alias: "Test User"},
      home_zip: "00000",
      wallet_balance: Decimal.new("0.00"),
      available_to_tip: Decimal.new("0.00"),
      offered_amount: Decimal.new("0.00"),
      ads_count: 0,
      pending_referral_clicks_count: 0,
      trait_count: 0,
      tag_count: 0,
      active_tiqit_count: 0
    }
  end

  test "arqade_page_wrap forwards :modals through the mobile shell" do
    html =
      render_component(fn assigns ->
        ~H"""
        <QlariusWeb.Widgets.Arcade.Components.arqade_page_wrap
          base_path=""
          wrap_mobile={true}
          title="Test"
          flash={%{}}
          current_scope={stub_scope()}
        >
          <:modals>
            <div id="modal-marker">modal</div>
          </:modals>
          <div id="page-marker">page</div>
        </QlariusWeb.Widgets.Arcade.Components.arqade_page_wrap>
        """
      end)

    doc = LazyHTML.from_fragment(html)

    refute Enum.empty?(LazyHTML.query(doc, "#page-marker"))
    refute Enum.empty?(LazyHTML.query(doc, "#modal-marker"))
    assert Enum.empty?(LazyHTML.query(doc, ".slide-panels #modal-marker"))
  end
end
