# Current Marketer Selection

## Overview

The current marketer is the "working context" for campaigns, traits, targets, sequences and media. It is stored in the Phoenix session and validated against the user's marketer memberships on every mount. See `current_marketer_implementation_decision.md` for the design.

## Selecting a marketer

From `/admin/marketers`, the check button in each row posts to:

```
POST /marketer/select/:marketer_id?return_to=/admin/marketers
```

To add a selection control elsewhere:

```heex
<.link href={~p"/marketer/select/#{marketer.id}?return_to=/marketer/campaigns"} method="post">
  Use {marketer.business_name}
</.link>
```

`return_to` must start with `/admin/marketers` or `/marketer/`; anything else falls back to `/admin/marketers`.

## Using it in a LiveView

```elixir
defmodule QlariusWeb.Live.Marketers.SomethingLive do
  use QlariusWeb, :live_view

  alias QlariusWeb.Live.Marketers.CurrentMarketer

  on_mount {CurrentMarketer, :load_current_marketer}

  def mount(_params, _session, socket) do
    items =
      if socket.assigns.current_marketer do
        list_items_for_marketer(socket.assigns.current_marketer.id)
      else
        []
      end

    {:ok, assign(socket, :items, items)}
  end
end
```

The hook assigns `@current_marketer` (or nil) and `@current_marketer_id`. Pass `@current_marketer` to `<.current_marketer_bar>` for the shared header.

## Using it in a controller

```elixir
current_marketer =
  CurrentMarketer.resolve(conn.assigns.current_scope, get_session(conn, :current_marketer_id))
```

## Notes

- The selection clears on logout and is shared across tabs in the same browser.
- An id the user no longer has access to resolves to nil and renders as "No marketer selected".
