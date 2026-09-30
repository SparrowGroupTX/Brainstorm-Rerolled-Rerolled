# Evidence and unresolved findings carried into the clean context

This document distinguishes installed state, observed games, manufactured tests
and historical simulations. Nothing here establishes a population win rate.
No new gameplay/simulation was executed for documentation452.

## Current release

Installed451/2.226.0-alpha matches frozen candidate1. Digest:
`b302060aff407e963955a02be6ee55f9f764aa897917be95916ac98c23555b59`.
Both full gates pass330 Lua fixtures/494 Python tests;110 runtime dependencies,
383 frozen test files.94 existing paths backed/deployed, exactly three changes:
`Advisor/two_hand_finish.lua`, `Core/Brainstorm.lua`, `steamodded_compat.lua`.
Current config and all seven DLLs preserved. Backup:
`C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm\deployment-backups\advisor-20260929-093743`.

Receipts: `INSTALLED_CHECKPOINT_451.json`, `runs/repair451_candidate1/freeze.json`,
candidate/installed `validation/report.json`, `runs/repair451_installed/record.json`,
`development451/install/INSTALLED_VERIFICATION.json`. Candidate/source/tests and
installed hashes are independently checked. The last passive release process
check found no Balatro process; that is historical, not the next chat's fresh check.
2.226 activation was not observed. Do not claim it from installation alone.

451 fixes a no-discard two-hand Planet planning omission. Its307 new assertions
cover exact manufactured Flint arithmetic, complete paired worlds, better hold
alternative, last-source cost, Negative/Observatory, copied Perkeo/Yorick,
visibility/budget failures, Glass and actual Decision arbitration. The old module
declines the invented zero-discard case. It does not prove a historical rescue,
global optimum, all unused-discard fixes or general whole-inventory planning.

## Latest public journals

| Capture | What is established |
|---|---|
| `development451/install/captures/001` | Latest preserved session `session-20260929T053217Z-1`, loaded2.225;22 segments,60,585,325 bytes,23,010 events;8 starts/7 terminal endings:5 wins,2 losses,1 unended run;0 archive errors |
| `development451/captures/001` | Earlier prefix of SAME session, not additional games:8 segments,19,842,365 bytes,7,539 events;3 starts,2 wins,1 unended;0 errors |
| `development450/captures/001` | Previous complete session `session-20260929T022428Z-1`, loaded2.224;28 segments,71,649,259 bytes,26,655 events;10 starts/10 endings:7 wins,3 losses;0 unended/0 errors |

Each capture includes immutable `.brj` segment copies, `manifest.json`, verified
`summary.json` and a bound `events.sqlite3`. Exclude duplicate prefixes when
building datasets. An unended run is not a loss, win or automatically normal exit.
The latest8-start session has not received a full deep strategy review; the install
turn preserved and verified it, not analyzed every decision. Later public journals
may exist; check passively only when relevant and preserve before use/release.

## Last fully analyzed cohort:450

Report and exact witnesses: `development450/REPORT.md`, `METRICS.json`,
`TRACE.json`, `TERMINAL_TOTALS.json`, `UNUSED_CLEAR_TRACE.json`, `ALL_FLAGS.json`.

478 confirmed discards removed2,066 cards:4.322 cards/use.167 qualified rounds
with positive initial discards:158 three-discard rounds averaged11.8354 cards
against the user's12 target;9 four-discard rounds averaged17.6667 against16.
15 clears left41 discards. These are selected development data, not causal proof
of improvement versus a different release's cohort.

All seven observed Blueprint/Brainstorm offers were acquired.38 Buffoon offers,
29 opens;12 Death requests (10 pack/2 owned), not proof every sequence optimal.
The180 screener flags include163 short discards,15 unused clears and2 pack-score
conflicts. The latter chose Burnt over Green and Blueprint over Blue Joker; weaker
opening score alone does not establish a strategically inferior choice.

Authoritative terminal totals come from final joined observations, not a
pre-action `last_hand` snapshot:

| Run | Loss | Final chips/target | Unused discards |
|---|---|---:|---:|
|4|Ante2 Wheel|1,740/2,000|0|
|5|Ante2 Flint|1,998/2,000|0|
|6|Ante1 Big|388/450|0|

Run5 request12152 retained the last Negative Uranus with two hands/zero discards,
729 chips accumulated; chosen Two Pair scored702, later Pair567. Immediate
post-Uranus arithmetic would be792, not1,056, because Flint rounding matters.
451 addresses the supported comparison gap, without executing this captured
state or proving it would rescue the run.

Run4 passed a$4 Buffoon with$5 after buying Hierophant; leave-shop11141 still
reported at-risk sampled worlds. This is a reserve/survival hypothesis; unseen
pack contents cannot prove a rescue. Run6 had Perkeo/unscaled Yorick and used
three discards/11 cards before its early loss, not an unused-discard failure.

450's installed2.225 change added Steel-preserving discard candidates, preserving
the six-item shortlist/twelve-score budget and actual retained-resource proof.
It helps demonstrated manufactured families; it is not global maximum search.
Other unused-clear classes include Juggler/Bootstraps order/admission, conditional
held effects, Ancient/Idol, exhausted budgets, changing bosses and large Acorn
families. Do not repeatedly "fix"450 or assume all these classes are closed.

## Previous learning experiment355

Evidence remains in `development355/`: `CLOSED.json`, `FINAL_POLICY_SELECTION.json`,
`SIMULATOR_FIDELITY_AUDIT.md`, `SPECIALIZED_POSTMORTEM.md`, `SPARSE_REWARD_NEXT.md`,
`jobs/T02/summary.json`, `jobs/V02/analysis.json`, `jobs/V03/analysis.json`.

T02 recorded127,744 transitions/6,986 starts:6,859 losses,119 unsupported,8 censored,
no wins or positive terminal sticker examples. It used an approximately5.6M-
parameter model on an RTX5090 and a historical distinct-new-Gold objective, not
today's win-first target. The V02 learned policy sold both anchors in32/32 starts
and spent1,564/2,177 decisions reordering. V02 and held-out V03 each evaluated32
learned attempts plus32 weak-heuristic attempts, with zero wins in every cohort.
Do not interpret censored/unsupported cases as actual losses or this simulator
evaluation as loaded-game results.

The selected checkpoint was rejected and is not deployed. All355 jobs/unused
capacity are closed. Its simulator was explicitly unqualified; failure does not
prove neural learning or PPO cannot work. It does show that more identical
training, faster kernels or a bigger model alone does not address the observed
data, objective, exploration and fidelity failures.

## Known simulator gaps supported by current source

The Python overlay fixes Burnt/Perkeo copies, sticker compatibility/exclusion and
an expired-debuff latch. It still censors near-expiry Perishables, debuffed passive
effects and Mime held-card repetitions. Source audit shows interleaved round-end
callback/rental/expiry order differs from grouped processing, and cash-out bonuses
can be computed before the correct debuff point. The Lua continuation adapter
does not model round rewards or the full shop cycle. None of the existing local
fixtures establishes complete RNG/seed/whole-game equivalence.

The teacher converter produces structured public data, marks labels unreviewed,
and does not reconstruct a training candidate set. The old trainer uses its own
heuristic labels and numeric simulator features. Therefore current logs are useful
raw material, not a plug-and-play expert dataset.

## Claim vocabulary

An observed win is one recorded game outcome. A suspect flag is a hypothesis.
A manufactured fixture proves its stated artificial case. A source callback
comparison qualifies its declared callback/context, not all intervening gameplay.
A sampled continuation estimates only its declared world/family/horizon. A frozen
gate verifies tested bytes, not strategy optimality. A successful installation is
not activation. Preserve these distinctions in both reports and training labels.
