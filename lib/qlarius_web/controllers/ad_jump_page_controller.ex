defmodule QlariusWeb.AdJumpPageController do
  use QlariusWeb, :controller

  alias Qlarius.Sponster.Offers

  def jump(conn, %{"id" => offer_id}) do
    offer = Offers.get_offer_with_media_piece!(offer_id)
    Offers.create_pending_copy_and_delete_original(offer, 1) #to be replaced with better complete offer check after demo needs
    render(conn, :jump, layout: false, offer: offer)
  end
end
