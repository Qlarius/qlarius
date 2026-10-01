# Designing traits and survey questions

Traits describe people (a MeFile). A parent trait (for example "Arts and
Crafts") has child traits (the answers, for example "Knitting"), one survey
question, and one survey answer per child.

## Discover first

- `GET /api/admin/trait_categories` for category ids.
- `GET /api/admin/traits?q=<name>` to check the parent does not already
  exist. If it does, reform it by id instead of creating a duplicate.
- `GET /api/admin/traits/:id` for its children, tag counts, and survey text.

## Write with a design pack

`POST /api/admin/traits/design_packs` creates or reforms a parent, its
children, the survey question, and the answers in one transaction.

- `mode`: `create` or `reform` (reform needs `parent.id`).
- `parent`: `trait_name`, `input_type` (`single_select` or `multi_select`),
  `trait_category_id` or `category_name_hint`, `has_search_filter`.
- `survey_question.text`: the question people see.
- `children[]`: `trait_name`, `survey_answer_text`, `display_order`, and `id`
  when reforming an existing child.
- `deactivate_missing_children`: `true` to retire children you left out.
  Their MeFile tags stay.

## The skip answer

Every parent (except zip) keeps one child flagged `is_skipped_tag`, shown to
people as Skip. You do not need to include it: if no child is flagged, one
named "Prefer not to say" is added. To use your own wording, include a child
with `is_skipped_tag: true`. A child named "Prefer not to say" without the
flag is a normal answer.

## Protected parents

Age and zip parents reject child changes and input type changes unless
`force` is true. Do not send `force` unless the admin asks.
