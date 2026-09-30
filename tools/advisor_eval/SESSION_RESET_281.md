# Clean stopping point — 2.81.0-alpha, 2026-09-13

Read `ADVISOR_START_HERE.md`, this file, then `NEXT_PRIORITIES_281.md`. Use
`ARCHITECTURE_MAP_281.md` for current component/source/test navigation. These
records supersede all earlier current-state, pending-work and budget wording.
Read only relevant component notes and dated HANDOFF sections; do not ingest
the entire historical handoff or rely on previous chat/subagent memory.

The user requested a clean stop and a detailed fresh-chat prompt. Runtime work,
installation and final regression are complete. No source worker, search,
installation, failed final regression, automation or scheduled continuation is
pending. Further implementation starts only when the user resumes it.

## Objective and honest outcome

The overall objective remains minimum expected real time to finish all 20
challenges, including failed attempts, manual retries, opening/filter costs,
computation and user actions. The current development focus is Jokerless;
Knife's Edge remains a secondary requested focus. The user specifically allowed
Jokerless seed search favoring Four of a Kind, Five of a Kind or Flush, and
online strategy research. The broad top-ten roadmap is not complete.

**No verified complete Jokerless win was achieved.** The latest push used all
12 complete-attempt leases: **10 losses, one error and one unsupported result**.
These were selected synthetic-profile experiments across different policies,
including fresh dependent attempts on previously studied seeds, not a representative player win-rate cohort.
Current and projected numerical odds are unknown. No percentage-point benefit
from online advice, these releases or five manual restores is established.
Neither the 50% nor 75% target has been demonstrated for each challenge.

The farthest audited attempt used policy274 and reached the final Cerulean Bell,
then lost with 38,802/100,000 chips. Its incidental `GAME.won=true` field does not
override GAME_OVER, the unmet threshold and the normalized audited loss. Later
valid mechanical improvements did not demonstrate a better terminal result.
Policy281 has captured-state and regression evidence, **no complete-run result**.

## Installed state

- Version: **2.81.0-alpha**, installed **2026-09-13T14:12:34.2093921-05:00**.
- Installation: `C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm`.
- Backup: `deployment-backups/advisor-20260913-141233` beneath that installation.
- **51 deployment files / 66 frozen product and dependency files** match the
  repository and installation. Exact file hashes and Git status are in
  `runs/jokerless281_installed/record.json`, its `policy/`, and final verification.
- Installed policy digest:
  `d6b30124a74d2845d7b813fcbcb47fb8d77db7d94c6b2f579cac3e16d52ade29`.
- Settings preserved at installation:
  `083f6c62a485cceceae4f0c55708ddde2750d18a0912e39cfcca47fc0e722f6c`.
  This is an observation, not a configuration to restore. Always preserve the
  user's current settings if subsequent user activity changes them.
- Legacy DLL unchanged:
  `34598478571391d272c1e1a837832061bd767a09ab552bb61ef3458e24e9d751`.
- Selected sidecar unchanged:
  `a569e1cb834352c23fed5eac3db30059279a57fe1eaf46e71cc8a594b672f885`.

Final candidate validation: **113 Lua fixtures / 253 Python tests pass**, with
unchanged frozen policy and test hashes, 13.453s / 11.469s, in
`runs/jokerless281_candidate/validation`.
Exact-installed final regression: **113 / 253 pass**, 13.688s / 11.593s,
unchanged policy and test hashes, in `runs/jokerless281_installed_validation`.
Each suite had its own 60-second cap. Earlier errors remain preserved separately.

The running game's loaded version is unknown. No normal restart activation or
live behavior has been confirmed. The game was never launched, foregrounded,
restarted, stopped or controlled; saves were never accessed for evaluation.
Product Execute remains user-clicked. Activation waits for the user's normal
restart, which the agent must not perform.

## Completed development since the original 266 reset

| Checkpoint | Implemented behavior and evidence navigation |
| --- | --- |
| 266 | Ordinary discarded display backs remain known identities; genuinely concealed discards retain safeguards. `DISCARD_VISIBILITY_266.md`. |
| 267 | Exact compact classification-cache keys; evaluator forced-selection/terminal/provenance fixes and captured-decision profiling. Original deferred pilot executed once. `SESSION_RESET_267.md`, `CACHE_KEYS_267.md`. |
| 268–269 | Supported generator revelation/rescue, no-Joker-rate Planet refresh, ordered Dagger/Chicot forecasting, bounded order equivalence and completed revealed-Planet commitment. See architecture map and targeted generator/commitment notes. |
| 270 | Five manually reported checkpoint retries with persistent public-state first-action memory and guarded complete alternatives. No save management or full continuation learning. `RETRY_CHECKPOINTS_270.md`, `RETRY_EVAL_270.md`. |
| 271 | Visible deck/Planet development and upgraded Straight/Flush discard targets. `VISIBLE_DEVELOPMENT_271.md`, `DRAW_TARGETS_271.md`. |
| 272 | Source-matched Jokerless Coupon/Blue/Telescope opening model, bounded search, UI and runtime integration. `JOKERLESS_OPENING_271.md`. |
| 273 | Original-source edition normalization and equal-positive-history paid-Planet comparisons. `PLANET_HISTORY_TIES_273.md`. |
| 274 | Ordinary deck-back handling in draw targets; complete common-world resource guard against an unsupported play-over-discard override; optional Blue/Steel presets. `RESOURCE_ADMISSION_274.md`. |
| 275 | Exact owned main-hand Planet preparation at shop/blind even when readiness forecasts are unavailable. `PLANET_PREPARATION_275.md`. |
| 276 | Four/Five-of-a-Kind draw targets from finite public rank populations. `RANK_DRAW_TARGETS_276.md`. |
| 277 | New default Mars/Four-of-a-Kind and alternative Jupiter/Flush presets, requiring two Blue seals including one Steel card. Existing Saturn presets preserved. `JOKERLESS_RESEARCH_277.md`, `JOKERLESS_SOURCE_MECHANICS_277.md`. |
| 278 | Eligible revealed-pack Fool creates an ordinary held copy of the previous eligible consumable; whole-inventory guards retained. `FOOL_PACK_278.md`. |
| 279 | Exact legal clearing-play substitutions can retain Blue/Gold/Glass, including five-card Psychic legality, inside the existing fast-clear allowance. `CLEAR_RETENTION_279.md`. |
| 280 | Narrow exact free-Planet buy/sell financing for an already-declared visible voucher; signed borrowing-limit correction. `CASH_BRIDGE_280.md`. |
| 281 | At blind selection only, main-hand Planets remain first; an ordinary Planet for another actually played hand may then be used under the existing preservation guards. Shop remains main-hand-only. `PLANET_PREPARATION_275.md`. |

Every coherent runtime slice was tested and installed with backups and preserved
settings. The release ledger is
`runs/jokerless271_push_20260912_214242/runtime_slices.json`.
No native DLL was built or replaced during this push. Existing tactical packs,
shops, economy, survival, finishing, concealed continuations, scoring reuse and
the conditional two-Legendary-plus-later-Rare filter remain implemented within
their documented bounds; do not repeat those completed batches.

## Latest evidence and what it proves

Use `runs/jokerless271_push_20260912_214242/FINAL_SOURCE_EVIDENCE_280.md` and its
JSON companion for all 12 outcomes, timing and independently reverified frozen
policy/adapter/profile/source/runtime provenance. Original records and logs are
under that push's `source_attempts/` directory.

- Policy279 retained a Blue seal through an actual legal winning Flush,
  generated Jupiter and used it. It also played Five of a Kind and used a pack
  Fool to create a Magician. It still lost at Ante3 Eye, 2,658/4,000.
- Policy280 retained Blue through a legal five-card Psychic play and generated
  Mercury. The run still lost at Ante2 Flint, 762/1,600. Mercury was idle at a
  later blind selection despite a previously played Pair; that supports281.
- Policy280 bought free Uranus, sold it for $1 and acquired the otherwise
  unaffordable Telescope. A later Telescope Jupiter raised Flush to level3. The
  run still lost at Ante2 Big, 466/1,200, worse than the earlier dependent route.
  Financing proves affordability, not strategic superiority over keeping cash
  or using that Planet.
- The final281 detached comparison uses source11 step27. Frozen280 reproduces
  `select_blind Small` with218 score calls. Candidate281 uses Mercury with0 score
  calls, raising Pair from level1 to2, 10×2 to25×3, preserving Chariot, cash and
  population. The input is unchanged. No continuation or rescued outcome is
  imputed. Receipt: `root_component07_secondary_planet/report.json` under the push.
- The preceding root component6 failed because the harness incorrectly required
  the baseline to use zero score calls. That spent receipt is retained. Component7
  was separately registered before execution; no old lease was reset or retried.

The source adapter normalizes source editions and validates declared Mars/Jupiter
opening metadata. Chosen-action legality, exact scores/supported floors, random
prediction gaps and terminal consistency are separately recorded. This is not
full source-adapter or player-profile qualification. Source profiles remain
synthetic `all_unlocked_discovered_v1`; retry evaluation is explicitly disabled
and clean. No user saves or actual checkpoint restores were evaluated.

## Closed budgets — do not renew

The resumed push retained its original one-use limits. Its authorizations are
`authorization.json` and `authorization_resume_20260913.json` under the push.
The resumed deadline was19:25UTC, source workers19:18UTC. Work stopped cleanly
within that window. These deadlines and allowances are historical, not reusable.

| Scope | Spent / cap | Reserved seconds | Actual seconds |
| --- | --- | --- | --- |
| Complete source attempts | 12/12 | 2160 | 484.6128155000624 |
| Source-agent mechanical workers | 4/12 | 60 | 1.1228700000210665 |
| Seed search | 6 requests; 300/300 seconds reserved | 300 | 127.86543420003727 |
| Seed-source mechanical workers | 7/12 | 105 | 1.1098500000080094 |
| Root detached components | 7/8 | 105 | Exact sum in `FINAL_BUDGET_281.json` |

All unused mechanical allowances are closed at this stopping point, not
converted into complete attempts or carried into the next chat. Search included
one timeout. Its last request completed4,000,000 indices: no Mars matches among
2,700,000, and three Jupiter matches among1,300,000. Raw `not_found` means the
requested fourth match was not found; it does not erase the three matches.
These rates describe that searched range, not future yield or win probability.

The original `runs/weakness263_requests` still contains only its preserved plan.
However, the allowance behind it **was consumed** by the fresh
`runs/weakness266_current_pilot1` experiment, documented in267. All16 workers ran:
6 losses,5 timeouts,5 unsupported, no wins; 729.6207304s actual,80s/worker and1320s
cumulative caps. It compared262 against266, not current281. Do not mistake the
unchanged plan directory for an unused allowance. Earlier component/experiment
leases also remain spent. A new chat must not silently relabel old experiments
or renew their budgets; genuinely new evaluation needs a fresh bounded authority
and prospective registration before any worker.

## Research, remaining weaknesses and development phase

We are in **failure-driven policy development and evaluator qualification**,
not release qualification for measured win rates or a demonstrated winning
autopilot. Online advice suggested Blue-seal/Telescope Planet growth, rank
consolidation through Strength/Death, and later Glass/Steel. Original source
confirmed the important mechanics; old online guides can reflect older patches.
Mars adds more base Chips/Mult per level than Jupiter; Planet X is initially softlocked until Five of
a Kind is actually played. Five of a Kind is a conditional development option,
not an automatic reason to abandon a developed Four-of-a-Kind plan. Four cards
leave a fifth-slot option against Bell but do not make the hand immune to Bell.
See the research note for URLs and mechanical qualifications.

The highest demonstrated gaps are early-blind survival, translating acquired
Blue/Steel into enough timely Planet generation, consuming useful inventory,
and jointly planning hands/discards/consumables. Static opening search predicts
a catalog under a declared route; it does not prove the initial Big Blind can
be beaten, that every purchase is affordable, or that the build survives or is
retained. No generally optimal opening pattern has been demonstrated.

Complete joint resource planning, broader strategic cash-versus-upgrade
comparison, meaningful changed-action calibration, unseen terminal validation,
manual-retry benefit and measured total time-to-finish remain unfinished.
Expanded Legendary/Rare-filter acquisition and retention evaluation also remains
unfinished. Current tools/fixtures are useful infrastructure, not substitutes
for these outcomes. `NEXT_PRIORITIES_281.md` orders the next work.

## Operational constraints

Preserve all tracked modifications and untracked work on
`codex/exact-search-speedups`. Most development is uncommitted. No commit, reset,
clean, deletion of existing work or PR. Install tested runtime slices promptly
with `tools/advisor_eval/install_slice.py`, explicit files, backups, current
settings/save protection, verified hashes, versions and ledgers. Never restore
old settings. Preserve both native DLLs; changed native work requires the
documented sidecar/evidence gate. Tooling/docs-only changes need no runtime release.

Never launch Balatro.exe, even with headless flags; never foreground, fullscreen,
restart, stop or control it or execute live gameplay through tools. Hidden
bounded probes may read the executable as a ZIP and use isolated lua51.dll
execution. No saves for evaluation. No neural/GPU training, scheduled tasks or
automations. Generalize mechanics rather than hardcode seeds/challenge names.
Preserve deterministic complete common-world comparisons,140000/50000/25000
ordinary/shop/consumable budgets and70-score fast clear, Glass/population,
whole-inventory Perkeo/Negative/Observatory, Kings Strength/Death, exact
Yorick/Burnt and safe growth. Unsupported mechanics remain explicit.
