defmodule QlariusWeb.Sponster do
  alias Qlarius.Wallets
  alias Qlarius.Offers

  def on_mount(:initialize_bottom_bar, _params, _session, socket) do
    import Phoenix.Component

    socket =
      socket
      |> assign_new(:wallet_balance, fn ->
        Wallets.get_user_current_balance(socket.assigns.current_user)
      end)
      |> assign_new(:ads_count, fn ->
        Offers.count_user_offers(socket.assigns.current_user.id)
      end)

    {:cont, socket}
  end

  def initialize_bottom_bar(conn, _opts) do
    conn
    |> assign_new_wallet_balance()
    |> assign_new_ads_count()
  end

  defp assign_new_wallet_balance(%Plug.Conn{} = conn) do
    if conn.assigns[:wallet_balance] do
      conn
    else
      balance = Wallets.get_user_current_balance(conn.assigns.current_user)
      Plug.Conn.assign(conn, :wallet_balance, balance)
    end
  end

  defp assign_new_wallet_balance(conn) do
    if conn.assigns[:wallet_balance] do
      conn
    else
      balance = Wallets.get_user_current_balance(conn.assigns.current_user)
      Plug.Conn.assign(conn, :wallet_balance, balance)
    end
  end

  defp assign_new_ads_count(conn) do
    if conn.assigns[:ads_count] do
      conn
    else
      count = Offers.count_user_offers(conn.assigns.current_user.id)
      Plug.Conn.assign(conn, :ads_count, count)
    end
  end
end
