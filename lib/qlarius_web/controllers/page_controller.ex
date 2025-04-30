defmodule QlariusWeb.PageController do
  use QlariusWeb, :controller

  alias Qlarius.MeFile

  @debug false

  def home(conn, _params) do

    render(conn, :home, debug: @debug)
  end
end
