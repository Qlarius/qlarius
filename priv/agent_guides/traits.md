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

Each word scores the best hit on a name, a meta tag (`meta_1`, `meta_2`, or
`meta_3`), or a search term. Those three count the same at the same tier.
On a tie the result reports a search term ahead of a meta tag, and a meta
tag ahead of the name. Highest tier first:

1. Exact match on a search term, a meta tag, or the full trait or child name.
2. A whole word inside a name, meta tag, or search term.
3. A prefix of a word, so "vet" finds "veterinary" but not "corvette".
4. A substring anywhere in the text, only for query words of 5 or more
   characters. Shorter words do not match inside unrelated words, so "cat"
   does not find Education, Location, or Vacation.

A category name is the weakest hit, below all four. A topic whose own name
contains the query is listed first, then one whose child name contains it,
then one whose meta tag contains it, then a search term or category. Inside
that group, ties go to the parent with more MeFile tags, then to the name A
to Z. A child hit counts toward its parent, and the parent's tag total is
the one that breaks the tie.

## The skip answer

Every parent keeps one child flagged `is_skipped_tag`, shown to people as
Skip, unless the parent is zip or `skip_exempt`. Age (93), Sex (Bio) (1),
Home Zip (4), and Days From Birthday (2607) are exempt, and so is every zip
parent. You do not need to include the skip: if no child is flagged, one
named "Prefer not to say" is added and returned as `inserted_children`. An
empty list means nothing new was inserted. To use your own wording, include
a child with `is_skipped_tag: true`. A child named "Prefer not to say"
without the flag is a normal answer. A flagged skip is always exclusive.

## Protected parents

Age and zip parents reject child changes and input type changes unless
`force` is true. Do not send `force` unless the admin asks.

## Tag quality

A tag that has values shows a light. Green means nothing is wrong, including
a parent with no rules. A tag with no values shows no light. You set the
rules; the app does not invent them.

Read before you write.

- `GET /api/admin/traits?q=` to find the parents and children. Use ids from
  the catalog, never names, when you write.
- `GET /api/admin/traits/:id` shows the parent's count and freshness rules
  and the relationships already on it or its children. Do not create a
  relationship that is already there.
- Age and zip are protected. Set their freshness days (a zip change should
  ripen) and do not send `force`.

### Counts, on multi-select parents only

`PATCH /api/admin/traits/:id` with `ideal_min_tags`, `ideal_max_tags`, and
`hard_max_tags`. Sending a field replaces it; `null` clears it; leaving the
key out keeps it.

- Set them when a parent has enough children that picking all of them would
  look like padding. A parent with 30 children whose honest answers cluster
  around 3 to 8 gets `ideal_min_tags: 3`, `ideal_max_tags: 8`,
  `hard_max_tags: 15` (or whatever the catalog supports).
- Leave all three null when any count is honest: a short list, or a list
  where selecting every child is reasonable.
- Do not send count fields for a single-select parent or for a child. Those
  saves are rejected. A skip does not count toward the minimum, and a parent
  whose only answer is a skip stays neutral.
- Inside the ideal range, inclusive, is green. Below the minimum is yellow
  ("Fewer than usual"). Above the maximum but at or under the hard maximum
  is yellow. When both an ideal minimum and maximum are set, it reads
  "{min}–{max} works best. Keep more and confirm only if every choice is truly accurate."
  Otherwise it reads "For best results, consider selecting fewer tag values."
  Over the hard maximum is red. When both bounds are set, it reads
  "{min}–{max} works best. Keep these and confirm only if every choice is truly accurate."
  Otherwise it reads "Too many selected. Advertisers will likely suspect and exclude."
  followed by the limit when one is set.
- Those ranges are estimates. On a too-many warning, yellow or red, the
  person can tap "Confirm accuracy" after reading that a wide set can work
  against them. The tag goes green. The warning stays on the sheet,
  with a badge "Confirmed as accurate {date}", so they can still read it.
  "Remove confirmation" deletes that override and brings the warning back.
  "Fewer than usual" has no such button. Saving that parent replaces its
  tags and deletes the confirmation, even when the values are the same.
  It also ends after the parent's `stale_days`, counted
  from the tap. If `stale_days` is null, only a save clears it.
- A tag that has a warning or a confirmation opens as Review tag. The guidance
  is shown, and the question and the answers are not. Cancel closes it.
  Edit tag opens the answers, with Cancel and Save. Confirm accuracy, when
  the warning can be kept, records the override and closes the sheet. A tag
  with no warning opens straight on Edit tag.

### Freshness, on any parent

The same PATCH, with `unripe_days`, `ripen_days`, `stale_days`, and
`expired_days`. Any of them may be null.

- A fact that changes slowly (a degree, a childhood activity) gets a long
  `stale_days` and usually no `expired_days`, so it goes yellow and stays
  yellow.
- A fact that goes out of date (income, zip, job, address) gets a shorter
  `stale_days` and an `expired_days` after it.
- A fact that is untrustworthy right after a change (zip) gets `unripe_days`
  and `ripen_days`. Leave `unripe_days` null when new data is only mildly
  untrusted. Until `ripen_days` (or `unripe_days`, when ripen is null), the
  light stays green. The edit sheet warns that some marketers will wait
  until the tag is ripe before they target it.
- Order must be `unripe_days <= ripen_days < stale_days <= expired_days`
  for the values that are set. A save replaces the parent's tags, even
  when the values are the same, so the clock restarts from that save.

### Relationships

`POST /api/admin/trait_relationships` with `trait_id`, `related_trait_id`,
`kind` (`conflicts`, `requires`, or `excludes`), an optional `severity`
(`hard` or `soft`; conflicts and excludes), and an optional `note`.
`DELETE /api/admin/trait_relationships/:id` removes one.
`GET /api/admin/trait_relationships?trait_id=` lists the ones touching a
trait; add `direction=from` or `direction=to` to see only the rows where
that trait (or its children) is the subject or the object.

Two of the kinds are about the person's own answers and color their tag
(`conflicts`, `requires`). The third, `excludes`, is about who an advertiser
wants to reach, and never colors a tag. Keep them apart.

- `conflicts` points both ways. Store it once; the API keeps the two ids in
  a fixed order. Use it for values that cannot both be true, including
  "this child conflicts with any value of that parent" by passing the
  parent id. `severity` defaults to `hard`, which is red. `soft` is yellow.
  With no note, a soft link reads "{value} ({parent}) is unusual with
  {other}. Keep both if accurate." A `note` replaces that sentence. Do not
  rewrite notes that are already stored. A stored note of the form
  "{a} can't be combined with {b}." is shown as
  "{a} combined with {b} does not make sense."
- A person who sees a hard or soft conflict can tap "Confirm accuracy" and
  keep both answers. That pair goes green. The conflict sentence stays on
  the edit sheet, with a badge "Confirmed as accurate {date}", and stops
  coloring the tag. "Remove confirmation" deletes that override.
  Saving either parent replaces its tags and deletes the confirmation,
  even when the values are the same. It also ends after the shorter `stale_days` of
  the two parents, counted from the tap. If neither parent has `stale_days`,
  only a save clears it. Confirming a pair does not change ad targeting.
- `requires` is yellow and points one way: the first trait needs the second.
  Use it when one tag is incomplete without another ("working on my golf
  game" requires Golf under Activities).
- Relate the specific children when the clash is between values, and a
  parent when any of its values is enough.
- Write a `note` whenever the trait names alone would not explain the
  problem.
- Do not relate a trait to itself, and do not invent traits to relate. If
  the other side does not exist yet, skip it and say so.
- A link is still saved when it looks odd. Read `warnings`. You will see one
  when a child conflicts with its own parent, when two children of a
  single-select parent conflict, when either side is inactive or is a skip,
  or when the same pair already has the other kind of link.

### Excludes: who a marketer will not want

`excludes` is directed and reads "a marketer who targets `trait_id` will
(`hard`) or may (`soft`) want to keep out people who hold
`related_trait_id`". It drives the Anti-Trait Group suggestions a marketer
sees while building a target, and nothing else: tag quality ignores it, the
MeFile owner never sees it, and a target is never marked wrong for leaving
it unanswered. The marketer can decline every suggestion.

- Direction matters, and the reverse is usually false. A burger place will
  not want vegans (`Hamburgers excludes Vegan`, hard). A vegan restaurant
  may still welcome burger eaters, so do not store `Vegan excludes
  Hamburgers` unless that is true on its own. Store each direction only when
  it stands alone.
- `hard` ("will not want") is for answers that make the product pointless
  to the person: dietary and ethical rules, allergies, legal age, owning no
  car for an auto part. `soft` ("may not want") is for habits and tastes
  that often, not always, rule the product out. When unsure, use `soft` or
  leave it out. An over-eager row costs a marketer reach they wanted.
- `note` here is for the marketer, one short reason: "Vegans eat no
  seafood". It shows under the suggested answer.
- Relate the specific answers. `Hamburgers excludes Vegan` says more than
  `Fast Food Preferences excludes Typical Daily Diet`, and the suggestion
  can name both sides. Do not point a trait at an answer under its own
  parent; that is a `conflicts` row in disguise and is reported as a
  warning (`excludes an answer under its own parent`).
- `warnings` for excludes also flag a reverse row that already exists
  (`the reverse excludes row is also present`) and a pair that also
  `conflicts`. Both are saved; read them and decide.
- Read `GET /api/admin/trait_relationships?trait_id=<parent>&kind=excludes&direction=from`
  before adding: it lists what that family already keeps out.

Checklist for a new product category: list the answers an honest buyer
holds; for each, ask which answers elsewhere in the catalog make the buyer
impossible (hard) or unlikely (soft); store those rows from the buyer's
answer to the other answer; stop there. Do not add the reverse to be tidy.

## Exclusive answers

`is_exclusive` on a child is a warning flag. A skip is always flagged. When a
person holds that answer and another answer under the same parent, the tag
shows yellow: "exclusive answer combined with other answers". Saving does
not remove either tag. Leave the cleanup to the person.

A skip stays a normal tag. Trait groups and targets match it, tag counts
include it, and its freshness clock still runs. The only definition of a
skip is `is_skipped_tag`. Do not treat a name like "Rather not say" as a
skip unless that flag is set.

A parent whose only tag is a skip fills the hole with the tag border color.
Freshness can still color that hole yellow or red. A skip does not count toward ideal or hard
limits, does not satisfy a `requires` link, and does not trigger a
`conflicts` link.

To define exclusivity with links, `POST /api/admin/traits/:parent_id/children/:child_id/make_exclusive`.
That adds a `conflicts` link between the child and every other active sibling,
and skips links that already exist. Optional body: `{"note": "...", "include_inactive": false}`.
The response has `created`, `skipped`, and `relationship_ids`.
`POST .../unmake_exclusive` removes only the `conflicts` links between that
child and its siblings.

`exclusive_child_ids` on `GET /api/admin/traits/:id` and on `traits_catalog`
lists children that conflict with every other active sibling.

When a design pack or `POST /traits/:id/children` adds a child, and a sibling
already conflicts with all the other active children, the new child gets that
conflict too. Those links come back as `inserted_relationships`. Packs do this
unless `extend_exclusive_conflicts` is false. It defaults to true.

## Bulk writes

Each of these is one write against the rate limit, up to 1,000 operations,
in one transaction. `dry_run: true` returns the same per-item results and
writes nothing. If any item is an error, nothing is written.

`POST /api/admin/trait_relationships/bulk`

```json
{"create": [{"trait_id": 1, "related_trait_id": 2, "type": "conflicts", "severity": "soft", "note": "..."}], "delete": [10, {"trait_id": 3, "related_trait_id": 4, "type": "requires"}], "dry_run": false}
```

`type` and `kind` are the same field (`conflicts`, `requires`, or
`excludes`). `severity` is `hard` or `soft` and applies to conflicts and
excludes; leave it out for hard. Each result is `created`, `exists`,
`deleted`, `not_found`, or `error`, and created or existing links include
the same `warnings` as a single POST. `excludes` rows keep `trait_id` and
`related_trait_id` exactly as sent; `conflicts` rows are stored in a fixed
order because they have no direction.

```json
{"create": [
  {"trait_id": 1101, "related_trait_id": 1665, "type": "excludes", "note": "Vegans eat no seafood"},
  {"trait_id": 1101, "related_trait_id": 1668, "type": "excludes", "severity": "soft", "note": "Steak-and-potatoes eaters rarely order sushi"}
], "dry_run": true}
```

`PATCH /api/admin/trait_relationships/:id` changes `note`, `type`, or
`severity` in place. Leave a key out to keep it. `null` clears a note.
`severity` left out stays as it is. `requires` ignores `severity`.

`PATCH /api/admin/traits/bulk_rules`

```json
{"items": [{"trait_id": 1, "ideal_min_tags": 2, "nudge_text": "This helps you see more relevant offers"}], "dry_run": false}
```

Same rules as a single parent PATCH. A missing field is kept. `null` clears
it. Count rules on a child or a non-multi-select parent are an error for that
item. This does not insert a skip child.

`PATCH /api/admin/traits/bulk_search_terms`

```json
{"items": [{"trait_id": 1, "search_terms": ["clay"]}, {"trait_id": 1, "child_id": 2, "search_terms": ["wheel"]}], "dry_run": false}
```

Replaces each list the way a single PATCH does. No skip child is inserted.

`GET /api/admin/trait_relationships?parent_id=` returns the links among that
parent's children. Add `type=conflicts`, `type=requires`, or `type=excludes`
to filter. `trait_id` still lists every link touching that trait or, for a
parent, its children; `direction=from` keeps the rows where they are the
subject (`trait_id`), `direction=to` the rows where they are the object
(`related_trait_id`). Direction is only meaningful for `requires` and
`excludes`.

`GET /api/admin/audit_log?trait_id=` is read-only. Each row has the admin
token label, the time, and the before and after values for relationship,
rule, and search-term changes.

## Nudges

`nudge_text` on a parent is one plain sentence about why the answer helps,
such as "This helps you see more relevant offers". After a skip ages past
`ripen_days`, the Builder shows that sentence once. A later save of the
skip can earn one more showing after it ripens again. Leave `nudge_text`
blank to stay quiet. People can always skip again.

Set `skip_exempt` on a parent that must be answered, so it never receives
an automatic skip.

## Integrity report

`GET /api/admin/traits/integrity_report` reads the catalog and writes
nothing. `skip_rate_threshold` defaults to 15 (percent). A value of 1 or
less is a ratio.

`summary` counts issues per check. `issues` is one row per problem, with
the trait id, name, parent, tag count, and severity. `skip_monitoring`
lists each answered parent with its skip count, skip rate (skips divided
by everyone who answered), skips in the last 30 and 90 days, and the
survey name. A rate above the threshold is `review_wording` and also an
issue: the question may need different wording. Sort your review by skip
rate.

`excludes` reports the health of the `excludes` rows that drive Anti-Trait
Group suggestions. `total` is the row count. `dead` rows have an inactive
trait on either side and can never fire. `symmetric` rows exist in both
directions; one of them is usually wrong (see Excludes above). `unused`
rows have a subject that sits in no active include group, so no marketer
has ever seen the suggestion; that is informational, not an error.
`over_constraining` rows are hard rows where more than half the people who
hold the subject also hold the excluded answer (`subject_holders`,
`also_hold_excluded`); confirming one would gut a target, so consider
`soft` or removal. Every row carries `relationship_id`, both trait ids and
names, `severity`, and `note`.

`confirmed_overrides` lists links and parents that people are currently
confirming, highest count first. A conflict row has `relationship_id`, both
trait ids, `severity`, and `count`. A count row has the parent `trait_id`
and `count`. A link people often confirm should be softened or removed. A
parent people often confirm should have a wider range. These are not
catalog issues. The report does not delete expired confirmations; a row
older than the relevant `stale_days` is left out of the count.

The checks are:

- an active child named like a skip ("rather not say", "prefer not to say",
  "prefer not say", "decline") that is not flagged, on a parent that
  already has a flagged skip
- an active parent with no active flagged skip, other than zip and
  `skip_exempt`
- more than one active flagged skip on a parent
- a flagged skip that is not last, or two children with the same
  `display_order`
- an active parent on no active survey
- a name containing TEST, placeholder, or lorem
- a child with a blank survey answer
- leftover survey wording: "click Add/Update", a `<br`, or a double space
- a search term that repeats the trait's own name, or the same term on
  more than three parents
- a relationship that points at an inactive trait, conflicts inside a
  family, a pair that has both kinds, an `excludes` row aimed at an answer
  under its own parent, or an `excludes` row whose reverse is also stored
- count or freshness values that contradict each other, including count
  rules on a parent that is not multi-select
- a skip rate above the threshold

