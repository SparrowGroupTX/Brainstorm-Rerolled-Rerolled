# Lucky source components and attempt adapter preparation

This tooling supports fresh root-registered B1/B2 components under the current
287 authority. It grants no independent job, replacement or reusable allowance.
The source executable is read only as a ZIP; the game is never launched or
controlled. No saves are read, loaded or modified.

`lucky_source_truth.py` builds one finite source-method truth table from exact
frozen `card.lua` and `functions/common_events.lua` functions. B1 uses a King of
Spades, ordinary Lucky enhancement, base level-one High Card, no Jokers, no
edition and no repetition. It covers the four independent Mult/cash assignments.
B2 adds a Red seal and covers all sixteen assignments across the base evaluation
and one repeated evaluation. The advisor input starts at $10 with three hands,
two discards and a 10,000-chip ordinary blind. There is no draw, terminal attempt,
empirical probability estimate or seed search in these components.

The untouched source `eval_card`, Lucky chip/cash methods and Red repetition
method supply conditional effects. The harness checks Mult then cash random
call order, the source's Lucky trigger flag, returned cash, temporary cash buffer
and its actual reset callback. Chip/Mult accumulation, consuming returned cash
once, and event scheduling are **explicit test doubles**. This is a conditional
source-method boundary, not original full scoring-phase or adapter qualification.
Each case compares the resulting score and cash with frozen286 `after_play`,
checks unchanged input and preserved population/inventory/resource counters, and
emits its entire trigger/event timeline. The worker retains partial output if a
case fails. A failed or timed-out job is consumed and cannot be retried here.

The root coordinator creates an immutable `prospective287_job` registration
binding the unchanged authority hash, one manifest hash and the exact command.
Its start marker binds the registration hash, actual coordinator PID and an
absolute deadline. `lucky_source_worker.py --registration <path>` validates that
chain and requires the marker PID to equal its actual process parent before
creating an exclusive worker-consumed receipt. It then rechecks source ZIP,
isolated runtime, policy modules, source snippets and harness hashes, executes
only the generated Lua and rechecks all frozen inputs. The parent imposes the
30-second subprocess cap covering all worker setup, verification and output.

The accepted prepared inputs are under
`runs/diagnostic287_20260913_222344/b_preparation2/`. The first preparation remains
preserved because root review added actual parent-PID enforcement before any B
registration or execution. `preparation_failure1.json` separately records a Python
syntax error in the preparation script before any source read or file creation;
it consumed no source job. Source/runtime hashes were freshly read under this
new authority and match the historical recorded bytes. Preparation alone proves
no executed mechanics result; use the root B1/B2 job logs and final records.

Routine tooling tests use handwritten callback doubles and synthetic files only:
sixteen Python tests cover extraction, caps, immutable registration, expired or
wrong authority, PID admission, one-use consumption and post-run mutation; the
Lua fixture checks all twenty controlled assignments and rejects wrong
repetitions, double-paid getters and score disagreement (ninety checks). These
tests do not execute original source. Their receipt is `validation/focused1/`.

## Full-attempt compatibility inspection

The current full-attempt adapter consists of exactly six runtime files:
`engine_probe.py`, `engine_probe.lua`, `engine_run.lua`, `engine_contract.lua`,
`opening_support.py` and `benchmark.py`. Freeze all six together. Freeze the
read-only aggregation helpers separately (`development_report.py` and, when used,
`paired_policy_audit.py`); do not invoke the old closed `jokerless_push.py` runner.

`engine_probe.py` preloads every frozen Advisor Lua module. `engine_run.lua`
conditionally wires `resource_finish`, so286's planner participates and282's
older module set can omit it. Whole-blind dependency wiring matches current
product runtime. Retry context stays disabled and clean. Source filesystem calls
use an isolated in-memory Love filesystem; `io.open`, `io.popen`, shell execution,
native extension loading and external Lua file loading are disabled in the Lua
dispatcher. These are static integration observations, not proven complete-run
compatibility or whole-adapter qualification.

The direct leaf command for each separately registered C job is:

```text
python -u <frozen-adapter>/engine_probe.py --episode --install <rules-and-runtime-directory> --policy-root <full-frozen-policy> --challenge c_jokerless_1 --seed <declared-seed> --unlock-profile all_unlocked_discovered_v1 --debug-decisions --seed-selection-evidence <frozen-declaration.json> --jokerless-opening-recipe <frozen-recipe.json>
```

The root must impose the hidden 180-second process cap and preserve complete
stdout/stderr, including partial flushed JSON after timeout. The dispatcher has
its own 500-action limit. Do not add replay, scenario, search or stop flags. It
checks the original-source catalog prediction against the complete fixed recipe
before autonomous advice. The recipe remains a selected development opening;
acquisition and survival are not assumed.

Selected play predictions are independently re-scored for the action actually
chosen; exact scores, supported floors and unresolved random predictions remain
distinct. Terminal logic gives actual `GAME_OVER` priority over incidental
`GAME.won`; in-memory challenge completion is required for a win. After each job,
audit complete provenance, action legality, score/floor coverage, random gaps,
terminal consistency, population/cash/inventory and the exact first divergence.
The current inspected adapter exposes no concrete startup incompatibility, but
only fresh attempted execution can establish an outcome on a selected seed.
