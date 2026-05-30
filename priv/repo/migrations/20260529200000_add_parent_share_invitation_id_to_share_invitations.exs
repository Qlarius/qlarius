defmodule Qlarius.Repo.Migrations.AddParentShareInvitationIdToShareInvitations do
  use Ecto.Migration

  def change do
    alter table(:share_invitations) do
      add :parent_share_invitation_id, references(:share_invitations, on_delete: :nilify_all)
    end

    create index(:share_invitations, [:parent_share_invitation_id])
  end
end
