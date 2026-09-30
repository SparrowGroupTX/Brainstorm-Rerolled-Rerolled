# Sole read-only review431

Same reviewer /root/readonly_review; one substantive design review and one
focused implementation recheck. No recursive delegation, edits or captured replay.
The reviewer examined source and recorded results without executing tests.

Design review established three requirements: allocate a fresh private Joker row
because score_cache keys by table identity; project each real after_discard
endpoint so Yorick/Burnt growth survives; reject the new receipt in Acorn's
retained product until all public worlds receive that same proof. Canonical
Raised Fist has extra=nil/effect=Socialized Mult; every hand/deck nominal must
be nonnegative and canonical. Implementation and fixtures cover these contracts.

Focused review found a missing explicit card-visibility check: a plausible
canonical deck payload with unknown/identity_redacted flags could enter the proof.
Fixed by rejecting unknown/identity_unknown/identity_redacted/concealed entries
throughout hand/deck. Ordinary deck orientation remains allowed. Four negative
cases and a positive back-facing-deck case passed in targeted6 (384 checks).
The reviewer confirmed disposition and reported no remaining blocker. Review
allowance is exhausted. A final stricter guard also rejects back-facing held
cards; the full frozen gate includes that negative case (387 checks total).

Preserved fixture failures: targeted1 incorrectly expected a one-score additive
proof to require more than two total calls; corrected to test an actual two-order
Glass/Mult family in targeted2. targeted4 accidentally made the manufactured
Burnt discard a Flush by giving all cards Clubs; targeted5 changed one suit to
test the intended Pair. Runtime safeguards were not loosened for either fixture.
Exact frozen430 reproduces both old guards in targeted1. Targeted2/3/5/6 pass;
the final combined frozen full gate passes all302 Lua fixtures and458 Python tests.
