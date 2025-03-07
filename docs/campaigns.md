
This document describes the UI for managing campaigns

## Data model review:

To understand the context, here's a reminder of the key relationships:

*   `Marketer` has many `Campaigns`
*   `Campaign` belongs to one `Marketer`
*   `Campaign` belongs to one `Target`
*   `Campaign` belongs to one `MediaSequence`
*   `Campaign` has many `Bids` (through a join with `TargetBand` and `MediaRun`)
* `Campaign` has one `LedgerHeader`
*  `Campaign` has many `Offers`
*  `Campaign` has many `AdEvents`

## UI Breakdown and Use Cases

### Campaigns Index Page

*   **Purpose:** Lists all campaigns belonging to the currently selected marketer.
*   **Content:**
    *   Heading: "Campaigns"
    *   A "New" button/link to create a new campaign.
    *   A list of campaigns (see below)

1.  **Campaign List:**
    *   [ ] Display a list of campaigns.
    *   [ ] Provide links/buttons to create, edit, and delete campaigns.
    *

*   **Actions:**
    *   Clicking "New" navigates to the `new` action.
    *   The list displays each campaign.

**2. Campaign Partial (`sponster/campaigns/_campaign.html.erb`)**

This partial is used to display a single campaign's information, primarily within the index view. It's a bit complex because it also handles bid display and editing.

*   **Content:**
    *   **Campaign Header:**
        *   Campaign Title ( `campaign.title` )
        *   Buttons:
            *   "Edit" (links to the `edit` action).
            *   "Delete" (links to the `destroy` action, with confirmation).
    *   **Campaign Info Table (Top):**
        *   Start Date: (`campaign.start_date`)
        *   End Date: (`campaign.end_date`)
        *   Spend To-Date: (`campaign.total_spend_to_date`)
        *   Balance: (`campaign.ledger_header.try(:balance)`)  -- Note the use of `try` to handle potentially missing `ledger_header`.
        *   Unique Reach:  Displays "n/a" (Not implemented in the current code).
        *   Banner Impressions: Displays "n/a" (Not implemented in the current code).
        *   Text Jumps:  Displays "n/a" (Not implemented in the current code).
    *   **Target and Media Sequence Table (Bottom):**
        *   Headers: "Target" and "Media Sequence".
        *   **Target Column:**
            *   Displays the Target title (and ID).
            *   Includes a form (`target_band_bid_table_form`) to manage bids for each `TargetBand` associated with the `Campaign`'s `Target`.  This is the core of the bid management UI.
        *   **Media Sequence Column:**
            *   Uses the `_media_run.html.erb` partial *repeatedly* to display the `MediaPiece` and rules of each `MediaRun` in the *selected* `MediaSequence`.  There's no way to change the sequence from here; it's display-only.

**3. New/Edit Campaign Forms (`new.html.erb` and `edit.html.erb`, using `_form.html.erb`)**

*   **Purpose:** These forms are nearly identical, used for creating and updating `Campaign` records.
*   **Fields:**
    *   `title`: Text field for the campaign title.
    *   `media_sequence_id`:  Dropdown/select to choose the `MediaSequence`.
    *   `target_id`: Dropdown/select to choose the `Target`.
    *   `start_date`: Date selection.
    *   `end_date`: Date selection (optional).
    *   `description`: Text area for campaign notes.
    *   `is_payable`: Checkbox.
    *   `is_throttled`: Checkbox.
*   **Buttons:**
    *   "Create Campaign" / "Update Campaign" (submit button)
    *   "Cancel" (link)

**4. Show Campaign (`show.html.erb`)**

* A very simple, barely used, view.
*  It only renders a notice and the @campaign attributes.
* **There is no detailed view that allows us to see a Campaign.** The list (index view) uses the partial `_campaign.html.erb` which contains all of the information and is described in the index.

**5. Javascript (`*.js.erb` files):**

*   **`enter_bid_edit_mode.js.erb`:**  Hides the "display mode" elements and shows the "edit mode" elements in the bid table.
*   **`enter_bid_display_mode.js.erb`:** Hides the "edit mode" elements and shows the "display mode" elements in the bid table.
*   **`update_bid_amounts.js.erb`:**  Re-renders the `_target_band_bid_table_form` partial to update the bid display after saving changes.

**CRUD Actions and Data Flow**

*   **Create:**
    1.  User navigates to `new_sponster_campaign_path`.
    2.  `new` action renders the form.
    3.  User fills in the form, selects a `Target` and a `MediaSequence`.
    4.  Form is submitted to the `create` action.
    5.  `Campaign` record is created.
    6.  `seed_initial_bids` is called, creating `Bid` records for each `TargetBand` of the chosen `Target`, and for the (first, and only) `MediaRun` of the selected `MediaSequence`.
    7.  `seed_initial_ledger_header` is called, to ensure a `LedgerHeader` exists.
    8.  Sidekiq jobs are enqueued to populate the target and create initial offers.
    9.  Redirect to the `show` action for the new `Campaign`.

*   **Read:**
    *   `index`: Lists all campaigns for the current marketer.
    *   `show`: Displays basic campaign details.  The *real* display of campaign information, including bids, happens in the `_campaign` partial, which is rendered by the `index` view.

*   **Update:**
    *   User navigates to `edit_sponster_campaign_path`.
    *   `edit` action renders the form, pre-populated with the `Campaign` data.
    *   User modifies the fields.
    *   Form is submitted to the `update` action.
    *   `Campaign` record is updated.
    *   **Important:**  The provided code *does not* update bids when a campaign is updated. Bid updates are handled *separately* via the `update_bid_amounts` action.
    *   Redirect to the `show` action for the updated `Campaign`.

*   **Delete:**
    *   User clicks "Delete" on the `index` view.
    *   Confirmation dialog is shown (handled by `data: { confirm: 'Are you sure?' }`).
    *   `destroy` action deletes the `Campaign` record and associated `Bid` records.
    *   Redirect to the `index` action.

**Feature Checklist for Reimplementation (Strictly Based on Existing Code)**

2.  **Create Campaign:**
    *   [ ] Provide a form to create a new campaign.
    *   [ ] Require a title.
    *   [ ] Allow optional description.
    *   [ ] **Require** selection of an existing `Target`.
    *   [ ] **Require** selection of an existing `MediaSequence`.
    *   [ ] Include fields for `start_date` and `end_date`.
    *   [ ] Include checkboxes for `is_payable` and `is_throttled`.
    *   [ ] On successful creation, redirect to the campaign list.
    *   [ ] On failure, re-render the form with error messages.
    *   [ ] Upon creation, automatically create `Bid` records for each `TargetBand` of the selected `Target` and each 'MediaRun' of the chosen `MediaSequence`.
    *   [ ] Upon creation, ensure a `LedgerHeader` exists for the campaign.
    * [ ] Upon creation enqueue the jobs `CreateInitialPendingOffers` and `PopulateInitialTargetPopulation`.

3.  **Edit Campaign:**
    *   [ ] Provide a form to edit an existing campaign.
    *   [ ] Pre-populate the form with existing campaign data.
    *   [ ] Allow updating of title, description, start/end dates.
    *   [ ] Allow changing the selected `Target` and `MediaSequence`. *Important Note:* The existing code doesn't provide a way to *add* new `MediaRun` records to a `MediaSequence` after creation, a major limitation.
    *   [ ] On successful update, redirect to the campaign list.
    *   [ ] On failure, re-render the form with error messages.

4.  **Delete Campaign:**
    *   [ ] Provide a way to delete a campaign.
    *   [ ] Require confirmation before deletion.
    *   [ ] Delete the `Campaign` record and all associated `Bid` records (cascade deletion).
    *   [ ] Redirect to the campaign list.

5.  **Display Campaign Details:**
    *   [ ] Show campaign title.
    *   [ ] Show campaign start and end dates.
    *   [ ] Show total spend to date.
    *   [ ] Show ledger balance.
    *   [ ] Show associated `Target` (likely just the title).
    *   [ ] Show associated `MediaSequence` (likely just the title).  *Ideally*, this would show the sequence of `MediaRun` records, but the current implementation makes this difficult.
    *   [ ] Show a table of `TargetBands` and associated `Bid` amounts.

6.  **Bid Management (within Campaign context):**
    *   [ ] Display a table of Target Bands and their current bid amounts.
    *   [ ] Provide a way to enter "edit mode" for bids.
    *   [ ] In edit mode, show input fields for each `offer_amt`.
    *   [ ] **Critical:** Calculate and display the `marketer_cost_amt` based on the `offer_amt` (client-side, using JavaScript).
    *   [ ] Provide a "Save" button to update bid amounts. This should use an AJAX request to a dedicated controller action (`update_bid_amounts`).
    *   [ ] Provide a "Cancel" button to exit edit mode without saving.
    *   [ ] After updating bids, refresh the bid table display (using JavaScript).

7. **Media Run:**
    *  [ ] Display the media run within the campaign view.

This checklist is strictly based on the *existing* code, even if the functionality is limited or unconventional.  A well-designed rebuild would almost certainly have a separate controller and views for managing `MediaRun` records within a `MediaSequence`.
