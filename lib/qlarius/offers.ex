defmodule Qlarius.Offers do
  @moduledoc """
  The Offers context.
  """

  import Ecto.Query, warn: false
  alias Qlarius.Repo
  alias Qlarius.Offer

  @doc """
  Returns the list of offers for a user.
  """
  def list_user_offers(user_id) do
    Offer
    |> where([o], o.user_id == ^user_id)
    |> preload(:media_piece)
    |> Repo.all()
  end
end
