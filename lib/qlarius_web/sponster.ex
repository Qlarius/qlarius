defmodule QlariusWeb.Sponster do
  alias Qlarius.Wallets

  def on_mount(:initialize_bottom_bar, _params, _session, socket) do
    socket =
      Phoenix.Component.assign_new(socket, :wallet_balance, fn ->
        Wallets.get_user_current_balance(socket.assigns.current_user)
      end)

    {:cont, socket}
  end

  def initialize_bottom_bar(conn, _opts) do
    if conn.assigns[:wallet_balance] do
      conn
    else
      balance = Wallets.get_user_current_balance(conn.assigns.current_user)
      Plug.Conn.assign(conn, :wallet_balance, balance)
    end
  end
end
