# Bounded independent review406

One existing read-only reviewer performed one substantive schema/false-positive
review and one focused implementation recheck. No replacement/recursive reviewer,
parallel implementer, reviewer tests or active-journal/game access occurred.

The substantive review established the main acceptance constraints: separate
Invisible maturity/random-copy behavior from immediate Blueprint value; bind
observation/advice/action by explicit run-scoped identity; resolve sale plans to
physical offers; do not treat callback or settlement markers as physical proof;
stop attribution at run endings; distinguish pack choice from opening cost;
do not equate boss debuff with expiration; treat incomplete or truncated receipts
and omitted survival arbitration as uncertainty. Multi-choice packs, credit
allowance loss, Negative slots and charged Invisible sales require guards.

The focused recheck found three concrete correctness issues in the first version:

1. Generic phase/offer changes admitted transient empty `other` states as closure.
   Fixed with supported action-specific endpoints and same-round/context checks.
   New tests preserve the pending state through empty transition and unchanged
   pack observations, then admit a supported exit. Rerolls require their new
   nonempty disjoint row and recorded cash debit.
2. Merit and sale-plan reversals could flag the first of two pack choices even
   when the preferred card was acquired next. Both comparisons now require an
   explicit final choice, with unassessed-ordering coverage counters. Tests now
   include complete ranking receipts and explicit sale plans in two-choice packs.
3. Before/after file hashing did not bind bytes consumed during decoding. A
   hashing reader now caps and verifies the exact consumed stream against the
   manifest. The manufactured A-path/B-decode/A-path case is rejected.

The wording "Full states" was corrected to "projected decision contexts".
No further reviewer pass was requested; all focused issues are covered by
manufactured acceptance in the full452-test gate.

The primary implementer also checked a necessary context exception against the
preserved older public records: boss cash-out can advance ante while retaining
the completed round number.28 earlier unused-discard flags had that transition.
The clear detector admits exactly that public boss transition, with the same
round and target clearance, and has a paired manufactured test; a nonboss ante
change still fails. This preserves valid boss-round coverage without admitting
menu or next-round snapshots.

Earlier targeted logs and `historical403_attempt1/` are preserved. Authoritative
final source is in `validation/sources/`; final demonstration is
`historical403_final/`. These are passive analysis/fixture checks, not policy
replays, new gameplay or evidence of a better win rate.
