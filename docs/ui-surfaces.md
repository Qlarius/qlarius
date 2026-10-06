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

## Wider screens

The consumer shell covers phones, iPads and desktop browsers. Breakpoints are width-based (the responsive block at the end of `app.css`), because iPadOS sends a desktop user agent and `is_mobile` can't tell an iPad from a laptop.

| Width | Navigation | Content |
|-------|------------|---------|
| < 48rem (phone) | Bottom tab bar + off-canvas side menu | Full width |
| 48rem–64rem (iPad portrait) | Compact tab bar (27.5rem, centered) + off-canvas menu | Centered column, 42.5rem max |
| ≥ 64rem (iPad landscape, desktop) | Side menu docked as a 20rem sidebar; hamburger and tab bar hidden | Centered column beside it |

- `Layouts.shell_width/2` sets `data-shell-width="wide"` (72rem column) for screens that fill a grid: `/home`, `/me_file_builder`, `/arqade`, `/content`, `/tiqits` (Stash), and `/me_file` in Tags mode. MeFile in List mode stays at the reading column. Slide-over screens (`.shell-narrow`) stay at the reading column on wide pages.
- Grids inside wide screens should size by available space, not viewport breakpoints, because the docked sidebar takes 20rem: the Stash grid uses `repeat(auto-fill, minmax(min(19rem, 100%), 1fr))`, and the Builder index uses CSS columns (`columns: 18rem 3`).
- Home (`home_live.ex`) is one markup set inside an `@container`; the `.home-*` and `.setup-*` rules in `app.css` switch at a 56rem content width (about a 1250px window beside the docked menu):
  - **Phone / narrow:** balance hero with Collect below it; setup checklist as one row (progress ring, "Finish setting up", next step) that opens the five steps, the next step's action, and Remind me later / Don't show again; products as rows (colour chip, name, tagline, one figure) in one card; recent activity (latest three ledger entries).
  - **Wide:** hero and Collect in one row; the setup checklist stays open with the five steps as tiles with the next step highlighted and its action beside it; products as three cards with the brand wordmark and full stats (40px figures, Stash counts 2x2).
  - The header balance chip is hidden on Home and Wallet because each leads with the balance.
- 3-tap ads keep their own 470px cap, so they stay phone-sized everywhere.
- Fixed floating elements follow the column, not the window: `#mefile-floating-toolbar` and `#discovery-view-toolbar` use `--shell-gutter-right`; `#onboarding-tip`, `.split-reminder-tip` and the video collection drawer shift past the docked sidebar. New fixed elements inside the shell need the same treatment.

## Side menu

`layouts/mobile_sidebar.html.heex` is the same component as the phone/iPad drawer and the docked desktop sidebar. It is a grid, not a list:

- **Everyday tiles** (`Layouts.mobile_menu_tile/1`): Home, Wallet (spendable balance), Qai. Neutral `base-200` tiles; the active one gets a 1.5px `primary` ring.
- **Product cards** (`Layouts.mobile_menu_brand/1`): one per brand, YouData, Sponster, Tiqit, each with its wordmark, tagline and two branded tiles (MeFile/Builder, Ads/Referrals, Stash/Arqade). The card sets `--brand` (tint, from the brand 500) and optionally `--brand-chip` (icon chip; Tiqit uses 600 so white icons stay legible). The active branded tile gets a ring in its brand colour.
- Tiles show a live figure from `current_scope` where one exists (tag count, ads and offered amount, active tiqits). New destinations go into the right product card as another tile.
- Settings is a gear button in the profile header, beside close (account-level, and it keeps the footer uncrowded). The footer holds only the appearance switch and Log out. The profile avatar uses the colour squares mark (`qadabra_logo_squares_color.svg`); long aliases wrap rather than truncate.

## MeFile views

- **List** (default): label above value rows; multiple values join with " · ". YouData brand touches, values kept neutral: a 3px YouData rail down each card's left edge (`youdata-card` on the panel) and labels in the YouData tint (600 light, 300 dark). The Builder index cards and the survey slide-over list share the rail. Shared by MeFile, the Builder survey slide-over and the read-only "Why you?" lists.
- **Tags**: one `trait_tag` per parent trait, the unit the app counts as a "tag" (counts are parent traits, so users aren't nudged to pile on values). The trait name sits on top and its values inside, joined with " · ". The `.trait-tag` shape is cut left corners plus a punched hole (a CSS mask, so it shows whatever surface is behind). Tags size to content and flow side by side, straight on the page canvas with no card around them (`parent_traits_display bare`; the read-only "Why you?" lists keep their card). On the canvas, light mode uses a stronger tint for filled tags and near white for empty ones (a blank tag), via `--tag-tint` / `--tag-tint-empty` on `.trait-tags--bare`; empty tags carry the tease prompt, inline Skip and the same warm pulse as List's empty prompt (`empty-trait-header-strobe`, staggered per trait).
- **Edit sheet**: "Edit tag", then the same `.trait-tag` for the trait being edited, whose values update live from the selection (zip shows the zip on file until a new one is looked up). No decorative header; options use solid hairlines and primary controls.
- Category labels sit above each card. One floating capsule holds search and the two views (single tap).

## Builder index

`/me_file_builder` is an index: a glance at every topic, not a guided flow (nudging belongs to a separate Guided flow, still to come).

- Same category label and card as MeFile (`.mefile-category`), one `.builder-row` per survey: name, a thin primary progress line (`.progress-line`), the answered/total count, chevron. A finished survey shows a success check instead of the line and count.
- The category count shows only when it holds more than one survey (the row already has it). When its only survey shares the category's name ("Your Home"), the row reads "4 questions" instead of repeating it.
- Surveys with no questions, and categories left with none, are hidden.
- CSS columns, up to three at 18rem or wider, so short cards stack without gaps beside the docked menu.

### Survey slide-over

- Under the title: "2 of 4 answered" over the same `.progress-line`, or a success check and "All answered", then one short line, "Tap a tag to answer or change it."
- List rows sit in a card; Tags sit on the canvas, as on MeFile. Inline Skip comes before the chevron.

## Slide-over header

Every slide-over (Builder survey, Settings, the Ads video player, Arqade, the Tiqit player) shares one header row from `Layouts.mobile`: a round back button (header-chip style), the title, and an optional chip (`slide_over_show_wallet`). `.slide-over-head` is a `1fr minmax(0, auto) 1fr` grid, so a short title is centred; a long one wraps between the button and the chip. The right cell holds a back-button-wide ghost, so it balances the button when empty and grows to fit a chip.

## Wallet

`/wallet` (`wallet_live.ex`, components in `wallet_html.ex`). Titles and labels stay as written ("Activity Ledger", lowercase spendable / activity / in-app / cashable / credit), and ledger titles show as stored (many are saved in capitals).

- **Summary card:** spendable leads (`.wallet-summary__hero`), with a bar and key for what it's made of: in-app (light Sponster green), cashable (Sponster green), credit (light blue; grey read as disabled). No card title, since the page title already says Wallet; the wallet icon sits beside the figure. With activity below zero the bar shows credit left plus credit in use (hatched). One "Details" toggle opens a statement: activity (in-app + cashable, each with a line of copy), credit, and a spendable total. Copy says "proceeds from attention sales", never "earned". Balances use `balance_usd/1` (minus only); ledger movements use `signed_usd/1` (`+$0.07` / `−$0.25`).
- **Activity Ledger:** title on the left, a `pill_join_selector` on the right. **By day** (default) shows the latest 30 under day labels (Today, Yesterday, Aug 20, with the year for other years) and Show more adds 30. **By page** is 20 per page with Newest / ‹ Page N of M › / Oldest above and below, rows carrying date and time. The view is in the URL (`?view=pages&page=3`); `WalletBalanceSync` reloads whichever view is showing.
- **Rows** (`.ledger-row`): icon chip (`WalletHTML.icon_tone/1`: Tiqit colour for Tiqit lines, meaning a tiqit attached or a Tiqit / Will Call event, refunds included; Sponster tint for other credits; neutral otherwise), title, "event · time", amount over running balance, chevron. Tapping opens the detail pane.
- **Transaction detail pane** (`right_sidebar_drawer.html.heex`): round close button like the slide-over header; one compact card whose first row is the summary (icon, title as stored, event, amount on the right), then Marketer or Creator, Date & Time, Balance after; section labels (`.detail-section-label`); Matching Tags in a YouData-rail card. Entries with nothing more to show stop at the summary.

## Mobile shell tokens

`.mobile-shell` (in `Layouts.mobile`) redefines a few DaisyUI tokens for the consumer app only, so Admin (whose light/dark themes also come from `nexus.css`) and embedded widgets are unaffected:

- **Light:** `base-100` is pure white.
- **Dark:** black canvas with lifted surfaces, as in iOS and Material: `base-300` `#000` (page canvas), `base-100` `#141416` (panels, cards, side menu, sheets, 3-tap covers, Arqade cards), `base-200` `#232326` (tiles, inputs), `neutral` `#3a3a3c`, `base-content` `#f2f2f4`. Inside the shell, `.surface-panel`, `.surface-panel-fill` and `.three-tap-offer-cover` take `base-100` instead of the black they use elsewhere; avoid hard-coding `dark:bg-black` on mobile screens. The PWA `theme-color` for dark is `#000000` to match.
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
