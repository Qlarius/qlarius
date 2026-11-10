defmodule Qlarius.Repo.Migrations.AddThrottleActivationIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    create_if_not_exists index(:offers, [:me_file_id, :pending_until, :id],
                           where: "is_current = false AND is_throttled = true",
                           concurrently: true,
                           name: :offers_pending_throttled_index
                         )

    create_if_not_exists index(:offers, [:me_file_id],
                           where: "is_current = true AND is_throttled = true",
                           concurrently: true,
                           name: :offers_current_throttled_index
                         )

    create_if_not_exists index(:ad_events, [:me_file_id, :created_at],
                           where: "is_throttled = true",
                           concurrently: true,
                           name: :ad_events_throttled_me_file_created_index
                         )
  end

  def down do
    drop_if_exists index(:offers, [:me_file_id, :pending_until, :id],
                     concurrently: true,
                     name: :offers_pending_throttled_index
                   )

    drop_if_exists index(:offers, [:me_file_id],
                     concurrently: true,
                     name: :offers_current_throttled_index
                   )

    drop_if_exists index(:ad_events, [:me_file_id, :created_at],
                     concurrently: true,
                     name: :ad_events_throttled_me_file_created_index
                   )
  end
end
