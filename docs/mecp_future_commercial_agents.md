# MeCP Commercial Agents Extension (Suggested Future Addition)

**Status: NOT on the current roadmap.** Separated from the MeCP + Qai build plan (July 2026) because the marketplace is not currently asking for it, and its go-to-market differs fundamentally from the current consumer/advertiser/media direction. This is a B2B/agent-platform BD motion: integrating with commerce agents, payment rails, and merchant platforms. Preserved here so the thinking is not lost and so current architecture keeps the door open.

## What it is

1. **Re-ranking API (disclosure tier 1).** Commercial agents send candidates in (products, restaurants, itineraries); MeCP scores them against the MeFile inside the vault and returns rankings. The MeFile never leaves, not even as answers. Technically this generalizes the existing `trait_groups` / `target_band_trait_groups` deterministic matching machinery from ad targeting to arbitrary candidate sets.
2. **Agentic-commerce rail integrations.** Wallet-level settlement compatible with the emerging protocols (x402, AP2/FIDO, Visa Intelligent Commerce Connect): a commercial agent's query is a settlement event, with revenue share to the consumer. The consumer's own AI queries free; a brand's agent pays per answer.
3. **Commercial client onboarding.** `mecp_clients` client_type for commercial agents, per-query pricing, MyTerms posture requirements as a condition of access.

## Why it was deferred

- No present market pull; agentic commerce protocols are still stabilizing.
- GTM is enterprise BD (agent platforms, merchants, payment networks), not the current consumer/advertiser/media motion.
- The consumer-side products (connector, Qai) neither depend on it nor benefit from coupling to it.

## What the current build already preserves

- The disclosure tier enum reserves tier 1 (re-rank).
- `mecp_access_events.kind` reserves `rerank`.
- The grants/budget/audit model applies unchanged when commercial clients arrive.

## Triggers to revisit

- Inbound demand from agent platforms or merchants for preference-aware ranking.
- Agentic-commerce rails reaching consumer-scale transaction volume.
- Sponsor/advertiser requests that look like re-ranking in disguise (candidate scoring rather than audience targeting).

See the concept doc (`qadabra_web/docs/qai-personal-ai-concept.md`) Sections 4, 9, and 13 for the strategic framing that produced this design.
