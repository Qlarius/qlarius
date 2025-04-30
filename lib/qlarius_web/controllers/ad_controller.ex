defmodule QlariusWeb.AdController do
  use QlariusWeb, :controller

  alias Qlarius.LegacyRepo
  alias Qlarius.Legacy.{Offer, MediaPiece}

  def jump(conn, %{"id" => offer_id}) do
    offer = LegacyRepo.get_by!(Offer, id: offer_id)
    offer = LegacyRepo.preload(offer, :media_piece)
    render(conn, :jump, layout: false, offer: offer)
  end
end
