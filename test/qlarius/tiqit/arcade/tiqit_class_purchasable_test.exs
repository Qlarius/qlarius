defmodule Qlarius.Tiqit.Arcade.TiqitClassPurchasableTest do
  use ExUnit.Case, async: true

  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.Tiqit.Arcade.TiqitClass

  defp piece_class(hours, price, id \\ 1),
    do: %TiqitClass{id: id, content_piece_id: 10, duration_hours: hours, price: price}

  defp group_class(hours, price, id \\ 2),
    do: %TiqitClass{id: id, content_group_id: 5, duration_hours: hours, price: price}

  defp catalog_class(hours, price, id \\ 3),
    do: %TiqitClass{
      id: id,
      catalog_id: 7,
      content_piece_id: nil,
      content_group_id: nil,
      duration_hours: hours,
      price: price
    }

  describe "tiqit_class_purchasable?/2" do
    test "allows purchase with no active tiqits" do
      assert Arcade.tiqit_class_purchasable?(piece_class(3, Decimal.new("0.10")), [])
    end

    test "blocks the exact active class" do
      active = piece_class(3, Decimal.new("0.10"))
      refute Arcade.tiqit_class_purchasable?(active, [active])
    end

    test "allows longer duration at same scope" do
      active = piece_class(3, Decimal.new("0.10"), 101)
      candidate = piece_class(24, Decimal.new("0.25"), 102)
      assert Arcade.tiqit_class_purchasable?(candidate, [active])
    end

    test "blocks shorter duration at same scope" do
      active = piece_class(24, Decimal.new("0.25"), 201)
      candidate = piece_class(3, Decimal.new("0.10"), 202)
      refute Arcade.tiqit_class_purchasable?(candidate, [active])
    end

    test "allows broader scope with equal or greater duration and price" do
      active = piece_class(24, Decimal.new("0.25"))
      candidate = group_class(24, Decimal.new("0.50"))
      assert Arcade.tiqit_class_purchasable?(candidate, [active])
    end

    test "allows broader scope even with shorter duration" do
      active = piece_class(24, Decimal.new("0.25"), 401)
      candidate = group_class(3, Decimal.new("0.25"), 402)
      assert Arcade.tiqit_class_purchasable?(candidate, [active])
    end

    test "blocks narrower scope with shorter duration at same scope" do
      active = group_class(24, Decimal.new("0.50"), 501)
      candidate = group_class(3, Decimal.new("0.25"), 502)
      refute Arcade.tiqit_class_purchasable?(candidate, [active])
    end

    test "blocks narrower scope even with longer duration" do
      active = group_class(3, Decimal.new("0.50"))
      candidate = piece_class(24, Decimal.new("0.25"))
      refute Arcade.tiqit_class_purchasable?(candidate, [active])
    end

    test "allows broader scope at equal price and duration" do
      active = piece_class(24, Decimal.new("0.25"), 301)
      candidate = group_class(24, Decimal.new("0.25"), 302)
      assert Arcade.tiqit_class_purchasable?(candidate, [active])
    end

    test "allows catalog upgrade from group tiqit" do
      active = group_class(24, Decimal.new("0.50"))
      candidate = catalog_class(24, Decimal.new("1.00"))
      assert Arcade.tiqit_class_purchasable?(candidate, [active])
    end
  end
end
