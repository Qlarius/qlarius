defmodule QlariusWeb.Admin.TraitsIndexController do
  use QlariusWeb, :controller

  alias Qlarius.YouData.Traits

  def index(conn, _params) do
    traits_index = Traits.traits_index_by_parent()
    json_string = Jason.encode!(traits_index, pretty: true)

    render(conn, "index.html", json_string: json_string)
  end
end
