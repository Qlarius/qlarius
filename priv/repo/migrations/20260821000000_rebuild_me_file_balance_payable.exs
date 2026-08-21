defmodule Qlarius.Repo.Migrations.RebuildMeFileBalancePayable do
  use Ecto.Migration

  def up do
    flush()
    Qlarius.Wallets.rebuild_me_file_balance_payable!()
  end

  def down do
    :ok
  end
end
