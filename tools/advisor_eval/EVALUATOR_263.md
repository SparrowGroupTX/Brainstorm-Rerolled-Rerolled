# Source evaluator corrections — 2026-09-11

The evaluator now preserves source phase transitions, verifies the action actually
selected, and distinguishes terminal source outcomes from prediction coverage.
These tooling changes require no runtime deployment. They do not qualify the
episode adapter or establish any challenge win probability.

## Corrected boundaries

- `engine_run.lua` mirrors the original `Game:update` empty-held-hand/nonempty-deck
  transition into `DRAW_TO_HAND`, clearing `STATE_COMPLETE`. Without this guard,
  an entirely destroyed held hand could leave the adapter waiting indefinitely
  while the original game would draw again. The source was inspected read-only
  from the executable ZIP; its process was never launched.
- `engine_contract.selected_prediction` matches the final action indices against
  the ordinary prediction. When a specialist selects a different play, the source
  verifier rescores those selected indices after the decision. Matching supported
  random floors remain floors; source-side rescoring does not influence the policy
  or reveal hidden identities to its decision process.
- `development_report.classify` requires source completion evidence for a win,
  gives actual game-over precedence, rejects terminal/censor conflicts, duplicate
  terminal/stopped records, non-boolean source evidence and nonfinite terminal
  antes. Missing historical completion evidence is unsupported, not silently
  upgraded to a win. Original final-Boss code may set `GAME.won` before a loss;
  fresh in-memory profile completion is therefore checked separately.
- Every played action reports exact/floor verification or an explicit uncertain
  score gap. Missing, duplicate, unmatched and unknown-scope verification records
  cannot produce complete parity coverage. A source terminal result is not itself
  proof that every advisor score prediction was supported.
- Development cohorts include both declared profile-spec and actual unlock-flag
  digests. Both named profiles remain synthetic and unrelated to user saves.
- Failure traces retain a detached current snapshot and last decision; the
  reporter identifies observed symptoms and replay entry points without assigning
  unproven strategic causation. The existing Lua error wrapper exports this state;
  the host fallback now checks an emitted flag so the context remains unique and
  a diagnostic failure never replaces the original cause.
- Optional source-loader injection supports `blind_finishing` with draws,
  sampled outcomes, search, finish rewards, strategy and multi-discard dependencies.
  `liquidity.snapshot` is bound explicitly. Frozen 2.62 remains loadable because
  the new module is optional.

## Bounded original-source evidence

`qualify_episode_boundaries.py` freezes the complete policy and source adapter,
registers all requests/caps before execution, uses hidden isolated `lua51.dll`
workers, and reaudits provenance, profile inventory, commands and trace hashes.
Its fresh output directory is a one-time lease; audit never runs workers or
renews an allowance. Named scenario subsets support a narrow regression rerun.

- `runs/episode_boundaries263_source1`: registered 46 synthetic fixtures, 5 seconds
  per worker and 90 seconds cumulative; actual source-worker total **15.341s**.
  All 20 original challenge initializations passed their final-Boss win/loss
  boundary pair. Empty-hand refill and zero-hand-limit loss, selected-action
  deterministic score, and Mr. Bones' exact save threshold also passed.
  These fixtures explicitly jump to final-Boss state; they do not play or win a
  challenge run. The full-matrix initial report passed, but subsequent uniqueness
  review identified duplicate failure-context output introduced by the host
  fallback. `reaudit_current.json` correctly records **45/46**, preserving the
  initial artifact and the defect instead of rewriting it.
- `runs/episode_boundaries263_context2`: after the emitted-flag correction, one
  newly registered failure-context regression, 5-second total/worker cap, passed
  in **0.330s**. The intentional original unsupported error and exactly one
  detached context are retained. This is a one-case correction, not a rerun of
  the other 45 source fixtures.
- `runs/evaluator263_final_focus`: the adapter contract passes **22 Lua checks**;
  the current Python suite passes **150 tests** (5.815s), including seven boundary
  protocol tests and 15 development-report tests. Hidden worker caps were 60
  seconds each. Earlier focused outputs remain in evaluator263_unit1/unit2.

The stable source-adapter digest after these corrections is
`6a233d5fbcba98002e9feeeafb032388d6d773c4ad90840e2be4807c15f8f724`.
The boundary policy is frozen installed 2.62, digest
`60ededca68ab3e5ff10c655b4a0351b0df82b4bec498bd67ed4f7f09b159f98b`.
The context correction's registration and adapter bytes are frozen independently.

## Interpretation and next evidence

The source matrix qualifies only its listed synthetic boundaries. Intervening
full-run transitions, all Joker/Boss/consumable combinations, uncertain forecasts,
actual user unlock populations and live user/frame timing remain unqualified.
No source error, timeout, unsupported state or action-budget censor may become
an imputed loss or win. Neither 50% nor 75% on each challenge is demonstrated.

New full-attempt development/holdout pilots must freeze both policies and this
adapter before execution, retain every attempted/missing result, include failed
attempt/setup/compute/action costs, and report action divergences as replay targets
rather than causal gains. Do not use these boundary fixtures in policy outcome
denominators. No game process/control, executable launch, user-save access,
settings mutation, commit, reset, clean or deletion occurred in this work.
