defmodule Qlarius.Repo.Migrations.CreateOffersAndMediaPieces do
  use Ecto.Migration

  def change do
    create table(:media_pieces) do
      add :title, :string, size: 256
      add :display_url, :string, size: 256
      add :body_copy, :string, size: 1028

      timestamps()
    end

    create table(:offers) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :media_piece_id, references(:media_pieces, on_delete: :delete_all), null: false
      add :phase_1_amount, :decimal, precision: 8, scale: 2, null: false
      add :phase_2_amount, :decimal, precision: 8, scale: 2, null: false
      add :amount, :decimal, precision: 10, scale: 2, null: false

      timestamps()
    end

    create index(:offers, :user_id)
    create index(:offers, :media_piece_id)
  end
end
