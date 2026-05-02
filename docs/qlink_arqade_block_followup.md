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

## Target result: expand arqade on the same page (not a new tab)

When the viewer uses **expand to full screen** from the inline arqade
widget on a Qlink (or similar host) page:

- **Approach (Option B):** **`QlinkPage.Show` owns the shell** — a
  full-viewport overlay (or fixed pane) that wraps the *existing*
  nested `ArcadeLive` / `ArcadeSingleLive` from `live_render/3`. Open
  and close are parent-driven assigns + events; **no second**
  `live_render` of the same catalog. The child LV keeps a single
  socket, wallet, and auth context.

- **Sponster bottom bar stays visible:** The full-screen arqade
  **content** must occupy only the area **above** the persistent
  Sponster dock (same bar used for wallet / ads / show–hide today).
  The bar remains **visible and interactive**; the arqade layer must
  not cover it (e.g. `height: calc(100dvh - bar)` or layout where the
  pane sits in the main column and the bar stays in document flow
  below). Z-index and stacking should be defined so the bar is never
  obscured by the expanded arqade layer.

- **Fallback:** Keep **open in new tab** where it still matters (e.g.
  third-party iframe embeds, or when breaking out of `window.top !==
  window.self` is required).

### When implementing (pointers)

**Shipped (2026-05):** Qlink `QlinkPage.Show` wraps inline `live_render` in a
shell that becomes `fixed` full viewport width (`z-[45]`, `bottom-[50px]`) when
`@arqade_fullpane_dom_id` matches; nested `ArcadeLive` uses
`phx-click="toggle-arqade-fullpane"` when `@inline?` instead of a new-tab
`<a>`. Close: bar-sized header control, Escape, or toggle again.

### Possible follow-ups

- **ArcadeSingleLive:** If single-piece embeds gain the same control,
  mirror the inline `phx-click` + parent `arqade_fullpane_dom_id` pattern
  (group arqade only today).
- **Body scroll lock** while full-pane is open (optional polish).
- **`HideOpenInTabWhenFullscreen`:** Still applies to the new-tab `<a>`
  path (`/widgets` + in-app); no change required for Qlink inline button.
