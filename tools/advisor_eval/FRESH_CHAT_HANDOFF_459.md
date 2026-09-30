# Fresh context: simulator accuracy for Balatro RL

Documentation checkpoint459, 2026-09-29. Read this and the
[compact continuation contract](../../ADVISOR_RESUME_PROMPT.md) first. Load only
the relevant sections of the [fidelity plan](SIMULATOR_FIDELITY_PLAN_452.md) next.
Do not reload archived conversations or walk all historical handoffs.

## Goal and current state

The user explicitly wants the simulator accurate to the real game so we can
begin training a Balatro RL model. Immediate target: **Red Deck / Gold Stake,
Perkeo/Yorick, win-first**, including the user's actual mod/configuration and
searched-opening distribution. The direction and ordinary engineering are
approved. Full lifecycle fidelity and training readiness are **not established**.

- Workspace: `C:\Users\trevo\Documents\GitHub\Brainstorm-Rerolled-Rerolled`.
- Continue existing branch `codex/exact-search-speedups`; preserve its extensive
  tracked and untracked work. Do not clean, reset or create a replacement checkout.
- Production is the heuristic **installed451 / 2.226.0-alpha**, already validated.
  Do not reinstall to resume. Installation is not evidence of loaded activation.
- Current Python overlay: `tools/advisor_learning/simulator_patches.py`,
  `PATCH_ID = "development458-source-fidelity-v6"`, SHA-256
  `7a539e3070ec3a5cb458f9413a97f794e10643b9221444aef5f09f829614e084`.
- The pinned Jackdaw upstream355 remains unchanged. Repairs are in-memory overlays
  in `tools/advisor_learning/lifecycle_453.py` through the applicable458 modules.
  The rejected355 learned policy is not deployed and is not today's RL interface.
- Latest458 source probe is prepared, **unexecuted, and awaiting explicit approval**.
  The approval question received no answer before this documentation request.
  Old454/456 one-use source leases are consumed; the hour of engineering was not
  treated as new source-worker authority. No training job was started.

The Python learning environment has broad phases with fidelity exclusions. The
production Lua continuation adapter stops at a supported blind clear and has
`round_rewards_modeled=false`. Isolated original-source harnesses are selective
references. None is currently a qualified whole-game oracle.

## Compact qualification matrix

Each row's report links the exact fixtures and receipts. A handwritten independent
source-rule model is manufactured evidence; it is not execution of original code.

| Slice | Delivered behavior/evidence | Limits that remain |
|---|---|---|
| [453](development453/REPORT.md) | Plain Perishable Juggler expiry removes passive capacity; manufactured tests. | Broad near-expiry guard remains; other passive effects/compositions unqualified. |
| [454](development454/REPORT.md) | Plain Golden final-life cash-out bonus repair; seven isolated original-source cases agreed at settled/evaluation boundaries. | Not complete round-event or cash-out/shop sequence parity; source lease closed. |
| [455](development455/REPORT.md) | Cash-out shop-entry bookkeeping: counters, hands/discards, shop flags and preserved previous-round fields; six manufactured cases. | Does not qualify stock generation or full shop. |
| [456](development456/REPORT.md) | One original cash-out probe; offline recovery found six settled-field agreements. | **Primary result remains parse_error** from mixed native/Python stdout. Raw failure preserved; recovery is not a clean run. Lease closed; no retry. |
| [457](development457/REPORT.md) | Physical booster slots persist across shop population; USED slots skipped, keys/positions retained. Eight stock cases plus one opening case agree with independent model. Native stdout flush repaired with manufactured success/error tests. | Plain no-tag prescribed draws only; original shop not executed. Flush checked for bundled Lua DLL/Windows CRT. |
| [458](development458/REPORT.md) | Physical slot becomes USED **before** opening callbacks; old observer sees pack key, repaired observer sees USED. Invalid-action controls preserve cash/slot. Original branch probe prepared. | Manufactured callback-order qualification only; source worker has not run. |

Last engineering regression: **68 focused tests passed**. After the final parser
strictness change, its four parser tests passed again. This documentation turn
does not claim a new full test run. Reuse the command for relevant code changes:

```powershell
python -B -m unittest tools.advisor_learning.test_lifecycle_453 tools.advisor_learning.test_lifecycle_454 tools.advisor_learning.test_lifecycle_455 tools.advisor_learning.test_lifecycle_457 tools.advisor_learning.test_lifecycle_458 tools.advisor_learning.test_simulator_patches tools.advisor_learning.test_environment tools.advisor_eval.development457.test_runner_capture tools.advisor_eval.development458.test_probe_parser -v
```

## Immediate next step: finish the selected booster source comparison

Read [458 acceptance](development458/ACCEPTANCE.md) and the exact
[one-use proposal](development458/SOURCE_EXECUTION_PROPOSAL.md) if pursuing this
probe. Its runner, prepared Lua, expected observations and dependencies are frozen
by [SOURCE_PROBE_PREPARED.json](development458/SOURCE_PROBE_PREPARED.json), SHA-256:
`89319182932454a41483f0a0f9bf6ef659532ad6f755d1af7f6dc2fc1a6e7e7e`.

The probe compares verbatim original `game.lua:3145–3159` stock-loop statements and
`functions/button_callbacks.lua:2241–2247` inner Booster-use statements against
independent expectations and frozen candidate observations. It covers eight fixed
457 fixtures, physical slot/key/order, prescribed draw consumption, and USED as
observed by the opening callback. Stock and post-open snapshots are distinct.

Caps: **one worker, one Lua state, eight stock calls, at most sixteen prescribed
get_pack calls and sixteen stub Card constructions, one inner-use/open call,
20-second worker wall cap, 30-second coordinator target, 1 MiB attempt artifacts,
no GPU, numeric thread environment one, no retry**. No hard OS CPU quota is claimed.
Only `development458/source_attempt_001` may be consumed; it is absent at handoff.

Safe optional integrity check (does not execute original Lua or create a lease):

```powershell
python -B -m tools.advisor_eval.development458.run_source_probe --check-only
```

Do not regenerate prepared458 artifacts or pass `--authorization` merely to
resume. If the user explicitly approves this exact proposal in the new chat,
record that approval and execute it once without asking again. Preserve any
failure and stop at the first unsupported result. Preparation, the general goal,
and this handoff are not execution approval.

Even a successful probe cannot qualify prices, affordability, cash charging,
natural RNG/pools, tags, full `Game:update_shop`/`G.FUNCS.use_card`, event scheduling,
Perkeo shop exit or next blind: those paths are stubbed or outside the boundary.

Without that approval, continue useful authorized source inspection and
manufactured engineering. The next candidate slice is held-card round-end
Gold/Blue Seal/Red Seal/Mime repetition and ordering against rental/expiry. Inspect
actual source and candidate first; select one demonstrated mismatch, independently
specify its state/events, show old failure and repaired success with adverse and
held-out composition cases. This is a proposed inspection target, not a claim of
a newly proven bug. Keep adjacent unsupported guards. Ask only for a specific
still-missing execution allowance after the work/proposal is concrete.

## Remaining path to training

1. **Finish the supported lifecycle.** Round-end held effects/copy order/rental/
   expiry; cash-out conservation; complete shop pricing/debt/legality, tags,
   vouchers, first Buffoon guarantee and stock; Perkeo exit copying with expanded
   pool and independent ability state; next-blind resets/start/Boss effects.
2. **Qualify sequences and randomness separately.** Independent canonical state
   and ordered events, exact prescribed-outcome transitions, conservation and
   legal actions, held-out multi-round compositions including losing paths. Check
   random pools, stream consumption/order and correlations separately; distinguish
   distributional fidelity from source-seed equivalence. Define the supported
   opening population; synthetic post-Soul states need not match searched openings.
3. **Specify the RL environment.** Reset/step, action masks, public observations,
   win-first reward, terminal evidence and truncation. Unsupported/error/censored
   outcomes are not losses. Private seeds, unseen order and future outcomes stay
   out of features and action selection; test invariance. Split evaluation by
   whole runs and seed/opening families. The355 network/labels/reward are unsuitable
   as an assumed current contract. A supervised pilot is optional, not prerequisite.
4. **Only then propose a bounded training/evaluation pilot.** Freeze mechanics,
   inputs, code and budgets; obtain any specific missing authority. Simulator wins
   alone do not establish real-game improvement, optimality or population win rate.

These are gates and unresolved scope, not a promise that a finite suite proves
all Balatro interactions. Stop each engineering delivery after one coherent slice.

## Preservation and on-demand context

Never control or launch Balatro, read saves/profiles, silently run source workers,
full games or training, or reopen old budgets. Preserve installed451, settings,
DLLs, public journals, raw failures and frozen evidence. No release is needed for
these simulator/tooling/docs changes. Detailed standing rules are in the contract.

Historical overlay/runner bytes remain in `development454/frozen`,
`development455/frozen`, `development456/frozen`, and `development457/frozen`;
do not overwrite them with current code. The456 raw attempt and offline recovery
are both retained. Current458 manifest verifies its22 dependencies.

Only as needed: [architecture](ARCHITECTURE_MAP_452.md),
[baseline evidence](CURRENT_EVIDENCE_452.md), [strategy](STRATEGY_CONTEXT_452.md),
[workflow](WORKFLOW_452.md), [installed451](INSTALLED_CHECKPOINT_451.md).
Those452 documents are historical baseline context; the matrix above records later
simulator work. [Reset receipt459](development459/REPORT.md) records this docs-only
delivery. [Copy/paste prompt](RESUME_PROMPT_459.txt) starts the next chat.
