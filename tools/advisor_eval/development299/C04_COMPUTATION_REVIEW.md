# Read-only C04 computation review

Input: preserved C04 synthetic selected development trace,198 completed
decisions before its180.03100000007544s timeout. No new policy decision or
source execution was performed by trace_costs.py.

Completed advisor time147.25781750003776s. By actual published action:

| Action | Count | Advisor seconds | Score calls |
| --- | ---: | ---: | ---: |
| Hand discard |37|62.819260399439116|4,373,983|
| Hand Joker reorder |14|19.362417900003525|1,336,246|
| Shop leave |17|15.407618300407211|651,947|
| Shop Joker reorder |11|12.37055290013078|497,783|
| Pack choice |16|11.136281999875747|591,799|
| Shop pack open |14|9.72120270004962|443,181|
| Hand consumable use |23|6.742722499999244|445,299|
| Hand play |24|5.0682152004446515|348,193|

These costs include deciding the action, not only its final specialist. They
do not show that every discard or reorder was unnecessary. Actual repeated
advice after a reversible reorder remains necessary before irreversible play.

At step185 the8192-entry per-decision classification cache saturated:140,000
classification calls,85,741 hits,54,259 misses. At85:139,880 classifications,
85,473 hits,54,407 misses. The existing implementation never stores a later
classification once full. The detached FIFO proposal replaces entries at the
same capacity and exact ordered keys; synthetic parity/late-working-set checks
passed. M19 preparation proposes balanced before/after full captured decisions
at these two selected states. It needs its own one-use registration before
execution and establishes no speedup before measured evidence.

A separate possible optimization is a cheap reversible hand-order preflight:
the current phase/order decision is reached after full hand search under the
shop-exit copy row. A narrow Perkeo-copy to scoring-copy setup might obtain a
held clear before spending140,000 evaluations. This is NOT implemented or
authorized as a new source experiment by this note. It would need complete
paired held-subset scoring, actual setup costs, pinned/hidden/order-hook guards,
first-discard Burnt preservation, whole-inventory safeguards, unchanged total
decision caps on both success and fallback, and a fresh decision before play.
Do not carry a prior irreversible action through a reorder without validation.

No completed terminal result follows from this review. Mean failure depth or
cache hit count is not a win probability or proof of human-level performance.
