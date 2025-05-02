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
    Offer
    |> where([o], o.user_id == ^user_id)
    |> preload([:media_piece, :ad_category])
    |> Repo.count()
  end
end
