defmodule Qlarius.Tiqit.Arcade.TiqitPurchaseSnapshotTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.Accounts
  alias Qlarius.Accounts.Scope
  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.Creators
  alias Qlarius.Tiqit.Arcade.Tiqit
  alias Qlarius.Tiqit.Arcade.TiqitClass

  setup do
    {:ok, creator} =
      Creators.create_creator(%{"name" => "Snap #{System.unique_integer([:positive])}"})

    catalog =
      %Catalog{creator_id: creator.id}
      |> Catalog.changeset(%{
        name: "Cat #{System.unique_integer([:positive])}",
        url: "https://example.com/#{System.unique_integer([:positive])}",
        type: :catalog,
        group_type: :show,
        piece_type: :episode
      })
      |> Repo.insert!()

    group =
      %ContentGroup{catalog_id: catalog.id}
      |> ContentGroup.changeset(%{title: "Group"})
      |> Repo.insert!()

    piece =
      %ContentPiece{content_group_id: group.id}
      |> ContentPiece.changeset(%{title: "Episode", date_published: ~D[2025-01-01]})
      |> Repo.insert!()

    class =
      %TiqitClass{content_piece_id: piece.id}
      |> TiqitClass.changeset(%{duration_hours: 3, price: Decimal.new("0.10")})
      |> Repo.insert!()

    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "snap-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    %{
      piece: piece,
      class: class,
      scope: Scope.for_user(user)
    }
  end

  test "purchase copies class values onto the tiqit", %{scope: scope, class: class, piece: piece} do
    assert :ok = Arcade.purchase_tiqit(scope, class)

    tiqit = Repo.get_by!(Tiqit, content_piece_id: piece.id)
    assert tiqit.tiqit_class_id == class.id
    assert tiqit.content_piece_id == piece.id
    assert is_nil(tiqit.content_group_id)
    assert is_nil(tiqit.catalog_id)
    assert tiqit.duration_hours == 3
    assert tiqit.price == Decimal.new("0.10")
    assert tiqit.expires_at
  end

  test "access survives deleting the purchased class", %{
    scope: scope,
    class: class,
    piece: piece
  } do
    assert :ok = Arcade.purchase_tiqit(scope, class)
    {:ok, _} = Repo.delete(class)

    tiqit = Repo.get_by!(Tiqit, content_piece_id: piece.id)
    assert is_nil(tiqit.tiqit_class_id)
    assert tiqit.content_piece_id == piece.id
    assert tiqit.duration_hours == 3

    assert Arcade.get_valid_tiqit(scope, piece)
    assert Arcade.has_valid_tiqit?(scope, piece)

    [held] = Arcade.active_tiqit_classes(scope, piece)
    assert held.duration_hours == 3
    assert held.price == Decimal.new("0.10")
    assert held.content_piece_id == piece.id
  end

  test "free_tiqit? uses the snapshotted price" do
    refute Arcade.free_tiqit?(%Tiqit{price: Decimal.new("0.10")})
    assert Arcade.free_tiqit?(%Tiqit{price: Decimal.new("0.00")})
  end
end
