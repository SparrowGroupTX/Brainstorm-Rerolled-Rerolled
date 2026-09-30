# Certified generator priority — 2026-09-12

`ordering.lua` now keeps an owned-generator reveal ahead of a Joker reorder when
the existing complete maximum certificate has already ruled out every immediate
played/Joker order. A larger losing score must not displace that last-hand reveal.
No additional scoring or broader loss claim is introduced.

A losing deterministic score alone is NOT sufficient to suppress reordering.
Review found a joint-order rescue: two Aces, Glass then Mult, with Duo then Joker,
score640 initially,768 after only Joker ordering,896 after only card ordering,
and1024 after both. At target1000 the first nonclearing reorder enables the second
clearing reorder. Random upside and Mr. Bones can also preserve sub-target plans.
These cases retain existing behavior; the installed guard needs a real generator
certificate, which already handles randomness and refuses Mr. Bones.

`tests/advisor_final_order_priority.lua` uses the real scorer, search, ordering
and Decision path. It checks generator priority, nonfinal progress, immediate
clears, Misprint upside, Mr. Bones survival, the two-step joint reorder and the
unchanged fast-clear70 budget.

Preserved intermediate evidence: `runs/final_order269_before1` is an expected
frozen268 failure of the initial broader test, under30s (0.125s). The broader
prototype passed four fixtures/421checks in `runs/final_order269_focus1`,30s cap,
0.172s, before review exposed the joint-order limitation. That broad guard was
REJECTED before installation. Final exact269 validation owns the narrowed guard
and expanded regression; do not treat the early pass as its final evidence.
No source attempt, generated outcome, native change or global budget increase.
