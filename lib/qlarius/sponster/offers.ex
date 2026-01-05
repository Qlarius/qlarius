defmodule Qlarius.Sponster.Offers do
  @moduledoc """
  The Offers context.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.Sponster.Offer
  alias Ecto.Multi

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

  def get_offer_with_media_piece(id) do
    case Repo.get(Offer, id) do
      nil -> nil
      offer -> Repo.preload(offer, :media_piece)
    end
  end

  @doc """
  Creates a pending copy of an offer with a future pending_until timestamp and deletes the original.
  Returns {:ok, new_offer} if successful, {:error, changeset} if creation fails.

  This function is to be updated to check the media_run parameters and create a new offer only if needed. For now, it just creates a new offer with a future pending_until timestamp and deletes the original for demo purposes.
  """
  def create_pending_copy_and_delete_original(offer, hours) do
    pending_until = DateTime.add(DateTime.utc_now(), hours, :hour)

    offer_copy =
      %{offer | id: nil, is_current: false, pending_until: pending_until}
      |> Map.from_struct()
      |> Map.drop([:created_at, :updated_at])

    Multi.new()
    |> Multi.delete(:delete_original, offer)
    |> Multi.insert(:new_offer, Offer.changeset(%Offer{}, offer_copy))
    |> Repo.transaction()
    |> case do
      {:ok, %{new_offer: new_offer}} -> {:ok, new_offer}
      {:error, _failed_operation, changeset, _changes} -> {:error, changeset}
    end
  end
end
