defmodule Qlarius.Repo.Migrations.ContentPiecesDisplayOrder do
  use Ecto.Migration

  def up do
    alter table(:content_pieces) do
      add :display_order, :integer
    end

    flush()

    {:ok, %{rows: groups}} =
      repo().query("SELECT id, pieces_sort_order FROM content_groups", [])

    for [group_id, sort_order] <- groups do
      {:ok, %{rows: rows}} =
        repo().query(
          """
          SELECT id, title, inserted_at
          FROM content_pieces
          WHERE content_group_id = $1
          """,
          [group_id]
        )

      sorted =
        rows
        |> Enum.map(fn [id, title, inserted_at] ->
          %{id: id, title: title || "", inserted_at: inserted_at}
        end)
        |> sort_rows_for_legacy_preset(sort_order)

      sorted
      |> Enum.with_index()
      |> Enum.each(fn {%{id: id}, idx} ->
        repo().query!(
          "UPDATE content_pieces SET display_order = $1 WHERE id = $2",
          [idx, id]
        )
      end)
    end

    create index(:content_pieces, [:content_group_id, :display_order])

    alter table(:content_pieces) do
      modify :display_order, :integer, null: false, default: 0
    end

    alter table(:content_groups) do
      remove :pieces_sort_order
    end
  end

  def down do
    alter table(:content_groups) do
      add :pieces_sort_order, :string, default: "desc", null: false
    end

    drop index(:content_pieces, [:content_group_id, :display_order])

    alter table(:content_pieces) do
      remove :display_order
    end
  end

  defp sort_rows_for_legacy_preset(rows, "asc"),
    do: Enum.sort_by(rows, & &1.inserted_at, :asc)

  defp sort_rows_for_legacy_preset(rows, "title_asc"),
    do: Enum.sort_by(rows, &String.downcase(&1.title), :asc)

  defp sort_rows_for_legacy_preset(rows, "title_desc"),
    do: Enum.sort_by(rows, &String.downcase(&1.title), :desc)

  defp sort_rows_for_legacy_preset(rows, _),
    do: Enum.sort_by(rows, & &1.inserted_at, :desc)
end
