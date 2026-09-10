defmodule Qlarius.Repo.Migrations.SnapshotTiqitPurchaseFields do
  use Ecto.Migration

  def up do
    alter table(:tiqits) do
      add :price, :decimal, precision: 10, scale: 2
      add :duration_hours, :integer
      add :content_piece_id, references(:content_pieces, on_delete: :nilify_all)
      add :content_group_id, references(:content_groups, on_delete: :nilify_all)
      add :catalog_id, references(:catalogs, on_delete: :nilify_all)
    end

    create index(:tiqits, [:content_piece_id])
    create index(:tiqits, [:content_group_id])
    create index(:tiqits, [:catalog_id])

    execute("""
    UPDATE tiqits AS t
    SET
      price = tc.price,
      duration_hours = tc.duration_hours,
      content_piece_id = tc.content_piece_id,
      content_group_id = tc.content_group_id,
      catalog_id = tc.catalog_id
    FROM tiqit_classes AS tc
    WHERE t.tiqit_class_id = tc.id
    """)

    execute("""
    ALTER TABLE tiqits
      ALTER COLUMN tiqit_class_id DROP NOT NULL
    """)

    execute("""
    ALTER TABLE tiqits
      DROP CONSTRAINT IF EXISTS tiqits_tiqit_class_id_fkey,
      ADD CONSTRAINT tiqits_tiqit_class_id_fkey
        FOREIGN KEY (tiqit_class_id)
        REFERENCES tiqit_classes(id)
        ON DELETE SET NULL
    """)
  end

  def down do
    execute("""
    ALTER TABLE tiqits
      DROP CONSTRAINT IF EXISTS tiqits_tiqit_class_id_fkey,
      ADD CONSTRAINT tiqits_tiqit_class_id_fkey
        FOREIGN KEY (tiqit_class_id)
        REFERENCES tiqit_classes(id)
    """)

    execute("""
    ALTER TABLE tiqits
      ALTER COLUMN tiqit_class_id SET NOT NULL
    """)

    alter table(:tiqits) do
      remove :price
      remove :duration_hours
      remove :content_piece_id
      remove :content_group_id
      remove :catalog_id
    end
  end
end
