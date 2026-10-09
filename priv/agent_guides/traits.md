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
  `search_terms`, including `GET /api/admin/traits_catalog` (on each parent
  and each child).
- Propose terms whenever you create or reform a trait: synonyms, everyday
  phrasing, and common misspellings a person would type. Skip words that
  belong to a different trait, and don't repeat the trait's own name.
- A term is how a short or ambiguous word finds the right trait. "pot" is a
  prefix of Pottery, so Cannabis needs `search_terms: ["pot"]` to outrank it.
  The same for "car" (Cards, Career), "cat" (anything starting with those
  letters), "trans" (Transmission).

## How search ranks

`GET /api/admin/trait_search?q=pottery&scope=builder` returns the Builder's
ranking (traits in an active survey, top 15). A parent whose question is on
an active survey is included even when that parent's `is_active` flag is
false, which is how the survey screen already decides the topic is taggable.
A child still has to be active. `scope=all` (the default) returns Qai's
`search_traits` ranking (every trait with `is_active` true, top 10). Each
result includes `score`, `tag_count`, and `matches` (the field and tier each
query word hit). When the topic name and a value tie, `matches` names the
topic.

Query words under 3 characters are dropped, except a word that is all digits
("420"). A trailing "s" is stripped, and a word ending in "ies" is also tried
as "y" ("dispensaries" finds "dispensary").

Each word scores the best hit on a name or a search term. A search term
counts the same as a name at the same tier, and wins a tie so the result
reports the term. Highest tier first:

1. Exact match on a search term or the full trait or child name.
2. A whole word inside a name or search term.
3. A prefix of a word, so "vet" finds "veterinary" but not "corvette".
4. A substring anywhere in the text, only for query words of 5 or more
   characters. Shorter words do not match inside unrelated words, so "cat"
   does not find Education, Location, or Vacation.

A category name is the weakest hit, below all four. Ties go to the parent
with more MeFile tags, then to the name A to Z. A child hit counts toward
its parent, and the parent's tag total is the one that breaks the tie.

## The skip answer

Every parent (except zip) keeps one child flagged `is_skipped_tag`, shown to
people as Skip. You do not need to include it: if no child is flagged, one
named "Prefer not to say" is added. To use your own wording, include a child
with `is_skipped_tag: true`. A child named "Prefer not to say" without the
flag is a normal answer.

## Protected parents

Age and zip parents reject child changes and input type changes unless
`force` is true. Do not send `force` unless the admin asks.
