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
- `search_terms` on `parent` and on each child (optional, see below).

## Search terms

Builder search and assistants' `search_traits` match trait names, category
names, and each trait's `search_terms`: extra words people use for the same
thing. "pottery" already finds Arts and Crafts through its Pottery child;
`search_terms: ["ceramics", "clay", "wheel throwing"]` on that child makes
those words find it too.

- Put a term on the child it means (Pottery), or on the parent when it means
  the whole topic ("crafting" on Arts and Crafts).
- A list of strings, or one comma-separated string. Terms are lowercased,
  trimmed and deduplicated; at most 20 per trait, 60 characters each. Sending
  `search_terms` replaces the list; `[]` or `null` clears it; leaving the key
  out keeps it.
- Write them in a design pack, `PATCH /api/admin/traits/:id` (parent),
  `PATCH /api/admin/traits/:id/children/:child_id` (child), or with new
  children on `POST /api/admin/traits/:id/children`. Reads return them as
  `search_terms`.
- Propose terms whenever you create or reform a trait: synonyms, everyday
  phrasing, and common misspellings a person would type. Skip words that
  belong to a different trait, and don't repeat the trait's own name.

## The skip answer

Every parent (except zip) keeps one child flagged `is_skipped_tag`, shown to
people as Skip. You do not need to include it: if no child is flagged, one
named "Prefer not to say" is added. To use your own wording, include a child
with `is_skipped_tag: true`. A child named "Prefer not to say" without the
flag is a normal answer.

## Protected parents

Age and zip parents reject child changes and input type changes unless
`force` is true. Do not send `force` unless the admin asks.
