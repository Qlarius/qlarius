# UI surfaces (page canvas & section panels)

Consumer mobile screens use a two-layer surface model inspired by high-contrast dashboard apps (soft page background, elevated action panels).

## Vocabulary

| Term | CSS / component | Role |
|------|-----------------|------|
| **Page canvas** | `.page-canvas` | Scrollable shell background behind content. Softer than panels so cards read clearly. |
| **Section panel** | `.surface-panel` / `<.surface_panel>` | Primary grouped content (Home feature blocks, Strong Start, MeFile categories). White/near-white in light mode, black in dark mode, with top accent, shadow, and subtle side/bottom borders. |
| **Metric tile** | _(not standardized yet)_ | Inner stat/action cells inside a section panel (e.g. tag count, ads count on Home). Still use brand-tinted styles until a follow-up pass. |

## DaisyUI tokens

- **Canvas:** `bg-base-200` (light), `bg-base-300` (dark).
- **Panel fill:** `bg-base-100` (light), `bg-black` (dark) — dark uses black (not `base-100`) so panels stay clearly elevated on the charcoal canvas.
- **Panel accent:** `border-t-4 border-neutral-300` / `dark:border-neutral-600`.
- **Panel edge:** no side/bottom border; elevation comes from fill contrast and `.surface-panel-shadow` (shared with 3-tap offer cards).

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

## Rollout

1. **Done:** `/home` section panels, Strong Start, global mobile page canvas, `/me_file` category groups, `/me_file_builder` category index, `/wallet` ledger list and transaction detail drawer, `/ads` 3-tap cards and video list, `/referrals`.
2. **Later:** metric tile system, builder slide-over trait list wrapper (if needed).

## Related

- CSS: `assets/css/app.css` (`.page-canvas`, `.surface-panel`, `.surface-panel--padded`)
- Component: `QlariusWeb.Components.SurfaceComponents`
- Cursor rule: `.cursor/rules/ui-surfaces.mdc`
