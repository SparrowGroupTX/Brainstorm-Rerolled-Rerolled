# Passive decision-timing audit — 2026-09-23

This is one tooling-and-analysis slice while the user runs a separate ten-start
marathon. The installed 2.171 runtime, settings, search recipe, journals and
game remain untouched. The only data input is the previously frozen, converted
loaded-public-label 2.169 cohort under
`win_rate_research/20260923_2_169_ten_start/capture/`. Its manifest and
checkpoint establish a 2026-09-23T16:36:58Z cutoff, 17,189 contiguous public
events, 25 frozen source segments and 2,696 win-first observations. A public
version label does not attest exact loaded bytes.

Acceptance criteria:

1. A bounded read-only analyzer accepts one explicit converted public JSONL
   file and its expected SHA256. It rejects changed/truncated input, duplicate
   conflicting decision receipts, invalid durations, noncontiguous event
   sequences and oversized inputs. Identical receipts copied to the linked
   action events count once. It emits no card state or hidden information.
2. Report coverage separately for current, stale and unavailable advice;
   missing timing is unknown rather than zero. The journal can deduplicate a
   `teacher_advice` before its receipt arrives, then attach that receipt to
   later linked action events. Reconcile those copies by decision ID. Link
   available receipts to public observation phase/ante and action requests
   without treating advice as execution. Report grouped active/elapsed wall
   time, evaluation counts, percentiles and a few slow anchors.
3. Manufactured parser fixtures cover valid joins, missing timing, duplicate
   receipts and malformed durations. Run the analyzer once on the frozen
   cohort and save a compact, hash-bound summary. Do not run any policy,
   scorer, game, component-profile worker, source-game code or live batch.
4. Rank an actionable performance target and its correctness/measurement
   requirements. No runtime edit, installation or speedup claim is included.

`active_seconds` sums measured decision-resume wall intervals. It is neither
CPU utilization nor total game time. The report must preserve that distinction
and the older synthetic-profile provenance separately.

## Frozen audit result

The final compact result is `frozen_2_169_decision_timing_final_v2.json`, SHA256
`3e30ee56a002bcb4488b38bce2ea8d62ac54c2957ce24e00e8e179bec28cb90d`.
It reads the unchanged 54,551,112-byte converted public `capture/events.jsonl`,
SHA256 `819cb4b5f9d895e44a66bbea130b3ef61959a56107d44242d8ad7005c6a9f189`.
The source capture manifest separately verifies the 25 frozen journal segments;
`checkpoint.json` records the installed 2.169 hashes and public loaded label.
The prior cohort report establishes the ten starts and terminal outcomes.
No event from the new in-progress marathon was read.

The first advice-only extraction found 1,542 timed receipts and appeared to
leave 64 `current` advice records untimed. That was an **incomplete join**,
not proof of absent instrumentation. `player_journal.lua:207-216` excludes
timing from the stable advice key, so it can emit `teacher_advice` before the
receipt is attached, suppress the otherwise-identical later advice event,
and carry the receipt as `advice_timing` on linked `auto_run` and
`action_requested` events. Sequence 174 (run 1, shop) has no inline receipt;
sequences 175-177 carry the same decision 49 receipt. Earlier draft and
final-v1 extracts are retained as intermediate evidence and superseded by the
final-v2 reconciled result. The final join also rejects forward receipt links
and conflicting advice associations, and counts wrong-run/missing public
observations as unknown rather than borrowing their phase or ante.

The analyzer validates the linked run/collection/advice identity and complete
receipt fields, then counts identical copies once. Across the 17,189 events it
found **1,606 unique completed current-decision receipts**, zero current
advice left untimed, zero conflicting/orphan sidecars, and **5,072 identical
receipt copies** on later events. All 1,603 auto-run action requests link to
one of those timed current decisions; the other 22 requests are labeled
`player_callback` and link to unavailable advice. Three current timed advice
records were not requested by auto-run. Two receipts precede the first of the
ten recorded `collection_run_start` instances. Request linkage does not prove
settlement; the cohort report checks requests, callbacks and first settled
observations separately.

| Phase | Unique decisions | Measured active wall s | Share | Reported evaluations | Active p95 s |
|---|---:|---:|---:|---:|---:|
| Hand | 741 | 310.963 | 60.2% | 42,504,511 | 1.112 |
| Shop | 410 | 166.053 | 32.2% | 8,006,261 | 1.577 |
| Pack | 138 | 39.183 | 7.6% | 3,177,184 | 0.929 |
| Blind and round | 317 | 0.122 | <0.1% | 0 | <0.001 |
| **All current** | **1,606** | **516.321** | **100%** | **53,687,956** | **1.098 overall** |

The 1,603 requested auto-run decisions account for 516.321 of those active
seconds (rounded) and 53,687,956 reported evaluations. Hand decisions have
79.2% of those evaluations. The longest recorded decision is a run-1 shop buy
at sequence 292: 3.754 active seconds and 37,199 evaluations; the next two
also are shop buys at sequences 1610 and 10856. The phase share and p95 are
descriptive of this selected loaded-label-2.169 cohort, not a version
comparison or a calibrated latency distribution. `evaluations` is a policy
work counter with different cost per phase; it is not a uniform scorer-call
or CPU-time measure.

The ten run durations in the existing `runs.json` sum to 2,604.695 wall
seconds. The recorded decision active sum is about 19.8% of that span. Even
the arithmetic thought experiment of eliminating all 516 measured seconds
would yield only about 1.25x end-to-end speed if all of them were sequential
critical-path work. This is **not** a proven speed ceiling: other advisor
work, frame waits, search, game animations, overlap and measurement scope
remain unseparated. It does show why a 2-5x *marathon* speed claim cannot
follow from an isolated scorer improvement alone.

## Architecture and next target

`runtime.lua:632-708` runs a decision in measured coroutine resumes and
records a completion receipt. `search.lua:701-733` charges ordinary score
work against the 140,000 cap; `shop_scoring.lua:418-422` has its own 50,000
comparison cap. `score_cache.lua:20-96` already reuses exact classification,
row and flag preparations per decision, but still calls the full
`scoring.lua:212-330` score body for every scored candidate. That body creates
per-call sets/tables, scans the hand, classifies, prepares held-card/Joker
state and runs effects. The first performance target is therefore **repeated
score-body preparation and allocation within hand search**, with shop
profile preparation as a separate long-tail target. The latter has only 14.9%
of reported evaluations yet 32.2% of measured active time; this suggests
nonuniform work but does not isolate its cause. The 1.50 million recorded
resume calls are a secondary scheduling-overhead hypothesis, not evidence
that changing yield cadence would help without harming responsiveness.

The older `runs/component_profile243/report.json` is explicitly an
unqualified synthetic component profile. It put most measured work in the
score body and showed mixed prepared-cache medians (nonclear 0.254→0.231 s,
safe shop 0.040→0.035, weak full shop 0.035→0.036). This motivates a
**hypothesis** about residual score-body work, not a measured 2.171 speedup.
The next runtime candidate should cache only immutable, exact per-state
score preparation after proving its full dependency key. It must preserve
score/action parity, evaluation charges and yield cadence, candidate coverage,
complete common-world order, Glass/population conservation, unsupported
mechanics and the 140000/50000/25000/70/12 caps. Falsify the hypothesis
with manufactured parity fixtures spanning transformed cards, changing Joker
rows, copies, held effects and boss restrictions, followed by a separately
authorized, bounded paired performance measurement before claiming speed.

There is also a maintainability opportunity: a future versioned public
`decision_completed` event could carry one receipt once, with advice and
action events referring to its decision ID. That would remove the currently
necessary sidecar reconciliation and make missing telemetry distinguishable
from deduplicated advice. It is a prospective runtime schema change, not part
of this audit or the live marathon.

## Validation and release status

`analyze_teacher_decision_timing.py` uses explicit input/hash/output paths,
stream/line/event caps and exclusive output creation. Manufactured tests cover
joining, sidecar recovery, wrong-run/missing observations, forward/cross-advice
links, duplicate/conflicting receipts, malformed durations, sequence/anchor
duplication, incomplete lines and hash mismatch. The focused new and existing
timing suites passed **32 Python tests**. One
read-only review independently checked timing semantics and source constraints.
No unchanged full regression was rerun. This is tooling and documentation
only: repository and installed gameplay bytes remain 2.171; activation of
2.171 and the new marathon's loaded version are unconfirmed. No runtime
installation, game control, captured-state evaluation, worker experiment or
budget renewal occurred.

## Wall-time addendum — user question, 2026-09-23

The follow-up asks what occupies the rest of the run if active decision work
is about one fifth. `wall_time_decomposition.py` reads the same explicit
hash-verified frozen public event stream; its final compact output is
`wall_time_2_169_final.json`, SHA256
`b258a5e8336a218d94f81d8cedad8a834e1d5316e6f2109d5dc7abcce49a0fe7`.
Two earlier iteration outputs are preserved and superseded. The existing
`analyze_player_timing.py` parsed all 25 frozen source segments in two bounded
groups (`frame_timing_part1.json`, `frame_timing_part2.json`): all 17,189
events were covered, but there were **zero `performance_window` events**.
Frame, draw, game-update, journal and animation costs therefore cannot be
assigned directly in this cohort.

The ten public run-start-to-finish spans total 2,604.257 monotonic wall
seconds. Product `run_seconds` receipts total 2,604.695 seconds; the 0.438 s
difference is boundary/timestamp scope, not silently inserted into a category.
The following are disjoint measured intervals after subtracting overlaps:

| Visible interval | Seconds | Share of run-start-to-finish wall |
|---|---:|---:|
| Advisor decision coroutine actively running | 516.321 | 19.8% |
| Decision open, between coroutine resumes | 747.705 | 28.7% |
| After callback, before first settled public state, outside decision | 1,140.198 | 43.8% |
| Outside both observed interval families | 200.033 | 7.7% |

All 1,603 auto-run requests have a callback and first settled observation.
Callback return occurs quickly (median 0.0067 s); it is not completed game
effect. The callback-to-first-settled intervals total 1,217.276 s, of which
77.078 s overlaps decision intervals, leaving the 1,140.198 s disjoint row
above. These action intervals do not overlap each other in this cohort.
**Play** is the largest identified subclass: 280 actions account for 655.681
seconds after callback and outside decisions, with a 2.649 s median gross
callback-to-first-settled gap. Opening 117 packs accounts for another 121.458
exclusive seconds. Those windows plausibly include game scoring/opening
animation and transitions, but also update/render scheduling, journal work
and advisor refresh. The log cannot isolate animation as the measured cause.

The 747.705 s between decision resumes similarly includes frame scheduling
and other interleaved work; it is decision *latency* but not measured advisor
CPU. A coarser yield cadence might change it, but could harm responsiveness
and would need fresh bounded paired evidence. The ten searched-opening
receipts total only 2.579 s of search wall time; native seed search is not the
large observed wall-time bucket here. The remaining 200.033 s is genuinely
unattributed, not a hidden claim of UI or logging overhead.

The wall analyzer uses interval unions and intersections, so it does not add
overlapping decision/settlement time twice. Manufactured interval and
action-link checks plus the earlier timing suites passed **34 Python tests**.
No live marathon observation, game control, source execution, scorer/policy
replay, runtime edit or installation was involved.
