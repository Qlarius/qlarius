# Promo sequences

The anonymous third-party embed rotates a banner sequence on the bottom
Sponster bar. Logged-in viewers and the Connect strip are unchanged.

A sequence has a `name`, two tracks (`wide` and `narrow`) that switch at the
`md` breakpoint, one `max_height` in pixels (default 80, both tracks), and an
optional bounce image. No bounce image keeps the quarter at
`/images/sponster_us_quarter.png`.

`global: true` puts the sequence in the shared catalog. A custom sequence can
still be assigned to any recipient. `is_default: true` is the sequence copied
onto a recipient when that recipient is created. Changing the default later
does not move recipients that already have one. Send `promo_sequence_id: null`
on `PATCH /api/admin/recipients/:id` to clear an assignment. A recipient with
no sequence, or a track with no slides, keeps the three built-in banners.

Images are PNG or SVG, sent as a multipart file or an `https` URL. A dry run
(`dry_run: true`) checks the request and writes no row and no file.

## Create

`POST /api/admin/promo_sequences` requires `api_ref` and `name`. Optional:
`global`, `is_default`, `max_height` (1 to 400), `bounce_image` (file) or
`bounce_image_url`. The same `api_ref` returns the existing sequence.

## Slides

`POST /api/admin/promo_sequences/:id/slides` with `track` (`wide` or `narrow`)
and `image` or `image_url`. The new slide is appended.

`PATCH /api/admin/promo_sequences/:id/slides/:slide_id` replaces the image.

`DELETE /api/admin/promo_sequences/:id/slides/:slide_id` removes it.

`POST /api/admin/promo_sequences/:id/slides/reorder` with `track` and
`slide_ids` listing every slide on that track, in the new order.

## Bounce image

On create or `PATCH /api/admin/promo_sequences/:id`, send `bounce_image` or
`bounce_image_url`. `clear_bounce_image: true` removes it and the bar shows
the quarter again.

## Default

One sequence is the default. The seeded sequence is named `Sponster`. Mark
another sequence `is_default: true` before deleting the current default, and
before turning `is_default` off.
