# Building Sponster campaigns

This topic covers building ad campaigns through the admin API, starting with
Prime the Pump (PTP) campaigns: ads Qadabra pays for so new users see matched
ads. They are usually real-brand ads, and the same records keep working when a
PTP campaign later becomes a paying one.

Each brand gets its own marketer record. There is no shared PTP parent
marketer. Dev and prod are separate builds: read ids from the system you are
building in and never copy ids between systems.

Build in this order: marketer, media piece, trait groups, target, then the
sequence (the run is created with the sequence, from the piece), then the
campaign. Stop before launch unless the admin has confirmed it. The checklist
at the bottom is the same order. `POST /api/admin/ptp_campaigns/builds` does
the whole chain in one call and never launches.

## API reference keys (required)

Every create needs an `api_ref`. A create without one is refused with
`422 api_ref_required`.

Why it matters:

- **Safe retries.** Sending the same `api_ref` again returns the existing
  record with `"matched": true` instead of creating a duplicate. If a call
  times out or you lose your place, resend it.
- **Provenance.** A record with an `api_ref` was made through the API. Records
  made in the UI have none.
- **Review and cleanup.** List calls and delete dry runs accept
  `api_ref_prefix`, so you can see or remove one brand's drafts at once.

### How to build a key

Build every key from the inputs, so the same build always produces the same
key. Never use random values or timestamps: a retry must send the identical
key.

Pattern: `<program>-<yymm>-<brand>-<area>.<type>[-<n>]`

- `program`: `ptp` for Prime the Pump.
- `yymm`: the month the build was planned, for example `2610`.
- `brand`: a lowercase slug of the brand name using **underscores**, never
  hyphens: `joes_tacos`, `pet_barn`. Hyphens are reserved as separators.
- `area`: the campaign's scope. The PTP coverage report groups campaigns by
  it, so always include it for PTP builds:
  - `nat` for national campaigns.
  - A short place code for zip or local targeting, for example `phx`, `tuc`,
    `sea`. Keep codes consistent across brands.
  - `niche-<topic>` for interest-led campaigns, for example `niche-pets`.
- `type`: `marketer`, `ad`, `tg` (trait group), `target`, `seq` (media
  sequence), or `campaign`.
- `n`: a 1-based counter when a brand has more than one of a type, for
  example `.tg-2`.

Example keys for one local brand:

    ptp-2610-joes_tacos-phx.marketer
    ptp-2610-joes_tacos-phx.ad
    ptp-2610-joes_tacos-phx.tg-1        (interests)
    ptp-2610-joes_tacos-phx.tg-2        (zip codes)
    ptp-2610-joes_tacos-phx.target
    ptp-2610-joes_tacos-phx.seq
    ptp-2610-joes_tacos-phx.campaign

### Rules

- Lowercase letters, digits, `-`, `_` and `.` only, 3 to 128 characters,
  starting with a letter or digit (`422 invalid_api_ref` otherwise).
- One key means one record. Never reuse a key for something else. To make a
  new version, add `-v2` after the type (`.campaign-v2`) so the area stays
  readable.
- Keep a run log of each key and the id it returned, so you can report
  results and resume where you left off.
- `"matched": true` means the record already existed. Read `differences`
  (`{field: {current, requested}}`). Nothing changes unless you resend with
  `on_existing: "update"`, and only do that when you mean to change the
  record. `on_existing` is `skip` (default) or `update`.
- `409 api_ref_conflict` means the key belongs to a record of another
  marketer or owner. Stop and ask the admin. Do not invent a new key to get
  around it.
- `api_ref` can't be changed once set (`422 api_ref_immutable`).
- The same key in dev and prod is fine; they are separate databases.

## Throttling and PTP pacing

PTP campaigns are created with `is_throttled: true` unless you send
`is_throttled` explicitly. Throttling spaces a user's ads out so they never
get many at once and then nothing.

The throttle cap is **global**: `THROTTLE_AD_COUNT` ads per `THROTTLE_DAYS`
days (currently 3 per 7) applies to all throttled campaigns together, not to
each campaign. It counts throttled ad events in the window, and a completed
3-tap ad records more than one event (a banner view and a click-through), so
in practice a user completes fewer throttled ads than the raw number
suggests. Do not change these Global Variables; report coverage concerns to
the admin instead.

PTP campaigns also default to `is_payable: false` (earnings from them are not
cashable) unless you send `is_payable`. Both flags can be changed later.

## Media piece types

`GET /api/admin/media_piece_types` lists every type with `id`, `name`,
`description`, `ad_phase_count_to_complete`, `base_fee`,
`markup_multiplier`, `required_fields`, `field_limits`, and `writable`.

- The standard banner is the 3-tap ad: media piece type **id 1**. It is the
  writable type today. Its `required_fields` are `banner_image`, `display_url`,
  and `jump_url`. `field_limits` caps `title` at 32 characters and `body_copy`
  at 120. Confirm that on the GET response before you create.
- Video ads are media piece type **id 2**. The list shows them with
  `writable: false` and `required_fields` of `video_file` and `duration`.
  Video creates are coming. Until `writable` is true, do not upload a video
  through this API. When it flips to true, use those required fields.
- `base_fee` and `markup_multiplier` are how a bid becomes the marketer
  cost: `marketer_cost = offer_amt × markup_multiplier + base_fee`.

## Media pieces

- `GET /api/admin/media_pieces` filters with `marketer_id`, `row_id` (the ad
  category row), `active`, `q` (title contains), `api_ref_prefix`, and
  `limit`.
- `GET /api/admin/media_pieces/:id` returns one piece, including
  `ad_category_row_id`.
- `POST /api/admin/media_pieces` creates a piece. Required: `api_ref`,
  `marketer_id`, `media_piece_type_id` (a writable type), `ad_category_row_id`
  (an active row from the ad categories API), `title`, `display_url`,
  `jump_url`, and an image. `active` defaults to true when omitted. Optional:
  `body_copy`, `on_existing`, `dry_run`.
- A 3-tap `title` is one line, at most 32 characters. `body_copy` is at most
  120 characters, about three lines, so the display URL stays visible. Longer
  title or body copy is refused. `display_url` is at most 40 characters.
- `display_url` is the green text under the body copy, not a link. Send the
  host only, for example `joestacos.example`, with no `https://`. `jump_url`
  is the address the tap opens, so that one is a full `https://` URL.
- The banner displays at 300 by 100 pixels. Send the image at double that,
  600 by 200 pixels, so it stays sharp. Both sizes are 3:1. A file that is
  not 3:1 is stretched to the slot.
- Create and update both accept a banner file upload. On `POST` and `PATCH
  /api/admin/media_pieces`, send a multipart file in a field named
  `banner_image`, and send `Accept: application/json` with that request. The
  same requests accept an HTTPS `image_url` instead of a file. Create requires
  one of the two. On update, send an image only when you want to replace the
  stored banner. Video file upload is not accepted.
- The uploaded file and the URL are both limited to JPG, PNG, GIF, or WebP, at
  most 10 MB. URL fetches must be HTTPS. Hosts that resolve to a private,
  loopback, or link-local address are refused, and every redirect is checked
  the same way.
- After the piece exists, open its edit page in the app:
  `/marketer/media/<id>/edit`. That page has a Preview panel. For a 3-tap ad
  it shows the banner and the text panel. For a video ad it shows the video.
  Use that preview to judge the ad before launch. A create or update response
  also includes `banner_url`, the stored banner file.
- A dry run checks the image and the fields and stores nothing.
- `PATCH /api/admin/media_pieces/:id` edits the same fields, including
  `ad_category_row_id` and `active`. `api_ref` cannot change. A replacement
  banner is the same multipart `banner_image` or HTTPS `image_url` as create.
  Omit both to leave the stored image alone. A category change is allowed on a
  piece that already sits in a launched campaign. Offers do not store the
  category; the offer screen reads it from the piece, so the new row's label
  shows on offers that already exist. An inactive row is still refused.
  `active: false` does not delete or refresh those offers. It blocks a new
  sequence and blocks launch. Offers already out keep serving this piece.
- `DELETE /api/admin/media_pieces/:id` deletes a piece that is in no media run
  and has no ad events. `?dry_run=true` first. Otherwise `409 has_dependents`.

## Marketers

- `GET /api/admin/marketers` lists marketers with counts of campaigns,
  PTP campaigns, media pieces, targets, trait groups, media sequences, and
  members. Filters: `q` (business name contains), `domain` (matches the host
  of `business_url`; `https://` and `www.` are ignored), `api_ref_prefix`,
  `has_ptp=true`, and `limit` (default 100, max 500).
- `GET /api/admin/marketers/:id` returns one marketer with the same counts.
- `POST /api/admin/marketers` creates a marketer:
  `{api_ref, business_name, business_url?, contact_first_name?,
  contact_last_name?, contact_number?, contact_email?, sic_code?,
  on_existing?, dry_run?}`. Returns `201` with `result: "created"`, or `200`
  with `result: "matched"`, `"would_create"`, `"would_update"`, or
  `"updated"`. Creating a marketer attaches no user, sends no email, and sets
  up no billing. A person is given access later from the admin Marketer
  Manager page.
- `PATCH /api/admin/marketers/:id` edits the same fields (not `api_ref`).
  Supports `dry_run`.
- `DELETE /api/admin/marketers/:id` deletes a marketer that has no campaigns,
  media pieces, targets, trait groups, media sequences, or members. Send
  `?dry_run=true` first. Otherwise `409 has_dependents` lists the counts.

## Trait groups

Build groups before targets. A target never creates groups for you.

- `GET /api/admin/trait_groups?marketer_id=&creator_id=&api_ref_prefix=` lists
  groups with `trait_ids` and `me_file_count`.
- `POST /api/admin/trait_groups` creates one:
  `{api_ref, title, marketer_id or creator_id, parent_trait_id?, trait_ids,
  dry_run?, on_existing?}`. `trait_ids` are active children of
  `parent_trait_id`. Omit the parent only for a free set of traits. Read trait
  ids from this system's traits catalog.
- `POST /api/admin/trait_groups/:id/traits` with `{add: [], remove: []}`
  changes membership. A group used by a launched campaign is `409 frozen_target`.
  A group that sits on more than one target is `409 trait_group_shared`: create
  a new group instead of editing the shared one.
- `DELETE /api/admin/trait_groups/:id` only when the group is on no band.
  `?dry_run=true` first.
- `GET /api/admin/zip_codes?q=` searches zip traits. `q` must be at least 2
  characters. With no `parent_trait_id`, the ids are children of Home Zip Code.
  Pass `parent_trait_id` to search another zip parent, such as Work Zip Code.
  The response names the parent. Use those ids as `trait_ids` on a group whose
  `parent_trait_id` is that same parent. Do not adjust the ids. Zip targeting
  is an ordinary trait group. There is no radius search.

## Targets

Bands are built bullseye outward. The bullseye holds every group. Each entry
in `drop_order` peels that one group off to form the next, wider band. The
last remaining group is the widest. Create the bullseye groups first so its
band id is smallest: bids pay the tightest band the most.

- `POST /api/admin/targets/builds` body:
  `{api_ref, marketer_id or creator_id, title, bullseye: [group ids],
  drop_order: [group ids], dry_run?, on_existing?}`.
  `drop_order` ids must be in the bullseye, and each step drops exactly one.
  The response includes `bands`, each with `estimated_reach`. Near-zero reach
  on a local database is expected and is not an error.
- `GET /api/admin/targets?marketer_id=&creator_id=&archived=` and
  `GET /api/admin/targets/:id` return bands, labels, frozen, and campaign ids.
- `POST /api/admin/targets/:id/bands` with `{exclude_trait_group_id}` adds one
  outer band. `DELETE /api/admin/targets/:id/bands/outermost` removes the
  widest band. Both refuse a target a launched campaign still uses.
- `POST /api/admin/targets/:id/clone` requires a new `api_ref`. Same owner
  shares the trait groups. `dest_marketer_id` or `dest_creator_id` copies into
  another org.
- `POST /api/admin/targets/:id/populate` enqueues population.
  `GET /api/admin/targets/:id/population` returns the status and a count per band.
- `DELETE /api/admin/targets/:id` only when no campaign has ever used it.

## Media sequences

A sequence is built from an ad, not the other way around.

1. The media piece already exists and has an id.
2. A media run is that piece plus frequency rules. A run cannot be created
   without `media_piece_id`.
3. A media sequence is the container for those runs.

Today every sequence has one run, and a campaign uses that run. The tables
allow a sequence to hold more than one run later. Until then, bids use the
first run.

- `POST /api/admin/media_sequences`:
  `{api_ref, marketer_id, media_piece_id, title?, frequency?,
  frequency_buffer_hours?, maximum_banner_count?, banner_retry_buffer_hours?,
  dry_run?}`.
  The ad must belong to that marketer and be active. Omitted frequency fields
  come from the PTP Global Variables, and the response `defaults_used` lists
  which ones were filled in:
  `PTP_SEQUENCE_FREQUENCY` 3, `PTP_SEQUENCE_FREQUENCY_BUFFER_HOURS` 96,
  `PTP_SEQUENCE_MAX_BANNER_COUNT` 3, `PTP_SEQUENCE_BANNER_RETRY_BUFFER_HOURS` 48.
  If a variable is missing, the code uses those numbers.
- `DELETE /api/admin/media_sequences/:id` only when no campaign references it
  at all, including deactivated ones.

## Campaigns

Bids: the outermost band is $0.10 and each band inward adds $0.01. Marketer
cost is `offer × markup_multiplier + base_fee` from the ad type. There is no
budget cap. The campaign ledger may go negative; that negative balance is
Qadabra PTP spend.

- `POST /api/admin/campaigns/bid_preview` with `{marketer_id, target_id,
  media_sequence_id}` returns each band's offer, cost, population, and a
  worst-case total. It writes nothing.
- `POST /api/admin/campaigns`:
  `{api_ref, marketer_id, target_id, media_sequence_id, title, is_ptp?,
  is_payable?, is_throttled?, start_date?, end_date?, dry_run?}`.
  The target and sequence must belong to the marketer, and the target must
  not be archived. `is_ptp: true` sets `is_payable: false` and
  `is_throttled: true` unless you send those fields. A dry run returns the
  bid preview and does not create a ledger.
- `GET /api/admin/campaigns?marketer_id=&is_ptp=&status=&api_ref_prefix=`
  filters `status` as `draft`, `launched`, or `deactivated`.
  `GET /api/admin/campaigns/:id` adds bids, offer count, ad event count,
  ledger balance, and the target's population status.
- `PATCH /api/admin/campaigns/:id` edits title, dates, and the flags.
  `target_id` and `media_sequence_id` cannot change after launch. Changing
  `is_payable`, `is_throttled`, or `is_ptp` on a launched campaign
  refreshes its offers. A dry run says it would.
- `POST /api/admin/campaigns/:id/launch` requires `{confirm: true}`.
  Without it: `422 confirm_required`. Preflight refuses a target with no
  bands, a sequence with no run, an inactive ad, an inactive ad category, or
  a band without a bid. Launch populates the target if it is not populated
  yet, and does not wait for population to finish.
- `POST /api/admin/campaigns/:id/deactivate` deletes the campaign's offers.
  A dry run reports how many. `POST /api/admin/campaigns/:id/reactivate`
  clears `deactivated_at`.
- `GET /api/admin/campaigns/:id/offers?limit=` returns counts and a sample.
- `DELETE /api/admin/campaigns/:id` only for a campaign that was never
  launched and has no ledger entries. It also removes the bids and the empty
  ledger. `409 launched` or `409 has_dependents` otherwise.

## One-call PTP build

`POST /api/admin/ptp_campaigns/builds` creates the marketer, ad, trait groups,
target, sequence, and campaign in one transaction. It never launches.

Required: `api_ref_base`, shaped like a key without the type, for example
`ptp-2610-joes_tacos-phx`. The call derives:

- `base.marketer`, `base.ad`, `base.tg-1`, `base.tg-2`, ...
- `base.target`, `base.seq`, `base.campaign`

`trait_groups` is an array in bullseye order. `target.drop_order` is a list
of indexes into that array (0 drops the first group), not trait group ids.
`campaign.is_ptp` is always true. `is_throttled` defaults to true unless
`campaign` sends it. Send `dry_run: true` first. A dry run rolls the database
transaction back. Resending the same base returns `result: "matched"` and the
same ids.

To upload the banner on this call, send `multipart/form-data` with
`Accept: application/json`. Put the whole JSON body in one string field named
`payload`, and the file in a field named `banner_image`. The file becomes the
ad's banner. Do not send `trait_groups` as separate form fields when you use
`payload`.

A form that does send fields directly is also accepted. `trait_groups[0][title]`
and `trait_groups[0][trait_ids][0]` are read as lists, not as one collapsed
group. Prefer `payload` whenever the body has nested lists.

Keep a run log of each key and the id that came back.

## Coverage

`GET /api/admin/reports/ptp_coverage?month=YYYY-MM` is read-only. For PTP
campaigns it reports ads delivered that month per user (median, share at
least 10, share at zero), pending offers, and counts by campaign, band, and
scope. Scope is parsed from the `api_ref` area segment: `nat` is national,
`niche-...` is niche, another area is local, and no area is unscoped.

`throttle_blocked_users` counts people who hold a pending throttled PTP offer
and have already hit the global throttle cap in the current window. The cap
is shared by every throttled campaign, so it can be what limits coverage.

## Worked example

One local PTP brand, Phoenix, stopping before launch. Read trait ids and the
ad category `row_id` from this system first. Send `dry_run: true` on the
build, then send it again without `dry_run`. Do not call launch.

```json
{
  "api_ref_base": "ptp-2610-joes_tacos-phx",
  "dry_run": true,
  "marketer": {"business_name": "Joe's Tacos", "business_url": "https://joestacos.example"},
  "media_piece": {
    "title": "Joe's Tacos",
    "media_piece_type_id": 1,
    "ad_category_row_id": "<row_id from this system>",
    "display_url": "joestacos.example",
    "jump_url": "https://joestacos.example",
    "image_url": "https://cdn.example/joes.png"
  },
  "trait_groups": [
    {"title": "Taco fans", "parent_trait_id": 100, "trait_ids": [101, 102]},
    {"title": "Phoenix", "parent_trait_id": 200, "trait_ids": [85001]}
  ],
  "target": {"title": "Phoenix taco fans", "drop_order": [0]},
  "sequence": {"title": "Joe's Tacos"},
  "campaign": {"title": "Joe's Tacos PTP"}
}
```

`media_piece_type_id`, `parent_trait_id`, and `trait_ids` above are
placeholders. Replace them with ids from the system you are calling. The
campaign comes back with `is_ptp: true`, `is_payable: false`, and
`is_throttled: true`.

## Checklist

| Step | Call |
| --- | --- |
| Read this guide | `GET /api/admin/agent_guide?topic=campaigns` |
| Choose an ad category row | `GET /api/admin/ad_categories` |
| Choose a writable ad type | `GET /api/admin/media_piece_types` |
| Look up traits, including zips | traits catalog, `GET /api/admin/zip_codes?q=` (Home Zip Code unless you pass `parent_trait_id`) |
| Or build everything below in one call | `POST /api/admin/ptp_campaigns/builds` |
| Create the marketer | `POST /api/admin/marketers` |
| Create the ad | `POST /api/admin/media_pieces` |
| Create trait groups | `POST /api/admin/trait_groups` |
| Assemble the target, bullseye outward | `POST /api/admin/targets/builds` |
| Preview reach | the build response `estimated_reach` |
| Populate when you want counts filled in | `POST /api/admin/targets/:id/populate` |
| Create the sequence and its run | `POST /api/admin/media_sequences` |
| Preview bids | `POST /api/admin/campaigns/bid_preview` |
| Create the campaign, still a draft | `POST /api/admin/campaigns` |
| Launch only after confirm | `POST /api/admin/campaigns/:id/launch` with `confirm: true` |
| See what was delivered | `GET /api/admin/reports/ptp_coverage?month=YYYY-MM` |
| Remove an unlaunched draft | `DELETE` the campaign, then sequence, target, groups, ad, marketer, each with `dry_run=true` first |

## Errors

- `422 api_ref_required`, `422 invalid_api_ref`, `422 api_ref_immutable`
- `409 api_ref_conflict`: stop and ask the admin.
- `409 has_dependents`: `dependents` has the counts that block the delete.
- `422 invalid_on_existing`: `on_existing` must be `skip` or `update`.
- `422 invalid`: per-field `errors`, for example a missing `business_name`.
- `422 confirm_required`: launch needs `confirm: true`.
- `409 launched`: the campaign has been launched and cannot be deleted.
- `409 frozen_target`: a launched campaign still uses this target.
- `409 trait_group_shared`: create a new group instead of editing this one.
- `422 traits_required`, `422 traits_not_children`, `422 drop_not_in_bullseye`,
  `422 empty_band`, `422 zip_query_too_short`.
- `422 invalid_month`: coverage `month` must be `YYYY-MM`.
