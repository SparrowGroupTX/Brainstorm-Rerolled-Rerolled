# Experimental original-engine adapter

This is an engineering pilot, not qualified win-rate evidence. It runs the installed
game's original Lua rules in its bundled LuaJIT library without starting the game,
creating a window, using the GPU, or reading/writing the user's saves.

## Evidence on 2026-09-10

- All 20 original challenges initialized and dealt an opening blind successfully.
  The sequential smoke sweep took 3.8 seconds including Python process startup.
  A subsequent instrumented Jokerless opening took 0.102 seconds in the host.
- One distinct full episode, Omelette / `ADVISOR1`, followed the shared runtime
  `decision.run` policy through 34 actions, including its initial blind choice.
  It completed three blinds (Small, Big, Hook) and three shops, then lost at
  Ante 2, round 4. Nine deterministic hand predictions matched engine chips.
- The actual engine executed discards, plays, cashouts, Egg growth/sales ($5 then
  $8), booster generation/opening, Crazy Joker pack selection, Telescope redemption,
  Joker purchases, leaving shops, and selecting subsequent blinds.
- The early-loss pilot completed in under a minute, but its exact duration was
  not instrumented. Future runs now emit elapsed seconds. A reliable full-campaign
  duration cannot be extrapolated from one early loss; winning runs are longer.
- Logs: `engine_probe_openings.jsonl` and `engine_probe_pilot.log`. The latter
  retains the exact source, adapter, and policy digests used for that pilot.
  Later changes to logging/timing produce a different current adapter digest.

## Reproduce

```powershell
python tools/advisor_eval/engine_probe_sweep.py
python tools/advisor_eval/engine_probe.py --episode --challenge c_omelette_1 --seed ADVISOR1
python tools/advisor_eval/engine_probe.py --episode --policy-root PATH_TO_FROZEN_POLICY --challenge c_omelette_1 --seed ADVISOR1
```

`--install` can point to another local Balatro installation. The host reads Lua
directly from `Balatro.exe` as a ZIP and uses `lua51.dll` through Python ctypes.
No game source is copied into this repository, and no downloads are required.
The policy receives ordinary detached public snapshots. Episode seeds are used
only by the engine; decision search uses exactly the runtime default options.

The wrapper emits JSON provenance, actions, resolved state changes, and terminal
results alongside diagnostic text. Errors stop the episode; there is no arbitrary
action fallback. The module loader only uses in-memory preloaded modules, graphics
APIs are explicitly limited to dimensions/metadata, and save APIs use private Lua
tables. Original Card, CardArea, Blind, EventManager, rules, shop/pack definitions,
and action legality callbacks remain active. The source UI trees are preserved
because they create gameplay areas and schedule cashout amounts.

## Remaining qualification blockers

1. The synthetic fresh profile uses source-default unlock/discovery flags, which
   may differ from the user's profile. Its fingerprint is
   `59a012422935e88481fa9fccd940d903e20aeb9f2c456f80fb28a2f4a57d7ddc`.
   Every run explicitly marks this profile `qualification_compatible: false`.
2. All challenges have opening coverage, but only Omelette has a terminal pilot.
   Consumable dispatch exists but inventory use, all pack types, all bosses,
   challenge-specific later triggers, and the winning terminal path need execution
   and parity coverage. Unknown required APIs fail with `HEADLESS_BOUNDARY`.
3. Terminal loss uses actual `GAME_OVER`; victory uses the original `win_game`
   mutation of in-memory challenge completion, with loss taking precedence.
   `G.GAME.won` alone is deliberately insufficient: the source can set it before
   checking whether the Ante 8 boss was lost. Victory overlays remain untested.
4. Rendering metadata and selected presentation effects are replaced explicitly.
   The reduced update driver follows source event/phase order, but broader parity
   review must establish that omitted presentation updates never affect gameplay.
5. The pilot exposed a policy weakness: after buying Banner, the advisor spent all
   discards on the next blind and lost its conditional chip bonus. That finding is
   a runtime policy issue, not evidence of a passing challenge success rate.
6. No registered held-out campaign has run, no adapter validation attestation has
   been issued, and neither the 50% nor the 75% per-challenge target is established.
   One loss on one distinct seed is not a useful win-rate estimate.

## Deterministic development follow-up

The debug baseline repeated Omelette `ADVISOR1` in 17.066 seconds. Detached
snapshots and all action alternatives for its three-discard chain are retained
in `engine_probe_resource_snapshots.json`; full trace is `engine_probe_resource.log`.
The wrapper now supports `--debug-decisions`, recorded-prefix `--replay-trace`
plus `--override` JSON (`{"step":28,"action":{...}}`), and intentional boundaries
`--stop-after-step` / `--stop-on-round-end`. Replay requires matching seed,
challenge, engine hash and runtime hash, and explicitly marks
`followed_advice: false`. These experiments are never campaign results.

Two additional sequential Omelette development seeds exposed missing targets
in pack advice: `ADVISOR2` selected Medium without a target (4.072 seconds), and
`ADVISOR3` selected Death without targets (13.223 seconds). Both correctly stopped
on original game legality rejection. After the strategy fix, both pilots passed
their old boundaries and reached Ante 4 before their separate 45-second caps
(65 and 77 actions respectively). Neither timed pilot produced a terminal result.
The old and revised traces remain in `engine_probe_development_ADVISOR*.log`.

The adapter also needed original `CardArea:align_cards()` calls after each update:
normal gameplay invokes them through `CardArea:move`, and Death uses physical
`Card.T.x` to determine the rightmost target. Merely updating the logical hand
array can give the wrong copy direction. Both bootstrap and episode driver now
run the original alignment function. The 45-second target-fix pilots predate this
adapter correction and demonstrate legality/execution, not directional parity.
With the correction, a bounded original-engine replay of `ADVISOR3` through
action 34 verified Death targets `[5,7]`: the left card (`playing:45`) copied the
right card's (`playing:43`) Five of Spades, center/enhancement, edition, seal and
permanent bonus. Coordinates were checked before use and copied fields afterward.
This fixture took 16.586 seconds and emitted `engine_episode_effect_verified` in
`engine_probe_death.log`.

Resource counterfactuals on the old `ADVISOR1` prefix were informative but narrow:
replacing the first discard with its two-card 244-chip play, or the final discard
with its four-card 152-chip play, each cleared the previously lost Ante 2 Small
Blind. Both later hit the then-unfixed Justice target omission. Those paths still
spent all remaining discards, so they do not prove a general resource-saving rule.
The revised bounded continuation policy was then checked with a new adapter:
replacing action 28 with its padded play `[1,2,3,6,8]` scored exactly 244, and the
shared policy continued to clear that 800-chip blind with 1,649 chips, one hand and
one discard remaining. The run intentionally stopped at round 4 completion after
23.751 seconds (`engine_probe_continuation.log`). This is a regression example,
not a success-rate estimate or held-out evidence.

Manual `reorder_jokers` and `reorder_hand` actions accept a complete 1-based
`action.order` permutation. The driver checks the settled phase, card identity,
draggability and pinned positions, preserves the original card objects, and runs
original layout/rank updates. Separate bounded reorder probes verify the returned
order by exact object identity. Illegal actions and deterministic score mismatches
now emit detached forensic snapshots before failing.

## Single v2.13 development run: ADVISOR4

Command: `python tools/advisor_eval/engine_probe_development.py --seeds ADVISOR4 --timeout 150 --label v213`.
Exactly one episode was attempted. It stopped after 9.132 seconds of host time
(9.229 seconds including the helper) with 17 resolved actions, before deciding the
first hand of Ante 1 Big Blind / round 2. The adapter reported
`HEADLESS_BOUNDARY advisor returned no machine action: hand nil`; no terminal
win/loss or deterministic score mismatch occurred. The two completed plays scored
260 and 60, matching the advisor exactly.

The main counterexample is unsupported large hands. Action 13 purchased Turtle
Bean; the original game gives it `h_size = 5` and immediately adds that amount to
the hand size. After this purchase the normal eight-card hand becomes thirteen
cards, while `Advisor/search.lua` explicitly returns without a playable action
for more than twelve held cards. The trace does not dump that final snapshot, so
the thirteen-card count is derived from the recorded purchase and original rule
code. This is an advisor coverage failure caused by a legal recommended purchase,
not evidence that the run was lost or that Turtle Bean was a bad game purchase.

Trace: `engine_probe_development_ADVISOR4_v213.log`.
Policy digest: `2c872c8690ec1c9327f4de6edf4add14db6953502a14d3f9873c4f368cdfb31d`.
Adapter digest: `7eaa7a863a66e3a47f7b667c7aa21d6672136c9b397460fc139519484275ce86`.
The policy modules were loaded once into that process, and the existing synthetic
profile remained isolated. No engine or runtime code was changed for this test;
no further episode was started. This single blocked attempt supplies a concrete
regression case and cannot establish a challenge win rate.

## Bounded v2.14 Turtle Bean regression: ADVISOR4

Exactly one source-engine check ran with `--episode --challenge c_omelette_1
--seed ADVISOR4 --stop-after-step 20`, in a hidden subprocess with a 150-second
hard timeout. It finished in 9.741 seconds of host time (9.831 including the
wrapper). Turtle Bean was purchased at action 13 as before. Action 18 now
selected `[4,6,8,9,12]`, scored exactly the predicted 640 chips, and cleared
Ante 1 Big Blind with three hands and three discards left. The adapter proceeded
through cashout and action 20 in the next shop, then stopped intentionally with
`development_action_limit`. There were no source-boundary errors or deterministic
score mismatches; all three plays matched predictions (260, 60, and 640 chips).

This passes the old no-action boundary. The thirteen-card hand size follows from
the recorded Turtle Bean purchase and its original +5 rule; this run did not
enable snapshot logging, so the count is not an independently dumped observation.
Detached regression fixtures additionally enumerate all 2,379 one-to-five-card
subsets of an explicit thirteen-card state, including a winning card at index 13.
The policy still used the isolated synthetic profile. This deliberately limited
check is neither a completed episode nor evidence of a full-run win rate.

Trace: `engine_probe_v214_ADVISOR4.log`.
Policy digest: `c4ef82cf1f5ac9f981073ef795a644d12f00dad6280a47d9a9246da2324247e6`.
Adapter digest: `5399b548a56d7c6d7bab72ca6c9b0428a4ec388af685075ffa5eafda6c9b9d32`.
No additional run was started.

## Bounded v2.15 integration probe: ADVISOR5

Exactly one hidden subprocess ran `engine_probe.py --episode --challenge
c_omelette_1 --seed ADVISOR5 --stop-after-step 30 --debug-decisions`, using
`CREATE_NO_WINDOW` and a hard 60-second timeout. Policy modules were read once
and retained in that process. It exited successfully after 16.514 seconds of
host time (16.640 including the wrapper), with all 30 actions resolved, and
intentionally stopped at `development_action_limit` in the Ante 2 shop after
buying Paint Brush. No source-boundary error or score mismatch occurred. All
five deterministic plays matched exactly: 124, 15, 252, 2,163, and 2,052 chips.

The trace confirms shared shop-scoring integration: `shop_diagnostics` appeared
on all 14 shop decisions. Four performed nonzero work: steps 9/10/29/30 used
9,592/8,720/6,976/3,488 evaluations, respectively; all reported `truncated=false`.
The policy executed normal blind selection, discards, plays, cashouts, Egg sales,
Joker/consumable/voucher purchases, a Buffoon pack choice, and one Pluto use.
This bounded path did not exercise a two-consumable sequence. No further episode,
tuning, game window, GPU work, save access, or installation was performed.

Trace: `engine_probe_v215_ADVISOR5.log` (2,826,216 bytes including detached
decision snapshots). Policy digest:
`5accba7d178cef9d0e0e5402a6abd7c6b29910658ae9b7013b48709ab7ca9de0`.
Adapter digest: `e8db905e2c38124bce01c9ab505497ea925f31ceaa21f951e1ed293fb53802ad`.
The synthetic default unlock-profile digest remains
`59a012422935e88481fa9fccd940d903e20aeb9f2c456f80fb28a2f4a57d7ddc`, explicitly
`qualification_compatible=false`. The intentional stop is neither a terminal
win/loss nor evidence of a full-run success rate, and does not qualify a later
policy digest if code changed after this process loaded its modules.

## Bounded v2.16 integration probe: ADVISOR6

One hidden subprocess ran the ordinary Omelette start with `--seed ADVISOR6
--stop-after-step 20`, hard timeout 55 seconds, and the development policy
including the new ordering/boss modules and paid-reroll wiring. It resolved all
20 actions and stopped intentionally in a Celestial pack after the Big Blind.
Host-reported source probe time was 19.87 seconds (19.966 with the wrapper).
The four deterministic play scores were 16, 280, 15 and 724, with no mismatch
or engine-boundary error. Source/profile construction remains synthetic and
`qualification_compatible=false`; no terminal result is claimed. No game
window or user save was accessed. Later final-review edits have a different
policy digest from this retained development trace.

Trace: `engine_probe_v216_ADVISOR6.log`. Separately,
`Immolate/tests/source_challenge_opening_probe.py` verifies the current opening
module and first-pack hook against actual challenge initialization, Card/Soul
generation/use, and Omelette Egg sales. All nineteen supported challenges,
Jokerless rejection and vanilla duplicate suppression passed (21 cases,
1.114 seconds); this verifies opening mechanics only.
