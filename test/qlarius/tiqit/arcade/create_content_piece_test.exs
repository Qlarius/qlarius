defmodule Qlarius.Tiqit.Arcade.CreateContentPieceTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.{Catalog, ContentGroup, Creators}

  setup do
    {:ok, creator} =
      Creators.create_creator(%{"name" => "Pieces #{System.unique_integer([:positive])}"})

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

    %{group: group}
  end

  test "string-keyed form params get the next display order", %{group: group} do
    assert {:ok, first} =
             Creators.create_content_piece(group, %{
               "title" => "First",
               "date_published" => "2026-01-01"
             })

    assert {:ok, second} =
             Creators.create_content_piece(group, %{
               "title" => "Second",
               "date_published" => "2026-01-02"
             })

    assert first.display_order == 0
    assert second.display_order == 1
  end

  test "atom-keyed params still work", %{group: group} do
    assert {:ok, piece} =
             Creators.create_content_piece(group, %{title: "Atom", date_published: ~D[2026-01-01]})

    assert piece.display_order == 0
  end
end
