This document describes the UI for managing media sequences.

## Data model review:

*   **MediaSequence:** (`lib/qlarius/marketing/media_sequence.ex`) This is essentially a *named container* or *template* for a sequence of ads. It has a `title` and a `description`. The *critical* part is that it's linked to `MediaRun` records.
*   **MediaRun:** (`lib/qlarius/marketing/media_run.ex`) This defines *how* a *specific* `MediaPiece` will be displayed within a `MediaSequence`.  It has the following key attributes:
    *   `media_piece_id`:  The ad content to display.
    *   `frequency`: How many *times* this ad should be shown (e.g., 3 times).
    *   `frequency_buffer_hours`:  A minimum time between *completions* of the ad cycle (all phases).  Example: 24 means "at least 24 hours between complete showings."
    *   `maximum_banner_count`:  How many times the banner ad (phase 1) can be *shown* without a click-through before it's considered complete.  This prevents infinite display if a user never clicks.
    *   `banner_retry_buffer_hours`: How long to wait before showing the banner again if it *wasn't* clicked.

## UI Breakdown and Use Cases

- [x] All routes for the following pages must go within the block within `router.ex` that's tagged with the comment 'MARKETER'

### List media sequences

**Purpose:** Displays a list of existing Media Sequences.

- [x] Has the heading 'Media Sequences'
- [x] Just below the heading is a button "New" that links to the "New Media Sequence form" described below)
- [x] Displays a table that lists all Media Sequences, with columns:
    - [x] "Sequence name" (shows the sequence's `title`).
    - [x] "Description" (shows the sequences `description`).
    - [x] "Phase Count" (an empty `<td></td>`)
    - [x] "Current Campaign Count" (an empty `<td></td>`)
    - [x] "Notes" (an empty `<td></td>`)

## New Media Sequence

**Purpose:** Form to create a new Media Run with associated Media Sequence

Despite the name, all of the fields on the form are for a media *run*, not a media sequence. The associated media sequence will be created on submit.

- [x] Has heading "New Media Sequence"
- [x] Has a form with the following fields:
    - [x] "Media piece" - a dropdown select that lists all `MediaPiece` records sorted by their `title`. Each option's content is the `title` and its `value` is the MediaPiece's `id`. This field sets the media run's `media_piece_id` attr.
    - [x] "Frequency" - number field. Default `3`. Sets the run's `frequency` attr.
    - [x] "Frequency Buffer (hours)" - number field. Default `24`.  Sets the run's `frequency_buffer_hours` attr.
    - [x] "Maximum Banner Count" - number field. Default `3`.  Sets the run's `maximum_banner_count` attr.
    - [x] "Banner Retry Buffer (hours)" - number field. Default `10`.  Sets the run's `banner_retry_buffer_hours` attr.
- [x] Submit button ("Create")
- [x] On successful submission, it creates the MediaRun with an associated MediaSequence.
    - [x] The sequence's `title` is calculated from the media piece's attributes like this: `"#{display_url} | #{title} | #{frequency}:#{frequency_buffer_hours}:#{maximum_banner_count}:#{banner_retry_buffer_hours}"`
- [x] On unsuccessful submission, it re-renders the form with errors.
