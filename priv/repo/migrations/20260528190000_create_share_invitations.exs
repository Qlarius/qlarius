defmodule Qlarius.Repo.Migrations.CreateShareInvitations do
  use Ecto.Migration

  def change do
    create table(:share_invitations) do
      add :token_hash, :string, null: false
      add :sender_user_id, references(:users, on_delete: :nilify_all), null: false
      add :sender_me_file_id, references(:me_files, on_delete: :nilify_all), null: false

      add :share_type, :string, null: false
      add :share_target_type, :string

      add :content_piece_id, references(:content_pieces, on_delete: :nilify_all)
      add :content_group_id, references(:content_groups, on_delete: :nilify_all)
      add :tiqit_class_id, references(:tiqit_classes, on_delete: :nilify_all)

      add :status, :string, null: false, default: "active"

      add :personal_message, :text
      add :claim_window_hours, :integer, null: false, default: 48
      add :gift_expires_at, :utc_datetime
      add :converts_to_share_after_gift_expiration, :boolean, null: false, default: true

      add :redeemed_at, :utc_datetime
      add :redeemed_by_user_id, references(:users, on_delete: :nilify_all)
      add :redeemed_by_me_file_id, references(:me_files, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:share_invitations, [:token_hash])
    create index(:share_invitations, [:sender_me_file_id])
    create index(:share_invitations, [:content_group_id])
    create index(:share_invitations, [:share_type])
  end
end
