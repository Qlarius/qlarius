# Managing the Sponster ad taxonomy

Every media piece (ad) has one ad category row. The taxonomy is flat: each
row is a subcategory with its own `row_id` (for example `SP06-03`), and a
category is the set of rows that share a `category_id` (for example `SP06`).
There is no separate category record.

- `ad_label` is the text people see on ads. It is unique across all rows and
  at most 46 characters.
- `category_name` is the formal name; `category_label` is the friendly one.
- `age_gated` and `age_min` (18 or 21) mark rows for adult products.
  `age_min` is required when `age_gated` is true and blank otherwise.
- `sales_channel_default` is `local`, `online`, or `both`.
- `meta_1`, `meta_2`, `meta_3` are search keywords, pipe separated. `meta_3`
  holds Overture place slugs as free text.
- `cohort` records when a row was added: `legacy` for the original rows, or
  `YYMMDD-xxxx` (date plus 4 random lowercase letters or digits, for example
  `261002-k7q2`). Rows can move between cohorts.
- `active: false` keeps a row for the ads that use it but stops new ads from
  choosing it.
- The original rows live in category `LEGACY` with row_ids `LEGACY-001` and
  up. Remap their ads to new rows over time.

## Discover first

- `GET /api/admin/ad_categories` lists every row grouped by category, with
  `media_pieces_count` (all ads) and `active_media_pieces_count` (ads in
  active campaigns). Filter with `category_id`, `cohort`, `active`, and `q`.
- `q` matches every word against the label, category names, row_id, and meta
  keywords. Rows whose label holds every word come first.
- `GET /api/admin/ad_categories/cohorts` lists cohorts with row counts,
  newest first.

## Writes

- `POST /api/admin/ad_categories` adds one row. Send `category_id` for an
  existing category, or `new_category: {category_name, category_label}` to
  start the next `SPnn` code. Codes are never reused, so SP24 stays retired.
  The response has the assigned `row_id` and the `cohort` used. Leave
  `cohort` out to start a fresh one.
- `PATCH /api/admin/ad_categories/:row_id` edits `ad_label`, age fields,
  `sales_channel_default`, meta fields, `sort_order`, `cohort`, and `active`.
  `row_id` and `category_id` never change (`422 immutable_key`).
- `PATCH /api/admin/ad_categories/categories/:category_id` renames
  `category_name` and/or `category_label` on every row of the category.
- `POST /api/admin/ad_categories/import` upserts CSV-shaped rows on `row_id`:
  `{rows: [...], cohort?, dry_run?}`. It never deletes. Cohort is set on new
  rows only. The report lists inserted, updated, unchanged, and rows missing
  from the input. If any row is invalid nothing is saved and `errors` names
  each `row_id`.
- `POST /api/admin/ad_categories/cohort` moves rows: `{row_ids | category_id,
  cohort}`.
- `POST /api/admin/ad_categories/remap` moves ads to another row:
  `{mappings: [{from_row_id, to_row_id}]}` or `{media_piece_ids, to_row_id}`.
  The target must be active. All mappings run in one transaction.
- `POST /api/admin/ad_categories/prune` deletes rows no ad uses (any status):
  `{row_ids?, category_id?, cohort?, dry_run?}`. At least one selector is
  required.
- `DELETE /api/admin/ad_categories/:row_id` deletes one unused row. A row in
  use returns `409 in_use` with `media_pieces_count`; remap its ads or set
  `active: false` instead.

Send `dry_run: true` first on import, remap, and prune, show the admin the
counts, and wait for a yes.

## Errors

`in_use` (409), `row_inactive`, `invalid_cohort`, `unknown_category`,
`immutable_key`, `selector_required`, `invalid_remap`, and `invalid_rows`.
Field problems, such as a missing `age_min` on an age-gated row, come back as
`422 invalid` with per-field `errors`.

## Attribution

This taxonomy includes material from the IAB Tech Lab Ad Product Taxonomy 2.0,
which is licensed under CC BY 3.0
(https://creativecommons.org/licenses/by/3.0/). Source:
https://iabtechlab.com/standards/ad-product-taxonomy/
