defmodule Qlarius.Sponster.DraftOfferCleanup do
  @moduledoc """
  Deletes offers that belong to campaigns which have never launched.

  An offer that already has an ad event is left in place. Those rows may have
  ledger entries, and removing them needs a separate decision.

  Run through `mix qlarius.delete_draft_campaign_offers` after review.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.Sponster.AdEvent
  alias Qlarius.Sponster.Offer

  def delete_unlaunched_offers do
    offer_ids =
      from(o in Offer,
        join: c in assoc(o, :campaign),
        where: is_nil(c.launched_at),
        select: o.id
      )
      |> Repo.all()

    kept_ids =
      if offer_ids == [] do
        []
      else
        from(ae in AdEvent,
          where: ae.offer_id in ^offer_ids,
          distinct: true,
          select: ae.offer_id
        )
        |> Repo.all()
      end

    deletable_ids = offer_ids -- kept_ids

    deleted =
      if deletable_ids == [] do
        0
      else
        {count, _} =
          from(o in Offer, where: o.id in ^deletable_ids)
          |> Repo.delete_all()

        count
      end

    %{deleted: deleted, kept_with_events: length(kept_ids)}
  end
end
