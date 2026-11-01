# Creators and recipients

Use this to add a publisher or a creator, then their catalogs, groups, and
pieces. Read it before the first write. Authentication, `dry_run`, and error
shape are in the overview.

A publisher is a creator whose recipient has `recipient_type_id` 1. There is
no publishers table.

## API reference keys

Every create needs `api_ref`: 3 to 128 characters of lowercase letters,
digits, `.`, `_`, or `-`, starting with a letter or digit. Sending the same
key again returns the existing row and writes nothing unless you pass
`on_existing: "update"`.

Suggested shape: `pub-2610-north_shore.creator`,
`pub-2610-north_shore.catalog`, `pub-2610-north_shore.group`,
`pub-2610-north_shore.ep1`.

`api_ref` cannot be changed later. `split_code` is generated. Do not send
`user_id`, `split_code`, or `price` / `price_default` / `tiqit_classes`. A
price field is `422 price_not_writable`. New catalogs, groups, and pieces
still receive the app's default tiqit classes. Read them with
`GET /api/admin/tiqit_classes?catalog_id=`, `content_group_id`, or
`content_piece_id`.

## Create a creator and its recipient

`POST /api/admin/creators` creates the creator and its primary recipient in
the same call. The token's admin user owns the recipient. That call is
unchanged for callers who only need one publication.

```json
{
  "api_ref": "pub-2610-north_shore.creator",
  "name": "North Shore",
  "bio": "Stories from the harbor.",
  "dry_run": true,
  "recipient": {
    "site_url": "https://northshore.example",
    "description": "A publisher",
    "message": "Thanks for reading.",
    "recipient_type_id": 1
  }
}
```

`recipient_type_id` defaults to 1. `GET /api/admin/creators` keeps
`recipient` (the primary) and adds `recipients`. Each catalog includes
`recipient_id`.

`POST /api/admin/recipients` is only for a recipient that has no creator.
The same approval rules apply. `split_code` is on the read, never the write.

## Several publications under one creator

A media company is one creator. Each sister publication is a recipient with
its own ledger, `split_code`, tip jar, and Sponster bar. Exactly one
recipient is primary. `creators.recipient_id` still points at that primary.

`POST /api/admin/creators/:id/recipients` adds the next one. `api_ref` is
required. The same key returns the existing row. `dry_run` is supported.
The new row is approved, owned by the token's admin user, and gets a
generated `split_code`. It is not primary.

```json
{
  "api_ref": "cities-west.phg",
  "name": "Phoenix Home & Garden",
  "site_url": "https://phgmag.com"
}
```

`PATCH /api/admin/creators/:id/recipients/:recipient_id` updates it. Send
`is_primary: true` to make it the primary. You cannot clear the primary
flag directly. Archive with
`POST /api/admin/creators/:id/recipients/:recipient_id/archive`. Delete with
`DELETE` on that path. Archive returns `409 has_dependents` when the
recipient has ledger entries. Delete returns `409` when it has ledger
entries or catalogs still point at it. Both return `422 primary_recipient`
when it is still the primary and another publication exists.

Give a catalog `recipient_id` on create or update. Omit it on create and the
catalog uses the primary. A recipient from another creator is `422`. Tiqit
revenue from that catalog's groups and pieces posts to that recipient's
ledger. Tips and Sponster revenue already post to the recipient named by
the widget's `split_code`.

Cities West Media, with one catalog on each publication:

```json
{
  "api_ref": "cities-west.creator",
  "name": "Cities West Media",
  "recipient": {
    "api_ref": "cities-west.phoenix-magazine",
    "name": "PHOENIX Magazine",
    "site_url": "https://phoenixmag.com"
  }
}
```

Then `POST /api/admin/creators/:id/recipients` for Phoenix Home & Garden, and
one catalog each:

```json
{
  "api_ref": "cities-west.phoenix-magazine.catalog",
  "name": "PHOENIX Magazine",
  "url": "https://phoenixmag.com",
  "type": "catalog",
  "group_type": "section",
  "piece_type": "article",
  "recipient_id": 101
}
```

```json
{
  "api_ref": "cities-west.phg.catalog",
  "name": "Home & Garden",
  "url": "https://phgmag.com",
  "type": "catalog",
  "group_type": "section",
  "piece_type": "article",
  "recipient_id": 102
}
```

Use the recipient ids from the create responses. `name` is at most 30
characters.

## Catalogs, groups, and pieces

1. `POST /api/admin/creators/:id/catalogs` with `name`, `url`, `type`,
   `group_type`, `piece_type`, and `api_ref`. `name` is at most 30 characters.
2. `POST /api/admin/catalogs/:id/content_groups` with `title` and `api_ref`.
   Leave `feed_auto_sync` off unless you want the daily job.
3. `POST /api/admin/content_groups/:id/pieces` with `title`, `api_ref`, and
   optional `date_published` (defaults to today), `description`, `length`,
   `media_type`, `youtube_id`, `file_url`, `external_id`.

`POST .../pieces/reorder` takes `piece_ids` for every active piece in the new
order. Archive with `POST /api/admin/content_pieces/:id/archive`. A delete
returns `409` when the piece has a purchase or is archived. A catalog or
group delete returns `409 has_dependents` while groups or pieces still exist;
`dry_run` lists the counts.

Images are https URLs (`image_url` on a creator, catalog, group, or piece;
`graphic_url` on a recipient). Files over 5 MB are resized and stored. Do
not upload multipart.

## Embeds

`GET /api/admin/creators/:id/embeds` keeps top-level `split_code`,
`referral_code`, `widgets.sponster_bar`, and `widgets.insta_tip` for the
primary recipient. `recipients` lists every active publication with its own
`split_code`, `referral_code`, `sponster_bar`, `insta_tip`, and the catalogs
that post to it. Paths stay relative, such as `/widgets/ads_ext/:split_code`
and `/widgets/arqade/creator/:id`. Script paths are
`/sponster-tipjar-widget-ext-script.js` and
`/tiqit-arqade-widget-script.js`. The page that embeds them supplies the host.

## RSS

`strip_patterns` remove those exact phrases from descriptions.
`drop_patterns` skip a piece whose title contains one of them,
case-insensitive. They are not stored.

`POST /api/admin/content_groups/rss_imports` with `dry_run: true` reports
`kept`, `dropped`, and `cleaned`. A later `POST /api/admin/content_groups/:id/sync`
refreshes audio URL, duration, and episode fields only, so a description you
edited stays. Send `refresh_existing: true` when you also want titles and
descriptions replaced from the feed. Pass `api_ref` on the import to make a
rerun hit the same group.

## YouTube

`GET /api/admin/youtube/preview?input=` and
`POST /api/admin/content_groups/youtube_imports` use the app's YouTube
client. A missing `YOUTUBE_DATA_API_KEY` is `503 youtube_unavailable`.

The group is matched by `api_ref`. Pieces are matched by `external_id` (the
video id), so a rerun does not duplicate them. `feed_auto_sync` stays off
unless you set it. Send `catalog_id`, `api_ref`, and `input` (channel or
playlist URL).
