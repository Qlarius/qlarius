# MeFile Open Schema v1

The portable JSON format for a MeFile export, produced by
`Qlarius.MeCP.Export.build/2`. Published so that consumers own their data in a
form any tool can read, and so third parties can build against a stable shape.

Design intent (from the MeCP build plan): the export mirrors the taxonomy
structure exactly as it appears in capsules (category > trait > values), and
freshness dates ship from v1 because downstream consumers are expected to
reason about staleness.

## Top level

```json
{
  "schema": "qlarius.mefile",
  "schema_version": "1",
  "exported_at": "2026-07-09T12:00:00Z",
  "me_file": { ... }
}
```

| Field | Type | Notes |
|---|---|---|
| `schema` | string | Always `"qlarius.mefile"`. Identifies the document kind. |
| `schema_version` | string | `"1"` for this spec. Bumped on breaking changes only. |
| `exported_at` | string | ISO 8601 UTC timestamp of the export. |
| `me_file` | object | The profile payload. |

## `me_file`

```json
{
  "created_at": "2009-04-12T00:00:00",
  "categories": [
    {
      "id": 2,
      "name": "General Information",
      "display_order": 1,
      "traits": [
        {
          "id": 93,
          "name": "Age",
          "display_order": 1,
          "values": [
            { "value": "42", "added_date": "2026-05-14T09:30:00" }
          ]
        }
      ]
    }
  ]
}
```

| Field | Type | Notes |
|---|---|---|
| `created_at` | string or null | When the MeFile was created (ISO 8601). |
| `categories` | array | Ascending `display_order`, then case-insensitive name. Only categories with at least one value appear. |
| `categories[].traits` | array | Effective traits (child traits roll up to their parent), ascending `display_order`, then case-insensitive name. |
| `traits[].values` | array | The user's values for that trait, ascending by value text, then `added_date`. |
| `values[].value` | string | The tag value exactly as the user confirmed it. |
| `values[].added_date` | string or null | ISO 8601. The freshness date: MeFile tags are delete-and-rewrite, so this is always the date the user last confirmed the value. |

## Semantics consumers must honor

1. **All values are self-declared by the MeFile owner** and carry no
   provenance beyond that; there is no inferred or third-party data in a
   MeFile.
2. **`added_date` is a confirmation date, not a creation date.** Editing a
   tag rewrites it, so older dates mean "not re-confirmed since", which is a
   staleness signal.
3. **Ordering is deterministic.** Two exports of an unchanged MeFile differ
   only in `exported_at`.
4. **Ids are stable within a Qlarius deployment** but are not global
   identifiers; match on names when interoperating across systems.

## Versioning

Additive fields may appear within v1 (consumers should ignore unknown keys).
Any change to existing fields or semantics bumps `schema_version`.
