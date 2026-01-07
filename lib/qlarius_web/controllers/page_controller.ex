defmodule QlariusWeb.PageController do
  use QlariusWeb, :controller

  def home(conn, _params) do
    if conn.assigns[:current_scope] do
      render(conn, :home, title: "Home")
    else
      redirect(conn, to: ~p"/accounts/register")
    end
  end
end
