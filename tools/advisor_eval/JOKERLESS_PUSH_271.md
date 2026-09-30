# Jokerless source push — 2026-09-12

The prospective authorization is
`runs/jokerless271_push_20260912_214242/authorization.json`. It is immutable;
closeout belongs in a separate ledger. This agent has at most twelve 180-second
complete-attempt leases (2160 seconds reserved) and twelve 15-second mechanical
source leases (180 seconds reserved), ending before 23:35 UTC. All historical
allowances remain closed. No source retry/restore adapter is authorized.

## Current source evidence

`source_attempts/01_clean270` registered a cryptographically generated unseen
request, seed `7JSNBBW4`, frozen installed270 policy
`bfd867f36693b720026332674253a47380d1f5a18cbad594534609e748eec47b`, adapter
`c38107e749df5e4d4e42f07de012cbc6236edff19b28b0723f566b6b08b95712`, explicit
`all_unlocked_discovered_v1`, empty disabled retry context and no opening hook.
Its registration is
`5c7d1cf7d2b9442d28886d4e12a49898f9a460bd9fd50af8ac11a66f724c9150`.

The worker spent **42.2766877 seconds**. Its strict outcome is **ERROR /
malformed_trace**, not an audited loss: full debug output exposed existing
`routing_diagnostics.minimum_capacity=inf`, emitted as invalid JSON. The raw
source separately reached **game-over at Ante2, The Goad, step61,723/1600chips,
$1,0hands,0discards**. This terminal observation and all invalid records remain
unchanged. The later discovered UI cleanup defect also invalidates its later
pool trajectory. This attempt is spent and must not be replayed as a fresh run.

Valid detached development decisions still locate bounded weaknesses without
claiming a rescue. At step50, $5 could fund revealed Jupiter($3), while the policy
opened unknown Arcana($4). At step51 it made QueenSpades Steel before the known
Goad, despite another QueenHearts target. The chosen target's paired opening
score remained254.25. `step50_snapshot.json` and `step50_result.json` preserve the
valid public source decision for component investigation. They do not establish
that a different pack purchase, target, or hand policy would have won.

## Adapter corrections and original-source evidence

`engine_run.lua` formerly represented UI elements as Moveables. Removing their
box recursively removed Moveables but never ran the original
`UIElement:remove` treatment of `config.object`. Those objects include shop and
pack CardAreas. Unchosen/unbought cards remained in the original `G.I.CARD` and
`GAME.used_jokers` population, eventually exhausting ordinary Planet eligibility
and causing repeated Pluto fallback. Baseline snapshots directly show previously
unselected Planet keys accumulating across shops/packs.

The adapter now loads original `engine/ui.lua` method definitions, attaches the
original `UIElement.remove` to its detached display nodes, calls original
`UIBox.remove`, and registers boxes under their original instance type. Original
CardArea/Card cleanup therefore owns card removal and duplicate exclusions.
No source scoring, RNG, costs, unlocks, challenge rules or outcomes are replaced.
Prior traces and outcome labels are never rewritten after this correction.

- `source_probes/01_ui_object_lifecycle`: one15s lease, **ERROR**,0.3432966s.
  The first implementation found that the old adapter had never loaded the
  original UIElement class. No lifecycle assertions ran; this error remains spent.
- `source_probes/02_ui_source_methods`: distinct corrected-adapter fixture,
  one15s lease, **passed**,0.3411070s. It reproduces the legacy object/pool leak,
  removes two original offered cards (56->54), restores Saturn eligibility,
  preserves an owned Mercury and its duplicate exclusion, and conserves all52
  playing cards. It deliberately stops as a censored mechanics fixture, never
  an episode win. Frozen provenance/profile/receipt/trace reaudit passes.
  Registration:
  `e022ce12b428ded5bb3ae396bc9f34732ddc5150a75c513517458794397ec371`.
  Trace:
  `337da9010f441c090ebafbc64294f3daf33d7792ee82d0e26c1ad41462943810`.

Diagnostic nonfinite numbers now remain explicit tagged JSON objects, never
zero/null or fabricated finite outcomes. Full debug projection replaces only
large internal readiness `observation_key` strings with declared byte counts and
SHA256 hashes. Actions, public snapshots, source fingerprints, compared sample
outcomes and resource evidence are retained. This removes repeated cache payloads
without affecting policy decisions. `trace_unit1` passes40 existing contract and
16new trace checks in0.0957354s. These are isolated Lua unit tests, not source workers.

## Selected opening protocol

`jokerless_push.py` freezes one actual request at a time, with product, adapter,
auditor, original executable/runtime, profile, options, authorization and one-use
execution receipt. It refuses spent directories, inconsistent previous leases,
deadline extensions and duplicate seed requests. Frozen auditor imports use the
same frozen adapter. Errors/timeouts/unsupported/censors retain their raw records.
The latest focused runner protocol suite has13 passing Python tests in
`runner_unit3` (0.1757367s); no source worker was used for these tests.

An explicit `--seed-selection-evidence` records selected development seeds as
`declared_development_selection`; they cannot silently inherit the ordinary
unfiltered label or become independent random samples. A separately declared
`--jokerless-opening-recipe` loads the frozen product's
`Core/jokerless_opening.lua`, calls its initial source catalog and pure predictor,
requires exact equality with the frozen recipe, then installs the same metadata
the product uses. The dispatcher records the applied recipe/module/catalog check
before the first decision. It still invokes ordinary `decision.run` for every
action; no action script is invisibly forced and hand play remains autonomous.
Runtime route integration and full-attempt qualification are separate from this
protocol's tests. Recipe acquisition, retention and terminal outcomes require
their actual complete-attempt trace.

Current source-agent spending: **1/12 complete-attempt leases** (180 seconds
reserved,42.2766877 actual) and **2/12 mechanical leases** (30 seconds reserved,
0.6844036 actual). Remaining leases are not renewed by faster workers or new
directory names. No complete win is recorded here yet. Source profiles remain
synthetic; player win rates, numerical odds and all20 completion-time estimates
remain unknown. No game process/control, settings mutation, physical saves,
native change, training or automation was used.

## Resumed 2026-09-13 — bounded source continuation

The user explicitly resumed after powering off the PC. The immutable companion
`authorization_resume_20260913.json` binds the original authority and existing
registrations. Counts and reserved worker seconds remain shared; worker deadline
is19:18UTC. No old allowance is renewed.

The declared Jokerless source hook now waits for the original settled Small Blind
input state before validating the strict product catalog. It mirrors the product
filtered challenge-progress route (`used_filter=true`, `seeded=false`) and records
that activation explicitly. All actions still come from frozen `decision.run`.

Mechanical request03 failed **before registration or worker launch** because old
mechanical records carry seed in their command, not at top level. Its fresh
folder and `registration_error.json` remain. It is not an executed lease.

Mechanical lease03b **ERROR**,0.0925987seconds: the CLI initially excluded the
`blind` decision checkpoint. It never initialized Lua/source and remains spent.
Lease04 uses an explicit hashed dependency on that argument error and the changed
CLI. On frozen installed272 policy
`49c512174ca4c4f92f95243f6c28dac30cca676d53aa0c609fe385d5329cd5c2`, it passed the
original catalog/prediction/initialization checks and proposed the legal Coupon
skip. It stopped **censored** before executing any action,0.3458677seconds,
with no provenance audit errors. Registration
`b2003f0f24051a299e24738213eefc8c814a50fa0b7fe988127cedc3764d3291`.

Complete attempt02, `source_attempts/02_coupon272_dla`, seedDLA21111, froze that
installed272 policy and adapter
`b884667259b57654b6a73ca28ef771211a345705c6df14ccb20ea975f2654487`.
Registration
`163633ab7bc797878c160abc915c7342621a68c0ecc93849e1e6e419087132fc`.
It is **UNSUPPORTED**,6.1202512seconds, not a win/loss: at step12 the product
opening validator paused on original Foil metadata. Before that pause the source
legally cleared Big450 with452chips in2hands, bought/used freeSaturn, bought
Telescope for$10 and opened the first free JumboStandard pack. Its five public
cards exactly matched the recipe. `visible_key` incorrectly rejected the original
edition table `{foil=true,type='foil',chips=50}`. The opening owner is repairing
that generic normalization with this detached source snapshot. This complete
attempt remains spent and is not rerun or relabeled.

`route_wfi31111.json` and `route_ckv31111.json` derive distinct existing search01
matches by removing ranking fields and attaching the same verified catalog
signature. Derivation hashes are explicit; no new search/source worker ran.
Every subsequent source request must independently match its recipe against the
actual initial source catalog and reveal/acquire offers through legal actions.

Current source worker totals: **2/12 complete attempts**,360seconds reserved,
48.3969389actual; **4/12 mechanical probes**,60seconds reserved,1.1228700actual.
No complete Jokerless win has yet been observed. Synthetic qualification remains
false. No live game, saves, settings or native binaries were controlled/changed.

## Installed273 failures and dependent274 experiment

Attempt03, `source_attempts/03_coupon273_wfi`, is an audited **LOSS**, Ante2Big,
1128/1200chips, step43,24.5200327seconds. All9plays matched exact source scores.
It legally acquired both Blue seals and used Saturn, but generated no Planets
before losing. FirstBig used3hands, leaving$9, so Telescope was not affordable;
after the Ante1Boss the source correctly refreshed the voucher to Director'sCut.
There was no later missed purchase of that same Telescope. The profile remains
synthetic and this selected development attempt is not a win-rate sample.

Attempt04, `source_attempts/04b_coupon273_to6o`, testedTO6O4111 from a completed
batch retained inside search05's timed-out request. Its raw canonical recipe first
failed wrapper-schema validation in directory04 **before registration or worker
launch**; that error folder remains. Actual lease04b is an audited **LOSS**,
Ante1Pillar,476/600chips, step25,10.5733249seconds. It legally acquired all three
predicted BlueSteel cards, including the Holographic5, plus Telescope and Saturn.
All6plays matched exact source scores. All25actions resolved with contiguous
source fingerprints. The source's8Pillar-debuffed IDs exactly match the8cards
played inBig and original `played_this_ante` flags. Original source definitions
and hashes are recorded in `04b/source_audit.json`; no Pillar adapter defect was
found. Acquisition alone did not establish a viable full run.

The root's component lease02, `root_component02_step19_resource`, froze exact
273and candidate policies, source module setup and the public step19snapshot.
One15second worker ran two fresh Lua contexts with default options. It completed
in2.8219998seconds: baseline exactly reproduced HighCard16 play; candidate chose
discard[1,2,3,4]. Both used105196evaluations, no truncation, and preserved input.
The new admission rule rejects a play-now override when later discard decisions
are omitted and paired sampled worlds cross. These are detached decisions, not
source replay or an imputed rescue. Initial registration's root-path error was
caught before registration/worker launch and is preserved separately.

`jokerless_push.py --dependent-attempt ... --repair-evidence ...` now supports an
explicit changed-hand-policy experiment. It requires an actual prior audited
failure, intact original registration/rawtrace/record hashes, a changed module
that participates in hand observations/scoring/action selection, concrete repair
evidence, and identical seed/challenge/profile/openingrecipe/cleanretrycontext.
Version/UI/adapter-only changes cannot admit it. It consumes a new one-use180s
lease inside the same shared12attempt cap and deadline. The old result remains
unchanged. Selection provenance declares dependency and fresh original source
initialization: no saves, restored state, forced actions or independent rate
sample.25protocol unit tests pass, including unchanged/version/UI rejection,
profile/recipe/seed preservation, prior evidence tampering and failed-audit guards.

Attempt05, `source_attempts/05_dependent274_to6o`, was prospectively registered on
installed274 policy
`e2c40a5a328a22e9cea9e6da9735362ab5df1966365416e6d2a109368946db49`, registration
`d4b74d36cc6f83510ae781d94b954a1c3c83a7977dc9b7b9d5ad8654658957f8`.
It binds original273loss04b and component02 repair evidence; its outcome is pending
in its own `record.json` until the bounded worker completes. No provisional
progress is a win. Current reserved source totals are5/12complete attempts
(900seconds) and4/12mechanical probes(60seconds); rootcomponent02 is charged to
the separate root allowance, not the source-agent mechanical allowance.

Attempt05 has now completed as audited **LOSS**, Ante8CeruleanBell,
38802/100000chips,231decisions,119.0375025seconds. All231source actions resolved;
all adjacent state fingerprints match, with no illegal-action records, Jokers or
duplicate playing-card identities. Original `GAME.won=true` did not override the
actual GAME_OVER and uncompleted challenge profile.30scores were verified
(25exact,5supported random floors);8additional plays retain explicit random/
unverified prediction coverage. There is no score mismatch, but those8are not
parity successes. Full reaudit is `05_dependent274_to6o/source_audit.json`.

The opening required17actions and5.1074759advisor seconds plus1.4179088source
transition seconds. Full advisor computation was89.0701748seconds, with a131035
maximum evaluation count. Four BlueSteel cards survived at loss, with a50card
population, StraightLv19 and$56. Nine winning plays visibly added tenSaturns.
TwoSaturns remained unused in the final two consumable slots despite noObservatory;
this blocked further capacity. The finalshop and finalblind random-readiness path
is now a concrete failure investigation. Extra permanent levels alone are not
claimed to rescue the run. Search05 remains an independently recorded60.010215s
TIMEOUT with its completed earlier candidate batch retained; search time is not
silently folded into advisor/source execution. Physical user action time is
unmeasured. Current actual source-worker spending is202.5277990s across5complete
leases plus1.1228700s across4mechanical leases; reservations remain900+60seconds.

## Attempt06 and explicit target metadata — 2026-09-13

`source_attempts/06_dependent275_to6o` is a new dependent clean-initialization
experiment on installed275, prospectively bound to attempt05 and the exact
preparation repair in `PLANET_PREPARATION_275.md`. Its immutable registration is
`8f652d53f0cdfadb2c9627433b8c3f5bcf49522ea67e329a6e1c559f67ce48cb`;
policy is `fa2122e6bd87a10942da0bf4bfa4bd1e4ba06232470bd4314b0802c6b68d91f2`.
It ended in an audited **LOSS**, Ante3 The Eye, 2,658/4,000, 82 actions,
50.1403201 seconds. All actions resolved with contiguous matching fingerprints;
there were no illegal actions, Joker inventory entries or duplicate population
identities. Fifteen deterministic scores and one supported random floor match
the source; two random predictions remain explicit unverified gaps.

The first action difference from274 was step40: consuming the just-purchased
Saturn instead of leaving the shop. The original source applied Straight2→3;
a later Celestial pack applied3→4. All three opening BlueSteel cards and
Telescope were actually acquired and retained through the loss, but no winning
play in this trajectory generated a Blue-seal Planet. The final population was
53, hand size9, cash$1, with no consumables. The Eye allowed the first Straight
for2,465; the three remaining distinct hands added100,60,33. The preparation
repair works mechanically but this dependent trajectory ended earlier; no
general survival improvement or final-Bell rescue is claimed.

`source_audit.json` and the relevant public snapshots/results are preserved
under attempt06. Advisor computation was39.1928405 seconds, source transitions
9.1465104 seconds, snapshots0.0389999 seconds; maximum per-action evaluations
134435 remains inside140000. Six of twelve complete leases are now reserved
(1080 seconds; actual252.6681191 seconds), and four of twelve mechanical leases
remain reserved (60 seconds; actual1.1228700 seconds).

The source adapter now accepts optional explicit `target_planet`/`target_hand`
metadata. It validates an ordinary initially available Planet and matching hand,
then passes `{require_planet=..., target_hand=...}` to the frozen product
predictor before requiring exact original-catalog recipe equality. Missing both
fields preserves legacy prediction bytes. Partial, mismatched or hidden initial
Planet targets reject. Twenty-nine protocol tests pass, including the narrowly
added `blind_prep` runtime-action dependency gate; version/UI/adapter-only and
Strategy-only changes still cannot admit a repeated complete attempt.

Original ZIP mechanics supporting Mars, Jupiter, later Planet X, Blue capacity,
Cerulean forced selection and Ouija hand-size cost are recorded in
`JOKERLESS_SOURCE_MECHANICS_277.md`. No source worker was spent on those reads.

## Prospectively ordered Flush attempts07–09 — 2026-09-13

The final allocated search completed4million indices and retained three Jupiter
matches, with no Mars match. `targets277_selection_plan.json` fixed the selection
order before the search. All three Jupiter starts were attempted in completed
index order on exactly the same frozen277 product and source adapter, despite
subsequent runtime work. Policy digest:
`1b5425735afb8190359949faef16084f8fc5394c041f559e43b83634fbf30a36`;
adapter digest:
`8b33291d9b8d6b2085211a23780da329baf6ff27d1647cc56761c147baf95ca9`.

- `07_flush277_ff7p`, FF7P6111: LOSS Ante2 Big,1087/1200,42actions,
  37.1628356seconds. TwoBlue,oneSteel,54cards,FlushLv2,PairLv2,$21;
  Telescope was unaffordable in the firstshop ($9 versus$10). Nine deterministic
  scores verify; two random predictions remain explicit gaps.
- `08_flush277_p83r`, P83R7111: LOSS Ante2 Flint,762/1600,55actions,
  40.1524143seconds. TwoBlue,twoSteel,oneGlass,54cards,FlushLv2,$2 and Telescope.
  Ten deterministic scores verify; one random prediction remains an explicit gap.
- `09_flush277_5xbb`, 5XBB8111: LOSS first Big,396/450,9actions,
  7.8400950seconds. No searched acquisition was reached; all four deterministic
  scores verify.

All original initial catalogues exactly matched their declared explicit target
recipes. All actions resolved with contiguous fingerprints, and read-only audits
found no illegal actions, forced-card omissions, Jokers or duplicate population
IDs. None of these trajectories generated a Blue-seal Planet. All selected
outcomes are retained in `targets277_source_summary.json` and
`TARGETS277_SOURCE_SUMMARY.md`; these selected synthetic profiles are not a
measured player-rate cohort. Nine of twelve complete leases are reserved
(1620seconds), leaving three; mechanical reservations remain4/12 (60seconds).
No further seed-search budget remains. There is still no complete Jokerless win.

Actual source snapshots exposed missed safe Blue retention in attempt06steps37
and70 and attempt08step21. Root component03 independently validates the first
two candidate repairs under the unchanged70-score fast-clear cap; its receipt is
`root_component03_blue_retention/report.json`. These component decisions do not
impute a rescued episode. A later changed-policy attempt requires its own fresh
dependency registration and original initialization within the remaining leases.

## Attempt10: actual Blue retention, no rescued run — 2026-09-13

`source_attempts/10_dependent279_to6o` is a freshly registered dependent attempt
on installed279, bound to attempt06's original failure and rootcomponent03.
Registration `74e3da9824fafce77e9ed00191098ff3e2944e9b197432e203a2a03f46ca40c0`;
policy `738e4a743ce239ae364cbe6ef11f14b813ab9d77d80b81f6f840154a7b2661ba`.
It ended in audited **LOSS**, Ante3 Eye,2658/4000,81actions,63.6552107seconds.
The three opening BlueSteel cards and Telescope were acquired and retained.
The repaired winning hand atstep37 actually generated Jupiter; step44 used it
and raised Flush1→2. A Five-of-a-Kind hand was actually played during the
trajectory, but Straight remainedLv4 at loss. These improvements did not rescue
the attempt. No Planet was left unused at loss; the only owned consumable was
Hanged Man, so this result does not justify a broader Planet-use exception.

All81 actions resolved with contiguous matching fingerprints; there are no
illegal-action records, forced-card omissions, duplicate population identities
or owned Jokers. Ten exact scores and one supported random floor verify;
four other plays remain explicit random/unverified gaps. Maximum per-action
evaluations134816 stays below140000. Advisor computation was51.4850338seconds,
source transitions10.1612763seconds and snapshots0.0386605seconds. The full
read-only audit and relevant public snapshots/results remain beside the raw
record. Ten of twelve complete leases are reserved(1800seconds), actual
401.4786747seconds; four mechanical leases remain reserved(60seconds), actual
1.1228700seconds. Two complete attempts remain inside the unchanged deadline.

## Final source attempts11–12; complete allowance exhausted — 2026-09-13

Both final prospectively ordered dependent requests froze identical installed280
policy `63b9c29f0c318e66da82f4cd01c956f0790bab2e9cc3715d2682d5bca6a13308`.

Attempt11, `11_dependent280_p83r`, binds original attempt08 and the corrected
five-card Psychic component04. Registration:
`147d3d10b5c0309fdca3c65ddd4f7120eb5b8372d14e1ace338edda12f6df9d9`.
It ended in audited LOSS Ante2 Flint,762/1600,55actions,46.2497321seconds.
The source actually generated Mercury after the repaired legal five-card Pair
atstep21, but Mercury stayed unused through loss. At the first subsequent blind
selection, step27, Pair was level1 with one actual play; ordinary Mercury and
Chariot filled the two consumable slots, with no Jokers, Observatory or Fool.
This public snapshot/result was exported for a narrow blind-phase preparation
investigation. It does not establish that consuming Mercury rescues the run.
Ten deterministic scores verify and one random prediction remains an explicit
gap. Maximum per-action evaluations118742 remains below140000.

Attempt12, `12_dependent280_ff7p`, binds original attempt07 and actual component05
funding evidence. Registration:
`a87421b4e3727c2a8c6e087f9a4f7d4a125c762635a4ac8d7a04a65f65c9d2b7`.
It ended in audited LOSS Ante2 Big,466/1200,45actions,36.8844087seconds.
The original source executed the funding sequence: step12 bought free Uranus at
$9, step13 sold it to reach$10, step14 bought Telescope to reach$0. Both searched
Blue cards were acquired and retained. The Telescope Celestial offer raised
Flush2→3 atstep36, but no Blue Planet was generated and the full attempt still
failed. Nine deterministic scores verify and two random predictions remain
explicit gaps. Maximum per-action evaluations118080 remains below140000.

All actions in both attempts resolved legally with contiguous fingerprints and
no forced-card omissions, Jokers or duplicate population identities. Their
read-only audits and relevant public snapshots/results are preserved. There was
no current-policy full Jokerless win. A later281 preparation component/release,
if completed, has no full-attempt evidence under this exhausted allowance.

`FINAL_SOURCE_EVIDENCE_280.json` independently reverified the frozen files of all
twelve requests and binds their original records/traces. Accounting outcomes
are ten losses, one unsupported attempt and one error; these selected synthetic
and dependent outcomes are not a player win-rate sample. All twelve complete
leases are spent/reserved (2160seconds, actual484.6128155seconds). Four source
mechanical leases remain spent/reserved (60seconds, actual1.1228700seconds);
their unused eight leases are not converted into complete attempts. No source
worker is running and no additional complete request is permitted by this
authority. Current and projected numerical player win odds remain unknown.

The final read-only action audit also found one actual new Fool execution in
attempt10: packstep51 had empty inventory and previous identity`c_magician`;
choosing Fool created one ordinary Magician in inventory atstep52 and closed the
pack, with population and cash unchanged. Original `last_tarot_planet` became
`c_fool`; the copied Magician was subsequently used atstep56. Exact source
snapshots and `10_dependent279_to6o/fool_source_receipt.json` bind this observation
to the unchanged raw trace. Attempts11–12 executed no Fool actions. This is
actual acquisition evidence for the copy behavior, not full-run success.
