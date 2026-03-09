# Tiqit Up Discounts

## Overview

Tiqit Up is a discount mechanism that credits users for tiqits they have already purchased within a content collection. When a user holds active single-episode tiqits, those paid amounts are applied as a discount toward a broader bundle (group or catalog) purchase, rewarding loyalty and incentivizing upgrades.

Tiqit Up discounts are only applied when `catalog.tiqit_up_enabled` is `true`.

---

## Tiqit Class Scopes

A `TiqitClass` belongs to exactly one of three scopes, determined by which foreign key is set:

| Scope | Field | Description |
|---|---|---|
| Single episode | `content_piece_id` | Access to one specific episode/piece |
| Entire series | `content_group_id` | Access to all pieces in a content group |
| Entire site | `catalog_id` | Access to all groups and pieces in a catalog |

---

## Discount Rules by Scope

| Tiqit Class Scope | Credit Applied |
|---|---|
| `content_piece_id` set | **No credit.** Single-episode purchases never receive a discount. |
| `content_group_id` set | **Group-level credit.** Sum of prices of active single-episode tiqits the user holds for pieces within **that specific group only**. |
| `catalog_id` set | **Catalog-level credit.** Sum of prices of active tiqits the user holds across **all groups and pieces** in the catalog. |

This means a user with active tiqits in two different groups within the same catalog will see:
- A smaller discount when upgrading a single series (only that group's tiqits count).
- A larger discount when upgrading to the full site (all tiqits across all groups count).

---

## Discount Calculation

Credit is the **sum of `tiqit_class.price`** for all active (non-expired, non-disconnected, non-undone) tiqits the user holds within the relevant scope.

The adjusted price is:

```
adjusted_price = max($0.00, original_price - credit)
```

Price is **never negative** — the minimum discounted price is `$0.00` (free).

Active tiqits are defined as:
- `disconnected_at IS NULL`
- `undone_at IS NULL`
- `expires_at IS NULL` OR `expires_at > now()`

---

## Key Functions

### `Arcade.calculate_tiqit_up_credit_with_count(scope, %ContentGroup{})`

Returns `{credit, count}` — the total credit amount and number of active tiqits within a specific content group.

### `Arcade.calculate_tiqit_up_credit_with_count(scope, %Catalog{})`

Returns `{credit, count}` — the total credit amount and number of active tiqits across all groups and pieces in a catalog.

### `Arcade.calculate_tiqit_up_credit(scope, collection)`

Convenience wrapper returning only the `credit` Decimal value.

---

## UI Behavior

### Pricing Grid (`tiqit_class_grid` component)

- **Group column** passes `tiqit_up_group_credit` to each price cell.
- **Catalog column** passes `tiqit_up_catalog_credit` to each price cell.
- Active (affordable) prices show the original price with strikethrough and the discounted price.
- Disabled (unaffordable) prices are styled with a faded primary color.
- A "Tiqit Up discounts applied to reflect active tiqits" notice appears below the table when either group or catalog credit is greater than `$0.00`.

### Confirmation Modal

When a user selects a tiqit class to purchase:
- The button shows the discounted price (not the original).
- If a discount applies, a notice reads: _"Price includes Tiqit Up discount of $X.XX for N active tiqit(s)."_
- The correct credit (group vs. catalog) is selected based on the tiqit class's scope at the moment of selection.

---

## LiveView Assigns

Both `ArcadeSingleLive` and `ArcadeLive` compute and store separate credit values at mount:

| Assign | Description |
|---|---|
| `tiqit_up_group_credit` | Credit applicable to group-scoped tiqit classes |
| `tiqit_up_group_count` | Number of active tiqits contributing to group credit |
| `tiqit_up_catalog_credit` | Credit applicable to catalog-scoped tiqit classes |
| `tiqit_up_catalog_count` | Number of active tiqits contributing to catalog credit |

On `select-tiqit-class` event, the handler computes and stores:

| Assign | Description |
|---|---|
| `selected_tiqit_class_adjusted_price` | Final discounted price (min $0.00) |
| `selected_tiqit_class_credit` | Credit amount that was applied |
| `selected_tiqit_class_active_count` | Count of active tiqits that contributed to the credit |
