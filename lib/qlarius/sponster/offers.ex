defmodule Qlarius.Sponster.Offers do
  @moduledoc """
  The Offers context.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.Sponster.Offer

  @doc """
  Returns the list of offers for a user, in descending order of their amount
  """
  # def list_user_offers(user_id) do
  #   from(o in Offer,
  #     join: u in assoc(o, :user),
  #     where: u.id == ^user_id and o.is_current == true,
  #     order_by: [desc: o.amount],
  #     preload: [:ad_category, :media_piece]
  #   )
  #   |> Repo.all()
  # end

  # def count_user_offers(user_id) do
  #   from(o in Offer, join: u in assoc(o, :user), where: u.id == ^user_id)
  #   |> Repo.count()
  # end

  def total_active_offer_amount(me_file) do
    from(o in Offer, where: o.me_file_id == ^me_file.id and o.is_current == true)
    |> Repo.aggregate(:sum, :offer_amt)
  end

  def get_offer_with_media_piece!(id) do
    Repo.get!(Offer, id) |> Repo.preload(:media_piece)
  end
end
