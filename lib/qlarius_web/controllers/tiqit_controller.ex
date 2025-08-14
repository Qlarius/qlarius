defmodule QlariusWeb.TiqitController do
  use QlariusWeb, :controller

  # Fixed alias - using new module structure instead of archived Qlarius.Tiqits
  alias Qlarius.Tiqit.Arcade.Arcade

  def index(conn, _params) do
    render(conn, :index, tiqits: Arcade.list_user_tiqits(conn.assigns.current_scope.user))
  end
end
