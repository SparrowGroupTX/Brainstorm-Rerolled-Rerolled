# Bounded public-log review, 2026-09-15

The latest inspected public journal declares **Brainstorm v2.121.0-alpha**. It shows one completed loss and a second ongoing run prefix. Each skipped only the opening Small Blind for the searched Charm/Legendary route; no later skip was recorded. Development actions after an available clear are real, but the logs cannot isolate advisor computation time or establish that omitting development or skipping later blinds improves total completion time.

This read covered exactly six previously identified files named `session-20260915T051708Z-1-000001.brj` through `000006.brj` under `C:/Users/trevo/AppData/Roaming/Balatro/advisor_player_log_v2/`. The fixed read contains2,287 events from05:17:08Z through05:33:18Z,23,129,656 physical bytes and443,352,240 reconstructed bytes. All segment/event hashes and cross-segment sequence/frame chains decoded without errors. File sizes and modification times were unchanged across each bounded read. The archive can continue after this prefix; no further log read is implied.

No save/profile, settings, executable, native runtime, source simulation, replay, rescoring, search or game control was used. The only external files opened were those six opt-in public journal segments. Parsing used the existing bounded `tools/advisor_eval/read_player_log.py`, with32MiB physical/512MiB decoded/6,000-event/50-second limits; actual parsing took4.828seconds. The public schema includes loaded profile observations, but no profile file was opened.

| Recorded run | M4BVSY11 | YVYN2Z11 prefix |
|---|---:|---:|
| Auto action attempts, all matched to accepted Execute callbacks |251|202|
| Settled observations linked to those callbacks |250|201|
| Blind selections / opening Small skips |22 /1|20 /1|
| Plays / cash-outs |31 /21|23 /20|
| Discards / explicitly titled Yorick growth discards |53 /4|13 /9|
| Owned-consumable uses / uses explicitly retaining an existing clear |24 /18|23 /16|
| Joker reorders |33|22|
| Shop-phase actions / pack openings / buys |60 /18 /6|62 /28 /3|

The first run records `run_finished` at05:27:09Z with GAME_OVER, zero hands/discards, **Ante8 Big Blind277,272/300,000 chips**, $122,251 actions and600.3516001seconds. These public fields agree with a loss; they do not use GAME.won as a success test. Yorick was X8/countdown10; Perkeo, Droll, Supernova and Brainstorm were retained, with eleven Empress and one Moon in inventory. This is player public-log evidence, separate from the earlier selected synthetic source attempts and their budgets.

The second run's last included settled observation is05:33:18Z, sequence2287, Ante8 round20 shop, $81. There is no second terminal event in this prefix. It must not be labeled a timeout, stop, loss or win. This review confirms only the logged loaded-version declaration, not hashes of loaded modules or the selected game animation speed.

All54 plays have associated before/settled public chip observations. These are observed chip deltas, not an independent exact-scoring qualification. The completed run had two cumulative clear scores over2x the target:14,175/3,200 at Ante3 and34,160/13,500 at Ante4. The second prefix had none above2x; its maximum was118,572/60,000. Many later clears were close: the second run's Ante7 Big was165,600/165,000. A large score at an earlier blind does not show sufficient later scaling.

Concrete extra-development sequence: M4 event293 used Empress while the advice stated an existing clearing play remained; its displayed follow-up estimate was10,935 against3,200. Event298 used another Empress and displayed14,175. Event303 actually produced14,175 in the associated settled observation. The two use-to-next-advice intervals totaled1.0195917seconds. This is an observed local action cost and development gain, not a measured saved-time or survival comparison.

The four deliberately titled M4 growth discards had1.3136477seconds of combined action-to-next-advice intervals; eighteen already-clearing consumable uses had9.3619109seconds. The second prefix's nine growth discards had4.4457657seconds; sixteen already-clearing uses had9.8553643seconds. M4 event458 physically discarded three cards and changed Yorick from X3/countdown3 to X4/countdown23. The second run's growth groups likewise include actual threshold crossings. These actions must not be called cosmetic without accounting for later value and retries.

All such intervals include game action, animation, settling, next advice and logging. They do not isolate advisor CPU. Across matched M4 actions the median interval was2.227seconds and maximum5.781seconds; second-prefix median1.408seconds and maximum12.251seconds. The largest second-prefix interval was cash-out→fresh shop advice, a mixed UI/shop/computation interval. It is not a verified decision latency or a safe estimate of time removable by changing compute caps.

## Logging gaps relevant to the requested speed work

- `Brainstorm/Advisor/player_journal.lua:151–161` captures public state plus advice status/title/lines/action. It does not capture score calls, evaluations, elapsed decision time, budgets, cache hits or structured score/resource proof.
- `Brainstorm/Core/auto_run_product.lua:126` supplies the same text-only advice summary. `Brainstorm/Advisor/auto_run.lua:317` and`:344` record action-observation/attempt timestamps, which mix execution and advice costs.
- Growth scope, paired-discard metadata and rejected alternatives are not structured public-log fields. The action title identifies deliberate growth but cannot identify every module that performed work.
- Skip decisions lack their structured route comparison/qualification receipt. The snapshot exposes visible route data, but this review performed no alternate-route forecast.
- `state_after_actions` is explicitly a first settled observation and can coalesce callbacks; callback acceptance alone does not prove every queued effect completed.

A small public timing/work receipt would make the computation question reviewable before changing caps. Any time-preference policy should keep actual thresholds, resource development, future blinds, inventory/cash and retry costs explicit. The inspected logs do not demonstrate that a general current-hand overkill rule or blanket later skipping is safe.

## Evidence

- `public_log_observations.json`: SHA256 `5d4fc2a143e59b58a6f9a46d9388769e2a72c1703140004c476f7e1befd396c8`; per-input hashes, fixed byte lengths, chain status and bounded projections.
- Authoritative compact report `public_run_report_final.json`: SHA256 `0f8ef1514aed9555288185c92dbe0f3df08b403572e6dac1747a007b47b6c582`; accepted-action joins, observed chip deltas, actual growth transitions, shop counts, mixed timing and terminal evidence.
- Initial `public_run_report.json` remains preserved. Its first-run last-observation field accidentally included the next run's pre-start screen; the final report uses that run's terminal or matching seed boundary. Outcome/action totals were unchanged.
- The initial parser attempt had a Python Counter key-counting error before output. It was corrected without changing logs; this was an analysis-tool error, not an experiment or gameplay result.

All experiment authority remains closed. No runtime or test file was edited by this review.
