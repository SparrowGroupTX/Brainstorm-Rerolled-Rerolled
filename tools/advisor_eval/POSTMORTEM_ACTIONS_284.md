# Development post-mortems and implementation decisions

This is a selected retrospective review, not an exhaustive proof of optimal play.
The source05/06/10 and source11 cases are inspected development data. No new run
or captured decision was executed while writing this analysis. Exact original
inputs and detailed observation/action extracts are in `runs/postmortem282_readonly/`
and the original twelve-attempt ledger under
`runs/jokerless271_push_20260912_214242/FINAL_SOURCE_EVIDENCE_280.json`.

## What the evidence supports

| Finding | Information available then | Status and useful repair |
| --- | --- | --- |
| Source05 final shop held two main-hand Saturns, then left them unused. | Owned inventory, Straight level19 and actual play history were public. | Already repaired275. Do not credit a later release for fixing this again. |
| Source05 Bell223–226 spent every discard while preserving five hands; the remaining-resource comparison was incomplete. | At226 a legal modeled300-chip play of the same five discarded cards could preserve the last discard. Bell's forced card and actual hand were public. | Counterfactual is sensible to compare, not proved better.284 adds a complete bounded family through all remaining hands, including play of the discarded selection and later observed redraws. |
| Source10 Eye75–77 preserved a known2465-chip Straight with three successive discards, then could not repeat it. | Eye's used-hand rule, four hands, three discards and target4000 were public. |284 adds later-hand policy comparisons with Eye history, including Two Pair/Full House category representatives. It does not prove an early Straight or alternate discard would rescue this run. |
| Lucky uncertainty repeatedly prevented future comparisons. | Ordinary Lucky effects and physical public composition were available; actual future outcomes were not. |282 supports private sampled score/cash transitions;283 connects these to whole-blind shop forecasts;284 connects them to larger/current-hand resource policies. Every actual final play must resolve the private outcome. |
| Source05/06 differed by one unused-hand dollar before a later Hanged Man offer. | Current cash and resource costs were public. The later random shop offer was not known at the earlier hand. | This is a real threshold chain, not proof Saturn use was bad or caused the terminal difference. Preserve cash and actual action costs; do not use the later revealed offer to justify hindsight. |
| Source11 Moon use and source10 unused Hanged Man involve timing and off-hand resources. | Targets, inventory capacity, boss restriction and public composition were available. | Joint use-versus-hold/discard timing remains unfinished. Hanged Man does not draw on use; ordinary preservation_cost=0 is not zero future option value. |

The strongest general diagnosis is missing complete comparisons between coupled
resources. Scoring a strong hand, valuing a Tarot, recognizing a boss restriction,
or knowing a Blue-seal effect separately does not establish the best sequence.
An integration repair must carry their changed state through the same alternatives.
It must not discard unsupported branches and promote whichever partial result is
left, or select a future action after seeing its private outcome.

## Nonlinear effects to test, not assume

- Cash thresholds: an extra unused hand can preserve an affordable purchase or
  interest threshold. Spending now may also prevent failure; blanket saving is
  not justified.
- Multiplication and access: hand level, rank/suit concentration, Glass/Steel,
  draw access and legal boss hands interact. A larger base level gain does not
  imply a larger realized run gain.
- Inventory capacity: using a held card may open a Blue-seal slot, but only a
  surviving clear with that Blue card retained produces the actual final hand's
  Planet. Negative capacity and whole-inventory utility remain guarded.
- Action timing: a low-scoring legal play can be useful cycling while retaining
  a discard. Conversely, spending a hand may destroy the only feasible path.
- Option value: keeping Hanged Man or Moon may matter for later observations.
  A no-Joker preservation_cost of zero excludes special Perkeo/Observatory value;
  it does not price every future use of the ordinary card at zero.

## Measurement and tuning

`cohort_progress.py` and `COHORT_PROGRESS.md` implement strict normalized reporting
for a prospectively registered paired cohort. All registered attempts stay in
the denominator, including missing/error/timeout/unsupported/censored outcomes.
Missing-outcome bounds are separate from conditional sampling intervals. Entering
and clearing fixed ante/blind milestones and skipping blinds remain distinct.
The tool trusts declared upstream terminal audits and provenance; it does not
qualify the adapter or convert the historical dependent attempts into a cohort.

Mean failure round is diagnostic. It can fall when late failures become wins,
and optimizing it alone can reward spending more real time on eventual losses.
Primary evaluation needs verified completion and all real time costs, including
failed attempts, opening/search overhead, computation and user actions. Original
source worker seconds do not measure the user's animation/click time.

Weight search should follow meaningful action coverage and a stable development
cohort. Six tunable heuristic weights already exist, and many contextual values
are computed rather than fixed constants. Tuning can price represented tradeoffs;
it cannot introduce an absent transition or fix a comparison that never completes.
Paired2x2 tests can distinguish separate A/B changes from their interaction; keep
development, selection and untouched terminal confirmation separate. No evolutionary
search, calibration simulations or fresh terminal cohort was run in this analysis.

## What stronger than a good human would require

Use a prespecified comparison with skilled humans on matched starting conditions
and information access, accounting for seed selection/opening time, retries,
computation and actions. Specify whether both use the same assistance/checkpoint
rules. Keep inspected seeds out of confirmation; count unresolved results and
repeat enough independent seed blocks to make uncertainty useful. Completion and
real time are separate endpoints; faster losses and slower wins need the actual
completion-time objective, not a convenient proxy. No such benchmark is complete,
and no current evidence establishes human-level or stronger performance.

Read the current checkpoint and component notes for release/test status. The
resource family remains bounded and heuristic: it is complete only for its
declared alternatives, not every possible hand/discard/consumable sequence.
No verified complete Jokerless win or numerical win-odds improvement is claimed.
