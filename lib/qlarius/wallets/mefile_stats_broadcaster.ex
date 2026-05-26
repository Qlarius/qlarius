defmodule Qlarius.Wallets.MeFileStatsBroadcaster do
  @moduledoc """
  PubSub for MeFile-scoped updates (`me_file_stats_updates:…`). Balance updates
  also broadcast `:update_balance` on `wallet:USER_ID` so any subscribed LiveView
  (e.g. arqade) stays in sync.
  """

  import Ecto.Query, only: [from: 2]

  alias Phoenix.PubSub
  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFile

  @topic_prefix "me_file_stats_updates:"

  def subscribe_to_me_file_stats(me_file_id) do
    PubSub.subscribe(Qlarius.PubSub, "#{@topic_prefix}#{me_file_id}")
  end

  def broadcast_balance_updated(me_file_id, new_balance) do
    PubSub.broadcast(
      Qlarius.PubSub,
      "#{@topic_prefix}#{me_file_id}",
      {:me_file_balance_updated, new_balance}
    )

    # Keep LiveViews on "wallet:#{user_id}" (arqade, wallet widget) in sync with ledger changes
    # that go through this broadcaster (ads, referrals, transfers, etc.)
    case user_id_for_me_file(me_file_id) do
      user_id when is_integer(user_id) ->
        PubSub.broadcast(Qlarius.PubSub, "wallet:#{user_id}", :update_balance)

      _ ->
        :ok
    end
  end

  @doc """
  Notifies `/wallet` (and future subscribers) that ledger rows changed — e.g. description
  sanitized after tiqit refund/fleet. Does not replace `broadcast_balance_updated/2` when
  balance also changes; call both when needed.
  """
  def broadcast_ledger_updated(me_file_id) do
    PubSub.broadcast(
      Qlarius.PubSub,
      "#{@topic_prefix}#{me_file_id}",
      {:me_file_ledger_updated, me_file_id}
    )

    case user_id_for_me_file(me_file_id) do
      user_id when is_integer(user_id) ->
        PubSub.broadcast(Qlarius.PubSub, "wallet:#{user_id}", :ledger_updated)

      _ ->
        :ok
    end
  end

  defp user_id_for_me_file(me_file_id) do
    Repo.one(from m in MeFile, where: m.id == ^me_file_id, select: m.user_id)
  end

  def broadcast_offers_updated(me_file_id) do
    PubSub.broadcast(
      Qlarius.PubSub,
      "#{@topic_prefix}#{me_file_id}",
      {:me_file_offers_updated, me_file_id}
    )
  end

  def broadcast_stats_updated(me_file_id) do
    PubSub.broadcast(
      Qlarius.PubSub,
      "#{@topic_prefix}#{me_file_id}",
      {:me_file_stats_updated, me_file_id}
    )
  end

  def broadcast_pending_referral_clicks_updated(me_file_id, pending_clicks_count) do
    PubSub.broadcast(
      Qlarius.PubSub,
      "#{@topic_prefix}#{me_file_id}",
      {:me_file_pending_referral_clicks_updated, pending_clicks_count}
    )
  end
end
