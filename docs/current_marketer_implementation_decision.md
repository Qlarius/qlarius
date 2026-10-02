# Current Marketer Implementation: Phoenix Session

## TL;DR

The selected marketer id lives in the Phoenix session. A controller action writes it; an `on_mount` hook reads it. Pages under `/marketer/*` render with the right marketer on the very first paint, with no JavaScript involved.

## Why not localStorage (the previous approach)

The id used to live in browser localStorage and reach LiveViews through socket connect params. Connect params only exist on the connected render, so the static render always had `current_marketer: nil`. Every full page load showed "Please select a marketer" and disabled nav links, then swapped in the real page once the socket connected. A second copy was also written to the session for the legacy controller pages, and the two copies could drift (for example, logout cleared the session but not localStorage).

## How it works

### Writing: `QlariusWeb.CurrentMarketerController.select/2`

`POST /marketer/select/:marketer_id?return_to=...`

1. Resolves the id through `CurrentMarketer.resolve/2`, which only returns marketers the scope may act for (admins reach all).
2. On success: `put_session(:current_marketer_id, id)`, flash, redirect to `return_to`.
3. On failure (unknown id, no membership, non-numeric): error flash, session untouched.
4. `return_to` is only honored for local paths under `/admin/marketers` or `/marketer/`.

The marketer list (`/admin/marketers`) uses `<.link href={...} method="post">`, so the request carries the CSRF token through `phoenix_html`.

LiveViews cannot write the session over the websocket, which is why selection goes through a controller and a full page load.

### Reading: `QlariusWeb.Live.Marketers.CurrentMarketer.on_mount/4`

```elixir
on_mount {QlariusWeb.Live.Marketers.CurrentMarketer, :load_current_marketer}
```

Reads `session["current_marketer_id"]`, resolves it against the scope, and assigns `:current_marketer` and `:current_marketer_id`. The session is available on both the static and connected render, so both see the same marketer.

Used by every LiveView in `live_session :marketer` (campaigns, traits, targets, sequences, media) and by `MarketerManagerLive`. `MediaPieceController` (`/marketer/media_old`) reads the same session key directly.

### Why the session snapshot is safe

A LiveView sees the session as it was when the page was first loaded, and live navigation within a `live_session` reuses that snapshot. Selection only happens on `/admin/marketers`, which is in a different live session, so reaching any `/marketer/*` page after a switch is always a full page load with the fresh cookie.

## Trade-offs

- The selection clears on logout (`renew_session` clears the session) and expires with the session cookie (60 days).
- The selection is per browser, shared across tabs.
- Every page now runs its queries on the static render as well as the connected render, which is standard LiveView behavior.
