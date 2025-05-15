defmodule QlariusWeb.TiqitHTML do
  use QlariusWeb, :html

  def index(assigns) do
    ~H"""
    <ul>
      <li :for={tiqit <- @tiqits}>
        {tiqit.content_piece.title} - {tiqit.expires_at}
      </li>
    </ul>
    """
  end
end
