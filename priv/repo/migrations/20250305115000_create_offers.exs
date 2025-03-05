defmodule Qlarius.Repo.Migrations.CreateOffers do
  use Ecto.Migration

  def change do
    create table(:offers) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :media_run_id, references(:media_runs), null: false
      add :phase_1_amount, :decimal, precision: 8, scale: 2, null: false
      add :phase_2_amount, :decimal, precision: 8, scale: 2, null: false
      add :amount, :decimal, precision: 10, scale: 2, null: false

      timestamps()
    end

    create index(:offers, :user_id)
    create index(:offers, :media_run_id)
  end
end
