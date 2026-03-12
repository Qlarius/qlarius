defmodule Qlarius.Repo.Migrations.AddRefundLockedAtToTiqits do
  use Ecto.Migration

  def change do
    alter table(:tiqits) do
      add :refund_locked_at, :utc_datetime
    end
  end
end
