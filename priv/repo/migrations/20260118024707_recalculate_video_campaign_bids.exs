defmodule Qlarius.Repo.Migrations.RecalculateVideoCampaignBids do
  use Ecto.Migration

  def up do
    # Recalculate marketer_cost_amt for ALL bids using the new database-driven pricing
    # Formula: (offer_amt × markup_multiplier) + base_fee
    # Video (id=2): (offer_amt × 1.5) + 0.15 = 0.30 for $0.10 bid
    # 3-Tap (id=1): (offer_amt × 1.5) + 0.10 = 0.25 for $0.10 bid (unchanged)

    execute """
    UPDATE bids
    SET marketer_cost_amt = ROUND((bids.offer_amt * mpt.markup_multiplier) + mpt.base_fee, 2)
    FROM media_runs mr
    JOIN media_pieces mp ON mr.media_piece_id = mp.id
    JOIN media_piece_types mpt ON mp.media_piece_type_id = mpt.id
    WHERE bids.media_run_id = mr.id
    """
  end

  def down do
    # Revert to old hardcoded calculation
    # This applies the old formula to all bids
    execute """
    UPDATE bids
    SET marketer_cost_amt = ROUND((bids.offer_amt * 1.5) + 0.10, 2)
    """
  end
end
