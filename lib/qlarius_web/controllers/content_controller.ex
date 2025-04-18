defmodule QlariusWeb.ContentController do
  use QlariusWeb, :controller

  alias Qlarius.Arcade

  def groups(conn, _params) do
    groups = Arcade.list_content_groups()
    render(conn, groups: groups)
  end
end
