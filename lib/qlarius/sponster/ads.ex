defmodule Qlarius.Sponster.Ads do
  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Sponster.Ads.MediaPiece

  @doc """
  Lists all active media pieces for a marketer with media_piece_type preloaded.
  """
  def list_active_media_pieces_for_marketer(marketer_id) do
    from(mp in MediaPiece,
      where: mp.marketer_id == ^marketer_id and mp.active == true,
      order_by: [asc: mp.title],
      preload: :media_piece_type
    )
    |> Repo.all()
  end

  @doc """
  Gets a media piece with preloaded associations.
  """
  def get_media_piece!(id) do
    Repo.one!(
      from mp in MediaPiece,
        where: mp.id == ^id,
        preload: :media_piece_type
    )
  end
end
