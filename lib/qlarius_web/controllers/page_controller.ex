defmodule QlariusWeb.PageController do
  use QlariusWeb, :controller

  alias Qlarius.Traits

  def home(conn, _params) do
    trait_count = Traits.count_traits_with_values(conn.assigns.current_scope.user.id)
    render(conn, :home, trait_count: trait_count)
  end
end
