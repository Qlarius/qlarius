# UI surfaces (page canvas & section panels)

Consumer mobile screens use a two-layer surface model inspired by high-contrast dashboard apps (soft page background, elevated action panels).

## Vocabulary

| Term | CSS / component | Role |
|------|-----------------|------|
| **Page canvas** | `.page-canvas` | Scrollable shell background behind content. Softer than panels so cards read clearly. |
| **Section panel** | `.surface-panel` / `<.surface_panel>` | Primary grouped content (Home feature blocks, Strong Start, MeFile categories). White/near-white in light mode, black in dark mode, with top accent, shadow, and subtle side/bottom borders. |
| **Metric tile** | _(not standardized yet)_ | Inner stat/action cells inside a section panel (e.g. tag count, ads count on Home). Still use brand-tinted styles until a follow-up pass. |

## Corner radius

- **Buttons** are pills. Daisy `btn` uses `--radius-field` (rounded rect) by default — always add `rounded-full`.
- **Badges** are rounded rectangles (`badge` uses `--radius-selector`). Do not add `rounded-full` to badges.

```heex
<%# ✅ Button — pill %>
<button class="btn btn-primary rounded-full">New connector</button>

<%# ✅ Badge — rounded rect %>
<span class="badge badge-success rounded">Active</span>

<%# ❌ Button left on Daisy default radius %>
<button class="btn btn-primary">New connector</button>

<%# ❌ Badge as a pill %>
<span class="badge badge-success rounded-full">Active</span>
```

## DaisyUI tokens

- **Canvas:** `bg-base-200` (light), `bg-base-300` (dark).
- **Panel fill:** `bg-base-100` (light), `bg-black` (dark) — dark uses black (not `base-100`) so panels stay clearly elevated on the charcoal canvas.
- **Panel edge:** inside `.mobile-shell`, a 1px hairline (`base-content` at 7%) on all sides and no top accent bar; elevation comes from fill contrast and `.surface-panel-shadow` (shared with 3-tap offer cards). Outside the shell (widgets, marketer pages) panels keep the older `border-t-4` neutral accent until their own pass.
- **Panel headings:** full `text-base-content`. Muted (`/50`) is only for group labels that sit above a card, as on Settings.

## Mobile shell tokens

`.mobile-shell` (in `Layouts.mobile`) redefines a few DaisyUI tokens for the consumer app only, so Admin (whose light/dark themes also come from `nexus.css`) and embedded widgets are unaffected:

- **Light:** `base-100` is pure white.
- **Dark:** `base-100` `#2e2e30`, `base-200` `#222224`, `neutral` `#3a3a3c`, `base-content` `#f2f2f4`. These neutral greys replace Phoenix's default blue-grey so the side menu, inputs and sheets match the pages. Canvas (`base-300`, `#1c1c1e`) and black panels are unchanged.
- **Primary** is the theme's own (orange in light, indigo in dark). Use it for the main action on a screen, the active tab and progress.
- **Header chips** (`.wallet-balance-pill` in the shell, `.header-count-chip`): neutral pill, fixed-width digits.
- **Ledger amounts:** in the shell the sign badge is hidden and amounts read `+$0.10` / `−$0.10` (`.ledger-amount--credit` / `--debit`). Admin's ledger keeps the badge.

## Usage

### Section panel (preferred)

```heex
<.surface_panel>
  <h2>Section title</h2>
  …content…
</.surface_panel>

<.surface_panel class="md:col-span-2" padding={false}>
  …full-bleed inner layout…
</.surface_panel>
```

### Page canvas

Applied in `Layouts.mobile` on the main content wrapper. Individual LiveViews should not set their own page background unless there is a deliberate full-bleed exception.

### Mobile bottom nav frosted glass

The floating pill nav uses a dedicated glass backdrop layer (`mobile_bottom_nav__glass-backdrop`): a `backdrop-filter: blur()` frost plus gradient highlights, applied consistently across all browsers. This is pure CSS — no JS hook and no per-browser refraction path, which keeps it flash-free on LiveView navigation.

Avoid SVG `url()` filters in `backdrop-filter` here: iOS WebKit accepts the syntax but drops the entire backdrop stack, and Chromium's variant required a JS-generated displacement map that flashed on every nav patch.

## Rollout

1. **Done:** `/home` section panels, Strong Start, global mobile page canvas, `/me_file` category groups, `/me_file_builder` category index, `/wallet` ledger list and transaction detail drawer, `/ads` 3-tap cards and video list, `/referrals`.
2. **Later:** metric tile system, builder slide-over trait list wrapper (if needed).

## Related

- CSS: `assets/css/app.css` (`.page-canvas`, `.surface-panel`, `.surface-panel--padded`)
- Component: `QlariusWeb.Components.SurfaceComponents`
- Cursor rule: `.cursor/rules/ui-surfaces.mdc`
