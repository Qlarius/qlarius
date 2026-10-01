# Qadabra admin API: guide for AI agents

You are calling the Qadabra admin API on behalf of a Qadabra admin. Read this
guide before making any write. It is served at `GET /api/admin/agent_guide`
(`?format=json` for JSON, `?topic=content_groups` or `?topic=traits` for one
section).

## Authentication

- Send the admin API token on every request:
  `Authorization: Bearer <token>`.
- Never print, log, or repeat the token back to the user.
- `401 unauthorized` means the token is missing or wrong. `403 forbidden`
  means the token belongs to a user who is not an admin. Ask the admin for a
  valid token; do not retry in a loop.
- Writes are rate limited per admin. Send one pack at a time.

## How to work

1. Discover before you write. List what exists (`GET` endpoints) and pick
   the target by id. Never guess ids.
2. Use `dry_run: true` first on every write that supports it. Show the admin
   the result (counts, titles, warnings) and wait for a yes before sending the
   same body without `dry_run`.
3. Prefer structured sources over scraping. A feed or official API is more
   reliable than a web page.
4. Report results plainly: what was created, updated, unchanged, or skipped,
   and every warning.

## Errors

Every error body has `error` (a code), `message`, and `guide` (this page).

- `422 invalid_pack`: `errors` lists `{index, message}` per piece or
  `{field, message}` for the group. Fix those entries and resend.
- `422 invalid`: a validation failure with per-field `errors`.
- `404 not_found`: the id does not exist. Re-run discovery.
- `422 request_failed`: a remote fetch failed (for example a feed returned
  403 or is not RSS). The `message` says why.
- Other `422` codes name the problem directly (for example
  `catalog_not_found`, `content_group_not_in_catalog`, `feed_url_required`).

## Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| GET | /api/admin/agent_guide | This guide |
| GET | /api/admin/creators | Creators and their catalogs |
| GET | /api/admin/content_groups?catalog_id= | Groups in a catalog |
| GET | /api/admin/rss/preview?feed_url= | Read a podcast feed |
| POST | /api/admin/content_groups/rss_imports | Import a feed as a group |
| POST | /api/admin/content_groups/packs | Create or update a group from a pack |
| POST | /api/admin/content_groups/:id/sync | Add new episodes from a group's feed; `{"reorder": true}` also puts the group in episode order |
| POST | /api/admin/traits/design_packs | Create or reform a parent trait |

Full schemas: `docs/admin_content_group_api.openapi.yaml` and
`docs/admin_trait_survey_api.openapi.yaml` in the Qadabra repository.
