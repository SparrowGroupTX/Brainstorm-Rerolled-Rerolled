# Repair430: both Amber Acorn unsupported stops repaired

Frozen combined2.211 candidate `e9fade65790a9e2d5c4aa7c023d9f46755f52d5b2158060a5f2a2142eb02141b` passed **301 Lua
fixtures and458 Python tests**.110 runtime dependencies and350 test files match
the exact freeze. Candidate includes the pending428 discard repair. It is not
installed; installed2.209 is unchanged. Balatro remains running; installation is deferred.

## Confirmed causes

Both reported runs reached Ante8 Amber Acorn and retired immediately after the
first hand because the public Joker ability model invalidated itself.

| Run | Cause | Advice/retirement | Resources remaining |
|---|---|---|---|
|7|Smiley Face missing from ability continuity whitelist|23370/23373|3 hands,3 discards;4,860/400,000 chips|
|8|Supernova missing from ability continuity whitelist|26046/26049|4 hands,3 discards;51,552/400,000 chips|

The initial120 possible Joker orders were intact. Public scoring observations
reduced them to18 and10 respectively. The next failure occurred in
`advance_public`, whose message was 'This Joker has unqualified changes during
public actions.' That removed the valid-ability qualification; Decision returned
no supported action and the product's existing retirement path ran. Neither
retirement was an actual terminal loss. The remaining resources do not prove
either run would have won. Full anchors are in TRACE.json and stop_trace.json;
immutable raw public events are in captures/001 and stop_events.json.

## Repair and evidence

Canonical Smiley Face and Supernova retain their public ability state across
plays/discards. Smiley's face-card coefficient is fixed; Supernova reads the
fresh public played count for the selected hand category. Neither is assigned
an identity from guessed popup amounts, and neither gets a stored score counter.
Wrong names, coefficients, effects, generic modifiers and editions are rejected
before scoring and at advancement, including debuffed/copied targets.

The new manufactured fixture passes3227 assertions: both affected mixed rows,
every24-order copied growth comparison, real score transitions, fresh category
history, malformed forms, hidden-payload traps and real observer-to-Decision
play/discard/play continuity with exactly-once settlement. The previous exact428
module reproduces both unsupported causes. Raw fixture failures/corrections and
the completed sole review are retained in targeted logs and REVIEW.md.

Latest preserved public prefix: tools/advisor_eval/development430/captures/002, 30608 verified
events; outcomes `{"loss": 2, "win": 6, "unsupported": 2}`; unended run IDs
`[]`. Preserve that distinction from game
process state. Original logs, settings, native DLLs and all7824
prior file hashes remain intact. No runtime deployment, live control, source
game execution, save/profile access or new simulation occurred in430.

## Discard counterfactual result from closed429

The independent2.209/2.210 comparison completed all302 jobs in419.3seconds,
with no worker error or timeout. On12 selected modeled rounds with two shared
hypothetical futures each, discards/round rose1.167->1.333 and cards/discard
3.000->3.094. Only one of12 rounds changed; remaining discards at clear still
averaged1.75. Eight of127 immediate paired decisions changed play->discard;
seven pairs abstained because public snapshots concealed cards. Short-discard
controls were unchanged. These results are modest and do not solve the broader
discard issue or establish a win rate. See development429/REPORT.md/RESULTS.json.
No new captured evaluation was performed on2.211;429 and every historical
experiment allowance remain permanently closed.

Next: validate loaded2.211 continuity through actual Amber Acorn encounters once
the user installs/loads it. Remaining priorities include Raised Fist/Blackboard
retained floors, larger order-dependent anchors, full-slot World/Fool replacement,
and the previously recorded full-row Blueprint admission gap. No all-fixed claim.
