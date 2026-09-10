defmodule Qlarius.Tiqit.Arcade.PieceTiqitClassDefaultsTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.Creators
  alias Qlarius.Tiqit.Arcade.Tiqit
  alias Qlarius.Tiqit.Arcade.TiqitClass

  describe "write_default_piece_tiqit_classes/2" do
    setup do
      {:ok, creator} =
        Creators.create_creator(%{"name" => "Defaults #{System.unique_integer([:positive])}"})

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

      piece_a = insert_piece(group, "A")
      piece_b = insert_piece(group, "B")

      %{group: group, piece_a: piece_a, piece_b: piece_b}
    end

    test "fill_in inserts missing durations and leaves existing prices", %{
      group: group,
      piece_a: piece_a,
      piece_b: piece_b
    } do
      insert_class(piece_a, 3, "0.99")

      assert {:ok, []} = Arcade.write_default_piece_tiqit_classes(group, mode: :fill_in)

      assert price_for(piece_a, 3) == Decimal.new("0.99")
      assert price_for(piece_a, 24) == Decimal.new("0.25")
      assert price_for(piece_b, 3) == Decimal.new("0.10")
    end

    test "overwrite replaces matching duration prices on every piece", %{
      group: group,
      piece_a: piece_a,
      piece_b: piece_b
    } do
      insert_class(piece_a, 3, "0.99")
      insert_class(piece_b, 3, "0.40")

      classes = [%{duration_hours: 3, price: Decimal.new("0.15")}]

      assert {:ok, []} =
               Arcade.write_default_piece_tiqit_classes(group,
                 mode: :overwrite,
                 classes: classes
               )

      assert price_for(piece_a, 3) == Decimal.new("0.15")
      assert price_for(piece_b, 3) == Decimal.new("0.15")
    end

    test "overwrite deletes piece classes missing from the submitted grid", %{
      group: group,
      piece_a: piece_a,
      piece_b: piece_b
    } do
      insert_class(piece_a, 3, "0.10")
      insert_class(piece_a, 720, "0.75")
      insert_class(piece_b, 720, "0.75")

      classes = [%{duration_hours: 3, price: Decimal.new("0.12")}]

      assert {:ok, []} =
               Arcade.write_default_piece_tiqit_classes(group,
                 mode: :overwrite,
                 classes: classes
               )

      assert price_for(piece_a, 3) == Decimal.new("0.12")
      refute class?(piece_a, 720)
      refute class?(piece_b, 720)
    end

    test "overwrite deletes sold classes after the purchase is snapshotted", %{
      group: group,
      piece_a: piece_a
    } do
      class_3 = insert_class(piece_a, 3, "0.10")
      insert_class(piece_a, 720, "0.75")

      tiqit =
        %Tiqit{
          tiqit_class_id: class_3.id,
          purchased_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }
        |> Tiqit.changeset(Tiqit.snapshot_attrs(class_3))
        |> Repo.insert!()

      classes = [
        %{duration_hours: 5, price: Decimal.new("0.35")},
        %{duration_hours: 24, price: Decimal.new("0.50")}
      ]

      assert {:ok, []} =
               Arcade.write_default_piece_tiqit_classes(group,
                 mode: :overwrite,
                 classes: classes
               )

      refute class?(piece_a, 3)
      assert price_for(piece_a, 5) == Decimal.new("0.35")
      assert price_for(piece_a, 24) == Decimal.new("0.50")
      refute class?(piece_a, 720)

      tiqit = Repo.get!(Tiqit, tiqit.id)
      assert is_nil(tiqit.tiqit_class_id)
      assert tiqit.content_piece_id == piece_a.id
      assert tiqit.duration_hours == 3
      assert tiqit.price == Decimal.new("0.10")
    end

    test "fill_in does not delete extra durations", %{group: group, piece_a: piece_a} do
      insert_class(piece_a, 720, "0.75")

      classes = [%{duration_hours: 3, price: Decimal.new("0.10")}]

      assert {:ok, []} =
               Arcade.write_default_piece_tiqit_classes(group,
                 mode: :fill_in,
                 classes: classes
               )

      assert class?(piece_a, 720)
      assert price_for(piece_a, 3) == Decimal.new("0.10")
    end

    test "defaults to overwrite for a single piece", %{piece_a: piece_a} do
      insert_class(piece_a, 3, "0.99")

      assert {:ok, []} = Arcade.write_default_piece_tiqit_classes(piece_a)

      assert price_for(piece_a, 3) == Decimal.new("0.10")
    end
  end

  defp insert_piece(group, title) do
    %ContentPiece{content_group_id: group.id}
    |> ContentPiece.changeset(%{title: title, date_published: ~D[2025-01-01]})
    |> Repo.insert!()
  end

  defp insert_class(piece, hours, price) do
    %TiqitClass{content_piece_id: piece.id}
    |> TiqitClass.changeset(%{duration_hours: hours, price: Decimal.new(price)})
    |> Repo.insert!()
  end

  defp price_for(piece, hours) do
    Repo.get_by!(TiqitClass, content_piece_id: piece.id, duration_hours: hours).price
  end

  defp class?(piece, hours) do
    not is_nil(Repo.get_by(TiqitClass, content_piece_id: piece.id, duration_hours: hours))
  end
end
