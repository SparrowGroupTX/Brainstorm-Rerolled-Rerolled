# Bounded whole-blind Lucky integration — development283

This slice completes a remaining integration gap after282. The original no-Joker
Lucky transition could resolve score and cash, but blind_finishing rejected an
ordinary uncertain Lucky score before invoking it. shop_scoring separately
rejected every profile with any uncertain opening candidate. Thus resolving a
mechanic in a shared transition did not make the existing shop policy usable.
The preserved source11/source10 continuation blockers motivated this work; see
LUCKY_CONTINUATIONS_282.md for the existing read-only source-mechanics evidence.
No preserved decision was executed and no run was rescued by this evidence.

## Implementation

- `blind_finishing.choice_supported(state,play)` admits an ordinary public-state
  mean only when its complete visible warning list names the exact Lucky warning
  and no other warning, at least one active scoring card is Lucky, there are no
  owned Jokers, physical IDs are present/distinct, and Lucky amounts and normal
  probability are finite nonnegative numbers. Suppressed/missing warnings fail
  closed. Ordinary legal exact scores retain their existing support path.
- Opening and future play selection use that admission gate. A Lucky mean never
  becomes a reliable clear for population/reward ranking. The selected indices
  are committed before `sampled_outcomes.after_play` resolves the private world.
  Every actual transition, including the last playable hand, must return legal,
  finite, nonnegative, fully resolved scoring. Score/cash/population changes then
  come from that result. Action evidence retains the existing sampled Lucky
  labels and `score_guaranteed=false`.
- `shop_scoring` checks *every uncertain opening candidate*, not merely its chosen
  play, against this gate before allowing a random profile into finishing.
  Stochastic startup remains excluded. The ordinary opening metrics retain their
  uncertain means; only a completed pair of whole-blind forecasts can influence
  cumulative progress comparisons. Identical endpoints receive no improvement
  credit. No budget, candidate family or policy weight changed.

The fixed family is still play-only versus one observed targeted discard, using
four common composition worlds, at most four hands/eight held cards/32 future
play candidates, within the existing shared shop budget. It does not plan
consumable use or prove the fixed policy's discard timing is optimal. In
particular, its observed discard trigger still compares the chosen ordinary
score with the target; admitting random scoring does not optimize that trigger.
The two_hand_finish module is unchanged and retains its own uncertainty guards.
Root current-hand planning is a separate component, not implied by this slice.

## Routine fixture evidence

`tests/advisor_blind_lucky.lua` passes294 checks. A synthetic future-Lucky family
fails with the former mean-only transition and completes both fixed policies in
all four worlds with the current transition. Every final Lucky play uses15 or315
chips, never the75-chip mean. Score/action/cash totals, charge counts, complete
families, deterministic repeats and unchanged input fingerprints are checked.
An opening Lucky commitment remains unchanged across private hit/miss worlds;
separate ranking checks preserve a certain clear over a larger uncertain mean.

The actual shop entrypoint now produces complete whole-blind evidence for its
synthetic no-Joker Lucky deck. The same input remains unsupported with the former
gate. The paired identical-endpoint result still labels uncertainty and gives
zero adjustment. Fixtures retain negative cases for suppressed warnings,
nonselected unsupported candidates, any owned Joker including debuffed Lucky
Cat, malformed values, missing/duplicate physical identities, concealment, Hook,
unknown enhancements, stochastic Marble startup, unresolved actual transitions
and exhausted shared budgets. They do not label four samples a measured success
rate or a scoring guarantee.

`runs/blind_lucky283_focused1` preserves the earlier direct-module validation.
`runs/blind_lucky283_focused2` validates the completed source/test slice with seven
fixtures: blind Lucky294, existing blind finishing41, Lucky632, shop startup30,
shop survival15, readiness24 and liquidity34; all pass in0.562s under an explicit
hidden60s subprocess cap. The source and test hashes recorded alongside that
focused result identify the reviewed implementation. Root checkpoint records
own full frozen regression, installation, exact-installed validation and hashes.

This work used read-only source inspection and routine synthetic fixtures only.
No captured replay, source component, executable ZIP read, search or complete
attempt ran. No game or save access/control occurred. No verified Jokerless win,
numerical win odds, changed source action or real completion-time improvement
is established. Historical experiments remain closed and unmodified.
