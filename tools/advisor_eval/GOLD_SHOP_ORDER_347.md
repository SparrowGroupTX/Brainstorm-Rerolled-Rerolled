# Bounded shop ordering for missing Gold Jokers — 347

This release addresses a concrete integration gap: collection planning checked
only the current shop Joker row, even though later scoring advice could move a
copying Joker onto a different target. That could reject a missing-Joker buy or
sell a retained target without considering an arrangement already available.

The preserved 346 passive timeline is motivation only. The last audited loaded
2.145 session won Verdant Leaf on YVYN2Z11 with 686,952/400,000 chips and $98,
but zero new Gold stickers; progress stayed 59/150. Brainstorm copied Perkeo in
the final shop, then copied Caino after a first-hand reorder. Other subsequent
actions intervened before the win. No alternate purchase score, counterfactual
win or sticker award is inferred from that observed sequence.

## Implemented behavior

`gold_order.lua` enumerates up to 720 legal permutations of at most 6 already-owned
physical Jokers without scoring or RNG. It returns the current row plus one
canonical row maximizing compatible copied activations for each active non-copy
target, at most 6 rows total. Ties use physical IDs, independent of the current
movable positions. Visibility, activity, pins, identity and copy-cycle guards
remain explicit. The projection checks the exact input physical metadata and
returns a detached state. This is a declared copy-target family, not an exhaustive
search of scoring arrangements.

`gold_acquisition.lua` projects an actual current-shop reorder, then one direct
visible missing buy or one completed original Joker sale followed by that buy.
The sale index is mapped into the reordered physical row. Buying appends the
new card normally; no not-yet-owned card is placed by the prefix reorder. Every
paid row qualifies its entire held inventory and actual Perkeo copy events.
Future generated consumables receive no speculative score value. Extra Perkeo
copies may be forgone to obtain missing cargo.

Selection prefers more distinct missing identities, then fewer total actions,
cash, score and a stable physical key. A winning reordered route publishes only
the reorder action, with no queued sale or buy. Fresh advice must complete the
next comparison before spending money or selling anything. The already settled
canonical row then has one fewer remaining action, preventing immediate
reordering back and forth within this family.

`gold_retention.lua` compares the original complete paid incumbent against the
current and canonical retained rows in the same public worlds. An eligible
current hold wins before a rearrangement. Otherwise it publishes one actual
reorder and requires fresh advice. The decision postprocessor preserves both
qualified retained reorders and exits, so phase copying cannot silently put the
row back on Perkeo and invalidate the compared scoring arrangement. Persistent
retry pending/unavailable protections still suppress execution.

`shop_scoring.lua` now preflights the complete fixed-row family using exact
prepared profile keys, costs and successful cached profiles. Failed cache
entries remain unsupported. It prepares each supplied state afresh rather than
trusting mutable table pointers. The bounded input is 1–128 states; acquisition
has at most 127 profiles before deduplication, retention at most 7. If expanded
work exceeds the allowance, the caller declares its existing current-only
family before observing any scores. Unsupported mechanics, late score failure
or incomplete comparisons cannot select a previously successful prefix.

The unchanged allowance is 50,000 shop score calls with up to 8,000 reserved for
retention. No larger cap or new timing assumption was introduced. Enumeration
and preflight add bounded preparation work while avoiding score work for a
family that cannot finish; no measured frame-rate improvement is claimed.

`player_journal.lua` records bounded scalar counts, actual arrangement actions,
current/expanded preflight cost/support/fit and fallback status in the existing
Gold review event. Candidate arrays, physical keys, projected snapshots and
full receipts remain excluded; this introduces no extra event stream. Endpoint
counting accommodates the new bounded family.

## Validation and evidence

Only manufactured fixture and ordinary regression validation ran in 347. No
captured player replay, original-source component, search or complete attempt.
Production-wired fixtures exercise actual reorder → fresh sale → fresh buy;
correct changing physical sale indices; reorder → fresh retained exit; stable
repeated advice; whole inventory/population/cash; pinned and unsupported rows;
exact work accounting; budget fallback before scoring; phase-copy integration;
and unchanged persistent retry guards. Native-shaped constructor metadata from
346 remains part of shared inventory fixtures.

Component staging and immutable receipts are under
`development347/order_component`, `preflight_component`, `retention_component`, `journal_component`
and `root_component`. Earlier fixture failures are preserved separately. The
first integrated run failed three assertions tied to the old single-row family
and late-budget-truncation behavior. Updated assertions now require complete
declared rows and zero-score preflight rejection rather than weakening those
invariants. Source and test hashes are bound in the final regression records.

Candidate evidence: `runs/gold347_candidate/validation/report.json`.
Exact installed evidence: `runs/gold347_installed/record.json` and `policy/`,
`runs/gold347_installed_validation/report.json`, and
`runs/gold347_final/final_verification.json`. Current checkpoint/navigation
records contain the final counts, digest, configuration and native hashes.

2.147.0-alpha was installed at 2026-09-16T00:52:18.3800117-05:00. Candidate
and exact-installed full regression each passed 214 Lua fixtures and 361 Python
tests with unchanged frozen policy and test hashes. All 87 deployment files and
103 frozen product/dependency files match the repository and installation.
Policy digest: `8b2267b2d9783880b835a1e34a8cce92fe39a75b088ca066986bb07ed24d1691`.
Backup: `deployment-backups/advisor-20260916-005217` under the installation.

The root production acquisition fixture reports 4,505 checks, including actual
Decision delivery of all three successive actions. In that manufactured case,
the fixed-row control spends 120 score calls and fails the margin; the expanded
family spends 360 and selects a 216,000 minimum against a 90,000 target. A cap
of 120 uses the complete smaller family; 119 spends zero calls. These figures
are fixture work/score facts, not measured game speed or success probabilities.

## Limits and next work

This remains winning-Ante Small/Big/Vessel/Leaf acquisition and retention, using
a 125% opening margin in four deterministic public deck-composition samples.
It does not establish a clear probability or final win. Whole-inventory,
Negative/Perkeo/Observatory, cash, population and supported-score guards remain.
Full-inventory Cartomancer support is unchanged. Future free-slot generation,
mixed Tarot/Planet copying, final Heart/Acorn acquisition, collection rerolls,
earlier acquisition, joint exit/later-hand ordering and multi-action resource
planning remain incomplete.

Static follow-ups include repeated profile preparation, repeated whole-inventory
certification and duplicate fixed-hold scoring across acquisition/retention.
Safe reuse requires immutable exact state/world/order/floor identity and one
cumulative allowance. Those optimizations are not silently assumed here.

No new eligible Gold award, terminal rescue, numerical win odds or completion
time benefit is demonstrated. All experimental authority stays closed. The
historical 345 four-call batch and older outcomes/limits are preserved; 347
uses none of that closed capacity. Installation preserves current configuration
and all existing native DLLs. Activation waits for normal user restart; tools
do not control the game.
