# Embedded Context Theming Strategy

## Overview

When Sponster/Qlarius UI elements are displayed in **third-party contexts** (Qlink pages, iframes on publisher sites, browser extensions, etc.), we need to manage theme/dark mode independently from the end-user's system preferences.

## Current Approach: `force_light`

We use a `force_light` boolean prop to override dark mode styling:

- `force_light: true` — Forces light mode, ignoring user's system dark mode preference
- `force_light: false` — Respects user's system preference (default)

### Rationale

When embedding on third-party sites, **publisher design preferences take precedence** over end-user system settings. We currently assume publishers prefer light mode, so we hardcode `force_light: true` for all embedded contexts.

### Where It's Used

- `QlariusWeb.OfferHTML` — Ad card components (`clickable_offer`, `click_jump_actions`)
- `QlariusWeb.AdsComponents` — Video ads, collection drawer (`three_tap_ad`, `video_offer_list_item`, `video_collection_drawer`)
- `QlariusWeb.Components.SplitComponents` — Split drawer components (`auto_split_controls`, `tip_split_drawer`)
- `QlariusWeb.ThreeTapStackComponent` — Passes through to child components

## Future Evolution: `pub_theme`

The `force_light` approach is temporary. Future implementation should allow publishers to specify their theme preference:

```elixir
# Future API
attr :pub_theme, :string, values: ["light", "dark", nil], default: nil
```

- `"light"` — Publisher prefers light theme
- `"dark"` — Publisher prefers dark theme  
- `nil` — Fall back to user's system preference

This would enable Sponster elements to blend naturally with dark-themed publisher sites.

## Context Summary

| Context | Current Behavior | Future Behavior |
|---------|------------------|-----------------|
| Our own domain/app | Respects user preference | Respects user preference |
| Third-party/embedded | Forces light mode | Respects publisher's `pub_theme` setting |
