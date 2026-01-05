defmodule Qlarius.Maintenance.BackfillReferralCodes do
  @moduledoc """
  Backfills referral codes for MeFiles, Creators, and Recipients that don't have them.

  Usage:
    Qlarius.Maintenance.BackfillReferralCodes.run()
  """

  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Creators.Creator
  alias Qlarius.Sponster.Recipient
  alias Qlarius.Referrals

  def run do
    IO.puts("Starting referral code backfill...")

    me_files_count = backfill_me_files()
    creators_count = backfill_creators()
    recipients_count = backfill_recipients()

    IO.puts("\nBackfill complete!")
    IO.puts("  MeFiles updated: #{me_files_count}")
    IO.puts("  Creators updated: #{creators_count}")
    IO.puts("  Recipients updated: #{recipients_count}")

    {:ok, %{me_files: me_files_count, creators: creators_count, recipients: recipients_count}}
  end

  defp backfill_me_files do
    query = from m in MeFile, where: is_nil(m.referral_code)

    Repo.all(query)
    |> Enum.map(fn me_file ->
      code = Referrals.generate_referral_code("mefile")

      me_file
      |> Ecto.Changeset.change(%{referral_code: code})
      |> Repo.update!()
    end)
    |> length()
  end

  defp backfill_creators do
    query = from c in Creator, where: is_nil(c.referral_code)

    Repo.all(query)
    |> Enum.map(fn creator ->
      code = Referrals.generate_referral_code("creator")

      creator
      |> Ecto.Changeset.change(%{referral_code: code})
      |> Repo.update!()
    end)
    |> length()
  end

  defp backfill_recipients do
    query = from r in Recipient, where: is_nil(r.referral_code)

    Repo.all(query)
    |> Enum.map(fn recipient ->
      code = Referrals.generate_referral_code("recipient")

      recipient
      |> Ecto.Changeset.change(%{referral_code: code})
      |> Repo.update!()
    end)
    |> length()
  end
end
