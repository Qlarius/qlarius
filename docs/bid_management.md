Extracted this from the campaign stuff, not implemented yet.

On the campaign index page, each campaign includes its bid table:

*   **Bid Table (`_target_band_bid_table_form.html.erb`):**  This is the most complex part of the UI, embedded within the Campaign display.
    *   **Rows:**  Each row represents a `TargetBand` associated with the `Campaign`'s `Target`.
    *   **Columns:**
        *   **Band:** Displays "Bullseye" for the bullseye band, or "OB-X" (Outer Band-X) for other bands.  The `index_of_band_in_target` method is used to calculate the "X".
        *   **Traits:** Lists the `title` of each `TraitGroup` associated with the current `TargetBand`.
        *   **Pop:** Displays the number of `MeFile` records that match the `TargetBand`'s criteria (through the `target_populations` association).
        *   **Bid | Cost:** This column has two modes:
            *   **Display Mode:** Shows the current `offer_amt` (bid) and calculated `marketer_cost_amt` for the `Bid` record associated with this `Campaign`, `TargetBand` and first `MediaRun`.  Uses badges for visual emphasis.
            *   **Edit Mode:**  Shows an input field (`text_field`) for the `offer_amt`.  The `marketer_cost_amt` is likely updated via JavaScript on change, but the provided code does not show where the `marketer_cost_amt` is calculated.  The field is named using a pattern that allows multiple bids to be updated at once: `bids[#{bid.id}]`.

    *   **"Edit bids" Link:** Toggles between display and edit mode using Javascript (see below).
    *   **"Update bids" Submit Button:** (Hidden in display mode) Submits the form to update the bid amounts.


Flows:


* **Bid Management**
    * **Edit Mode:** The 'edit bid' link uses javascript to display the form and hide the static values.
    * **Save Bids:** The `update_bid_amounts` action is called via AJAX.
        *   The action iterates through the `params[:bids]` hash, updating each `Bid` record with the new `offer_amt`.
        *   The `marketer_cost_amt` is recalculated based on the updated `offer_amt`.
        *   The `update_current_offers` method is called on each bid, updating the associated `Offer` records.
        *   The bid table is re-rendered via JavaScript.

