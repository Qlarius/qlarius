# Building a Tiqit arqade content group

A content group is a set of pieces (episodes, videos) under a creator's
catalog. Hierarchy: creator → catalog → content group → content piece. Each
new piece gets the default tiqit prices automatically.

A piece plays one of two ways:

- `youtube`: a YouTube video id.
- `audio`: a direct https audio file (for example the MP3 from a podcast feed).

## Rights

Only import content the creator owns or has agreed to sell through Qadabra.
If you are unsure, stop and ask the admin.

## Step 1: pick the target

1. `GET /api/admin/creators` and find the creator the admin named. Use its
   catalog id. If there are several catalogs, ask which one.
2. `GET /api/admin/content_groups?catalog_id=<id>` to see whether a group for
   this show already exists. If it does, you will update it (by id) instead of
   creating a second one.

## Step 2: look for a feed first

When the admin gives you a web page (for example a podcast series page), find
its RSS feed before reading the page itself:

- The page's `<link rel="alternate" type="application/rss+xml" href="...">`.
- Apple Podcasts: take the numeric id from an `podcasts.apple.com/.../id123`
  link on the page and call `https://itunes.apple.com/lookup?id=123`. The
  `feedUrl` field is the feed.
- The podcast host (Spreaker, Megaphone, Libsyn, Simplecast, Omny, Art19)
  usually publishes the feed at a stable URL.

If you find a feed:

1. `GET /api/admin/rss/preview?feed_url=<url>`. Read `seasons`. A single feed
   often carries several shows as seasons; the channel title may name a
   different season than the one you want. A season of `null` means the
   publisher set no season on those items; omit `season` to import them.
2. Pick the season that matches the page, and the episode types to include
   (`full`, `trailer`, `bonus`; the default is full and trailer).
3. `POST /api/admin/content_groups/rss_imports` with `dry_run: true`:

```json
{
  "feed_url": "https://www.spreaker.com/show/6208240/episodes/feed",
  "catalog_id": 17,
  "episode_types": ["full", "trailer"],
  "group_title": "Shane and Sally",
  "auto_sync": false,
  "dry_run": true
}
```

Add `"season": 3` when the preview shows the show under a season number.

4. Show the admin the counts and titles. When they approve, send it again
   without `dry_run`. Add `"content_group_id": <id>` to import into an
   existing group.

Set `auto_sync: true` only if the show is still releasing episodes and the
admin wants them added daily.

### Episode order and numbers from a feed

Publishers often upload a whole series at once and leave episode numbers
missing or wrong. Qadabra handles this; you do not need to fix it by hand.

- Items are ordered by full publish time (date and time), so episodes
  uploaded minutes apart on the same day keep their order.
- Full episodes are numbered per season in that order. If the feed's own
  numbers already run consecutively (1..8, or 101..108), they are kept.
  Otherwise they become 1..N and the response includes the warning
  "Episode numbers in ... were missing or inconsistent; numbered by publish
  order". Trailers and bonus items stay unnumbered.
- In the preview, `items` are already in publish order. `episode_number` is
  the number an import will store; `feed_episode_number` is what the feed
  says. `renumbered_seasons` lists seasons whose numbers were rebuilt
  (`null` means items with no season). `published_at` is the UTC publish time.
- Players show "Ep 1", "Trailer", or "Bonus" next to each piece, so correct
  `episode_type` and `episode_number` matter.

When reporting a dry run, mention the renumbering warning if present so the
admin knows the numbers came from publish order.

## Step 3: build a pack by hand only for what the feed lacks

Use `POST /api/admin/content_groups/packs` for items with no feed, such as
bonus videos on YouTube, or when there is no feed at all.

What counts as a piece: an episode, trailer, or video a person would pay to
watch or hear. Leave out articles, "share your thoughts" or comment prompts,
newsletters, merch, and promotional posts.

Pack fields:

- `mode`: `create` (new group) or `update` (existing group; include
  `content_group.id`).
- `catalog_id`
- `content_group`: `title` (required for create), `description`,
  `image_url`, `source_url` (the page you read).
- `pieces[]`:
  - `title` (required, max 200 characters)
  - `media` (required): `{"type": "youtube", "youtube_id": "abc123"}` or
    `{"type": "audio", "url": "https://.../episode.mp3"}`. Audio must be https.
  - `external_id` (strongly recommended): a permanent id from the source.
    Use the feed `guid` or the YouTube video id. This is how Qadabra knows a
    piece already exists; without it, re-sending can create duplicates.
  - `date_published` (`YYYY-MM-DD`), `length_seconds`, `description`,
    `image_url`, `source_url`, `season`, `episode_number`,
    `episode_type` (`full`, `trailer`, `bonus`), `display_order`.
- Artwork: set `content_group.image_url` to the show art. Only send a
  piece `image_url` when that piece has its own art. Art that matches the
  group image or is shared by several pieces is not stored; those pieces
  show the group image. Feed imports apply the same rule to episode art.
- Hand packs are not renumbered. Send `episode_type`, `episode_number`, and
  pieces in the order they should appear; new pieces are added in pack order
  after existing ones (or use `display_order`).
- `on_existing`: `update` (default, refresh matched pieces) or `skip`.
- `dry_run`: `true` to see the result without saving.

Example: adding the Shane and Sally bonus videos to the group created from
the feed.

```json
{
  "mode": "update",
  "catalog_id": 12,
  "content_group": {"id": 345},
  "dry_run": true,
  "pieces": [
    {
      "title": "Inside the Episode: Bonus Video for Episode 1",
      "description": "Hosts Rob D'Amico and Karen Jacobs dive deeper into the abandoned car.",
      "date_published": "2024-03-19",
      "episode_type": "bonus",
      "season": 3,
      "source_url": "https://www.texasmonthly.com/podcasts/series/shane-and-sally/",
      "external_id": "YOUTUBE_VIDEO_ID",
      "media": {"type": "youtube", "youtube_id": "YOUTUBE_VIDEO_ID"}
    }
  ]
}
```

## How matching works

Each piece is matched to an existing piece by `external_id` in the group,
then `youtube_id` anywhere in the catalog, then `source_url` in the group.

- Matched pieces are `updated` (or `unchanged` if nothing differs). Their
  order and prices are kept.
- A YouTube video already in another group of the catalog is `skipped`, not
  moved.
- Archived pieces are `skipped`.
- Everything else is `created` and added after the existing pieces.

## Keeping a group current

`POST /api/admin/content_groups/:id/sync` re-reads the group's stored feed.
New episodes are added. Existing pieces only get their audio URL, duration,
and episode fields refreshed, so titles edited by hand are kept. Sync does
not move existing pieces; new ones go after them.

To also put the whole group in episode order, send `{"reorder": true}`:

```json
POST /api/admin/content_groups/345/sync
{"reorder": true}
```

This syncs first (refreshing episode numbers from the feed), then orders the
group: trailers, then episodes by number, then bonus items. The response is
the sync result plus `"reordered": true`. Use it when a group imported before
this ordering existed looks out of order, or after a publisher fixes their
feed. Admins can do the same from the group's Display order menu ("Episode
order").

## Response

Every write returns:

- `content_group`: the group, including its feed settings.
- `pieces[]`: `{index, status, id, external_id, title, media_type, reason?}`
  where status is `created`, `updated`, `unchanged`, or `skipped`.
- `counts`: totals per status.
- `warnings`: problems that did not stop the import, such as an image that
  could not be downloaded or a feed item with no https audio.
- `dry_run`: whether anything was saved.
