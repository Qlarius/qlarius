defmodule Qlarius.Wallets.MeFileBalanceBroadcaster do
  alias Phoenix.PubSub

  @topic_prefix "me_file_balance_updates:"

  def subscribe_to_me_file_balance(me_file_id) do
    PubSub.subscribe(Qlarius.PubSub, "#{@topic_prefix}#{me_file_id}")
  end

  def broadcast_me_file_balance_update(me_file_id, new_balance) do
    PubSub.broadcast(
      Qlarius.PubSub,
      "#{@topic_prefix}#{me_file_id}",
      {:me_file_balance_updated, new_balance}
    )
  end
end
