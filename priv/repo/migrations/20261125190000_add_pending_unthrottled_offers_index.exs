defmodule Qlarius.Repo.Migrations.AddPendingUnthrottledOffersIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # ActivatePendingOffersWorker looks up due unthrottled offers on every cron
  # tick. Without this the lookup reads the whole offers table, once per batch.
  def up do
    create_if_not_exists index(:offers, [:pending_until, :id],
                           where: "is_current = false AND is_throttled = false",
                           concurrently: true,
                           name: :offers_pending_unthrottled_index
                         )
  end

  def down do
    drop_if_exists index(:offers, [:pending_until, :id],
                     concurrently: true,
                     name: :offers_pending_unthrottled_index
                   )
  end
end
