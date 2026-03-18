# Popover Component

Reusable popover built on [Floating UI](https://floating-ui.com/) for positioning, a Phoenix LiveView JS hook for client-side behavior, and a Phoenix component for declarative markup.

## Quick Start

```elixir
<.popover id="my-popover" placement="bottom-start" trigger_type="click">
  <:trigger>
    <button class="btn btn-sm">Open</button>
  </:trigger>
  <:content>
    <div class="p-3">Popover content here</div>
  </:content>
</.popover>
```

## Attributes

| Attribute      | Type    | Default    | Description |
|----------------|---------|------------|-------------|
| `id`           | string  | (required) | Unique identifier for the popover instance |
| `placement`    | string  | `"bottom"` | Floating UI placement — see [Placement](#placement) |
| `trigger_type` | string  | `"click"`  | `"click"`, `"hover"`, or `"focus"` |
| `offset`       | integer | `8`        | Pixel distance from trigger element |
| `class`        | string  | `nil`      | Additional CSS classes for the content panel |
| `role`         | string  | `"dialog"` | ARIA role — `"dialog"` or `"tooltip"` |

## Slots

- **`:trigger`** (required) — The element that activates the popover. Rendered inline.
- **`:content`** (required) — What appears inside the popover panel. Can contain any markup, including LiveView dynamic content.

## Placement

Supports all Floating UI placements:

```
top         top-start         top-end
bottom      bottom-start      bottom-end
left        left-start        left-end
right       right-start       right-end
```

The hook applies `flip()` and `shift()` middleware automatically, so the popover repositions when it would overflow the viewport.

## Trigger Modes

### Click (default)

Opens on click, closes on click-outside or Escape.

```elixir
<.popover id="menu" trigger_type="click" placement="bottom-start">
  <:trigger>
    <button class="btn btn-sm">Menu</button>
  </:trigger>
  <:content>
    <ul class="menu menu-sm w-48">
      <li><a>Option A</a></li>
      <li><a>Option B</a></li>
    </ul>
  </:content>
</.popover>
```

### Hover

Opens on mouseenter/focus, closes on mouseleave/blur. Content stays open while the cursor is over it.

```elixir
<.popover id="help" trigger_type="hover" placement="top" role="tooltip">
  <:trigger>
    <.icon name="hero-information-circle" class="w-4 h-4 cursor-help" />
  </:trigger>
  <:content>
    <p class="p-2 text-sm max-w-xs">Your wallet balance is used for purchases and tips.</p>
  </:content>
</.popover>
```

### Focus

Opens on focus, closes on blur. Useful for form field hints.

```elixir
<.popover id="hint" trigger_type="focus" placement="right" role="tooltip">
  <:trigger>
    <input type="text" class="input input-bordered" placeholder="Enter amount" />
  </:trigger>
  <:content>
    <p class="p-2 text-sm">Minimum: $0.25</p>
  </:content>
</.popover>
```

## Dynamic Server Content

Since LiveView renders the `:content` slot normally, server-side assigns work out of the box:

```elixir
<.popover id="user-info" placement="bottom" trigger_type="click">
  <:trigger>
    <button class="btn btn-ghost btn-sm">{@user.alias}</button>
  </:trigger>
  <:content>
    <div class="p-3 space-y-1">
      <p>Balance: {@balance}</p>
      <p>Tiqits: {@tiqit_count}</p>
    </div>
  </:content>
</.popover>
```

## Styling

The content panel uses DaisyUI semantic classes and automatically respects dark/light theme:

- Background: `bg-base-100`
- Border: `border border-base-300`
- Shadow: `shadow-lg`
- Corners: `rounded-lg`

Override or extend with the `class` attribute:

```elixir
<.popover id="wide" class="w-64 p-4">
  ...
</.popover>
```

## Accessibility

- `aria-haspopup="true"` on trigger
- `aria-expanded` toggled on open/close
- `aria-controls` links trigger to content panel
- `role="dialog"` (default) or `role="tooltip"` on content
- Escape key closes the popover and returns focus to trigger
- Click-outside dismissal for click-triggered popovers

## Architecture

```
Phoenix Component (popover/1)
├── Trigger slot → [data-popover-trigger] with aria attributes
└── Content slot → [data-popover-content] with transitions
    │
    └── JS Hook (Hooks.Popover)
        ├── Reads data-placement, data-trigger, data-offset
        ├── Attaches event listeners (click/hover/focus)
        └── Uses Floating UI computePosition() + autoUpdate()
            with flip(), shift(), offset() middleware
```

## Files

- **Component**: `lib/qlarius_web/components/core_components.ex` — `popover/1`
- **JS Hook**: `assets/js/app.js` — `Hooks.Popover`
- **Dependency**: `@floating-ui/dom` — installed via npm in `assets/`
