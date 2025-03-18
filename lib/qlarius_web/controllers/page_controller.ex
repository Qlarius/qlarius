defmodule QlariusWeb.PageController do
  use QlariusWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
