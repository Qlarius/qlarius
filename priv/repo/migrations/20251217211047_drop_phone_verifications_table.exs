defmodule Qlarius.Repo.Migrations.DropPhoneVerificationsTable do
  use Ecto.Migration

  def change do
    drop_if_exists table(:phone_verifications)
  end
end
