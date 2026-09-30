# Acorn332 root integration preparation

This package is prepared against installed/frozen 2.131.0-alpha, digest
`29f5f3112a7170c7a1181bde7ee91b436aa386ec7ff88145d4ed24b711807983`.
Preparation verified all 94 policy/dependency files and the current frozen test
manifest. It wrote only this detached directory. `integrate.py` has not been run
by the preparing agent, including its default read-only mode.

Root can review `spec.json`, `payload/`, and the script, then run:

```text
python -B tools/advisor_eval/development328/acorn332_preparation/integrate.py --apply
```

The script checks both complete sealed component manifests, all 94 frozen331
files in the frozen policy and repository, the passing regression manifest and
every existing frozen test, each destination baseline, and each payload hash
before writing. New destinations must be absent. It creates exclusive one-use
evidence and exact before-byte backups. Failures preserve their receipt and
partial state for review; there is no deletion, reset, rollback or retry reset.
It does not stamp versions, run tests, install or start experiments. Root owns
those subsequent steps. Do not stamp332 before running this baseline-331 gate.

## Runtime and test changes

Nine runtime payloads: four new modules `acorn_belief`, `acorn_ordering`,
`acorn_public`, `acorn_public_hooks`; changed `decision`, `runtime`, `execution`,
`snapshot`, `gold_stickers`. They are the exact sealed component bytes.

Two new production fixtures load `Brainstorm/Advisor` only:
`tests/advisor_acorn_belief.lua` (126 manufactured checks) and
`tests/advisor_acorn_public.lua` (115 manufactured checks). The allocation test
uses the current production planner with a manufactured fresh-copy scorer as
its reference; it no longer loads the historical detached implementation.
The fixed family still compares every score, profile, selected action, input
purity and 1,800-versus-120 observed scoring-state identities. This is allocation
parity evidence, not a measured live speedup.

Four public-slot/minimum-score UI checks are appended to existing
`tests/advisor_runtime.lua`, making its final total646. Existing execution313,
snapshot110 and Gold316 fixtures run unchanged against the new production
modules. Converted production fixtures require root regression; they have not
been executed through this uninstalled integration by the preparing agent.

## Module, deployment and navigation map

`tools/advisor_eval/component_profile.lua` adds the two pure belief/order modules
to its inert module list. No live observer hooks are instantiated there.

`benchmark.policy_sources` and `paired_policy_audit.freeze_product` discover
Advisor Lua files automatically. `tests/run_lua_tests.py` discovers both new
`tests/advisor_*.lua` fixtures. `validate_checkpoint.py` hashes/discovers the new
test files. The general PowerShell installer enumerates Advisor files. These
discovery tools need no edits.

For explicit `install_slice.py` deployment, `spec.json.install_relative_files`
lists all nine Advisor files. Root must additionally handle its normal version
files, freeze the complete final candidate, run full regression, install with
backups/current settings/native protection, and validate exact installed bytes.
No native DLL, settings, save or profile is included here.

Suggested architecture entry: public pre-concealment unordered inventory and
visible rendered activation history live in `acorn_public`/`acorn_public_hooks`;
`acorn_belief` maintains complete consistent permutations; `acorn_ordering`
compares fixed legal plays over all worlds with shared existing budgets;
`decision` intercepts hidden Joker rows before all ordinary scorers/specialists;
`snapshot`, `gold_stickers`, `runtime`, and `execution` preserve public-only
capture, presentation, staleness, retry and physical reorder protections.
Tests are the two new fixtures plus the existing runtime/execution/snapshot/Gold
fixtures. Component evidence remains the two sealed manifests and independent
`development328/ACORN_INTEGRATION_REVIEW.json`.

## Scope and limits

No hidden Joker key, identity, stable ID join, concealed order or future RNG is
used. Complete initial worlds permit a supported first scoring play; subsequent
visible numeric effects may narrow worlds. Unknown effects preserve ambiguity.
Hands of up to nine visible cards are admitted only when the complete legal
family fits the unchanged ordinary140000 budget. All-order comparisons require
their full family within30000 and remaining ordinary budget. Reordering requires
a supported all-world clearing play and a fresh epoch/revision/world-count proof.
Actual owned consumables, Observatory, forced-card/boss legality and retry limits
remain guarded. Unsupported/random/resource-changing inputs stay explicit.

A non-clearing immediate play is a conservative public-information fallback,
not a complete play/discard/consumable plan or a blind-survival/win prediction.
No captured public comparison, original-source execution, completed run, terminal
rescue, player win rate or human superiority was established by this package.

`engine_run.lua` and all source adapters remain unchanged. The completed C05
registration and frozen331 provenance remain intact. Future source graph and
observer qualification require a separate fresh frozen registration; this
integration does not expand the existing experiment allowance.
