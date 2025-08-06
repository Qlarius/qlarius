defmodule QlariusWeb.AdJumpPageController do
  use QlariusWeb, :controller

  alias Qlarius.Sponster.Offers

  def jump(conn, %{"id" => offer_id}) do
    offer = Offers.get_offer_with_media_piece!(offer_id)
    render(conn, :jump, layout: false, offer: offer)
  end
end
