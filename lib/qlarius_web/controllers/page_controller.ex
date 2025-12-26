defmodule QlariusWeb.PageController do
  use QlariusWeb, :controller

  def home(conn, _params) do
    render(conn, :home, title: "Home")
  end

  def hi(conn, _params) do
    if conn.assigns[:current_scope] do
      redirect(conn, to: ~p"/home")
    else
      render(conn, :hi, title: "Welcome to Qlarius")
    end
  end
end
