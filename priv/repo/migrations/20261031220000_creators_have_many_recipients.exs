defmodule Qlarius.Repo.Migrations.CreatorsHaveManyRecipients do
  use Ecto.Migration

  def up do
    alter table(:recipients) do
      add :creator_id, references(:creators, on_delete: :nilify_all)
      add :is_primary, :boolean, null: false, default: false
      add :archived_at, :utc_datetime
    end

    create index(:recipients, [:creator_id])

    Enum.each(backfill_sql(), &execute/1)

    create unique_index(:recipients, [:creator_id],
             where: "is_primary = true AND creator_id IS NOT NULL",
             name: :recipients_one_primary_per_creator
           )

    alter table(:catalogs) do
      add :recipient_id, references(:recipients, on_delete: :nilify_all)
    end

    create index(:catalogs, [:recipient_id])

    execute catalog_backfill_sql()
  end

  def down do
    drop index(:catalogs, [:recipient_id])

    alter table(:catalogs) do
      remove :recipient_id
    end

    drop_if_exists unique_index(:recipients, [:creator_id],
                     name: :recipients_one_primary_per_creator
                   )

    drop index(:recipients, [:creator_id])

    alter table(:recipients) do
      remove :archived_at
      remove :is_primary
      remove :creator_id
    end
  end

  @doc """
  Links each creator's existing recipient as its primary. Safe to run again:
  a recipient that already has creator_id is left alone, and a recipient
  shared by two creators is claimed by the lowest creator id.
  """
  def backfill_sql do
    [
      """
      UPDATE recipients AS r
      SET creator_id = c.id,
          is_primary = true
      FROM creators AS c
      WHERE c.recipient_id = r.id
        AND r.creator_id IS NULL
        AND c.id = (
          SELECT MIN(c2.id) FROM creators AS c2 WHERE c2.recipient_id = r.id
        )
      """
    ]
  end

  def catalog_backfill_sql do
    """
    UPDATE catalogs AS cat
    SET recipient_id = c.recipient_id
    FROM creators AS c
    WHERE cat.creator_id = c.id
      AND c.recipient_id IS NOT NULL
      AND cat.recipient_id IS NULL
    """
  end
end
