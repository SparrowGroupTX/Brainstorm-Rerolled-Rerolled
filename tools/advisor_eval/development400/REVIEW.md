# Bounded read-only review 400

One existing reviewer, `/root/readonly_review`, performed one substantive
pass and one focused recheck. It did not edit files or run the captured game
states. Its passive public-log audit distinguished nine financially reachable
copy offers, five acquisitions, three supported merit-gated misses, one
uncertain Brainstorm endpoint, 44 Buffoon offers and 20 settled Death uses.
The public evidence and action anchors are summarized in REPORT.md.

The focused recheck identified two correctness issues:

1. Two focused order candidates could be consumed by current/generic orders
   before copy-target arrangements were considered. Changed the bound to four;
   the fixture now requires the focused-acquisition receipt and checks physical
   ID and row-order variants through production scoring.
2. Missing playing-card IDs could produce a nil table key; a missing public
   deck also needed an explicit rejection. Added guards and manufactured
   missing-ID/missing-deck controls. Teacher Death's old spare-play route now
   also requires the qualified Death option.

These were repaired by the primary implementer and checked in the final
frozen full gate. No third review occurred. The full regression subsequently
found a separate reserve-versus-early-voucher rescue issue; the primary fixed
the exemption, ran the original regression, and created a new exact freeze
with a passing full gate. Do not describe that later change as independently
re-reviewed. The reviewer found no other survival, Glass, inventory, aggregate
budget or hidden-information blocker within the reviewed scope. That is not
loaded-game or win-rate validation.
