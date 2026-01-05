defmodule Qlarius.Wallets.MeFileStatsBroadcaster do
  @moduledoc """
  PubSub broadcasting for real-time MeFile statistics updates.

  Handles broadcasting updates for:
  - Wallet balance changes
  - Active offer count changes
  - Offered amount changes
  - Other MeFile-related stats
  """

  alias Phoenix.PubSub

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
