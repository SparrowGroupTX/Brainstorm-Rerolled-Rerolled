# Repair417 — verified partial repair, broader coverage still incomplete

**2.201.0-alpha is frozen and fully validated, not installed.** Installed and
running game bytes remain exact4162.200. The user's report is confirmed: the newer
preserved prefix contains17 physically settled clearing plays with discards left;
eight left three or four. This candidate fixes two supported causes, not the entire
insufficient-discard problem. No loaded2.201 performance claim is justified.

## Public evidence and causal trace

Session `session-20260927T010446Z-1` is loaded-label2.200, process39852. Capture001
contains3635 verified events. The later immutable capture002 contains10177 events,
11 public segments/24,976,640 bytes, four starts, two wins, one loss and one unended
run. All chains verify; no normal exit is inferred. Source journals remain untouched.
`trace_discards.py` only joins public observations, advice, requests, callbacks and
settlements; it never loads policy/scoring. Both captures have `discard_trace.json`
with original segment/ordinal/body hashes and actual before/after chips. The later
prefix has26 settled plays with discards left,17 of which actually cleared. These
counts are a descriptive prefix, not population rates or counterfactual wins.

The first five confirmed clear requests are1871,2479,2604,3001,3277. Four shared
the sorting-order rejection; Bell was separate. Their displayed advice, requested
selection and physical settlement agree. This is a planning-coverage failure,
not merely a UI mismatch or missed Execute callback.

| Request | Boss/round | Left | Advice → settlement | Diagnosis |
|---|---|---:|---|---|
|1871|Ante5 Psychic|3|1868 →1878|Cloud9 and Popcorn excluded from additive scope|
|2479|Ante6 Flint|3|2476 →2487|Cloud9 excluded|
|2604|Ante7 Small|4|2601 →2611|Cloud9 excluded|
|3001|Ante8 Small|4|2998 →3009|Cloud9 excluded|
|3277|Ante8 Cerulean Bell|4|3274 →3285|Forced winning singleton cannot legally be retained through discard|

For the first four, a supported clearing play existed, but the retained-discard
admission check rejected the row because canonical Cloud9 was absent from its
whitelist; Popcorn was also absent in1871. Five proof evaluations were reported,
so the ordinary140000 or growth12 cap was not the cause of that rejection. The
final arbitration then retained the clearing play, which executed and cleared.
No captured state was re-evaluated; independently invented hands demonstrate the
mechanism and repair. The logs do not establish that each alternative would win.

A second source defect made that veto unnecessarily final: `select_clear` returned
any score-valid incumbent before checking its sorting hazard. An already-scored
safe alternative could therefore be ignored even with equal or better resource
costs. This is independently reproduced in a manufactured two-pair comparison;
the historical journals do not expose every internal alternative, so it is not
claimed as a separately observed counterfactual for a particular request.

## Runtime changes

- Canonical Cloud9 income and Popcorn's current main-stage Mult now qualify for
  the existing order-independent retained-hand proof. Their actual fields are
  checked, including Cloud9's tally and Popcorn's decay/current Mult. Unknown,
  modified, edition and held arithmetic remain excluded. Round-end changes cannot
  happen between the discarded hand and its retained finish.
- A valid but hazardous incumbent can yield to a qualified already-scored
  alternative. Population, Glass, Arm and finishing-reward checks still prevent
  resource regression. Selection adds no scoring calls.

Only growth.lua and the two2.201 version stamps differ from exact416 runtime.
No new Bell transition, hidden-state inference, search allowance or installation.

## Verification

Exact candidate `runs/repair417_candidate1`, digest
`122e1796a0ca3ff12d8f1e8153b88522637c1ddfa11843a375af632055ebffc0`.
Full gate passes **284 Lua fixtures and458 Python tests**;109 runtime dependencies,
331 declared test files and helper provenance remain exact through validation.

The new fixture passes162 checks, including Psychic five-card anchors, a Flint
pair with no clearing singleton shortcut, all120 physical anchor orders, modified
mechanic negatives, complete manufactured discard/draw progression, safe-alternative
selection and Bell legal-selection rejection. Full runtime testing reaches933
checks and exercises real capture, final decision, rendering, Execute, duplicate
protection and three physical mocked settlements before a legal clearing play.
Both repair-specific assertions fail against exact416 growth.lua.

Iterative failures are preserved. They found a mistaken manufactured Joker order,
an arbitrary60-frame harness limit and incorrect fixture assumptions that every
production discard must use the retained-proof path. The full runtime legitimately
selected an existing discard plan. Proof qualification is now checked directly
against real capture, with physical outcome checked separately; runtime logic was
not altered to satisfy those assumptions. Same reviewer found no blocker after
one substantive review and one focused recheck; the cycle is exhausted.

## Remaining issues — this is not a complete fix

Capture002 adds12 unresolved clears beyond the first five:

- 4565 and9391: concealed-hand/public held-floor admission rejects a Joker row.
- 5277,5422,6301,6660,6832: sorting-card scope rejects Flower Pot with Even Steven
  or Greedy Joker. This is separate from Cloud9/Popcorn and remains unqualified.
- 8629,8752,8913,9586,10065: actual scoring-trigger ordering with Hanging Chad,
  alongside changing support Jokers. The first scoring card matters, so deleting
  the guard is not a sound fix.
- 3277 remains the Bell forced-card case. Original-source text, production executor
  and detached legal transition all require including that card in a discard.

The recurring problem is broader than a single valuation weight: the reliable
finish comparison has narrow, duplicated mechanic coverage. Next work should
qualify effect families with explicit lower-bound contracts, model ordinary
card-trigger additions and Wild/suit-sensitive Flower Pot interactions, and test
whether a bounded first-scoring-card family can support Hanging Chad safely.
These are proposed discriminating tests, not proven invariants. Existing Acorn
world-count and all-concealed-spare gaps also remain. Never replace uncertainty
with a fabricated guarantee merely to spend every discard.

No50% win rate, causal improvement or below1% unused-discard rate is established.
Release requires this session's explicit normal-exit confirmation, passive absence,
fresh public preservation, backed explicit deployment and exact-installed full gate.
Existing settings, seven DLLs, all tracked/untracked work and prior history remain
preserved. The old heartbeat remains paused; capture001's historical monitor-id
metadata did not start a monitor. Capture002 explicitly labels manual passive use.
