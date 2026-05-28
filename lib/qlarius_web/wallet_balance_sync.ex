defmodule QlariusWeb.WalletBalanceSync do
  @moduledoc """
  PubSub subscription and assign refresh for `wallet_balance` / `wallet_strip` UI.

  LiveViews that render wallet pills should call `subscribe/1` when connected and
  delegate wallet-related `handle_info/2` messages here so every instance on the
  page receives updated assigns (announcer bar, drawer header, arqade strip, etc.).
  """

  alias Qlarius.Accounts.Scope
  alias Qlarius.Repo
  alias Qlarius.Wallets
  alias Qlarius.Wallets.MeFileStatsBroadcaster
  alias Qlarius.YouData.MeFiles.MeFile

  import Ecto.Query, only: [from: 2]

  @doc "Subscribe to me_file stats + wallet topics for the scoped user."
  def subscribe(socket) do
    case wallet_user(socket) do
      {user_id, me_file_id} when is_integer(me_file_id) ->
        MeFileStatsBroadcaster.subscribe_to_me_file_stats(me_file_id)
        Phoenix.PubSub.subscribe(Qlarius.PubSub, "wallet:#{user_id}")
        socket

      {user_id, nil} when is_integer(user_id) ->
        case resolve_me_file_id(socket) do
          me_file_id when is_integer(me_file_id) ->
            MeFileStatsBroadcaster.subscribe_to_me_file_stats(me_file_id)

          _ ->
            :ok
        end

        Phoenix.PubSub.subscribe(Qlarius.PubSub, "wallet:#{user_id}")
        socket

      _ ->
        socket
    end
  end

  @doc """
  After an ad collection in a LiveComponent on the parent LV, push an immediate
  wallet/stats refresh to this process (banner tap runs in the drawer LC).
  """
  def sync_host_after_ad_collection(socket) do
    case socket.assigns[:current_scope] do
      %{user: %{me_file: %{id: me_file_id}}} when is_integer(me_file_id) ->
        send(self(), {:refresh_wallet_balance, me_file_id})
        socket

      _ ->
        socket
    end
  end

  @doc false
  def sync_message?({:me_file_balance_updated, _}), do: true
  def sync_message?(:update_balance), do: true
  def sync_message?({:refresh_wallet_balance, _}), do: true
  def sync_message?({:me_file_stats_updated, _}), do: true
  def sync_message?({:me_file_offers_updated, _}), do: true
  def sync_message?(_), do: false

  @doc false
  def wallet_message?(msg), do: sync_message?(msg)

  @doc """
  Applies a known balance to socket assigns. Updates `:current_scope`, and
  `:balance` / `:current_balance` when those assigns exist (arqade strip, modals).
  """
  def assign_wallet_fields(socket, new_balance) do
    case socket.assigns[:current_scope] do
      scope when not is_nil(scope) ->
        current_scope = Map.put(scope, :wallet_balance, new_balance)

        socket
        |> assign(:current_scope, current_scope)
        |> maybe_assign(:current_balance, new_balance)
        |> maybe_assign(:balance, new_balance)

      _ ->
        socket
    end
  end

  @doc "Refetch balance from the database and apply to assigns."
  def refetch_and_assign(socket) do
    case socket.assigns[:current_scope] do
      %{user: user} ->
        assign_wallet_fields(socket, Wallets.get_user_current_balance(user))

      _ ->
        socket
    end
  end

  @doc """
  Refetch full me_file stats into `:current_scope` (wallet, ads_count,
  offered_amount, ad counts, etc.) from the database.
  """
  def refresh_scope_stats(socket) do
    case scope_user(socket) do
      nil ->
        socket

      user ->
        refreshed = Scope.for_user(user)

        socket
        |> assign(:current_scope, refreshed)
        |> maybe_assign(:current_balance, refreshed.wallet_balance)
        |> maybe_assign(:balance, refreshed.wallet_balance)
    end
  end

  @doc "Route a wallet/stats PubSub message to the appropriate assign refresh."
  def handle_sync_message({:me_file_balance_updated, new_balance}, socket) do
    assign_wallet_fields(socket, new_balance)
  end

  def handle_sync_message(:update_balance, socket), do: refetch_and_assign(socket)

  def handle_sync_message({:refresh_wallet_balance, _me_file_id}, socket),
    do: refetch_and_assign(socket)

  def handle_sync_message({:me_file_stats_updated, _me_file_id}, socket),
    do: refresh_scope_stats(socket)

  def handle_sync_message({:me_file_offers_updated, _me_file_id}, socket),
    do: refresh_scope_stats(socket)

  def handle_info_message(msg, socket), do: handle_sync_message(msg, socket)

  @doc """
  Inline arqade embeds notify the hosting parent on connect so wallet PubSub
  events can be forwarded when the nested LV misses a broadcast.
  """
  def notify_inline_parent(socket) do
    if Phoenix.LiveView.connected?(socket) && socket.assigns[:inline?] && socket.parent_pid do
      send(socket.parent_pid, {:inline_arcade_embed_ready, self()})
    end

    socket
  end

  @doc "Forward a wallet PubSub message to the registered inline arqade embed, if any."
  def forward_to_inline_embed(socket, msg) do
    case socket.assigns[:arcade_embed_pid] do
      pid when is_pid(pid) ->
        send(pid, msg)
        socket

      _ ->
        socket
    end
  end

  @doc """
  Register the nested arqade embed pid on a hosting parent LiveView.
  Monitors the child so stale pids are cleared when the embed remounts.
  """
  def register_inline_embed(socket, pid) when is_pid(pid) do
    socket =
      case socket.assigns[:arcade_embed_monitor_ref] do
        ref when is_reference(ref) ->
          Process.demonitor(ref, [:flush])
          socket

        _ ->
          socket
      end

    ref = Process.monitor(pid)

    socket
    |> assign(:arcade_embed_pid, pid)
    |> assign(:arcade_embed_monitor_ref, ref)
  end

  @doc "Clear inline embed registration after the child process exits."
  def clear_inline_embed(socket) do
    socket
    |> assign(:arcade_embed_pid, nil)
    |> assign(:arcade_embed_monitor_ref, nil)
  end

  @doc "Notify the hosting parent LiveView when an inline embed updates wallet assigns locally."
  def notify_parent_wallet_update(socket, new_balance) do
    if socket.assigns[:inline?] && socket.parent_pid do
      send(socket.parent_pid, {:me_file_balance_updated, new_balance})
    end

    socket
  end

  @doc "After sync on an inline embed, push the refreshed balance up to the parent LV."
  def notify_parent_after_sync(socket) do
    case socket.assigns do
      %{inline?: true, current_scope: %{wallet_balance: balance}} when not is_nil(balance) ->
        notify_parent_wallet_update(socket, balance)

      _ ->
        socket
    end
  end

  defp resolve_me_file_id(socket) do
    case socket.assigns[:current_scope] do
      %{user: %{me_file: %{id: me_file_id}}} when is_integer(me_file_id) ->
        me_file_id

      %{user: %{id: user_id}} when is_integer(user_id) ->
        Repo.one(
          from m in MeFile, where: m.user_id == ^user_id, select: m.id, limit: 1
        )

      _ ->
        nil
    end
  end

  defp wallet_user(socket) do
    case socket.assigns[:current_scope] do
      %{user: %{id: user_id, me_file: %{id: me_file_id}}} -> {user_id, me_file_id}
      %{user: %{id: user_id}} -> {user_id, nil}
      _ -> nil
    end
  end

  defp scope_user(socket) do
    case socket.assigns[:current_scope] do
      %{true_user: user} when not is_nil(user) -> user
      %{user: user} when not is_nil(user) -> user
      _ -> nil
    end
  end

  defp assign(socket, key, value), do: Phoenix.Component.assign(socket, key, value)

  defp maybe_assign(socket, key, value) do
    if Map.has_key?(socket.assigns, key), do: assign(socket, key, value), else: socket
  end
end
