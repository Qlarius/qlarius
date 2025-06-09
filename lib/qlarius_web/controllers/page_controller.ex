defmodule QlariusWeb.PageController do
  use QlariusWeb, :controller

  alias Qlarius.MeFile

  def home(conn, _params) do
    render(conn, :home, debug: @debug)
  end
end
