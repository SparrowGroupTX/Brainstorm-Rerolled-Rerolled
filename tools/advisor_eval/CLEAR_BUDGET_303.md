# 303 clear discovery and phase-copy budget

Root integrated the reviewed four runtime modules and three fixtures after302
was installed and verified. Full candidate regression passed150 Lua fixtures and
300 Python tests, with frozen policy digest
`3179b32252e53e0424af3bcd1f99384ca0bb8e5dd80db4e03cdcfe0f52c53ae8`.
Exact installed evidence is under `runs/clear303_installed/`, its validation and
`runs/clear303_final/`. No source attempt result belongs to303 yet.

## Observed defect

Read-only C02 audit found two decisions labelled `fast_clear` after the ordinary
enumeration had already reached clear discovery at168/113 scores. Their full
decision totals were173/117, including four conservation scores each. C01 had the
same values. Those were ordinary-budget reliable-clear shortcuts; the label did
not establish a seventy-score whole-decision path. `phase_copy.apply` nevertheless
selected the seventy-score ceiling from the flag and therefore had no remaining
allowance for a complete Burnt comparison. No trace is imputed a different outcome.

## Changes

`search.lua` distinguishes discovery in its initial at-most32 candidate shortlist
from discovery in later enumeration. Only the former emits `fast_clear`; later
stops emit `clear_shortcut`. Both retain the existing sixteen-score conservation
ceiling, stop expensive continuation search and retain incomplete-play coverage.
Their diagnostics record the discovery path and the70/140000 aggregate limit.

`decision.lua` handles both shortcuts with the same six-score development and
twelve-score growth ceilings, clipping each call to the remaining whole-decision
budget. It still skips expensive specialists after a supported clear.

`phase_copy.lua` retains the same at-most30 score complete paired comparison and
existing70/50000/140000 ceilings. The corrected search flags allow a late clear to
use only its unused ordinary allowance. Diagnostics expose the actual aggregate
limit and remaining work. Every proposed reorder remains a real first action
requiring fresh advice; no imaginary arrangement is applied to input.

`retry_policy.lua` explicitly rejects both incomplete clear shortcuts. Existing
reliable-clear guards in finishing specialists remain sufficient, and expensive
specialists are still bypassed by the shared decision.

No numerical compute cap is raised. There is no new seed, source, captured-state,
terminal or player evaluation and no speedup, win-rate or rescued-run claim.

## Synthetic validation

Six ordinary Lua fixtures passed after one fixture dependency correction:

- New `advisor_clear_budget.lua`:33 checks. Real search classifies early and later
  discoveries separately, raw scoring calls remain counted, both post-clear
  branches respect aggregate boundaries, and an exact synthetic Burnt setup
  becomes available within the existing ordinary allowance. Input and physical
  inventory remain unchanged; insufficient remaining allowance still fails closed.
- Existing fast clear24, retention74, phase copy184, finish integration5 and
  retry91 checks passed through detached module paths. The fast-clear fixture's
  two later-enumeration assertions now expect `clear_shortcut`; retry adds one
  rejection case for that incomplete search scope.

The first run's5/6 failure is recorded in `fixture_failure_01.txt`: the new fixture
omitted the vanilla identity-registry dependency, and the product guard correctly
declined. No policy guard was weakened to repair that fixture.

## Preserved integration provenance

`development299/stage_clear303.py` verified every original runtime hash in the
draft's `integration_base_sha256.json` and every reviewed draft hash before
staging. The normalized `runtime.patch` remains review material; it did not
overwrite intervening changes.

The new fixture is `tests/advisor_clear_budget.lua`; updated expectations are in
`tests/advisor_fast_clear.lua` and `tests/advisor_retry_policy.lua`. Existing
retention, phase-copy and finishing integration fixtures also passed in the
focused `development294/clear303a/report.json` run. Other draft wrappers were
not installed. Source modules are `Brainstorm/Advisor/search.lua`, `decision.lua`,
`phase_copy.lua` and `retry_policy.lua`.

`READY_SHA256.json` records the reviewed draft and integration files. The original
C02/M10 traces, snapshots, policies, failures and audit receipts remain immutable.
