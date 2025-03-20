defmodule QlariusWeb.AdController do
  use QlariusWeb, :controller

  def jump(conn, _params) do
    render(conn, "jump.html", layout: false)
  end
end
