# Preserve collection slots when considering already-Gold Eternals — 349

Implemented in 2.149.0-alpha. The release receipts below bind the actual installation and verification; activation waits for the user's normal restart.

## Confirmed failure and public-state evidence

The fresh passive session `session-20260916T063659Z-1` confirms loaded **2.148.0-alpha**. Its frozen prefix covers two segments, 2,477,702 bytes and 864 events through `2026-09-16T06:41:47Z`, with no decode errors. The original append-active log remains untouched. No terminal or stop record appears in this prefix.

At sequence **85**, `2026-09-16T06:37:27Z`, the advisor requests **Buy Droll Joker ($4)** from shop index 2. This is an actual shop purchase, distinct from the previous session's Cartomancer/Devious pack selections. The public card `card:337` is `j_droll`, normal edition, Eternal true, and already Gold (`completionist_goal.by_key.j_droll.status = complete`).

The run is `M4BVSY11`, Ante 1 round 1, with $5 and next blind Psychic at 600 chips. The current row is Perkeo, Yorick and Eternal Brainstorm, all already Gold; three of five slots are occupied. All hands are level 1, Pair has been played twice, Full House once and Flush never. The public deck population has four of every rank. Perkeo has no held consumable to copy.

The other visible Joker is missing Loyalty Card at $1, **Eternal and Rental**. The evidence does not establish that buying it would have been preferable. These liabilities must remain part of any comparison.

Droll advice acknowledges its permanent slot and describes base-Mult support. It reports a four-sample opening estimate of **137 → 137**, an order shortlist of 2/5 layouts, and a complete observed whole-blind policy comparison that clears only some composition worlds. The decision used 48,774 score evaluations and was not marked truncated. The recorded opening-score equality does not establish zero whole-blind benefit: the journal does not expose those full endpoint values here.

The winning-Ante acquisition and final-boss comparison families reject this early state on scope; sale retention is inapplicable. The ordinary purchase path therefore makes the acquisition despite the known permanent collection-slot cost.

Callback 86 returns true. First postcallback observation 87 still has the original row and $5, and explicitly allows pending queued effects. At **88**, `action_observed` shows the same Droll held and **$1**, verifying actual purchase completion. The advisor leaves at 90 and starts Psychic at 95. No later win, loss or survival improvement is inferred.

## Implemented admission boundary

The repair is a shared admission rule across ordinary shop buys, pack choices, replacement/sale-buy routes, longer shop sequences, tactical replacements and heuristic fallbacks. A route must not bypass the rule merely because exact scoring is unavailable or because a previously selected sequence would acquire the card later.

The protection applies when the runtime objective is active, eligible and verified, the offered Joker's Gold status is explicitly `complete`, and acquiring the Eternal consumes an ordinary collection slot. Here "ordinary slot" means **non-Negative**; Foil, Holographic and Polychrome Eternals still occupy such a slot. A challenge-wide Eternal modifier must be recognized as well as the card's own Eternal flag.

Missing Jokers, Negative Jokers and ordinary sellable support Jokers retain their existing admission behavior. Unknown status remains unknown; it is not silently relabeled complete or missing. There is **no named core-Joker exemption** for Brainstorm, Blueprint, Yorick, Perkeo, Burnt or another preferred build component. The rule governs new acquisitions; it does not sell, remove or reinterpret an already-held Eternal.

The narrow exception may admit **one** direct acquisition only when its exact legal paid/free endpoint already has complete supported four-common-world opening evidence. It requires every original Joker unchanged, the exact purchase cost, unchanged capacities/inventory/population/development/resources, known next blind, and the actual current order at both endpoints. Sale replacements and resource-changing acquisitions conservatively decline the exception. At least one holding opening must be below the actual blind target, while every acquisition opening reaches at least **125%** of that target. A complete supported holding continuation that already clears all sampled worlds must not be described as needing this exception merely because it uses more than one hand.

This is a conservative sampled opening rescue criterion, not proof that holding loses, buying wins, the card is globally necessary, or future win odds improve. Heuristic ratings, averages, incomplete/uncertain scores, unsupported startup/consumable effects, mismatched target/order/worlds, or a truncated comparison cannot grant it. Do not manufacture hidden identities, generated cards, refreshed old source certificates or an alternative policy to make the exception pass.

Reuse evidence already computed for that exact endpoint; the admission check adds **no score calls**. Keep whole-inventory Perkeo/Negative/Observatory, cash, boss and public-order safeguards. Reject unsupported nonempty copying pools rather than changing a pack's phase to shop to borrow a certificate. A fallback should retain an admissible existing action or preserve cash/slot flexibility according to its normal rules, without inventing a counterfactual score.

## Snapshot schema audit

The observed state already contains all classification metadata: schema 1, goal `gold_stickers`, complete metadata/catalog/stake/held statuses, explicit `eligibility.eligible = true`, 59 complete/91 missing/0 unknown, and Droll's complete by-key record.

There is **no `completionist_goal.enabled` or `.active` flag**. Runtime capture attaches this objective only when `advisor.gold_stickers` is true. Requiring a nonexistent flag would miss the actual state. Card Eternal is `card.ability.eternal`, not a top-level card field. A normal edition can be absent. The explicit eligibility metadata, not presence of a public seed string, determines whether the run is eligible. Empty Lua lists can serialize as empty JSON objects; that does not make this eligible record malformed.

The underlying detached snapshot capture does not automatically attach runtime objective metadata. Manufactured fixtures should reflect the real goal table, while captured evidence remains unchanged. No profile/save read or additional original-source execution is needed to identify this offer.

## Evidence and scope

- `development349/log_analysis/report.json`: SHA-256 `0df19b1309c28aec2bd2172358782ea1add009bb5c97b533908729f784ca9694`.
- `development349/log_analysis/settled_purchase.json`: SHA-256 `e5c52122e48650ce67d8dcbfb4e34d9c288005269233459371906edeac2f20dc`.
- `development349/log_analysis/goal_shape.json`: SHA-256 `94433bb9f9f5c763f77dd000bbc3902be4f2714d7cd08539441809f28a140ca4`.
- These bind exact journal prefixes, stored-frame/decoded-event anchors and separately preserved original event bytes. The schema audit binds its read-only source versions.
- `development349/slot_evidence_review/README.md` records the static proposal for reusing supported opening evidence and the inventory/order/cash boundaries.

This release used passive logs, static source analysis and manufactured fixture/regression validation only. No captured policy evaluations, original-source components, native searches or complete attempts ran. Historical authorizations remain closed. Ordinary 140,000 / shop 50,000 / consumable 25,000 score budgets and 70-score fast clear are unchanged. No native DLL, game control, save/profile file or current setting is part of this repair.

## Final validation and installation

- Focused final validation: `development349/root_component/integration_final/report.json`, nine fixtures passed. Dedicated guard/routing/endpoint fixtures contain 79/34/79 manufactured checks, including actual deterministic opening score receipts and unchanged score accounting.
- Preserved old-policy reproduction: `root_component/before349/report.json` fails at the new already-Gold Eternal Droll assertion as expected. `integration_first/report.json` separately preserves an initial fixture setup failure: the old no-diagnostics test needed to clear the newly added nested diagnostics. It was corrected; no failing evidence was overwritten.
- Candidate freeze/regression: `runs/gold349_candidate/freeze.json` and `validation/report.json`.
- Exact installed freeze/regression: `runs/gold349_installed/record.json` and `runs/gold349_installed_validation/report.json`.
- Policy digest: `071e1e4aca2a3682a841ec0e6fe40eb3e25fcfd91adcdd536c5bc856ff756074`.
- Installed **2.149.0-alpha** at `2026-09-16T01:52:43.8016605-05:00`; backup `deployment-backups/advisor-20260916-015242` under the installation. 88 deployment files and 104 frozen product/dependency files match repository and installation.
- Explicit slice: `Advisor/gold_slot.lua`, `strategy.lua`, `shop_sequences.lua`, `gold_goal.lua`, `runtime.lua`, `player_journal.lua`, plus version stamps in `Core/Brainstorm.lua` and `steamodded_compat.lua`. The new admission validator adds no score calls. Pack evidence reuses its existing projected snapshot instead of making a second inventory copy.
- Candidate and exact-installed regressions both passed **218 Lua fixtures / 361 Python tests**, with unchanged frozen policy/test hashes. `runs/gold349_final/final_verification.json` binds the final checkpoint.
- Current settings and all existing DLLs are preserved. Installation does not remove previously held Eternals or activate code in the running game. No live activation, new Gold award, terminal improvement or achievement completion is demonstrated by this repair.
