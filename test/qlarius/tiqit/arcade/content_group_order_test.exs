defmodule Qlarius.Tiqit.Arcade.ContentGroupOrderTest do
  use ExUnit.Case, async: true

  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.ContentPiece

  describe "sort_pieces_by_preset/2 published dates" do
    test "orders by the YouTube publish date, newest or oldest first" do
      pieces = [
        piece(1, ~D[2024-06-01], ~N[2026-10-23 12:00:00]),
        piece(2, ~D[2020-01-15], ~N[2026-06-01 12:00:00]),
        piece(3, ~D[2025-03-09], ~N[2026-06-01 12:00:00])
      ]

      assert titles(ContentGroup.sort_pieces_by_preset(pieces, "published_desc")) == [
               "Piece 3",
               "Piece 1",
               "Piece 2"
             ]

      assert titles(ContentGroup.sort_pieces_by_preset(pieces, "published_asc")) == [
               "Piece 2",
               "Piece 1",
               "Piece 3"
             ]
    end

    test "does not follow the date the arqade was added" do
      pieces = [
        piece(1, ~D[2024-01-01], ~N[2026-10-23 12:00:00]),
        piece(2, ~D[2025-01-01], ~N[2026-06-01 12:00:00])
      ]

      assert titles(ContentGroup.sort_pieces_by_preset(pieces, "published_desc")) == [
               "Piece 2",
               "Piece 1"
             ]

      assert titles(ContentGroup.sort_pieces_by_preset(pieces, "desc")) == [
               "Piece 1",
               "Piece 2"
             ]
    end

    test "puts a piece with no publish date last" do
      pieces = [
        piece(1, nil, ~N[2026-01-01 00:00:00]),
        piece(2, ~D[2024-05-01], ~N[2026-01-02 00:00:00])
      ]

      assert titles(ContentGroup.sort_pieces_by_preset(pieces, "published_asc")) == [
               "Piece 2",
               "Piece 1"
             ]

      assert titles(ContentGroup.sort_pieces_by_preset(pieces, "published_desc")) == [
               "Piece 2",
               "Piece 1"
             ]
    end
  end

  defp piece(id, published, inserted) do
    %ContentPiece{
      id: id,
      title: "Piece #{id}",
      date_published: published,
      inserted_at: inserted
    }
  end

  defp titles(pieces), do: Enum.map(pieces, & &1.title)
end
