defmodule QlariusWeb.AdController do
  use QlariusWeb, :controller

  alias Qlarius.Repo
  alias Qlarius.Sponster.Offer
  alias Qlarius.Sponster.Ads.MediaPiece

  def jump(conn, %{"id" => offer_id}) do
    offer = Repo.get_by!(Offer, id: offer_id)
    offer = Repo.preload(offer, :media_piece)
    render(conn, :jump, layout: false, offer: offer)
  end
end
