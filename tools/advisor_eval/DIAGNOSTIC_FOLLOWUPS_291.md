# Jokerless diagnostic pass and installed repairs

Four complete attempts were audited; all four lost. The work produced five
bounded runtime improvements, each installed after its own validation. The
terminal comparisons used286 and289. Follow-ups290 and291 have synthetic and
regression evidence only; their effect on complete runs is unknown.

| Selected development start | Baseline286 | Candidate289 |
|---|---|---|
| TO6O4111 | Ante3 Small loss;5 cleared blinds | Ante4 Big loss;9 cleared blinds |
| P83R7111 | Ante2 Flint loss;4 cleared blinds;1,135/1,600 | Ante2 Flint loss;4 cleared blinds;748/1,600 |

These deliberately selected, previously studied synthetic-profile starts are
not a player sample. One deeper run and one unchanged failure depth do not
establish better win odds. No complete Jokerless win or stronger-than-human
performance has been verified.

The installed changes address concrete omitted comparisons:

- **287 — shop plans:** A complete remaining-blind improvement can justify a
  plan even when opening-hand score alone would reject it, subject to cash,
  inventory, incumbent-continuation and common-world protections.
- **288 — repeated discards:** The resource planner can consider consecutive
  observed discards and later repeated discards alongside its original policies.
  Exact state reuse limits redundant work within the existing caps.
- **289 — consumable timing:** It compares use-now, play, discard and holding
  ordinary targeted consumables through complete bounded continuations. Current
  targets and future public observations stay distinct.
- **290 — owned Fool:** A known main-hand Planet can be copied in a supported
  shop state, then retained or used in a separate action. Holding Fool remains
  an explicit option, and both actions and inventory changes are charged.
- **291 — matching free play:** A consumable proposal's immediate play is also
  considered with unchanged inventory, when legal. This prevents exclusive
  access to an omitted card selection from masquerading as the value of spending
  a consumable. The free play receives its own scores and complete transitions.

The last issue came directly from C4's Justice decision. The modeled use branch
selected a different play from every declared free first play. The actual next
clear left the new Glass card unused, while the consumed Justice was unavailable
at the following boss. That observation does not prove the use caused the loss:
Glass development could still have future value. The repair adds the missing
comparison instead of forcing a hindsight-based retention rule. In a controlled
synthetic regression, all old free first actions fail while the use branch and
its missing free counterpart clear;291 selects the free play and retains Justice.
This is evidence of repaired comparison coverage, not a rescued source run.

The audits also found real nonlinear cash and scaling tradeoffs. One route's
extra spent hand removed the dollar needed for a later $10 voucher. That offer
was unavailable at the earlier choice, so it must not be hardcoded. Other
decisions had four clearing model worlds but still lost the actual blind. Draw
reliability, resource value, complete target families and calibration remain
unresolved. Evolutionary weight tuning should follow reliable measurements;
average failure depth alone can reward losing slowly.

Four captured comparison jobs failed parsing before advice and remain recorded
as eight errors, without retries. The serializer was repaired and tested with
synthetic generated Lua. Two source-method Lucky components passed20 conditional
cases; their limited test-double boundary does not qualify the whole adapter.
Four fixed-range search workers observed about1.65 times faster traversal for286
than285, with identical empty match lists. Rare-match waiting time and live game
responsiveness were not measured.

Every current-cycle job and historical allowance is closed. No further worker,
search or scheduled continuation is pending. The game was left undisturbed;
settings and both native DLLs were preserved. Activation waits for a normal user
restart. Final installation hashes, test counts and backups are in
`SESSION_RESET_291.json` and `runs/freeplay291_final/final_verification.json`.

Detailed evidence and limits:

- `runs/diagnostic287_20260913_222344/FINAL_RESULTS.md` / `.json` and
  `FINAL_BUDGET.json`: all outcomes, timings, milestones and closed allowances.
- The cycle's `C1_C2_postmortem` and `C3_C4_candidate_audit` records, plus per-run
  extracted snapshots, exact decision rows and manual postmortems.
- `SHOP_SEQUENCE_FINISH_287.md`, `REPEATED_DISCARD_288.md`,
  `OWNED_CONSUMABLE_TIMING_289.md`, `OWNED_FOOL_SHOP_290.md` and
  `FREE_PLAY_COUNTERPART_291.md`: exact implementation scopes and fixture evidence.
- `NEXT_PRIORITIES_291.md`: remaining coverage, calibration, opening viability,
  Knife's Edge and twenty-challenge work. Neither50% nor75% per-challenge target
  has been demonstrated.
