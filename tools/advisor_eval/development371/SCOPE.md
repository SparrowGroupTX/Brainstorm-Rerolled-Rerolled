# Evidence-backed engine decisions — 2026-09-23

Selected behavior: address the three actionable gaps from the frozen loaded
2.169 ten-start cohort, WR-010/011/012, as one engine-development delivery.
The cohort and source anchors are in `WIN_RATE_RESEARCH.md` and
`win_rate_research/20260923_2_169_ten_start/REPORT.md`. Do not tune from
captured-state replay or claim a resulting win-rate change.

Acceptance before editing:

1. A visible $10 copy Joker with $9 cash, a free Joker slot and a $2
   supported sale enters a complete one-sale/one-buy comparison. It is
   selected only if the final row, actual cash/interest, supported paired
   survival, inventory and action cost beat hold/direct purchase. Unneeded,
   unfunded, protected, unsupported or truncated sale families do not execute.
2. A Buffoon Burglar offer prices the lost future discard growth when an
   active Yorick or first-discard Burnt would use it. The current blind's
   complete supported survival comparison can still select Burglar; no
   physical counter, future draw or growth is fabricated.
3. An opt-in proactive reroll may invest surplus cash for a durable copy
   Joker before Ante 8 when the current blind is supported safe. It requires
   a source-supported catalog opportunity, complete paired hit/miss and
   visible baseline comparisons, affordable real purchase/reserve, remaining
   horizon and positive net option value. Unknown outcomes get zero credit.
   The existing shortfall path and safe veto remain intact. No random seeds
   or claimed win probability enter the decision.

Use independent manufactured fixtures with deterministic common worlds,
snapshot immutability, Eternal/Negative/Perkeo/cash conservation, known and
unsupported catalog cases, incomplete-budget rejection and contrast cases.
Run targeted fixtures while iterating. At stable candidate freeze exact
runtime/test bytes, run full candidate gate, then install explicit runtime
files with backup and run the exact-installed gate. Preserve settings, saves,
all seven native DLLs, user journals and closed experiment budgets. No game
control, hidden search, captured-policy/scorer evaluation or cohort is
included.

## Delivered and checked — 2026-09-23

The selected paths are now in installed 2.171.0-alpha. `strategy.lua` admits a
complete one-sale, one-buy comparison with a vacant slot only when the visible
offer cannot otherwise be bought; the full-row path remains. Burglar's rating
charges a bounded future Yorick/Burnt discard opportunity, including remaining
blinds in the final ante, while supported immediate survival can prevail.
`paid_reroll.lua` adds a separate safe-blind, teacher-only future-Joker option:
one source-catalog first slot, ordinary and unstickered mass, fully charged
miss, complete paired hit endpoints, no speculative debt, reserved cash and
interest, and at most twelve replacement endpoints. The prospective full-row
sale family excludes the searched Yorick and Perkeo, then compares every
remaining supported legal victim. It cannot assert a win probability or a
future offer. Normal source proportions may still yield a correct hold.

Manufactured fixtures: `tests/advisor_funded_copy371.lua` (13 checks),
`advisor_burglar_horizon371.lua` (10), `advisor_proactive_reroll371.lua` (20).
The last one covers free/full rows, matched worlds, unknown pool dilution,
edition/sticker mass, Bull cash-sensitive miss, reserve, interest, Credit Card
debt and capped work. Twelve related fixtures passed targeted validation.
The first proactive fixture used an unsupported Droll source shape and failed;
the corrected source metadata (`type='Flush'`) passed. A capped fixture first
expected no reroll action at all, but the pre-existing strategic fallback may
reroll without claiming a supported proactive comparison; its final assertion
requires no proactive forecast. Both intermediate failures are historical
debugging evidence, not final validation failures.

The one independent read-only review (`engine_horizon_review`) found two
correctness risks: elective Credit Card debt could appear as a negative
purchase floor, and the highest-merit full-row victim could consume the
interest reserve before a lower-merit funded victim was considered. Both were
repaired and given manufactured contrasts before freezing. No further review
was commissioned.

Candidate policy digest `5aaf16bc787131d788788b425600c3ddb0234af571f1d9b9c0a8cd4935cf6ba5`.
`runs/engine371_candidate/validation/` and
`runs/engine371_installed_validation/` each passed 244 Lua fixtures and 391
Python tests with unchanged policy/test hashes. Five explicit files were
installed with `install_slice.py`; exact installed records are under
`runs/engine371_installed/` and `runs/engine371_final/`. There was no new
native file, game control, save access, hidden seed search, captured-state
policy/scorer evaluation, training, or cohort. Activation and full-run benefit
are unconfirmed.
