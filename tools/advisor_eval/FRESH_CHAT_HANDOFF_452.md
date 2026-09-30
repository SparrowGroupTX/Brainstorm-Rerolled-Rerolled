# Fresh context: simulator fidelity before broader training

Documentation checkpoint452, 2026-09-29. Runtime remains installed451/2.226.0-alpha.
This is the current entry point. Read this file and the compact
[mandatory resume contract](../../ADVISOR_RESUME_PROMPT.md), then the
[simulator plan](SIMULATOR_FIDELITY_PLAN_452.md). Load other documents only for the
selected component; do not traverse every historical handoff.

## What the user wants now

The user asked whether we are ready to train a model, then challenged the idea of
avoiding simulation: why not improve the simulator until it behaves essentially
like the real game? We agreed that this is a concrete engineering objective.
The user then said: "Well, I say let's do it," and asked for extensive documentation
to start a clean chat because this conversation's large context wastes credits.

Accepted direction: improve simulator fidelity for the current Red Deck/Gold Stake,
Perkeo/Yorick, win-first setup. The first recommended milestone is accurate
round-end -> cash-out -> shop -> Perkeo copying -> next-blind behavior, followed
by complete multi-round comparisons. Do not ask again whether to pursue that
direction. This documentation turn did not implement it or launch an experiment.

The previous suggestion of a small supervised candidate ranker remains a possible
training path, not the new primary task. The user chose to prioritize simulator
fidelity. A full model training job, new episode count, source-execution allowance,
worker/time/compute budget or automatic monitoring was not specified. Preserve the
execution boundaries below and in the resume contract; old experiment budgets are
closed. Do useful design/code/manufactured-test work before any necessary narrow
experiment approval, rather than asking broad permission to begin.

## Verified baseline

- Workspace: `C:\Users\trevo\Documents\GitHub\Brainstorm-Rerolled-Rerolled`.
- Existing branch: `codex/exact-search-speedups`. Reuse it; preserve all work.
- Installed version: **2.226.0-alpha**, revision451.
- Exact policy digest: `b302060aff407e963955a02be6ee55f9f764aa897917be95916ac98c23555b59`.
- Candidate and exact-installed gates: **330 Lua fixtures /494 Python tests**,
  110 runtime dependencies /383 frozen test files.
- Latest change: bounded last-Planet use versus hold over two hands with zero
  discards, respecting complete paired worlds, actual inventory and opportunity
  cost. General discard and retention policies were not replaced.
- No learned model is deployed.2.226 loaded activation remains unconfirmed in
  the evidence read for this handoff. Installation alone does not establish it.
- Current runtime status: [installed checkpoint](INSTALLED_CHECKPOINT_451.md).
  Exact receipts are linked there. Do not rerun closed deployment helpers.

## What "the simulator" means here

There are three distinct components, not one qualified engine:

1. **Python learning environment:** `tools/advisor_learning/`, using the pinned
   Jackdaw reimplementation and a small patch overlay. Supports broader episodes
   but has known fidelity exclusions and an older learning interface/objective.
2. **Lua continuation adapter:** `tools/advisor_eval/continuation_adapter.lua`,
   reusing production transitions. Narrow round continuations, at most16 actions;
   explicitly `full_run=false`, `round_rewards_modeled=false`, stops at a clear.
3. **Original-source reference harnesses:** selected isolated callback/boundary
   comparisons. Useful independent evidence, not a fully qualified whole-game
   engine. Some scripts execute original code; reading their source is not
   authorization to launch them.

Do not simply connect these and announce equivalence. The production scorer also
has means, floors, sampled outcomes and explicit unsupported mechanics. Reusing
it reduces duplicate code but does not independently verify correctness.

## First useful work in the new chat

1. Check branch and installed/candidate hashes, preserve current work. This is
   verification, not a request to reinstall or restart the game.
2. Read the plan's first milestone and locate the round-end ordering, passive
   debuff removal and Mime gaps in actual source. Documentation is a map, not an
   oracle. Use the [architecture map](ARCHITECTURE_MAP_452.md).
3. Write prospective acceptance for ONE coherent lifecycle slice. First build the
   canonical state/event comparison contract and a small manufactured lifecycle
   family. Decide reference versus candidate responsibilities explicitly.
4. Preserve exact provenance and all failed comparisons. Find the first divergent
   event; shrink it to a minimal fixture. Use the independent reference where
   permitted, not agreement between two callers of the same implementation.
5. Stop after the selected complete slice. Report supported scope, remaining
   mismatches and exactly what was or was not executed. Do not silently start
   training, whole games, source workers or a fresh historical experiment.

## Evidence and deferred work

Latest preserved public session: `development451/install/captures/001`, loaded2.225,
22 segments/60,585,325 bytes/23,010 events. Eight starts, seven terminal endings:
five wins, two losses, one unended run. Zero archive errors. This is not a complete
ten-run session. The earlier same-session prefix is separately preserved.

The previous complete loaded2.224 session in `development450/captures/001` has
ten endings, seven wins/three losses. It still missed the three-discard benchmark
and had15 clears leaving41 discards. Neither cohort is a population win-rate
estimate or proof that a patch caused improvement.

Juggler/Bootstraps ordering/visible-floor gaps, conditional held bonuses, Ancient/
Idol interactions, changing bosses, large Acorn families, early survival/reserves
and broader consumable planning remain. They are deferred behind the user's new
simulator priority unless directly needed for its selected slice.

## Small reading map

| Need | Read |
|---|---|
| Rules that must survive a new context | [ADVISOR_RESUME_PROMPT.md](../../ADVISOR_RESUME_PROMPT.md) |
| Fidelity milestones, acceptance, RNG, training criteria | [SIMULATOR_FIDELITY_PLAN_452.md](SIMULATOR_FIDELITY_PLAN_452.md) |
| Actual code entry points and source references | [ARCHITECTURE_MAP_452.md](ARCHITECTURE_MAP_452.md) |
| Releases, cohorts, old learning failure and proof limits | [CURRENT_EVIDENCE_452.md](CURRENT_EVIDENCE_452.md) |
| User strategy preferences, including discard/cash/Death rules | [STRATEGY_CONTEXT_452.md](STRATEGY_CONTEXT_452.md) |
| Commands, captures, review tools and preservation | [WORKFLOW_452.md](WORKFLOW_452.md) |
| Concise next task | [NEXT_PRIORITIES_452.md](NEXT_PRIORITIES_452.md) |

The previous five oversized entry points are preserved byte-for-byte under
`development452/before/` with their original relative paths. They total1,211,812
bytes and are history, not mandatory startup reading. Specific old checkpoints
and raw evidence remain in their original locations. Check
`development452/FINAL_VERIFICATION.json` for documentation preservation receipts.
