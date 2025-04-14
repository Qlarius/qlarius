defmodule QlariusWeb.Creators.CreatorController do
  use QlariusWeb, :controller

  def redirect_to_content_groups(conn, _params) do
    redirect(conn, to: ~p"/creators/content_groups")
  end
end
