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

- `Layouts.shell_width/2` sets `data-shell-width="wide"` (72rem column) for screens that fill a grid: `/home`, `/ads`, `/referrals`, `/me_file_builder`, `/arqade`, `/content`, `/tiqits` (Stash), and `/me_file` in Tags mode. MeFile in List mode stays at the reading column. Slide-over screens (`.shell-narrow`) stay at the reading column on wide pages.
- Grids inside wide screens should size by available space, not viewport breakpoints, because the docked sidebar takes 20rem: the Stash grid uses `repeat(auto-fill, minmax(min(19rem, 100%), 1fr))` (each tiqit card spans three grid rows through `subgrid`, so notches, tear lines and status rows line up across a row), and the Builder index uses CSS columns (`columns: 18rem 3`).
- Home (`home_live.ex`) is one markup set inside an `@container`; the `.home-*` and `.setup-*` rules in `app.css` switch at a 56rem content width (about a 1250px window beside the docked menu):
  - **Phone / narrow:** balance hero with Collect below it; setup checklist as one row (progress ring, "Finish setting up", next step) that opens the five steps, the next step's action, and Remind me later / Don't show again; products as rows (colour chip, name, tagline, one figure) in one card; recent activity (latest three ledger entries).
  - **Wide:** hero and Collect in one row; the setup checklist stays open with the five steps as tiles with the next step highlighted and its action beside it; products as three cards with the brand wordmark and full stats (40px figures, Stash counts 2x2).
  - The header balance chip is hidden on Home and Wallet because each leads with the balance.
- 3-tap cards keep their fixed 347 × 152 size everywhere; on `/ads` they flow into columns instead of growing (see Ads below).
- Fixed floating elements follow the column, not the window: `#mefile-floating-toolbar` and `#discovery-view-toolbar` use `--shell-gutter-right`; `#onboarding-tip`, `.split-reminder-tip` and the video collection drawer shift past the docked sidebar. New fixed elements inside the shell need the same treatment.

## Side menu

`layouts/mobile_sidebar.html.heex` is the same component as the phone/iPad drawer and the docked desktop sidebar. It is a grid, not a list:

- **Everyday tiles** (`Layouts.mobile_menu_tile/1`): Home, Wallet (spendable balance), Qai. Neutral `base-200` tiles; the active one gets a 1.5px `primary` ring.
- **Product cards** (`Layouts.mobile_menu_brand/1`): one per brand, YouData, Sponster, Tiqit, each with its wordmark, tagline and two branded tiles (MeFile/Builder, Ads/Referrals, Stash/Arqade). The card sets `--brand` (tint, from the brand 500) and optionally `--brand-chip` (icon chip; Tiqit uses 600 so white icons stay legible). The active branded tile gets a ring in its brand colour.
- Tiles show a live figure from `current_scope` where one exists (tag count, ads and offered amount, active tiqits). New destinations go into the right product card as another tile.
- Settings is a gear button in the profile header, beside close (account-level, and it keeps the footer uncrowded). The footer holds only the appearance switch and Log out. The profile avatar uses the colour squares mark (`qadabra_logo_squares_color.svg`); long aliases wrap rather than truncate.

## MeFile views

- **List** (default): label above value rows; multiple values join with " · ". YouData brand touches, values kept neutral: a 3px YouData rail down each card's left edge (`youdata-card` on the panel) and labels in the YouData tint (600 light, 300 dark). The Builder index cards and the survey slide-over list share the rail. Shared by MeFile, the Builder survey slide-over and the read-only "Why you?" lists.
- **Tags**: one `trait_tag` per parent trait, the unit the app counts as a "tag" (counts are parent traits, so users aren't nudged to pile on values). The trait name sits on top and its values inside, joined with " · ". The `.trait-tag` shape is cut left corners plus a punched hole (a CSS mask, so it shows whatever surface is behind). It has a 1px (hairline) YouData edge that follows the cut corners and rings the hole: the tag paints the edge colour (`--tag-edge`, 60%; 35% on empty tags) and `::before` paints the fill inside it, since clip-path would cut a real border off the corners. The trait name is youdata-900 (youdata-300 in dark). Tags size to content and flow side by side, straight on the page canvas with no card around them (`parent_traits_display bare`; the read-only "Why you?" lists keep their card). On the canvas, light mode uses a stronger tint for filled tags and near white for empty ones (a blank tag), via `--tag-tint` / `--tag-tint-empty` on `.trait-tags--bare`; empty tags carry the tease prompt, inline Skip and the same warm pulse as List's empty prompt (`empty-trait-header-strobe`, staggered per trait).
- **Edit sheet**: "Edit tag", then the same `.trait-tag` for the trait being edited, whose values update live from the selection (zip shows the zip on file until a new one is looked up). No decorative header; options use solid hairlines and primary controls.
- Category labels sit above each card. One floating capsule holds search and the two views (single tap).

## Builder index

`/me_file_builder` is an index: a glance at every topic, not a guided flow (nudging belongs to a separate Guided flow, still to come).

- Same category label and card as MeFile (`.mefile-category`), one `.builder-row` per survey: name, a thin primary progress line (`.progress-line`), the answered/total count, chevron. A finished survey shows a success check instead of the line and count.
- The category count shows only when it holds more than one survey (the row already has it). When its only survey shares the category's name ("Your Home"), the row reads "4 questions" instead of repeating it.
- Surveys with no questions, and categories left with none, are hidden.
- CSS columns, up to three at 18rem or wider, so short cards stack without gaps beside the docked menu.
- **First load:** the index (categories with counts, Qai suggestions) loads with `assign_async` in `mount`; until it arrives, `<.async_result>`'s :loading slot shows `builder_index_skeleton` (labels, YouData cards and rows with `.skeleton` bones, in the same columns). Saving or deleting tags and dismissing suggestions refresh it in place with `AsyncResult.ok/2`.

### Survey slide-over

- Under the title: "2 of 4 answered" over the same `.progress-line`, or a success check and "All answered", then one short line, "Tap a tag to answer or change it."
- List rows sit in a card; Tags sit on the canvas, as on MeFile. Inline Skip comes before the chevron.

## Slide-over header

Every slide-over (Builder survey, Settings, the Ads video player, Arqade, the Tiqit player) shares one header row from `Layouts.mobile`: a round back button (header-chip style), the title, and an optional chip (`slide_over_show_wallet`). `.slide-over-head` is a `1fr minmax(0, auto) 1fr` grid, so a short title is centred; a long one wraps between the button and the chip. The right cell holds a back-button-wide ghost, so it balances the button when empty and grows to fit a chip.

## Ads

`/ads` (`ads_live.ex`) renders both panes, 3-Tap and Video, inside `.ads-board`; CSS (a container query, so the docked menu is accounted for) decides what shows:

- **Phone and medium widths:** the selected type only, with the ad-type pill when both exist. 3-taps sit in `.three-tap-grid` (`ThreeTapStackComponent layout="grid"`): fixed 347px columns, as many as fit, which is one on a phone (identical to the old stack). The public Sponster page and widgets keep the default `layout="stack"`.
- **Wide** (content at least 1070px: two 3-tap columns + 12px + a 340px video column, about 1440px with the menu docked): both panes side by side, pill hidden, each with a label and count (`.ads-pane__label`).
- **Never changed:** 3-tap card size, phases, tap feedback and jump links; the video player slide-over and collect drawer.
- Video rows on `/ads` use `video_offer_list_item app_row`: icon chip left (ledger style), amount, category, length and rate, double chevron; still 120px tall. The amount (24px bold), category (16px, 50%) and green-600 chevron match the 3-tap card's first phase, and every $ amount on the page (cards, TAP / JUMP bar, Collected / Given, rates, the collect slider) uses `tabular-amount` like the rest of the app. Small amounts follow the wallet: the TAP / JUMP bar is 13px with regular labels and semibold amounts (like the wallet key), and Collected / Given amounts are 15px semibold (like ledger amounts), and a finished row matches its Attention Paid™ phase (14px grey text, large green check right). Change them together. Widgets keep the original row (no `app_row`), on the neutral widget theme.
- Empty panes show an icon, the message and a link to the Builder.

## Wallet

`/wallet` (`wallet_live.ex`, components in `wallet_html.ex`). Titles and labels stay as written ("Activity Ledger", lowercase spendable / activity / in-app / cashable / credit), and ledger titles show as stored (many are saved in capitals).

- **Summary card:** spendable leads (`.wallet-summary__hero`), with a bar and key for what it's made of: in-app (light Sponster green), cashable (Sponster green), credit (light blue; grey read as disabled). No card title, since the page title already says Wallet; the wallet icon sits beside the figure. With activity below zero the bar shows credit left plus credit in use (hatched). One "Details" toggle opens a statement: activity (in-app + cashable, each with a line of copy), credit, and a spendable total. Copy says "proceeds from attention sales", never "earned". Balances use `balance_usd/1` (minus only); ledger movements use `signed_usd/1` (`+$0.07` / `−$0.25`).
- **Activity Ledger:** title on the left, a `pill_join_selector` on the right. **By day** (default) shows the latest 30 under day labels (Today, Yesterday, Aug 20, with the year for other years) and Show more adds 30. **By page** is 20 per page with Newest / ‹ Page N of M › / Oldest above and below, rows carrying date and time. The view is in the URL (`?view=pages&page=3`); `WalletBalanceSync` reloads whichever view is showing.
- **Rows** (`.ledger-row`): icon chip (`WalletHTML.icon_tone/1`: Tiqit colour for Tiqit lines, meaning a tiqit attached or a Tiqit / Will Call event, refunds included; Sponster tint for other credits; neutral otherwise), title, "event · time", amount over running balance, chevron. Tapping opens the detail pane.
- **Transaction detail pane** (`right_sidebar_drawer.html.heex`): round close button like the slide-over header; one compact card whose first row is the summary (icon, title as stored, event, amount on the right), then Marketer or Creator, Date & Time, Balance after; section labels (`.detail-section-label`); Matching Tags in a YouData-rail card. Entries with nothing more to show stop at the summary.

## Tiqit cards

`TiqitComponents.tiqit_detail_card/1` on `/tiqits` (Stash), in the wallet detail pane, and read-only on the Arqade gift landing.

- **States** (don't merge them): **Active** (access is live, counting down to expiry or lifetime), **Fleeting** (already expired, counting down to AutoFleet), **Kept** (expired but kept, so it won't AutoFleet), **Gifted**. Fleeted / refunded tiqits render as blank cards.
- **One white ticket** for every state with a hairline edge; only Active gets the Tiqit-orange top edge. State is one status line above the tear line (`.tiqit-status`): a dot and words, e.g. "**Active** · expires in 2 days, 4 hrs", "**Fleeting** · auto-fleets in 5 hrs", "**Kept** · expired May 29, 2026", "**Gifted** · claimed". Dots: orange live, red Fleeting, green claimed gift, grey otherwise. The recipient's read-only gift view keeps a grey dot, as Arqade can be embedded.
- **Header:** 64px image; a small sentence-case kind line ("Episode", "Show · 96 Episodes"); title clamped to two lines (full title in `title`); one source line, creator › group, with repeated names dropped and only the ends kept for three parts (full path in `title`).
- **Stub line** (`.tiqit-stub`, just below the tear line): "Bought Oct 3 · $0.10" on the left; "⋯" (circle) and Open (pill) on the right as `.tiqit-stub-btn`: outlined at rest, filled on hover, "⋯" stays filled while its panel is open. Open is the solid primary pill when Active and outlined once expired, as the content page sends you to the Arqade. Gifts show "Gifted Oct 3 · $0.29 prepaid" and only get "⋯" when there's something to do (copy invitation / revoke).
- **"⋯" panel** (`.tiqit-more`, below the stub line): the full purchase time, refund-lock note, Refund (with its countdown), Keep / Don't Keep, Fleet. LiveView JS commands toggle it (`is-open`, `aria-expanded`, `inert` while closed), so no hook; it slides open on the grid row.
- **Stash first load:** the stash depends on the `status` filter in the URL, so `handle_params` loads it with `assign_async`; until it arrives, `<.async_result>`'s :loading slot shows `tiqit_stash_skeleton/1` (blank tickets with the real shell, notches and tear line, and `.skeleton` bones). Filter changes keep the current cards until the new ones land; card actions refresh in place with `AsyncResult.ok/2`. Counts appear on the filters once loaded. Same pattern as Arqade's `assign_async` pages and DaisyUI's `.skeleton` shimmer.
- **Stash filters:** All, Active, Fleeting, Fleeted, Kept, Gifted, with neutral counts (`.pill-join-count`, also on the Ads pill). On a phone the row scrolls with no scrollbar and fades at the right edge (`.stash-filter-scroll`).

## Qai

`/qai` (`qai_live.ex`, `.qai-*` in `app.css`). A `fixed_viewport` page: the thread scrolls, the session bar and composer stay put.

- **Session bar** (`.qai-bar`): the slide-over header's shape, round header-chip buttons either side of a centred title: Chats (opens the list) on the left, New chat on the right. Under the title a chip shows **Fleeting** (clock) or **Kept** (lock, primary tint); tapping it keeps or un-keeps the chat. A new chat with no session yet shows plain "Fleeting" text, not a chip.
- **Thread:** the user's messages in primary bubbles on the right (indigo in dark, orange in light, like Collect); Qai's replies as plain text on the canvas beside a small Qai mark (`.qai-mark`, the only place Qai coral appears). Replies are markdown with hard breaks (a model's one-item-per-line answers keep their lines), styled by `.qai-md` since there's no typography plugin. Copy and Regenerate sit under the latest reply; a stopped reply says "Stopped". Three dots show while waiting for the first token.
- **Composer** (`.qai-composer`): one capsule with the field and a round send button, which becomes Stop while a reply streams (the field stays usable). Return sends and Shift+Return adds a line, on phones too (`enterkeyhint="send"`). The field is `phx-update="ignore"` and the `QaiComposer` hook clears it when the server takes the message, so it keeps focus and a phone keyboard stays up. 16px text so iOS doesn't zoom.
- **Keyboard:** the `QaiKeyboard` hook watches `visualViewport`; while a phone keyboard is up it sets `html.qai-keyboard-open` with the visible height and offset, and unlayered rules at the end of `app.css` pin the shell to that area, hide the tab bar and drop its clearance, so the composer sits on the keyboard. `QaiScroll` keeps the thread on the latest message as it shrinks.
- **Chats** are the shell's slide-over ("Chats"): New chat, then one card of rows (icon chip, title, "Fleeting · auto-fleets in 5 hrs" or "Kept · Oct 3", delete), the open chat tinted.
- **Opt-in:** Qai mark, "Meet Qai", one card of three facts (private, personal through the MeFile, logged and revocable), "What Qai can see" as category chips on a card, and a full-width Enable Qai pill.

## Arqade

The Arqade group and single-piece pages (`widgets/arcade/`) render in the app, as widgets and inside Qlink, so **colours stay on the neutral widget ramp** (see Auth sheet). The pre-purchase state stays minimal: "Buy Tiqit • $0.10" and ⋯, nothing more; what a tiqit gets you is in the confirm dialog.

- **Buy / Get Tiqit / Accept Gift** use `.btn-widget-solid`: the one filled action, widget-800 with a base-100 label (flips on the dark ramp), like the auth sheet's `.auth-cta`. `.btn-widget-emphasis` (outlined) stays on Tiqit Pass, gift dialogs, the proxy sheet and the Qlink announcer toggle.
- **⋯** is a circle the height of Buy (56px). Its menu (Full purchase options, Share, Gift) is compact rows with hairline dividers (`.arqade-menu`, `.arqade-menu-row`).
- **Gutters:** the Buy row uses the hero's side gutter (16px; 12px in Qlink / full-screen embeds), and the list column is 16px on phones, so artwork, Buy and rows share one edge. Desktop overrides use `md:!…`, because `app.css` emits base spacing utilities twice and the later copy beats plain `md:` variants.
- **Description:** three lines with a "Show full" chip floating over the end of the last line, so it costs no height. Phones keep vertical space for the episode list: no extra lines or gaps in the hero.
- **Episode rows:** details (Ep, length, date) are 12px at 60%; dates read "Oct 9, 2020". Prices are 13px semibold with tabular figures in a hairline chip (`.badge-arqade-episode-cell`), and the Buy label and purchase options prices are tabular too.

### Widget dialogs

- **One filled main action** per dialog: Confirm • $0.10, Confirm gift, Create share link, Copy invitation, Tip, Done all use `.btn-widget-solid` (the shared kit's `primary_button` in `GiftModalComponents`); Cancel and secondary actions stay quiet. "All Tiqit options" is a neutral `.btn-widget` under its one-line question.
- **Sentence case** titles ("Confirm tip", "Purchase options"); Tiqit stays capitalised as a name.
- **Amounts** use tabular figures. The tip confirm shows the wallet pill without its icon (`wallet_balance icon?={false}`) and "After tip" as a dashed pill of the same height; copy says "attention sales", never "earned".
- **Close button:** dialogs that open on a content card get extra top padding (`!pt-12`) so the × doesn't sit on the card.
- **Share / Gift switch** uses `pill-join-selector--widget`: the active item is widget navy, not the app's orange.

## Wallet in widgets

Widgets (Arqade, tip jar, Tiqit Pass), Qlink pages and the Sponster bar all show the wallet; repeating it on one page is fine, and top up is part of the strip.

- **Wallet pill** (`WalletBalance.wallet_balance` with `footer_label`): a wallet icon beside the amount in tabular figures, Sponster green, 40px tall (32px compact, as in the bar), the same in the in-widget strip, the Sponster bar and the ads drawer header. The label ("Wallet") is the pill's accessible name, not text, because `WalletPulse` reads the amount from `innerText`. App header chips (no label) are unchanged.
- **Strip** (`.wallet-strip-tray`): a full-width row with a hairline above; the pill, an arrow (`hero-arrow-long-left`, pointing into the wallet) and the action sit together as one centred unit. Signed in, the action is "+ $1.64" (ads plus the daily gift, i.e. what the menu can add) and keeps its pulsing border; anonymous, the pill reads READY and the action is Connect, with the same arrow. The Sponster bar keeps its own layout (pill, then "9 ads • $1.14", which opens the drawer).
- **Top up menu:** "Top up wallet", then compact rows (`.arqade-menu-row`): Sponster ads with the count and amount, Daily gift $0.50 (disabled once used), Credit / Debit (shows "Coming soon").
- **Tip jar in a host iframe:** the widget posts `{type: "sponster_tipjar_height", height}` to the host (card height + 16px; at least 640px while a dialog or the sign-in sheet is open, as they were sized for it). The embed snippet listens and sets the iframe height; see `demosite/local_news/index.html`. Heights are measured on mount and with a timer, not `requestAnimationFrame`, which Chrome pauses in off-screen cross-origin iframes.
- **Arqade in a Qlink page (phones):** the episode title keeps clear of the ↗ expand button when that button shows and there's no title bar above it (`reserve_corner?`), and the Tiqit logo row under the strip is hidden so the episode panel fits without its own scroll.

## Referrals

`/referrals` (`referrals_live.ex`) uses Wallet's and Builder's parts:

- **Summary card:** what referrals have paid (`.wallet-summary__hero`, "paid from 11 referrals"), a Sponster-tint icon chip, and, when there are pending clicks, a row under a hairline: "$0.02 pending", "2 clicks · pays out Fri, Oct 9", and a quiet "Pay out now" that opens the confirm ("Pay out now?", Cancel / "Pay out $0.02"). Copy never says "earn" or "earnings".
- **Sections** use the Builder/MeFile label (`.mefile-category__head`): "Your link" (one line of copy, the link in a pill field with a filled Copy, then "Or share the code" with a quiet Copy; both use `CopyToClipboard` and flip to "Copied"), "Your referrer" (referred by …, the code form within the 10 days, or one line once they've passed; no disabled controls), and "People you referred" with the count.
- **People you referred** are ledger rows (`.ledger-row.is-static`, not links): person chip, masked alias, "N days left" or "First year complete", amount paid (Sponster green when above zero) and "N pending" under it.
- **Wide:** `.referrals-board` is a container; with people to list and at least 48rem of content, the list moves into a second column beside the summary, link and referrer. Otherwise one 42rem column.

## Auth sheet

`AuthSheet` (with `AuthSteps`) is the sign-in / sign-up sheet on `/connect`, Qlink, and widgets (Arqade, tip jar) on third-party sites. **Colours stay on the neutral widget ramp** (`widget-*`, `btn-widget`, plus semantic error red) so Qadabra branding never clashes with a host page; only structure follows the app. Classes are `.auth-*` in `app.css`.

- One filled main action per step (`.auth-cta`: widget-800 fill, label flips with base-100 so it works on both widget ramps). Auth sheet only; other widget buttons keep the outlined `.btn-widget`.
- Round close button (`.auth-close`). On sign-up steps a thin three-part step line with "Step N of 3 · Label" (`.auth-progress`) sits clear of it.
- Large entry fields (`.auth-entry__field`) for mobile number and zip: icon inside, ring on focus / valid (widget-700) / error; the zip shows the place on a line below and opens the number pad. Birthdate boxes (`date_input` with `widget_theme`) and the sex select (`.select.auth-select`, unlayered because DaisyUI 5 puts `.select` in the utilities layer) share the same fill and ring.
- Phone step: "New here?" is a second line under the opening sentence, not its own block.
- Code step: the code verifies itself at six digits, so Resend code and Different number are quiet links (`.auth-link`). Resend is held for 30s after each send (`ResendCountdown` hook; the server's `code_sends` count keys the button id so the count restarts), and a refused resend shows its message on this step. The server send limit (3 per number per 10 minutes) still applies.
- Alias choices are hairline pills (`.auth-option`; selected gets a widget-700 ring and check, unselected a drawn ring since Heroicons has no plain circle). The full alias wraps rather than truncates, and `alias_error` (regenerate rate limit) is shown.
- Confirm step: label / value rows in one card (`.auth-rows`), agreements as hairline cards (`.auth-check`) that take a widget-700 border when ticked. Checked boxes are coloured through DaisyUI's `--input-color`.
- Titles and field labels are sentence case ("Build your alias", "Home zip code"), matching "Connect via mobile".

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
