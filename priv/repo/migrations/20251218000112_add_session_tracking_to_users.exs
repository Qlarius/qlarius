defmodule Qlarius.Repo.Migrations.AddSessionTrackingToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add_if_not_exists :last_sign_in_at, :utc_datetime
      add_if_not_exists :last_sign_in_ip, :string
      add_if_not_exists :last_sign_in_user_agent, :string
    end

    create table(:user_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string

      timestamps(updated_at: false)
    end

    create index(:user_tokens, [:user_id])
    create unique_index(:user_tokens, [:context, :token])
  end
end
