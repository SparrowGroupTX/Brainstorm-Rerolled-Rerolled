# Context reset checkpoint — v2.42.0-alpha

Written 2026-09-10 for the user's request to preserve this conversation before
starting a fresh chat. This reset task changed documentation only: no runtime
feature, simulation, installation, game action, or schedule was started.

## Read order and authority

1. Read `ADVISOR_START_HERE.md` at the repository root first.
2. Read this checkpoint and `tools/advisor_eval/NEXT_PRIORITIES_242.md`.
3. Read only the relevant sections of `ADVISOR_HANDOFF.md`, then corresponding
   source and tests. Do not load the entire historical handoff just to resume.
4. `INTERVENTIONS_9.md` and `INTERVENTIONS_10.md` preserve completed release
   ledgers. The tools README and COEFFICIENT_CALIBRATION.md explain evaluation.

All relative paths in this checkpoint are relative to
`C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled`, unless expressly
described as relative to the installed mod or to a runs directory. Later dated
status supersedes historical phrases such as "current version", unchecked
acceptance cases, and old forecasts. Historical acceptance examples still
describe useful behavior; their unchecked labels do not prove missing code.

The six next improvements are **proposed and not started**. The question before
this reset asked for priorities and forecasts, not implementation. The saved
root-level `ADVISOR_RESUME_PROMPT.md` is an action-oriented prompt the user can
paste to authorize continuing with them. This document itself records status;
it does not imply those proposals were implemented or tested.

## Objective and persistent instructions

- Build a deterministic Balatro advisor minimizing expected real time to finish
  all 20 challenges, including losses, retries, opening/filter costs, advisor
  computation and user action time. Maximal chips alone is not the objective.
- The 50% and 75% win-rate targets apply to **every challenge individually**.
  Neither is demonstrated. An average cannot establish either target.
- Preserve all tracked modifications and untracked work. Do not commit, reset,
  clean, delete, rename away the dirty tree, or create a PR unless asked.
- Install each successfully implemented and appropriately tested runtime
  feature immediately, with backups and installed-file hashes, preserving
  settings and saves. The old ten-percentage-point batching rule is obsolete.
- Keep the running game undisturbed: never foreground, fullscreen, restart,
  stop, or control it; never execute live gameplay through tools. Execute in
  the product remains user-clicked, one legal action, then a fresh decision.
- **Never launch Balatro.exe**, even with nominal headless flags. Source probes
  may read that file as a ZIP and execute isolated Lua through lua51.dll.
  Hidden source execution is not permission to drive the live game.
- Use bounded hidden tests and simulations with hard wall limits. No unbounded
  campaign. Do useful targeted implementation rather than indefinitely testing
  the same state or repeatedly requesting confirmation.
- Defer neural/GPU training. No scheduled tasks or automations. A historical
  unwanted hourly continuation was deleted; do not recreate it.
- Keep progress concise. Report behavior, validation, installation, material
  limits, and honestly qualified estimates. Maintain durable handoff files.
- No web research is needed to recover this checkpoint. Original game source,
  local policy and recorded traces are the primary evidence for this work.

## Exact state, preservation and verification

Repository branch: `codex/exact-search-speedups`.
HEAD: `1fb4267701fc0545b5a3fd9148587505381e36ba`.
The actual project work is mostly uncommitted; HEAD alone is not a usable backup.

Installed root:
`C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm`.
Version **2.42.0-alpha**, deployed **2026-09-10 17:44:14 CDT**.
All **34 deployment files** (33 Lua files and the native DLL) were rehashed during
this documentation reset at **2026-09-10 23:22:18 UTC / 18:22:18 CDT** and match
repository, installation, and the latest deployment manifest exactly.

Latest backup, containing the files from before the 2.42 slice:
`C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm/deployment-backups/advisor-20260910-174414`.
The authoritative installation record is `deployment.json` inside that directory.
Short `deployment-backups/...` paths in older documents are relative to the
**installed mod**, not the repository. Backups are incremental previous states;
do not assume one slice's backup is the complete pre-nine-intervention version.

Config SHA256 remains:
`15A399DFBE89A1237C76F6BC06CB9173764EFC4BE976FE9DA0243F549AC9741E`.
Native `Immolate-v2.16.dll` remains:
`34598478571391D272C1E1A837832061BD767A09AB552BB61EF3458E24E9D751`.
Saves were not read or written; this is not a fresh save-hash assertion.

Full product freeze:
`tools/advisor_eval/runs/development_final242/policy`.
Product digest:
`f151758fda0aa885691416abd11a991af49627231dde4144808b7c8f37a2ff70`.
The installed product digest was rechecked and matches that frozen product.
The full product manifest has a broader scope than the 34 deployment files:
it also includes existing runtime/native dependencies such as Lovely files.
Personal config, saves and deployment backups are excluded from product freezes.

`tools/advisor_eval/SESSION_RESET_242.json` records all 34 file hashes, paths,
deployment time, full policy digest, branch/HEAD, and git status before these
documentation edits. It records historical validation without pretending to
rerun it. No product files changed during the reset. There is no outstanding
implementation, installation or test process, and no unfinished agent edits.
Do not depend on old agent names, process IDs, tool store variables, or chat memory.

The running game's loaded version is **unknown**. Installing Lua files does not
prove the live process reloaded them. Activation awaits the user's normal restart;
never trigger that restart or claim the active game has been upgraded.

Dirty state to preserve includes `.gitignore`, Core/Brainstorm.lua, UI/ui.lua,
steamodded_compat.lua, Immolate build/source changes, README changes, the entire
untracked Advisor directory, opening Core/UI/native files, tests, tools and all
advisor documentation. The Windows `README.MD` / `README.md` double listing
preexists. Do not resolve it by deleting or overwriting either entry.

## Completed behavior — do not reimplement it

The original priorities remain design constraints, but substantial coverage is
already installed: rapid reliable clears, bounded conservation/development,
whole-inventory Perkeo copying value including purchase dilution and accumulating
Negative copies, Planet/Observatory comparisons, build-aware Kings Strength/Death,
exact Yorick/Burnt discard progression, safe growth investment, Glass conservation,
and viable finishing-hand protection. Detailed original examples are in handoff
sections on progression, Perkeo, Kings and Glass; generalize them, do not hardcode
named fixture hands or challenge/seed exceptions.

The completed ten-intervention batch through 2.31 added executable Dagger row
preparation, Typecast pre-lock development, exact Hanged Man and supported seal/
Spectral population changes, score floors, population conservation, actual-next-
boss shop scoring, bounded mixed consumable/order rescues, objective early stops,
and frozen paired/provenance/replay infrastructure. Mature Canio preservation was
fixed in 2.29. Pinning, destruction order and unknown engine preservation matter.

The completed nine-intervention batch, 2.32–2.42, added:

1. Reliable-clear reward tie breaking after conservation: actual held Gold/Blue,
   supported Mime/copy effects, income and marginal interest, useful Planets,
   consumable slots/buffer and perishable timing. Actual DNA-created held cards
   contribute their rewards. Midas/Vampire row order and explicit h_dollars work.
2. Per-decision classification reuse, detached public classify results, ordinary
   deck-back reveal on simulated draw, strict finite-tail final-hand sample
   dominance, and an independent effect stream preserving ordinary draw samples.
3. Legal source action dispatcher/reorders, actual challenge terminal recognition,
   lower-bound verification using actual >= floor, and failure/profile records.
4. Bounded conditional two-discard rescue on the last playable hand, publishing
   only the first action and refreshing after the real observation.
5. Exact Trading Card destruction/cash/callbacks and DNA copy/population effects.
   Purple supports explicit complete Tarot outcomes, not an invented legal pool.
6. Executable skip choices after existing setup advice, using actual remaining
   blinds and margins, cash/rental/growth/shop/time costs and supported attrition.
7. Shared sampled Glass, Hook and Crimson Heart transitions; source-checked timing,
   corrected nonlinear outcome hashing, and rejection of hidden-future oracle
   decisions and unsampled random continuation growth.
8. Versioned bounded coefficients and a real frozen numeric candidate screen.
   It found no action change or calibrated improvement; defaults were retained.
9. Native filtered search executing exact frozen Lovely hooks and original setup
   callbacks, recording misses, acquisition, search/setup time and retention.

Each runtime slice was installed immediately. Release/backup suffixes:
2.32/171335, 2.33/171731, 2.34/171733, 2.35/172037, 2.36/172555,
2.37/173041, 2.38/173131, 2.39/173312, 2.40/173515, 2.41/174225,
2.42/174414, all on 2026-09-10. Full ledger details remain in INTERVENTIONS_9.md.

## Runtime wiring, contracts and bounds

Entry points: `Brainstorm/Advisor/runtime.lua` loads detached modules via nativefs;
`snapshot.lua` captures state; `decision.lua` is shared by in-game advice and the
source adapter. Execution/HUD remain fingerprint-guarded and user-triggered.
Add any future module to runtime, source adapter and syntax/module integration.

Non-hand order in `decision.lua`: blind_prep, opening advice, strategy/economy.
Tactical comparison context currently exists **only for phase shop**, which is
why revealed Buffoon choices are the first proposed patch. If tactical comparison
truncates, repeat the whole strategy/economy decision using fallback ratings; never
favor candidates that happened to be evaluated before the cap. Blind routing
can replace only a blind-phase fallback select_blind after setup has priority.

Hand order: Search first. A reliable fast clear gets at most six consumable
development evaluations and twelve growth evaluations, then returns and skips
expensive specialists. Otherwise evaluate consumables, Joker order, held-card
order, boss rescue, mixed rescue, then multi_discard. Publication priority is
mixed rescue, boss rescue, hand order, Joker order, consumable, multi-discard,
ordinary discard/play. A recommendation is one action, never a live action chain.

Preserve the existing **70-score whole fast-clear budget**: up to 32 obvious
proposals, four score-floor checks, sixteen conservation checks, six development
and twelve growth evaluations. A proved clear is not an exhaustive maximum-score
claim. Protect a viable finish before speculative investment; use small bounded
checks even when safely ahead, rather than simply skipping development.

Search defaults: hard 140,000 evaluations, 24 redraw samples, up to 16 discard
candidates, resource samples 8, horizon 4; exact initial hand limit 20 and
continuation hand limit 12. The remaining-blind resource model compares an initial
play/discard and then **future plays only** (`future_discards=false`). Do not claim
a general joint multi-hand/multi-discard optimizer exists.

`multi_discard.lua`: one playable hand, at least two discards, visible hand 1–10
and deck <=120. At most three first choices (including incumbent), four outer
observations, three conditional second choices, four inner draws, 24 play
proposals, and 12,000 scores. Select each second action over its complete inner
distribution, never after seeing the hidden draw. Require complete paired sets
and >=12.5 percentage-point estimated uplift over the incumbent nested policy,
with more benefit needed for extra paid discard cost. Finishes/rescues/development
retain priority. These are finite sampled estimates, not calibrated probabilities.

`mixed_rescue.lua`: at most eight consumable candidates, eight orders, sixteen
play subsets, 1,500 evaluations; source-legal supported mutations only.

`shop_scoring.lua`: four fixed composition draws, up to eight orders, hard 50,000
scores; actual next boss, hypothetical opening and conditional last-hand scoring.
No full future growth/discard probability model. Known vanilla startup boundaries,
unchanged deck and hand size 1–10 are required. Unknown startup effects fail closed.
Small public exports include apply_blind, next_blind and known_joker. Tactical
capacity/utility remains a bounded comparison, not a survival probability.

`blind_routing.lua`: fixed four composition samples, >=2x margin for each checked
remaining blind. A Small skip checks Big then Boss without imaginary intervening
purchases; supported Glass depletion and rental boundaries apply. Snapshot captures
route_blinds, route_tags, rental_rate, win_ante, consumeable_buffer and
consumeable_usage (including Satellite valuation). Unknown boundaries reject.

`scoring.lua` exposes classify, score, lower_bound, after_discard, prepare_play,
after_play and after_draw. Important transition contracts:

- prepare_play(s, selected, ctx) resolves Hook's unpaid held-card discard before
  scoring. ctx.hook_indices uses original hand coordinates, excludes selected
  cards, and obeys the source's up-to-two held-card choice requirement.
- after_play(s, indices, ctx) returns **state, effects, actual_result** before
  replacement draw. Use the third return for post-Hook score/clear decisions.
- ctx.glass_outcomes[index] provides explicit sampled stochastic destruction;
  certain destruction follows current live odds. Do not substitute a random mean
  for a guaranteed score. A supported lower bound can certify a clear.
- ctx.defer_crimson sets blind.crimson_pending. Draw replacement cards at the
  **old hand capacity**, then after_draw(state, {crimson_index=i}) changes the
  Joker debuff and hand/discard/odds resources. Crimson candidate selection uses
  surviving rows and excludes the prior blocked Joker unless it is alone.
  Unknown Chicot reactivation is unsupported.
- ctx.generated_consumables[original_index] supplies a complete generated Tarot
  for Purple. The public transition handles full slots/debuff/non-trigger paths;
  Search still has a blanket Purple continuation blocker. No legal Tarot-pool
  enumeration or full concealed-card belief policy has been implemented.

`draws.fill` reveals ordinary deck backs, retains hidden cards already in hand,
preserves source House/Mark/Fish/Wheel conditions, clears forced selection and
reselects Bell. Serpent's special three-card draw is continuation-only. Zero-card
draw can still run Bell/Heart callbacks. Unknown challenge flipped_cards rejects.
Hidden future hands must not optimize either survival or utility using their
internal identities. Unsampled random score/growth rejects remaining-hand proof.

`sampled_outcomes.lua` derives private common outcomes from seed, turn, channel
and physical card identity. Current hash is FNV byte hashing plus Murmur avalanche
with exact 32-bit limb multiplication; native-bit and portable XOR paths agree.
The earlier affine hash was biased and was replaced in 2.41. Hash only relevant
Glass candidates and actually drawn Wheel cards. Its counter stream is separate
from deck sampling as of 2.42; preserve that separation when adding effects.

`score_cache.lua` caches classification for immutable decision-state card/row
shapes, not final scoring arithmetic. Public outputs are detached; internal
membership maps may be borrowed. Do not extend cache lifetime or memoize exact
scores without proving complete keys and testing mutable-state invalidation.

`policy_weights.lua`, schema 1/version 1.0 defaults: growth_action_cost=4,
growth_utility_scale=1, discard_action_penalty=0.06. Runtime and source engine
inject them into the relevant Search/Growth paths. They are utility coefficients,
not measured seconds. All safety/finish constraints survive coefficient changes.

## Evidence, reproduction and interpretation

Historical completed validation: **56/56 Lua fixture files**, **69 Python tests**;
affected search/runtime checks and syntax were rerun after final 2.42 changes.
There are 33 runtime Lua files in the deployment. No tests were rerun for this
documentation-only reset.

Thirteen original-source mechanics probes: **247 scenarios / 4,410 comparisons**.
Each name below corresponds to tools/advisor_eval/<name>_source_parity.py:

| Probe | Scenarios | Comparisons |
|---|---:|---:|
| discard | 16 | 1196 |
| dagger | 8 | 48 |
| glass | 12 | 201 |
| deck | 13 | 271 |
| boss | 36 | 324 |
| score_bound | 14 | 924 |
| trading | 8 | 644 |
| dna | 6 | 93 |
| finish_rewards | 22 | 169 |
| heart | 9 | 135 |
| hook | 7 | 100 |
| blind_routing | 16 | 144 |
| draw | 80 | 161 |

Additionally, frozen 2.42 passed 15 phase/terminal assertions and nine filtered
retention assertions. Synthetic terminal wins are mechanics fixtures, never
policy episode wins. Sampler checks include 4,096-seed Hook subset frequencies
(six pair counts 673–711), joint Glass outcomes, vectors and implementation parity;
they are engineering checks, not a mathematical guarantee of perfect randomness.

All following artifact paths start with `tools/advisor_eval/runs/`:

| Directory | What it preserves |
|---|---|
| development_final242 | Exact final installed policy; source_parity/report.json; filtered_retention/report.json; golden_episode/report.json, episodes.jsonl, action log and failure snapshot |
| development_episodecoverage332 | Frozen 2.32: four ordinary full attempts, Golden Needle Ante 2 loss, Knife/Jokerless 45s timeouts, Omelette floor-equality error later fixed |
| development_current240 | Interim Omelette timeout and Golden Needle regression, retained even though later fixed |
| coefficient_screen239 | Actual two-candidate numeric freeze, screen registration, paired logs and calibration_report.json |
| development_filtered339 | Native paired_setup, ADVISOR1 no_find, source retention, Knife short episode prefix |

Final Golden Needle ordinary seed ADVISORCOVERAGE332: **loss at Ante 2 Small,
608 chips short**, 31 actions, 31.3846833 seconds. Its 2.32 trace made the same
31 actions and same loss in 41.0112972 seconds. This roughly 23.5% wall-time
reduction is one selected losing trace with different adapter revisions, not
a general speedup or a measured improvement in time to win. Final profile:
28.822s advisor work, 2.20055s source transitions, 0.0127565s snapshot work,
1,132,766 scoring calls across 31 decisions.

The v2.40 Golden Needle interim Ante 1 Big loss (150 short, 15.36s) remains on disk.
The 2.42 ordinary effect-stream separation restored the matched prior action trace.
Do not delete the regression evidence or mix versions when interpreting results.

The v2.40 Omelette 45s timeout **does not demonstrate a stuck Boss transition**.
There were 54 completed advisor decisions and 53 resolved actions; advisor time
37.325s + source transitions 7.161s = 44.486s before startup/logging/unfinished
select-Boss work. source_transition_timeout records interruption location, not
a proven cause. Fifteen hand decisions took 30.024s and 21 shops took 7.253s;
expensive nonclears used roughly 87k–116k scores, one 4.508s/104,843-score decision.
Use cumulative budget/progress diagnostics before claiming a queue stall.

The coefficient screen ran two variants (growth_action_cost=2 and
discard_action_penalty=0.09), each paired with baseline, on one Omelette seed.
All four were three-action censored prefixes with identical actions and 113,444
score calls. Timings 4.72/4.21/4.02/4.30s are not calibration evidence. Defaults
were retained. Current tool intentionally cannot promote an experimental policy.

The original-source adapter uses a **synthetic default unlock/discovery profile**,
not user saves. It is experimental and not qualification-compatible. Product,
native/rules source, runtime DLL, adapter, unlock profile, challenge/seed and start
distribution provenance all matter. Censored/timeout/error/unsupported/missing
requests stay explicit; never count them as wins or silently discard them from
the requested cohort. Ordinary and filtered starts are distinct distributions.

Filtered openings support the 19 eligible vanilla challenges, excluding Jokerless.
Native search start and found actual run seed are different fields. Preserve
misses, continuation seed and all search/setup costs. Use original frozen two
Lovely hook replacements and Core/challenge_opening.lua callbacks for setup.
setup_complete requires the actual ordered Legendary pair to equal native output;
acquisition and later retained-engine events must remain separate.

Selected fixture I1L21111 acquires Yorick/Perkeo on Omelette/Knife. On Knife,
pinned Eternal Dagger consumes Yorick on Big entry; Perkeo survives and source
play scores 528 to clear. Pack Souls must be used immediately and a blind cannot
be selected with an open pack. Storing Soul until after blind entry is not legal;
Core remained unchanged. This fixture proves a retention issue, not its prevalence.
Source setup roughly 0.65–0.76s and no-find roughly 0.028s native/0.297s total
are selected CPU timings with distinct endpoints, not general campaign savings.

## Next implementation: ranked scope and acceptance

Start with 1–3; 4 can be developed independently in parallel with clear file
ownership. Then use evidence to prioritize 5–6. Inspect actual source before
editing; line numbers in NEXT_PRIORITIES_242.md are approximate navigation aids.

1. **Tactical choices among revealed Buffoon cards.** Reuse shop_scoring for only
   actual offered Jokers and legal owned-row replacements. Free pack selection
   must not be charged a shop sticker price. Respect slots, pinned/Eternal cards,
   Typecast lock, legal sale order and current cash. Capture all offered cards
   before selection, including rejected choices, in development traces. Test
   weak unscaled builds that need useful immediate chips/Mult and established
   builds where compatibility changes the best choice. Test constrained/full rows
   and unsupported/truncated tactical comparisons. No imaginary replacement or
   unseen offer. Preserve complete paired comparison and deterministic caps.
2. **A credible next-blind scoring plan.** Supplement relative upgrade ratings
   with supported reachability/readiness under actual hands, discards, blind,
   deck and hand levels. Prioritize affordable flat Mult, useful Planets or
   necessary replacements/rerolls over growth too late to matter. Respect legal
   purchases and actual cash; a hypothetical reroll cannot promise a future offer.
   Test structurally weak vs already safe builds, last-hand restrictions, depleted
   decks, bosses, limited cash and unknown effects. Do not label a heuristic or
   sampled capacity a global mathematical upper bound. Preserve prudent savings
   when a credible clearing plan already exists; do not hardcode Golden Needle.
3. **Conditional income/growth payback.** Replace blanket income/low-cash urgency
   with expected trigger opportunities and timing before relevant danger. Consider
   discard-use conflicts, immediate vs end-round cash, next-shop Perkeo copying,
   rental/perishable costs, interest and purchase constraints. Delayed Gratification
   with likely necessary discards is a general trigger mismatch example; it should
   remain attractive in builds that can actually retain discards and survive.
   Preserve sensible growth investment when safely ahead and viable finish plans.
4. **Cheap verified replay and action-sensitive calibration.** engine_run.lua
   currently calls decision.run before replacing an action from replay. Bypass
   redundant policy work only for verified prefix actions, retaining source state
   fingerprints, provenance, phase/legality, score and checkpoint invariants.
   Explicitly log skipped advisor work; do not manufacture result diagnostics.
   Stop prefix replay at meaningful shop/growth/reroll decisions and compare
   matched candidate actions on frozen states. Include bounded terminal attempts
   and fresh unseen validation seeds. Current three-action screens are plumbing
   checks. Counterfactual replay is development evidence, not qualification.
5. **Repeated nonclear/shop computation.** Add component profiling, reuse only
   identical state comparisons, prove cache keys/invalidation before exact-score
   memoization, and preserve complete paired samples when pruning or capping.
   Preserve 70-score fast clears, ordinary draw streams, bounded conservation and
   finishing plans. Show matched actions/outcomes plus latency distributions on
   more than one workload before claiming general performance improvement.
6. **Filtered starts selected by retained engine and total setup cost.** Use fresh
   registered native starts and retain misses/search work. Compare useful legal
   filters/Any choices with actual retained copy/scoring engines over several
   blinds and bounded terminal attempts. Acquisition names alone are insufficient;
   no fixture-specific seed or impossible Soul-storage fix. Exclude Jokerless from
   this route and do not conflate filtered-subset estimates with all 20 ordinary
   challenges. Runtime filter changes still require native/source parity checks.

Failure evidence informing 1–3: final Golden Needle reached Ante 2 Small target
800 with Credit Card, Devious, unscaled Spare Trousers, unscaled Square and
Delayed Gratification; all 52 cards basic, all hand levels 1, no consumables.
Ordinary Straight max (30+51+100)*4=724; Four Aces with first Square growth
(60+44+4)*7=756; Full House with first Trousers growth (40+53)*6=558. A Straight
Flush was effectively needed. Step 22 spent the last $4 on Delayed Gratification
and the next blind required six paid discards before losing. Step 6 selected
Devious from Buffoon with zero scoring evaluations. Rejected offers are absent:
we have **not proved** a better available pack choice or that saving $4 wins.

Follow-ons after measured failure prioritization: mixed play/discard horizons
before the last hand, concealed-card belief policies, exact legal Tarot generation
and random growth coverage. These remain incomplete, not forgotten. Do not rank
them above early build decisions without evidence that their gain justifies cost.

## Latest forecasts — planning judgments only

| Distribution | Current 2.42 | After the six proposals and useful calibration |
|---|---|---|
| Equal-weight ordinary starts across all 20 challenges | ~35%, broad judgment range 20–50% | ~45%, range 30–60% |
| Useful supported filtered-opening subset | ~45%, range 30–60% | ~55%, range 40–70% |

These are low-confidence subjective forecasts, **not measured rates, statistical
confidence intervals, or per-challenge probabilities**. No representative terminal
win sample supports them. The last batch verified mechanics and some selected
latency improvement; calibration has not selected a better policy. Earlier
post-nine projections of ordinary ~50% and filtered ~60% are superseded. Some
hard challenges may remain far below 50%; neither 50% nor 75% each is established.

For a single challenge with unchanged mean attempt duration, moving 35% to 45%
would reduce expected retry time by roughly 22%. This illustrative arithmetic
cannot estimate the all-20 campaign using an average win rate. Per-challenge
failure durations, retries, filter costs and the hardest challenges matter.

## Commands and installation reference

Run PowerShell from the repository. Commands here are reference, not an instruction
to rerun all tests or begin a campaign on resume. Use fresh output directories;
never overwrite frozen evidence. Check each command's own exit/output: a later
PowerShell command can succeed after an earlier command failed. Avoid noisy or
ambiguous command chains.

```powershell
python tests/run_lua_tests.py
python -m unittest discover -s tests -p 'test_advisor_*.py'
```

The Lua runner creates a fresh isolated Lua DLL state per fixture. Focused fixture
paths can be supplied as positional arguments. Use rg to find tests corresponding
to changed modules. Tests asserting a behavior or source transition matter more
than tests merely repeating implementation. Run meaningful bounded integration
checks after related modules change; broaden only for an unresolved concern.

Original source is read from
`C:/Program Files (x86)/Steam/steamapps/common/Balatro/Balatro.exe` as a ZIP;
`lua51.dll` in that directory executes source in an isolated process. The executable
is never launched. Source callbacks use synthetic in-memory save/profile stubs.

Examples for a **new** directory name chosen before running, with frozen 2.42 as
a reproducibility baseline (do not reuse these as untouched validation seeds):

```powershell
python tools/advisor_eval/episode_source_parity.py --policy-root tools/advisor_eval/runs/development_final242/policy --output-dir tools/advisor_eval/runs/NEW_SOURCE_CHECK --timeout 15
python tools/advisor_eval/filtered_retention_parity.py --policy-root tools/advisor_eval/runs/development_final242/policy --output-dir tools/advisor_eval/runs/NEW_RETENTION_CHECK --timeout 15
python -u tools/advisor_eval/development_report.py --policy-root tools/advisor_eval/runs/development_final242/policy --output-dir tools/advisor_eval/runs/NEW_GOLDEN_REPLAY --seeds ADVISORCOVERAGE332 --challenge c_golden_needle_1 --timeout 45 --full-episode
```

`--policy-root` is the **parent containing Brainstorm/**, such as a repository or
frozen policy root; for installed freezes use the Mods directory, not Brainstorm
itself. `freeze_product` in paired_policy_audit.py captures actual source bytes.
Do not simulate against a source tree while another agent edits it.

`calibrate_policy.py` registration allows <=6 numeric candidates, <=4 challenge/
seed requests, per-attempt timeout <=45s, total wall budget <=180s; default screen
is a three-action prefix. COEFFICIENT_CALIBRATION.md documents JSON and flags.
Use --full-episode only within explicit bounded development, and meaningful
decision cutoffs/checkpoints for screens. It never installs or qualifies policy.
The formal benchmark gate exists but the adapter is still experimental: do not
launch a large qualification campaign to compensate for missing prerequisites.

Runtime slice installation example, **after an actual tested change**, selecting
the next unused version and the real changed file list:

```powershell
python tools/advisor_eval/install_slice.py --version 2.43.0-alpha Advisor/CHANGED_FILE.lua
```

This stages the installed runtime, overlays only explicitly named tested repo
Lua files, updates version strings in both stage and repository, then invokes
tools/install_advisor.ps1. Include all required related files in a coherent tested
slice; never deploy unfinished parallel edits. A tool/docs-only change needs no
runtime install or version increment. The installer backs up the selected set
before writes, skips unchanged binaries, writes Core last and checks every hash
and config hash. It refuses replacing an existing changed DLL; native changes
must use a new sidecar/version and the documented native workflow. No process
control is part of deployment. Keep backup paths and validation in the release
ledger and handoff after each successful slice.

## Handoff section map for targeted deeper reading

Search by heading rather than relying on old line numbers:

- Goal/preferences, exact file map, scoring/search/action architecture: sections 1–5.
- Native challenge opening, supported challenge/filter rules: section 6.
- Yorick, Burnt, safe-ahead investment, Perkeo inventory/Observatory and Kings:
  section 7 and its dated user counterexamples. Many original proposals there
  were subsequently implemented; compare against current source and release ledgers.
- Simulator, strict qualification, provenance and retry objective: section 8.
- Fast clears, Glass, responsiveness and conservation: section 9.
- Historical acceptance cases and sequences: section 10; current ranking is this
  checkpoint plus NEXT_PRIORITIES_242.md, not old unchecked todo status.
- Source/native commands, installation and rollback: sections 11–12; current
  command/version/path details above supersede old examples and counts.
- Historical forecasts/research/resume text: sections 13–15. Current forecasts
  and resume prompt supersede them; model/GPU work remains deferred.

The fresh chat should inspect, implement and test the next concrete slice, install
it if it changes runtime, and keep this record current. It should not repeat the
completed batches, claim measured wins, disturb the game, or pause because the
old chat and its subagents are no longer available.
