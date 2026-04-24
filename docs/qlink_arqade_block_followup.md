# Qlink page: first-class "Arqade Block" (follow-up)

## Status

**Not started.** Tracked here as a follow-up from Batch A
(inline arqade LiveComponent on Qlink pages, ~2026-04).

## Current flow (what creators do today)

To put an arqade widget on their Qlink page, a creator must:

1. Open the arqade admin / widget preview and copy an iframe URL
   like `https://qadabra.app/widgets/arqade/group/13`.
2. In `/creators/qlink_pages/:id/edit`, add a generic **Embed**
   block and paste that URL into the Embed's URL field.
3. At render time, `QlariusWeb.QlinkPage.Show.render_embed/1`
   parses the URL back into `{:group, id}` / `{:single, id}` via
   `Qlarius.Qlink.Urls.parse_arqade_widget_url/1` and either
   `live_render`s it inline (own-deployment + interactive
   surface) or iframes it (3rd-party / anon surface).

## Problems with the current flow

- Friction: creators must leave the Qlink page editor, find the
  widget URL, copy it back in.
- No validation: a creator can paste a URL to an arqade they
  don't own, or to a piece that's been deleted — the block will
  still save.
- No referential integrity: the arqade → Qlink binding lives
  only as a string in `link.url`. Rename/move/delete of the
  arqade's slug doesn't propagate. We also keep a denormalized
  copy in `link.embed_config.url`; `QlinkLink.parse_embed_config/1`
  already tries to de-drift these at save time (see
  `same_domain_url?/1`), which is a smell.
- Discoverability: creators probably don't even know they *can*
  embed their arqades unless someone tells them.

## Proposed: a first-class Arqade block type

Add `:arqade` to the `QlinkLink` type enum and give it typed
foreign keys:

```elixir
# lib/qlarius/qlink/qlink_link.ex
field :type, Ecto.Enum,
  values: [:standard, :embed, :social_feed, :insta_tip, :arqade]

belongs_to :content_catalog, Qlarius.Tiqit.Arcade.ContentCatalog
belongs_to :content_group,   Qlarius.Tiqit.Arcade.ContentGroup
belongs_to :content_piece,   Qlarius.Tiqit.Arcade.ContentPiece
# exactly one of the three is non-nil
```

### Creator UI

"+ New Block" dropdown gains an **Arqade** option. Selecting it
opens a picker that lists only arqades the current creator owns
(scoped by `creator_id`), at whatever granularity they want:

- Catalog (whole show/podcast)
- Group (season/playlist)
- Piece (single episode/track)

Picker populates the FK, no URL strings.

### Render

In `QlinkPage.Show.render_embed/1`, match on
`link.type == :arqade` **before** the `:embed` branch and
dispatch directly:

```elixir
case {link.content_piece_id, link.content_group_id, link.content_catalog_id} do
  {piece_id, _, _} when not is_nil(piece_id) ->
    live_render(@socket, ArcadeSingleLive,
      id: "arqade-piece-#{piece_id}-link-#{link.id}",
      session: %{"piece_id" => piece_id, "inline?" => true, ...})

  {_, group_id, _} when not is_nil(group_id) ->
    live_render(@socket, ArcadeLive,
      id: "arqade-group-#{group_id}-link-#{link.id}",
      session: %{"group_id" => group_id, "inline?" => true, ...})

  {_, _, catalog_id} when not is_nil(catalog_id) ->
    # catalog LV: still needs to be inline-aware (see note below)
end
```

Anon surface (`qlinkin.bio`) still uses the iframe path for
edge-cacheability, but can generate the URL server-side from
the FK — creator never sees the URL.

## Migration path

1. Add the FK columns + `:arqade` enum value.
2. Backfill: for every `QlinkLink` with `type: :embed` whose
   `link.url` parses as a valid arqade widget URL via
   `Qlarius.Qlink.Urls.parse_arqade_widget_url/1`, flip to
   `type: :arqade` and populate the matching FK.
3. Ship the picker in the Qlink editor.
4. Keep the URL-based Embed path working indefinitely for
   legacy blocks (and for 3rd-party-hosted arqades, if that ever
   becomes a thing).

## Prerequisites / known gaps

- `ArqadeCatalogLive` (catalog discovery widget) would need the
  same inline-aware treatment `ArcadeLive` / `ArcadeSingleLive`
  got in Batch A (handle `:not_mounted_at_router`, accept
  session-driven params, drop breadcrumbs when `@inline?`).
- `Qlarius.Tiqit.Arcade` needs a creator-scoped lister for the
  picker UI (`list_catalogs_for_creator/1`, etc.) — probably
  exists already; confirm before building the picker.

## Why it wasn't done in Batch A

Batch A's scope was "remove the iframe hop for own-deployment
arqade widgets without touching the admin flow." Adding a new
block type, schema migration, picker UI, and backfill was an
order of magnitude more work and orthogonal to the inline
rendering win. The URL parser (`parse_arqade_widget_url/1`)
that Batch A introduced is exactly the tool that'll power the
backfill when this lands.
