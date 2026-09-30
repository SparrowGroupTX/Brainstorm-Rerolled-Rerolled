# Verified replay and decision comparison — continuation through 2.46

Tooling only; root owns runtime releases. No live game process/window, saves,
settings, or installed files were touched by this work.

`engine_probe.py` now admits only fingerprinted, complete ordinary source prefixes
whose rules, runtime, adapter, frozen producing policy, and synthetic profile
match. Candidate policy identity is recorded separately. `engine_run.lua` bypasses
`decision.run` only for the verified prefix and reports `advisor_skipped=true`,
zero advisor time, and no invented result/evaluation diagnostics. Actual replay
verification scoring is separate from advisor scoring work. Source legality and
score checks remain active. All offered pack cards are recorded even when the
advisor is skipped; fresh decisions retain full pack comparison diagnostics.

The fingerprint uses detached source observations plus original source state,
RNG, pool flags, used Jokers, round/reset resources and win state. Before/after
hashes and cash/chips/hand/discard effects must match. The source producer's frozen
snapshot module is loaded separately for canonical fingerprints, while the
candidate's own snapshot supplies its decision. This mattered when 2.45 corrected
the next-blind observation; a changed observation should neither silently bypass
state verification nor prevent a source-identical counterfactual comparison.

`decision_replay.py` freezes both products and the adapter in a fresh directory,
retains the source trace, and registers a specific recorded decision. Default
execution stops after comparing the decision before applying it. Full bounded
continuation is optional. Saved results can be re-audited. Counterfactual prefixes
are explicitly excluded from ordinary paired episode/qualification evidence.
`engine_probe.py` also supports shop/pack/growth/reroll decision cutoffs and an
occurrence index, so three opening actions need not be used as calibration data.

New unit coverage: 11 replay/admission/audit tests, including provenance/product
mutation, duplicate or incomplete actions, missing predictions/fingerprints,
counterfactual-source rejection, immutable registration and explicit missing
requests. Existing Python tooling tests passed alongside these additions.

## Preserved source evidence

All paths below start at `tools/advisor_eval/runs/`. The first source freeze uses
the pre-canonical-snapshot adapter; the later source freeze includes that fix.
They are deliberately separate registrations, never overwritten.

- `verified_replay243_source/source_record.json`: frozen 2.42 ordinary Golden
  Needle / ADVISORCOVERAGE332, 31 actions, same Ante 2 loss, 42.714 seconds.
- `verified_replay243_source/full_replay_record.json`: same frozen policy and
  adapter, first 21 actions replayed and checked, fresh continuation at step 22;
  same 31 actions and same loss, 25.003 seconds. This is counterfactual replay
  throughput, not improved time to win or a general advisor speedup.
- `verified_replay243_source/evaluated_prefix_record.json`: the diagnostic
  comparator recomputed all 21 earlier advisor decisions, matched every action
  and source invariant, and reached the step-22 checkpoint in 17.182 seconds.
  `verified_replay243_shop/decision_report.json` reaches that same checkpoint
  with skipped advisor work in 2.844 and 1.966 seconds. Selected CPU timings,
  including concurrent workloads, do not establish a broad latency distribution.
- `verified_replay243_rejections/report.json`: four intentional corruption
  probes reject a wrong pre-state hash, wrong post-state hash, changed score
  prediction, and illegal selected index. Error/unsupported traces remain saved.
- `verified_replay243_pack_candidate/decision_report.json`: actual offers were
  Baseball Card and Devious; 2.42 and 2.43 both choose Devious. This closes the
  previously missing rejected-offer evidence. It does not show that this pack
  contained a better alternative.
- `verified_replay243_shop_candidate/decision_report.json`: 2.43 changes the
  step-22 Delayed Gratification purchase to leaving the shop. Its diagnostic
  wrongly observed the next Big blind at 1,200. This exposed the runtime snapshot
  issue corrected and installed separately by root in 2.45.
- `verified_replay244_source/source_record.json`: fresh adapter with canonical
  source snapshot loading; frozen 2.42 source through 22 actions, censored at the
  registered limit, 14.864 seconds.
- `verified_replay245_pack_candidate/decision_report.json`: source-identical
  2.42/2.45 checkpoint at step 6, same Devious choice, all actual offers retained;
  2.45 correctly observes the next Big blind at 450. Both are censored before
  applying the checkpoint action.
- `verified_replay245_shop_candidate/decision_report.json`: source-identical
  checkpoint at step 22; baseline buys Delayed Gratification, 2.45 leaves the
  shop with its cash. Candidate now correctly observes Ante 2 Small at 800,
  rather than 1,200. Its 696 capacity proxy remains a sampled warning, never a
  global score bound. Both are censored checkpoint comparisons.
- `verified_replay245_holdout/report.json`: fresh pre-registered ordinary seed
  REPLAY245HOLDOUT1, Golden Needle, baseline 2.42 and candidate 2.45. Both lose
  Ante 1 Small by 12 chips after identical eight actions (six discards, then the
  final play); 12.503 and 13.484 seconds. Both terminal records pass provenance
  audits. This unseen seed never reaches shop/pack decisions; it supplies an
  unchanged-hand-policy check, not evidence for the new shop behavior.
- `verified_replay245_shop_continuation/decision_report.json`: complete bounded
  counterfactual continuations from the verified step-22 state. Baseline 2.42
  buys Delayed Gratification, then loses Ante 2 Small by 608 chips after 31 total
  actions, ending at -$6 (25.366 seconds). Candidate 2.45 leaves the shop, saves
  $4 and one purchase action, then takes the identical six discards and final
  play; it loses by the same 608 chips after 30 actions, ending at -$2 (19.720
  seconds). Both finish within their registered 35-second per-attempt cap and
  pass provenance/prefix audits. Saving the money did **not** rescue this run.
  The latency difference is one selected counterfactual pair, not a population
  performance claim or improved win probability.
- `development246_selected_episode/report.json`: final single ordinary episode
  from the beginning, frozen 2.46 / ADVISORCOVERAGE332, fresh frozen adapter and
  policy, 45-second hard cap. It completes in 34.410 seconds with 30 actions and
  the same Ante 2 Small loss, 608 chips short, ending at -$2. The first 21 actions
  match the recorded 2.42 source; the first divergence is saving instead of buying
  Delayed Gratification at step 22. Earlier pack/shop changes therefore do not
  rescue this selected episode. Policy digest:
  `8dfb1955a4ced9491eaba8bdc0960b3edb66076bd888cb27d758f8946beee102`;
  adapter digest:
  `7a4088eaa1ec6002c2153a30a1762508a2074fe1526ccbd966f24c3151056013`.
  `manifest.json` freezes the single request and full product/adapter/rules/runtime
  provenance; this final attempt uses ordinary starts, not a replay prefix.

These meaningful action comparisons do not establish a calibrated coefficient
improvement. Defaults remain unchanged, and no measured per-challenge win-rate
or all-20 time-to-completion claim follows. The source adapter still uses the
explicit synthetic unlock profile.
