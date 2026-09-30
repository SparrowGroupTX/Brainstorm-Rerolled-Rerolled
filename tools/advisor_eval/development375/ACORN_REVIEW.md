# Read-only Amber Acorn boundary review (2026-09-23)

The current cohort's run 6 is an unsupported retirement, not a game loss.
Public sequence 12649 shows seven visible Jokers before Amber Acorn;
12662–12665 show unavailable advice and guarded retirement before any boss
play. The reported “Prior public model gap persists after shuffle” is a
sticky wrapper; the direct initial reason is not journaled. Static source
deterministically rejects the seven-Joker public inventory.

- `acorn_belief.lua:start` and `validate` require 1–6 Jokers and at most 720
  complete worlds; equal-payload quotienting occurs only after that cap.
- `acorn_ordering.lua:suggest` enumerates at most 720 candidate slot orders.
  Raising the belief limit alone can make `orders` nil and is unsafe.
- `acorn_belief.lua:own_signatures/advance_public` does not qualify Golden
  Ticket, Abstract Joker or Ice Cream. Merely selling Ice Cream before hide
  would reduce seven to six, but the first completed play or discard would
  invalidate the remaining row's value belief.
- Ice Cream had five chips remaining. Its first scoring play can remove it;
  `acorn_public.lua:sync` correctly rejects an unmodeled concealed population
  change. Selling it pre-boss loses its chips, changes Abstract's Mult and
  can affect Blueprint adjacency; it is not unconditionally safe.
- No hidden Joker identity or saved profile was inspected. The boss's
  counterfactual outcome is unknown.

The narrow future candidate is a **qualified public pre-hide sale** only
when the sale is legal and a complete supported survival comparison accepts
the lost effect, plus exact retained Golden Ticket/Abstract transitions.
Keeping seven instead requires 5,040 complete worlds, a bounded action
shortlist that never truncates worlds, independently safe current-order
advice, and modeled Ice Cream decay/removal. Neither variant is implemented
here.

Manufactured falsifiers for that future work: (1) six-card sale-only row
with Ticket and Abstract must still fail after a completed action before a
fix; (2) each retained Joker separately must preserve exact play/discard
transitions without duplicating physical Yorick growth through Blueprint;
(3) Ice Cream chips 5 versus 10 must handle removal versus decay and the
changed Abstract count; (4) a sale that drops a modeled score from 3,255 to
2,800 against a 3,000 target must be rejected; (5) a 5,040th-world-only
failure must never be hidden by a 720-world prefix; (6) cap-only order
enumeration must decline cleanly, not index nil; (7) stale epoch, concealed
sale, missed completion and unqualified effects remain unavailable.

The separate read-only reviewer inspected these interfaces and tests without
changing files or running a captured state. This document preserves that
finding; it is not an authorization to relax public-information safeguards.
