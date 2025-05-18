defmodule QlariusWeb.TiqitController do
  use QlariusWeb, :controller

  alias Qlarius.Tiqits

  def index(conn, _params) do
    render(conn, :index, tiqits: Tiqits.list_user_tiqits(conn.assigns.current_scope.user))
  end
end
