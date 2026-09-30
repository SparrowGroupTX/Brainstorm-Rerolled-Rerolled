# Earlier build evidence from frozen 2.46 — 2026-09-10

This first stage was tooling and diagnostic evidence only. Subsequent
REROLL_MAGNITUDE_247.md records resulting runtime module work; the parent task
owns its integrated release. No default coefficients changed. Original source
was read as ZIP and executed only through isolated
lua51.dll in hidden bounded workers; no game process, window or save was touched.

The selected ordinary Golden Needle trace is
`runs/development246_selected_episode/episode.log`, policy digest
`8dfb1955a4ced9491eaba8bdc0960b3edb66076bd888cb27d758f8946beee102`, adapter digest
`7a4088eaa1ec6002c2153a30a1762508a2074fe1526ccbd966f24c3151056013`.
It remains a development seed using a synthetic source-default unlock profile.

## Actual earlier offers and decisions

`runs/roi247_checkpoint{5,7,12,13}/decision_report.json` preserve complete source-
verified observations/results for four earlier decisions, each recomputed by
two identical frozen policies. All eight requests matched their checkpoints and
were deliberately censored before applying the boundary. They are observation
and replay-parity evidence, not calibrated candidates or wins.

| Step | Cash | Actual visible offers | Frozen 2.46 decision |
|---|---:|---|---|
| 5 | $13 | Mercury $3, Runner $5, Planet Merchant $10, Buffoon $4, Arcana $4 | Open Buffoon |
| 7 | $9 | Mercury $3, Runner $5, Planet Merchant $10, Arcana $4; Devious now owned | Leave shop |
| 12 | $13 | Square $4, Spare Trousers $6, Planet Merchant $10, Standard $4, Arcana $4 | Buy Trousers |
| 13 | $7 | Square $4, Planet Merchant $10, Standard $4, Arcana $4 | Buy Square |

At step 7 the existing Devious rewards Straights, and the actual Runner offers
matching growth before multiple remaining blinds. At steps 12/13, four opening
samples produce only one clear against the upcoming 600-chip Boss. Readiness is
`unresolved`, which currently preserves generic growth value. Square raises the
sampled mean only 263 to 273; the strongest 656-chip opening remains a five-card
Straight and cannot trigger Square's four-card growth. This is a concrete gap in
opportunity-aware growth, not proof that every unresolved build should reject
investment. Four opening samples are not a win probability or a finishing plan.

## Registered visible-action interventions

New `action_replay.py` freezes identical source policies, the current adapter,
the producing source trace, one explicit shop action and its hypothesis. It
replays the earlier prefix without repeated advisor work, retaining source-state
fingerprints, source legality, score/resolved-effect checks and provenance. The
selected card's actual identity at the matched checkpoint is audited. It saves
the workflow and refuses changed manifests, inputs, override, workflow, trace
or execution arguments. This is an action intervention, not a general policy.

Both hypotheses were saved before either candidate ran:
`ROI247_RUNNER_INTERVENTION.json` and `ROI247_REROLL_INTERVENTION.json`. Each pair
used a 40-second per-attempt hard cap and 90-second pair wall budget. Both pairs
were run concurrently, so their CPU timings should not be compared as a clean
latency benchmark. Each audit still records full elapsed attempt cost.

| Intervention | Baseline continuation | Intervention continuation |
|---|---|---|
| Buy actual Runner at step 7 for $5 | Loss at Ante 2 Small, 608 short; 30 actions, 37.185s | **Timeout**, 40.032s; 44 actions resolved, Ante 3 Small cleared, computing shop decision 45 |
| Pay for one reroll at step 12 for $5 | Same loss, 30 actions, 34.625s | **Timeout**, 40.026s; 69 actions resolved, reached Ante 4 Boss/Arm, computing hand decision 70 |

Artifacts: `runs/roi247_runner_intervention/action_report.json` and
`runs/roi247_reroll_intervention/action_report.json`; both passed re-audit.
The Runner survives with +60 Chips by the observed Ante 3 Small entry. Its
continuation buys Trousers, skips Square and later buys Raised Fist. The reroll
actually reveals Misprint and Banner; the unchanged policy buys both, respects
the Credit Card debt boundary and proceeds through several immediate clears.
Later it buys Wily and Abstract and sells Credit Card; all actions and effects
remain in the trace. Neither path assumes an unseen specific offer beforehand.

These two interventions avoid the selected baseline's immediate failure, but
**neither finishes the challenge within its registered budget**. They remain
timeouts, never wins or losses. No observed terminal win-rate improvement,
preferred general reroll policy, or revised numerical forecast follows. The
meaningful next runtime work is retained, trigger-compatible growth and scoring-
deficit-aware reroll upgrade magnitude with search/cash costs included.

## Why no coefficient candidate was fitted

The three exposed coefficients are `growth_action_cost`, `growth_utility_scale`
and `discard_action_penalty`. The first two govern specialized in-hand growth;
the third governs a redraw-versus-play margin. None enters visible shop build
valuation. The selected challenge has one playable hand, and its final-hand
discard branch bypasses that ordinary margin. Registering these values at the
captured shop checkpoints would not test a meaningful action-sensitive weight.

No coefficient candidate, default change or held-out policy promotion was made.
A holdout cannot validate a generalized improvement before such a policy exists.
This result directs implementation to missing opportunity/upgrade logic rather
than claiming progress from an inert grid or another opening-prefix screen.

## Independent source profile gate audit

`unlock_profile_source_audit.py/.lua` reads original prototypes and executes the
original `get_current_pool` callback in a separate DLL fixture with synthetic
minimal state. `runs/roi247_unlock_profile_audit/report.json` freezes source,
runtime, harness, workflow and runner hashes; 12 comparisons pass in 0.090s.

The original source has 150 Joker prototypes: 105 default unlocked and 45 locked.
Of the locked set, five are Legendaries whose rarity-4 pool bypasses the unlock
gate; 40 ordinary Jokers remain affected. Challenge mode does **not** bypass the
normal Joker unlock gate. Tag discovery prerequisites, voucher prerequisites,
already-owned bans and Planet softlocks also alter actual pools as checked.

This independently confirms why a synthetic fresh profile is a material start-
distribution limitation. It does not infer the user's unlock state, establish
equivalence to that state, or qualify the whole source episode adapter. No user
save was read. A declared and independently validated evaluation profile remains
necessary before making measured per-challenge population claims.

## Validation

Six new action-intervention admission/command unit tests pass. Both retained
action reports pass their manifest/input/trace/provenance re-audit, four earlier
checkpoints each match, and 12 independent source-pool gate comparisons pass.
All two losses, two timeouts and eight intentional checkpoint censors remain
explicit. No installed file or runtime release is needed for this tooling work.

Example:

```powershell
python tools/advisor_eval/action_replay.py --source-trace tools/advisor_eval/runs/development246_selected_episode/episode.log --source-policy-root tools/advisor_eval/runs/development246_selected_episode/policy --intervention tools/advisor_eval/ROI247_RUNNER_INTERVENTION.json --output-dir <fresh-directory> --timeout 40 --wall-budget 90 --execute
python tools/advisor_eval/action_replay.py --audit <existing-intervention-directory>
```
