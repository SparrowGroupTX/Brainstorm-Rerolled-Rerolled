# Lucky continuation coverage — installed 2.82, 2026-09-13

This note records a concrete remaining comparison failure found by read-only
analysis of preserved development evidence. The coherent runtime slice is installed and exact-installed regression passes. It does not authorize a source
worker, replay, seed search or complete attempt. All historical experiment
allowances remain closed.

## Observed failure

Source11, `11_dependent280_p83r`, lost at Ante2 Flint with762/1600 chips.
Every preserved step48–53 result aborted its remaining-hand comparison with:

`Random score or growth outcomes are not sampled by this continuation.`

The ordinary discard comparisons completed, but `resource_comparison` is absent.
At step48 there were four hands, three discards, zero chips and$2; the advisor
used Moon while holding Mercury. By step53 there were two hands, one discard
and384 chips. The same two ordinary Lucky cards remained drawable throughout:
`playing:16`,4 of Diamonds, and `playing:23`,Jack of Diamonds. Both had source
`ability.mult=20`, `ability.p_dollars=20`, no seal and no debuff. Neither was
currently held in these six snapshots. Future sampled hands could contain them.

The result references under
`runs/jokerless271_push_20260912_214242/source_attempts/11_dependent280_p83r/`
are `step48_result.json:11565`, `step49_result.json:11580`,
`step50_result.json:11250`, `step51_result.json:11109`,
`step52_result.json:10690`, and `step53_result.json:10502`.
Step48's drawable Lucky identities appear in `step48_snapshot.json:501` and
`:869`. Exact input/result hashes, resource counts and observed actions are in
`runs/lucky282_development/read_only_evidence.json`.

Source10's Eye steps75–77 also report this blocker with four Lucky cards in the
known population. Source12's final Big Blind has no Lucky cards and does not
report this blocker. This repair does not address every preserved loss.
All these seeds are previously inspected development data, not unseen holdouts.

## Source mechanics and provenance

Only already-preserved source files were inspected. No executable, runtime or
save was opened or executed for this analysis. The copies under
`runs/chicot_order_source1/source/` match source11's original trace header:

| File | SHA256 |
| --- | --- |
| `card.lua` | `5073d834e08119da9516f1795a8c3d93110669aeb409c29ad1b308e0eb0be453` |
| `functions/common_events.lua` | `522ea0810101de1004685e13e7ed05a750b4e115e5231dca2cbc97aeb8c3e5fc` |

Both hashes also match `chicot_order_source1/registration.json`; its rules
digest matches source11. Source11 `attempt.log:1` records these source hashes,
and the trace's SHA256 matches its preserved result record. The historical
Chicot component failed before completing any case. Its hash-matched source
bytes are source-inspection evidence, **not Lucky source-parity evidence**.

- `card.lua:983–998`: `get_chip_mult` returns zero for a debuffed card; Lucky
  checks `pseudorandom('lucky_mult') < G.GAME.probabilities.normal/5` and returns
  `ability.mult` on success.
- `card.lua:1067–1090`: `get_p_dollars` returns zero for a debuffed card, adds
  Gold-seal cash separately, and checks the distinct `lucky_money` stream against
  `normal/15` only when `ability.p_dollars>0`.
- `functions/common_events.lua:591–616`: each play evaluation invokes chip
  bonus, Mult, xMult and played dollars separately. Repeated scoring requires
  separate Lucky checks for each repetition.
- `card.lua:3076`: Lucky Cat growth uses the Lucky-trigger flag. This interaction
  is outside the no-owned-Joker sampled Lucky scope.

## Implemented bounded repair

Resolve Lucky Mult and cash in private common-world play transitions when there
are no owned Jokers. Use physical card identity, world, turn, separate channels
and scoring repetition so enumeration cannot consume different random streams
and Red-seal repetitions do not reuse a single outcome. A selected future play
must still be chosen using ordinary scoring before its private Lucky outcome
is resolved; the policy must not inspect future Lucky rolls to choose a play.

Ordinary expected scores and supported lower/upper bounds retain their existing
semantics. Sampled outcomes remain estimates, not guaranteed scores or the
original hidden RNG. Unknown mechanics, incomplete families and unsupported
Joker interactions must keep explicit fallback. Existing deterministic sampling,
140000/50000/25000 score budgets,70-score fast clears, Glass/population,
whole-inventory preservation and protected development remain required.

This is a prerequisite for complete existing resource comparisons; it is not a
general joint hand/discard/consumable planner. Source11 step48 also exposes a
larger unresolved Moon timing comparison: use now versus discard while holding
it and select conversion targets after observing the draw. Source10's Hanged
Man/Eye state has nine held cards and other specialist limits. No rescued
continuation is inferred from removing one coverage blocker.

## Validation and release

`scoring.lua` accepts complete private Lucky event rows only through detached
`after_play`; ordinary mean/floor/ceiling calls stay unchanged. `sampled_outcomes.lua`
uses separate Mult/money channels keyed by physical ID and repetition. Any owned
Joker, including a debuffed one, excludes this Lucky family. Missing/duplicate
IDs, malformed/incomplete events, negative/non-finite amounts and impossible
certain-probability outcomes fail closed. Unrelated uncertainty remains explicit.
Hook remaps event indices; exact sampled cash reaches existing cap/hand-size
transitions. Results carry `sampled_lucky=true`, `score_kind=private_sampled_lucky`
and `score_guaranteed=false`. These are conditional samples, never hidden RNG facts.

Shared `after_play` callers can consume this supported transition; their own
admission guards remain. In particular, `two_hand_finish.best_play` still rejects
an uncertain ordinary Lucky score; this release does not imply every specialist
can now finish. Search metadata names Lucky as uncalibrated Monte Carlo. No score
limit, fast-clear path, consumable policy, growth rule or retry journal changed.

New `tests/advisor_lucky_continuations.lua` passes 632 checks: independent score/
money outcomes, Red repetitions, Hook, Glass/population, cash caps/hand-size tax,
ordinary means/bounds/cache separation, identity and inventory guards, unrelated
uncertainty, complete-family fallback and deterministic comparisons. Its synthetic
three-hand case changes from rejected mean-only continuation to a complete four-
world resource comparison with 183 score calls. It proves coverage, not improved
win odds or a better captured-state action. Focused six-fixture validation passes
in `runs/lucky282_focused1`.

Candidate full regression: 114 Lua fixtures/253 Python tests,
12.985s/11.172s, unchanged frozen policy/tests.
Installed at 2026-09-13T14:29:33.6811494-05:00, backup `C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm/deployment-backups/advisor-20260913-142933`.
All51 deployment/66 frozen files match. Exact-installed full regression:
114/253, 12.969s/10.984s, unchanged hashes.
Each suite has a60s cap. Policy digest: `a11c28115e70692f5fdcbfc70ca54537a6d4a68f23fd26148fdfbf160da7fab5`.
Current settings and both native DLLs are preserved. Evidence/ledgers:
`runs/lucky282_candidate`, `runs/lucky282_installed`,
`runs/lucky282_installed_validation`, and `runs/lucky282_development`.

This turn executed zero original-source workers/components, zero captured-state
replays, zero seed searches and zero complete attempts. All historical allowances
remain closed. Source inspection used already-preserved hash-matched files;
routine synthetic fixtures use the isolated Lua library. No game executable or
save was read, no live process was controlled, and no automation was created.

No complete Jokerless win, numerical win odds or measured completion-time gain
is established. Source11 remains an audited loss. Neither281 nor282 has a
complete-attempt result. Running-game loaded version is unknown; activation
waits for the user's normal restart.
