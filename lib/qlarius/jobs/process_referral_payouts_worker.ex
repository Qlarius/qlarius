defmodule Qlarius.Jobs.ProcessReferralPayoutsWorker do
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger
  alias Qlarius.Referrals

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("[ReferralPayouts] Starting weekly referral payout processing")

    pending_by_referrer = Referrals.get_unpaid_clicks_by_referrer()

    referrers_grouped =
      pending_by_referrer
      |> Enum.group_by(fn {type, id, _referral_id, _click_count} -> {type, id} end)

    Logger.info(
      "[ReferralPayouts] Found #{map_size(referrers_grouped)} referrers with pending clicks"
    )

    results =
      Enum.map(referrers_grouped, fn {{type, id}, _referrals} ->
        case Referrals.process_referrer_payout(type, id) do
          {:ok, %{clicks: clicks, amount: amount}} ->
            Logger.info(
              "[ReferralPayouts] Paid #{clicks} clicks ($#{Decimal.to_string(amount, :normal)}) to #{type} #{id}"
            )

            {:ok, :paid}

          {:error, :no_ledger} ->
            Logger.error("[ReferralPayouts] No ledger found for #{type} #{id}")
            {:error, :no_ledger}

          {:error, reason} ->
            Logger.error(
              "[ReferralPayouts] Failed to process payout for #{type} #{id}: #{inspect(reason)}"
            )

            {:error, reason}
        end
      end)

    successful = Enum.count(results, fn {status, _} -> status == :ok end)
    failed = Enum.count(results, fn {status, _} -> status == :error end)

    Logger.info("[ReferralPayouts] Completed: #{successful} successful, #{failed} failed")

    {:ok, %{successful: successful, failed: failed}}
  end
end
