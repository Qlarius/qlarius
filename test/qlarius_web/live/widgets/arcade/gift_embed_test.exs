defmodule QlariusWeb.Widgets.Arcade.GiftEmbedTest do
  use ExUnit.Case, async: true

  alias Qlarius.Tiqit.Arcade.TiqitClass
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.ContentSharing.ShareInvitation
  alias QlariusWeb.TiqitArqadeLive
  alias QlariusWeb.Widgets.Arcade.ArcadeLive

  describe "gift_embed_scope/2" do
    test "returns nil when invitation is absent or claim succeeded" do
      assert TiqitArqadeLive.gift_embed_scope(nil, false) == nil
      assert TiqitArqadeLive.gift_embed_scope(active_group_gift(), true) == nil
    end

    test "returns piece, group, or catalog for active gifts" do
      assert TiqitArqadeLive.gift_embed_scope(active_piece_gift(), false) == "piece"
      assert TiqitArqadeLive.gift_embed_scope(active_group_gift(), false) == "group"
      assert TiqitArqadeLive.gift_embed_scope(active_catalog_gift(), false) == "catalog"
    end
  end

  describe "gift_embed_header_label/3" do
    test "returns nil for piece gifts or after claim" do
      group = group_with_catalog()

      assert TiqitArqadeLive.gift_embed_header_label(active_piece_gift(), group, false) == nil
      assert TiqitArqadeLive.gift_embed_header_label(active_group_gift(), group, true) == nil
    end

    test "labels group and catalog gifts" do
      group = group_with_catalog()

      assert TiqitArqadeLive.gift_embed_header_label(active_group_gift(), group, false) ==
               "Gifted to you · entire class"

      assert TiqitArqadeLive.gift_embed_header_label(active_catalog_gift(), group, false) ==
               "Gifted to you · entire catalog"
    end
  end

  describe "ArcadeLive gift pending helpers" do
    test "gift_scope_pending?/1" do
      assert ArcadeLive.gift_scope_pending?("group")
      assert ArcadeLive.gift_scope_pending?("catalog")
      assert ArcadeLive.gift_scope_pending?("piece")
      refute ArcadeLive.gift_scope_pending?(nil)
    end

    test "selected_gift_pending?/4 for group gifts applies to any selected piece" do
      owned = MapSet.new([1])

      assert ArcadeLive.selected_gift_pending?("group", nil, 99, owned)
      assert ArcadeLive.selected_gift_pending?("catalog", nil, 5, MapSet.new())
    end

    test "gift_piece_included?/4 marks unowned pieces for group gifts" do
      owned = MapSet.new([1])

      assert ArcadeLive.gift_piece_included?(2, "group", nil, owned)
      refute ArcadeLive.gift_piece_included?(1, "group", nil, owned)
      refute ArcadeLive.gift_piece_included?(2, nil, nil, owned)
    end
  end

  defp active_piece_gift do
    invitation = %ShareInvitation{
      content_piece_id: 10,
      content_group_id: 1,
      tiqit_class: %TiqitClass{content_piece_id: 10}
    }

    %{state: :active_gift, invitation: invitation}
  end

  defp active_group_gift do
    invitation = %ShareInvitation{
      content_piece_id: nil,
      content_group_id: 1,
      tiqit_class: %TiqitClass{content_group_id: 1}
    }

    %{state: :active_gift, invitation: invitation}
  end

  defp active_catalog_gift do
    invitation = %ShareInvitation{
      content_piece_id: nil,
      content_group_id: 1,
      tiqit_class: %TiqitClass{catalog_id: 5, content_piece_id: nil, content_group_id: nil}
    }

    %{state: :active_gift, invitation: invitation}
  end

  defp group_with_catalog do
    %ContentGroup{
      catalog: %Catalog{type: :catalog, group_type: :class, piece_type: :lesson}
    }
  end
end
