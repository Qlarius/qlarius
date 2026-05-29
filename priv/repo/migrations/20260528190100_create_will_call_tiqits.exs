defmodule Qlarius.Repo.Migrations.CreateWillCallTiqits do
  use Ecto.Migration

  def change do
    create table(:will_call_tiqits) do
      add :will_call_uuid, :uuid, null: false
      add :share_invitation_id, references(:share_invitations, on_delete: :delete_all), null: false

      add :sender_user_id, references(:users, on_delete: :nilify_all), null: false
      add :sender_me_file_id, references(:me_files, on_delete: :nilify_all), null: false

      add :tiqit_class_id, references(:tiqit_classes, on_delete: :nilify_all), null: false
      add :content_piece_id, references(:content_pieces, on_delete: :nilify_all)
      add :content_group_id, references(:content_groups, on_delete: :nilify_all)
      add :amount, :decimal, null: false

      add :claim_pin_hash, :string, null: false
      add :claim_pin_attempt_count, :integer, null: false, default: 0
      add :claim_pin_last_viewed_at, :utc_datetime

      add :claimed_by_user_id, references(:users, on_delete: :nilify_all)
      add :claimed_by_me_file_id, references(:me_files, on_delete: :nilify_all)
      add :recipient_tiqit_id, references(:tiqits, on_delete: :nilify_all)

      add :sender_debit_ledger_entry_id, references(:ledger_entries, on_delete: :nilify_all)
      add :recipient_gift_credit_ledger_entry_id,
          references(:ledger_entries, on_delete: :nilify_all)
      add :recipient_purchase_debit_ledger_entry_id,
          references(:ledger_entries, on_delete: :nilify_all)
      add :creator_credit_ledger_entry_id, references(:ledger_entries, on_delete: :nilify_all)
      add :sender_reversal_ledger_entry_id, references(:ledger_entries, on_delete: :nilify_all)

      add :will_call_status, :string, null: false, default: "at_will_call"
      add :claimed_at, :utc_datetime
      add :reversed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:will_call_tiqits, [:will_call_uuid])
    create unique_index(:will_call_tiqits, [:share_invitation_id])
    create unique_index(:will_call_tiqits, [:recipient_tiqit_id])
    create index(:will_call_tiqits, [:sender_me_file_id])
    create index(:will_call_tiqits, [:will_call_status])
  end
end
