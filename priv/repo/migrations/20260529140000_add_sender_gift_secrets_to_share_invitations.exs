defmodule Qlarius.Repo.Migrations.AddSenderGiftSecretsToShareInvitations do
  use Ecto.Migration

  def change do
    alter table(:share_invitations) do
      add :sender_claim_token_encrypted, :binary
      add :sender_claim_pin_encrypted, :binary
    end
  end
end
