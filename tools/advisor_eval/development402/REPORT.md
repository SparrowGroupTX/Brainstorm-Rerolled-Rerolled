# Continued source and contract audit 402

2026-09-26. The user requested continued investigation while reporting run 5/10
of their own session. That is a progress report, not an audited outcome count.
Repository and installation remain exact 2.194 checkpoint400 bytes. This slice
adds documentation and two manufactured diagnostic fixtures outside the frozen
test tree. It makes no runtime repair, installation or loaded-game claim.

## Main findings

### A402-1 — Complete Gold collection prevents a win-first search (P2, reproduced)

The controller deliberately permits teacher play after collection completion:
`Brainstorm/Advisor/auto_run.lua:356,466` stops for completion only when
`teacher_batch` is false. The product's fixed teacher recipe is strict with
`minimum_distinct=0` (`Brainstorm/Core/auto_run_product.lua:454–457`).
Nevertheless, the real query builder rejects an empty missing-sticker list
unconditionally (`Brainstorm/Advisor/collection_search.lua:53`). The validated
all-complete catalog produces exactly that list (`gold_search.lua:178–205`).

The connection is real: product `search_start` calls `n.prepare(recipe)`
(`Core/auto_run_product.lua:243–250`), whose implementation calls the real
`query.prepare` (`Core/collection_search_product.lua:191–200`). Rejection returns
false before `n.begin`; the controller records `search_start_failed`
(`Advisor/auto_run.lua:368–375`). This can prevent starting a teacher session on
a complete collection, or prevent its next search after the final sticker is
earned. No claim is made that the user's current profile is complete or that
their current session hit this path. No profile was inspected.

`teacher_complete_collection_probe.lua` ran once: **five checks passed**, including
the real metadata validator accepting 150 complete synthetic records, the
zero-quota request failing, the same request succeeding with one unrelated
missing sticker, no options mutation, and unknown metadata remaining rejected.
The passing fixture is a witness to the existing defect, not a repaired test.
`query_probe.log` preserves the output. Existing controller coverage in
`tests/advisor_teacher_batch356.lua:7–16` stubs `search_start` to succeed, so it
cannot test the real product/query integration.

Proposed repair: represent the win-first objective explicitly in request
construction and permit its zero collection quota on validated complete
metadata. Retain ordinary collection completion, unknown-record rejection,
profile binding, search ownership and all start/time budgets. Add a manufactured
product-to-query integration test with the complete catalog; do not only amend
the controller stub. Validate the eventual combined runtime under a new freeze.

### A402-2 — Search recipe does not guarantee a Blueprint acquisition (design gap)

The teacher recipe always sets `interchangeable_copies=true`. Its target list
names Brainstorm with a by-Ante-5 deadline (`Advisor/collection_search.lua:74–77`),
and `Immolate/src/collection_targets.hpp:17–19` accepts either Blueprint or
Brainstorm for that requirement. The collection UI accurately labels its
choices as "Blueprint or Brainstorm" and "Brainstorm only"
(`Brainstorm/UI/collection_run.lua:168`); this preset has no Blueprint-only
option. A match therefore need not contain a qualifying Blueprint offer.
This is distinct from passing an actually visible affordable Blueprint.

The native timeline tracks generated offers and selected acquisitions for pool
effects, but not purchase cash (`Immolate/src/immolate.cpp:1688–1725`). Its pack
scan prescribes opening displayed Buffoon packs in order
(`immolate.cpp:2135–2147`). It is not an affordability or survival simulation.
The request already states that accurately through `quota_scope`, `route_note`
and `limitation` (`Advisor/collection_search.lua:85–90`). Treat those source
claims as verified scope, not a newly discovered documentation lie.

The live policy can save cash, skip a pack, reroll, or acquire other Jokers.
Those actions can depart from the native route and alter later conditional
offers. Native search success is not evidence of an observable missed purchase.
The opening adapter verifies the early public steps; it does not enforce all
later forecast purchases (`Advisor/normal_opening.lua:118` onward). Its policy
recipe omits seed/search timing (`normal_opening.lua:95–100`), and the product
receipt marks future acquisition unverified
(`Core/collection_search_product.lua:419–426`).

Proposed improvements, in order:

1. Add a bounded public route-deviation receipt: skipped Buffoon, reroll,
   non-route acquisition or stock generator, with public action/settlement
   identifiers. Distinguish an untouched conditional forecast from one whose
   preconditions no longer hold. Never inject native hidden future offers or
   actual future draw order into live advice.
2. Decide whether a future win-first recipe should require Blueprint explicitly
   rather than accept either copy Joker. A request/schema change can be checked
   with manufactured fixtures; its effect on search yield or wins is unmeasured
   and would need separately authorized, bounded research. No search ran here.
3. Keep acquisition diagnosis grounded in actual public observation, candidates,
   valuation, admission, budget, arbitration and settled ownership. Audit401's
   receipt gaps still limit how much can be concluded from missing fields.

Native provenance was checked statically: all **35** source/CMake hashes match
the evidence for installed `Immolate-advisor-ecf7343e5cc19be0cf10d55e04a18b54b3456134e79acbd0dc1513ad73070acf.dll`.
`native_source_binding.json` binds the evidence manifest and individual matches.
This supports reading that source as the installed build's source; it is not
attestation of a loaded process or a new native validation/build.

### A402-3 — Playing-card visibility ignores reveal settlement (P2, boundary witness)

`Advisor/snapshot.lua:45` classifies playing cards using only `facing=='back'`.
The Joker predicate at lines55–64 additionally checks sprite orientation,
flip target and pinch state. A manufactured playing card with `facing='front'`
but `sprite_facing='back'` is captured as visible with its rank. Two identical
public backs with different manufactured ranks produce different visible
captures. `Advisor/runtime.lua:169–180` checks phase/controller locks but has no
per-playing-card reveal predicate.

This is a reproduced capture-contract mismatch. Whether that transient is
reachable while all live readiness checks pass remains unverified. The probe
does not run an advisor or demonstrate an actual hidden-information decision.
Proposed repair: define one conservative public presentation predicate for held
playing cards and use it consistently in capture and action readiness, preserving
the separate composition/hidden-card belief boundary. A future manufactured
capture-to-advice invariance test must hold advice constant while the backs are
identical, then permit identity use only after the fronts settle.

### A402-4 — Draw orientation can override new concealment (P2, boundary witness)

`Advisor/draws.lua:26` uses
`c.face_down=hidden and (source.face_down~=false) or false`. Thus Fish/Wheel can
produce `wheel_flipped=true` but `face_down=false` when the incoming detached
card was marked visible. Ordinary discard search passes deck metadata through
the draw adapter (`Advisor/search.lua:1314–1320`) and rejects optimization only
when the resulting hand is concealed (1354–1359). Concealed continuation first
normalizes incoming deck cards to backs (`concealed_belief.lua:418`).

`visibility_contract_probe.lua` ran once: **17 checks passed** across this gap
and A402-3. Fish and Wheel concealment differ solely with input orientation;
missing/back orientation conceals correctly, a disabled blind reveals, a
missing Wheel sample remains unsupported, and inputs remain unmodified.
`visibility_probe.log` preserves the output. This is a detached-input
inconsistency, not evidence of an ordinary live-deck failure: normal captured
deck cards ordinarily arrive on their backs. No live timing or source-game
experiment was performed.

Proposed repair: own new-draw orientation in the shared draw adapter, separate
from retained held-card visibility. Add equivalent-input tests for ordinary,
concealed, cycling and continuation callers, preserving challenge-flip rejection
and independent effect streams. Do not repair this by revealing hidden held
cards or assuming the actual next drawn identity.

## Verified safeguards and documentation correction

The focused read-only review found no use of actual next-draw order or live RNG
in the examined capture/draw/ordinary-search chain. Snapshot sorts remaining
composition by physical ID (`snapshot.lua:317`); ordinary search uses its own
fixed-seed generator (`search.lua:703,712–715`) and shares each permutation across
all candidates, counting only fully completed comparisons (`1391–1419`). Effect
streams are separated by sample, turn, channel and physical identity in
`sampled_outcomes.lua:46–60`. Concealed identities enter public-composition belief
sampling; ordinary future concealed hands stop before identity optimization.
These verified safeguards do not erase the two narrower boundary witnesses.

`ADVISOR.md` incorrectly said random outcomes were never individually sampled
and described sampled clears as best estimated-score clears. Supported Hook,
Glass, boss visibility and other selected transitions do sample outcomes
(`sampled_outcomes.lua:135–193`). Other families remain restricted or use floors;
Lucky sampling, for example, has explicit owned-Joker limitations at lines63–70.
Ordinary discard clears require supported reliability or an eligible conservative
floor (`search.lua:1369–1386`), not a random mean alone. The guide now reflects
these distinctions and the search/all-complete limitations above. No displayed
percentage is a measured run-win probability or calibrated confidence interval.

## Evidence, preservation and next work

Both probes execute only pure repository modules on fabricated inputs, outside
the 305 frozen test files. They use the existing Python/Lua runner, not
Balatro.exe. Each ran once; **2/2 diagnostic fixtures, 22 total assertions**
passed while reproducing current gaps. They are neither regression fixes nor a
new full validation gate. Final `verification.json` records their source, runner,
Python and Lua-library provenance and verifies the unchanged 109 runtime files
in repository/installation, 305 frozen tests and seven native DLLs. The
checkpoint400 full gates remain the applicable runtime validation evidence.
Pre-edit documentation bytes are preserved under `docs_before/`.

This used the existing reviewer's one focused recheck after audit401's substantive
review. The primary independently checked the source and manufactured witnesses.
No additional agents/reviews, runtime or harness edits, installation, native
execution/build/search, saved-game/profile access, captured-state replay, game
control, current-session outcome audit, automation or experiment occurred.

After the user reports completion, preserve public journals before another
clear and audit every start and relevant copy/Death opportunity, including
unsupported/interrupted outcomes. Keep observed runtime behavior separate from
these source-only risks. Audit401's receipt fidelity and gate-provenance work,
plus A402-1's request integration, are concrete next-slice candidates. The two
visibility gaps need the stated integration tests before release. No new slice
is automatically started by this report, and no 50% win rate is established.
