defmodule Qlarius.Offers do
  @moduledoc """
  The Offers context.
  """

  import Ecto.Query

  alias Qlarius.Accounts.User
  alias Qlarius.Repo
  alias Qlarius.Offer

  @doc """
  Returns the list of offers for a user.
  """
  def list_user_offers(user_id) do
    Repo.get!(User, user_id)
    |> Repo.preload(:offers)
    |> Map.fetch!(:offers)
    |> Repo.preload([:media_piece, :ad_category])
  end

  def count_user_offers(user_id) do
    from(o in Offer, join: u in assoc(o, :user), where: u.id == ^user_id)
    |> Repo.count()
  end

  def get_offer_with_media_piece!(id) do
    Repo.get!(Offer, id) |> Repo.preload(:media_piece)
  end
end
