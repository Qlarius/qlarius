# MeCP + Qai Build Plan (Draft 1)

**July 2026 · Companion to `qadabra_web/docs/qai-personal-ai-concept.md` (the concept doc). Read that first for strategy, personas, and vocabulary. This doc is the code-level plan for the `qlarius` Phoenix app.**

## Ground rules

1. **All tags are 100% user generated.** Qai and any AI only tee up suggested tag edits; nothing writes to a MeFile without explicit user confirmation. This is a hard constraint, not a default.
2. **Freshness semantics are delete-and-rewrite.** Tag modification deletes old rows and writes fresh ones, so `added_date` on `me_file_tags` is always the freshness/confirmation date. No `last_confirmed_at` column is needed; re-confirmation is a rewrite.
3. **Brand mapping:** MeCP components are YouData-branded product surfaces; Qai is the assistant surface only, exactly one MeCP client among many. Code contexts are `Qlarius.MeCP` and `Qlarius.Qai`.
4. **Git:** commit locally, never push. Trae pushes manually (origin = GitHub; gigalixir remote deploys and requires explicit targeting).
5. **Copy style:** no em dashes in any user-facing copy.

## New contexts

### `Qlarius.MeCP` (the gateway; YouData product surface)

Everything governing external access to MeFile data.

| Module | Responsibility |
|---|---|
| `MeCP.Clients` | Counterparty registry: Qai, BYO assistants, (later) commercial agents. Client type, status, MyTerms posture |
| `MeCP.Grants` | Permission ledger: per me_file + client, category/trait scope, disclosure tier, expiry, revocation |
| `MeCP.Capsules` | Capsule compiler: me_file + scope in, compact rendered context out (with tag dates) |
| `MeCP.Oracle` | Narrow question answering against grants, with disclosure budgets |
| `MeCP.AccessLog` | Audit trail: who asked what, at which tier, what shape returned, under which terms |
| `MeCP.Terms` | MyTerms (IEEE 7012) agreement records; proffer-at-handshake |

### `Qlarius.Qai` (the assistant; one MeCP client among many)

Phase 2. Kept thin by design: chat sessions, model routing, suggestion queue. Qai reads MeFile data only through MeCP grants like any other client, which keeps the architecture honest and dogfoods the gateway.

| Module | Responsibility |
|---|---|
| `Qai.Sessions` | Chat sessions and messages with `expires_at` (fleeting by default; preserve is opt-in) |
| `Qai.Router` | Model routing: local/cheap/frontier by task and sensitivity; pooled anonymous API calls |
| `Qai.Suggestions` | Confirm-to-add queue: proposed tag edits, pending until user confirms or dismisses |

## Schema changes

### Phase 0 migrations

1. **`me_file_tags`: add `add_source_context` (string, nullable).** UX-optimization tracking only (e.g., `"survey"`, `"mefile_builder"`, `"qai_suggestion_confirmed"`). Does not change authorship: the user is always the author.
2. **New tables (all `mecp_` prefixed):**

```
mecp_clients        id, name, client_type, status, public_key/token_hash,
                    myterms_roster_ref, inserted_at, updated_at

mecp_grants         id, me_file_id, mecp_client_id, scope (jsonb: category/trait ids),
                    tier (int: 0=vault,1=rerank,2=oracle,3=capsule),
                    budget (jsonb: per-period disclosure counters config),
                    expires_at, revoked_at, timestamps

mecp_access_events  id, mecp_grant_id, kind (capsule|oracle|rerank|handshake),
                    request_digest, response_shape (jsonb summary, never raw values),
                    terms_agreement_id, occurred_at

mecp_terms_agreements  id, mecp_client_id, me_file_id, roster_agreement_ref,
                       agreed_at, agreement_record (jsonb)
```

3. **`traits` volatility class: deferred.** Decision pending on new integer columns vs. `meta_*` fields; time calculations will want integers, so expect a migration. Circle back before Layer B work begins. Until then, capsule rendering treats all tags uniformly and includes dates.

### Explicitly not needed

- `last_confirmed_at` on tags (delete-and-rewrite makes `added_date` authoritative).
- Source/provenance enum for authorship (all tags user generated; `add_source_context` is analytics, not provenance).

## Phase 0 build (in order)

1. **Migrations** above.
2. **`MeCP.Capsules` compiler.**
   - Input: `me_file_id`, scope (trait category ids or trait ids), options.
   - Output: deterministic, compact markdown/text block: category → trait → tag values, each tag annotated with its `added_date` (month/year granularity) so consuming models can reason about staleness.
   - Target ~2-4K tokens for a full file; scoped capsules much smaller.
   - Respect grant tier and scope; sensitive-tier categories excluded unless explicitly granted.
   - Pure function over preloaded data; property-test the rendering.
3. **`MeCP.Oracle` prototype.**
   - v1: structured question forms only (trait lookup, boolean/bucket answers), not free-text NL questions. Free-text comes later and will itself need an LLM pass.
   - Enforce per-grant disclosure budgets (simple counters in `mecp_grants.budget`, incremented via `mecp_access_events`).
4. **`MeCP.AccessLog`** writes on every capsule/oracle/handshake event. LiveView admin page can reuse patterns from `admin/mefile_inspector_live`.
5. **Unit-economics model** (spreadsheet or livebook, not code): tokens/session × sessions/WAU vs. sponsorship and top-up rates; wallet write batching design (session-level or daily rollup; per-query ledger writes are untenable).

## Phase 1 build

1. **MCP server endpoint.**
   - Evaluate current Elixir MCP libraries at build time (the ecosystem moves fast; `hermes_mcp` and SSE-transport options existed as of mid-2026). Fall back to a thin hand-rolled JSON-RPC handler on a Phoenix route if libraries disappoint; the MCP surface is small.
   - Tools exposed: `get_capsule(scope)`, `ask_me(question_form)`. Auth: token bound to a `mecp_grant`.
   - **Acceptance target: a consumer can add MeCP as a custom connector in Claude and ChatGPT.** Both clients follow the MCP auth spec for remote connectors, which in practice means an OAuth 2.1 authorization flow (not just a pasted bearer token). Plan for a minimal OAuth server issuing grant-bound tokens; verify each client's exact connector requirements at build time. Simple token paste remains fine for local MCP clients (Ollama-based, LM Studio).
   - Connector onboarding flow: user initiates from the MeFile UI (creates the grant, sets scope/tier), then completes the client-side connector add via OAuth or token.
2. **MyTerms proffering.**
   - Handshake response carries the user's chosen Customer Commons roster agreement reference; agreement recorded in `mecp_terms_agreements` when the client acknowledges.
   - v1 is a stub (reference + record); enforcement is contractual. Track roster availability of AI-era terms; propose ours (see concept doc Section 7).
3. **Do-not-retain preamble** baked into every capsule/oracle response envelope.
4. **Hygiene kit** (mostly content, not code; lives with marketing but link from MeFile UI).
5. **Open schema publication** decision executes here: export format for MeFile (JSON, matching the taxonomy structure) + published spec. `created_at`/`added_date` included from v1.

## Phase 1.5 build (MeCP suggestion loop; next up)

Pulls `Qai.Suggestions` forward from Phase 2 and generalizes it to the MeCP layer so any
connected assistant can propose tags, not just Qai. Motivated by live acceptance testing:
the knitting case study, where Claude used the capsule for real personalization (Austin
yarn shops from the zip, weekday classes from work situation), surfaced the empty Arts
and Crafts category via the gap-nudge, offered "I can help you add a tag or two," and
had no way to follow through. This closes that loop.

1. **`suggest_tag` MCP tool.** The first inbound surface, but it writes only to a
   suggestion queue, never to the MeFile (ground rule 1 intact). Args: trait (name or
   id, must exist in the taxonomy), optional proposed values, short `reason` string.
   Grant-gated and access-logged (new `suggestion` event kind); costs no disclosure
   budget because it discloses nothing. Tool description teaches double opt-in: call
   only after the user says yes in chat; the app confirms again before any write.
2. **`mecp_tag_suggestions` table.** Grant-bound (user always sees which connector
   suggested; revoking a grant sweeps its pending suggestions), trait reference,
   proposed values (jsonb), reason (length-capped), status
   (pending/accepted/dismissed), resolved_at, timestamps.
3. **In-app surface.** "Tag Suggestions" badge/card on the MeFile page; each entry
   shows trait, proposed values, source assistant, date, and the reason rendered
   clearly as the assistant's words, not app copy. Accept opens the existing tag-edit
   modal prefilled so the write goes through the normal user-authored path with
   `add_source_context: "mecp_suggestion_confirmed"`. Dismiss deletes (reason text
   included; retention is user-controlled).
4. **Noise controls.** Cap pending suggestions per grant (~10), dedupe by trait,
   silently drop repeats. Taxonomy-bound only in v1: proposing new traits is taxonomy
   governance, out of scope.
5. **Metric.** Suggestion-to-acceptance conversion per client falls out for free and
   feeds both the freshness story and the unit-economics model.

The full arc this completes: MeCP reads (capsule/oracle) find gaps (`search_traits`),
propose fills (`suggest_tag`), user confirms in-app, richer MeFile, better next
conversation. Every chat makes the asset more valuable and the user authors every byte.

## Phase 2 build (Qai; sketch only, detail when Phase 1 ships)

**Acceptance target: a consumer can select Qai inside the existing qlarius consumer app and use it as a private/secure chat on par with current AI chat standards.** Qai ships as a LiveView surface in this app (consumer nav entry), not a separate app. "On par" checklist for v1: streamed responses, markdown rendering, session history (fleeting by default, preserve opt-in), stop/regenerate, mobile-first layout matching the existing PWA patterns. Explicit v1 scope decisions needed for: attachments/images, voice, and web search. Frontier-model quality comes via `Qai.Router` (pooled anonymous calls, ZDR); privacy posture (two-sided anonymity) is the differentiator, not a feature tradeoff.

- `Qai.Sessions` with `expires_at` sweeping (Oban job; fleeting default).
- `Qai.Router` with pooled provider keys, ZDR config, per-session ephemeral ids; local-model tier when available.
- `Qai.Suggestions` rides the shared MeCP suggestion queue from Phase 1.5 (Qai is just another suggesting client); confirmed suggestions write tags through the normal user-authored path with `add_source_context: "qai_suggestion_confirmed"`.
- Wallet integration: batched settlement per session or daily rollup (per unit-economics work in Phase 0).
- Sponsored inference pilot wiring against Sponster.

## Later phases (as demand justifies)

- **Attested compute (TEE inference)**: privacy hardening for Qai; adopt when provider availability matures.
- **Freshness ripeness product**: advertiser parameterization on tag freshness, decay curves, expiry policies. Fits the current advertiser GTM; ships when capture history has accumulated.

**Not on the current roadmap:** the commercial re-ranking API and agentic-commerce rail integrations have been separated out as a suggested future addition; see `docs/mecp_future_commercial_agents.md`. The marketplace is not currently asking for it, and its GTM differs fundamentally from the current consumer/advertiser/media direction.

## Verification plan

- Property tests on capsule rendering (determinism, scope containment: a capsule must never contain a trait outside its grant scope).
- Budget enforcement tests on Oracle (exhausted budget refuses).
- Access-log completeness: every external read has exactly one event row.
- Manual end-to-end: connect a real MCP client (Claude/ChatGPT connector or local Ollama-based client) against a seeded MeFile.

## Phase 1 acceptance findings (July 2026, live Claude connector testing)

1. **Cloudflare blocks MCP agents by default.** The "Manage AI bots" feature ate every
   authenticated `Claude-User` request; the fix is allowing `Claude-User` (and
   `ChatGPT-User`) in AI Crawl Control. Any consumer-facing MeCP deployment doc must
   mention this class of edge blocking; it presents as an opaque "connection failed"
   in the client.
2. **Tier-3 clients rarely use the oracle.** With capsule access, assistants fetch the
   capsule once and answer follow-ups from it. The oracle earns its keep at tier 2.
3. **Trait ids were not discoverable by clients**, making `ask_me` unusable in
   practice. Fixed with the taxonomy gap-nudge feature: `search_traits` tool
   (keyword match over trait/category/child-trait names, scope-filtered, has_data
   flags budget-gated) plus `ask_me` accepting trait names and a
   `missing_data_hint` on empty answers so assistants gently suggest the owner add
   tags in the MeFile Builder. Every unanswerable question becomes a capture prompt,
   which feeds the tag-freshness flywheel.

## Open items

- Volatility class columns on `traits` (integer time calcs; migration; decide before Layer B).
- Unit economics + wallet batching (Phase 0 deliverable, informs Phase 2).
- Elixir MCP library selection (evaluate at build time).
- Free-text oracle questions (needs LLM pass; post-Phase-1).
- Standalone gateway extraction: not now; revisit only if scale or isolation demands it.

## Handoff note for Claude Code

Start with the Phase 0 migrations and `MeCP.Capsules`. The concept doc (`qadabra_web/docs/qai-personal-ai-concept.md`) carries strategy context; this doc carries the build order. Existing code worth reading first: `lib/qlarius/youdata/mefiles/me_file_tag.ex`, `lib/qlarius/youdata/traits/trait.ex`, `lib/qlarius/sponster/campaigns/trait_group.ex`, `docs/trait_groups.md`, `docs/mefile.md`, `docs/data_model.mmd`.
