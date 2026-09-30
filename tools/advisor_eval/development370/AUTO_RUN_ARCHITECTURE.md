# Auto-run action lifecycle candidate — 2026-09-23

Status: **installed 2.170.0-alpha after the user-started ten-run marathon
completed; exact-installed gate passed; activation unconfirmed**. The cohort
loaded the prior public 2.169 label; the release is not evidence of better
play. Candidate and installed policy/test hashes match, with 106 frozen
runtime/dependency files. Exact release evidence is in
`runs/auto_arch370_installed/record.json`,
`runs/auto_arch370_installed_validation/report.json`, and
`runs/auto_arch370_final/final_verification.json`. The prior 369 checkpoint
and its 105-file manifest remain preserved as history.

## Behavioral scope and acceptance

- Preserve the existing controller, search ownership, terminal receipts,
  profile binding, session caps, exact action freshness and journal redaction.
- Put the exact pre-dispatch shop card, source, game and debit in one injected
  `Core/auto_run_settlement.lua` component. Its read-only check must wait for
  blocking base events, debit, card exit and the appropriate owned Joker,
  voucher or opened-pack evidence. Decorative nonblocking events do not block.
- Bind the receipt before Execute. A throwing or possibly queued callback keeps
  it; only confirmed rejection without an execution latch, an accepted new run
  or a verified checkpoint load clears it. A changed GAME identity invalidates
  the old receipt. The adapter's earlier transition, controller, save and
  loading gates remain before settlement.
- Use one acknowledgement predicate/commit in `Advisor/auto_run.lua` while
  retaining collection's acknowledgement before retirement and teacher's
  separate arbitration order. Exact changed fingerprint, ready observation,
  matching published advice and successful log are required before clearing
  `pending_action` or allowing another action.

Changed runtime: `Core/Brainstorm.lua`, `Core/auto_run_product.lua`, new
`Core/auto_run_settlement.lua`, `Advisor/auto_run.lua`, plus the two version
stamps. Targeted manufactured fixtures: new `advisor_auto_run_settlement.lua`,
`advisor_auto_run.lua`, `advisor_auto_run_product.lua`, and dependency injection
in `advisor_auto_observation.lua`, `advisor_legendary_auto.lua`,
`advisor_shop_settlement357.lua`. No strategy/scoring/search recipe, native DLL,
settings, log, save or profile file changed.

## Validation and review

The six affected Lua fixtures passed locally, including delayed purchase
settlement, exact adapter wiring, stale advice, log rejection and collection
retirement ordering. Full frozen candidate evidence:
`runs/auto_arch370_candidate/manifest.json` and
`runs/auto_arch370_candidate/validation/report.json` with raw Lua/Python logs.
The policy digest is
`53df27b9da3e53cd933636b5cc03e1ba56e1ae0f754397cb884a6d95c6e7fbf6`.
Read-only preflight found exactly one runtime file added and four changed
between the repository candidate and the installed 369 baseline: precisely
the five files listed for installation below; no runtime file was removed.
The full candidate passed **241/241 Lua fixtures and 391 Python tests**; both
policy and tests stayed hash-identical during the gate, below the 60-second
per-suite cap. A first validation invocation used the candidate parent rather
than its `policy` subdirectory and exited before creating a gate; the corrected
invocation passed. `VALIDATION_SETUP_ERROR.md` records the command and error.
It is neither a test failure nor a passing installed validation.

One read-only reviewer checked the action boundary and one focused recheck
found three fixture attach callers missing the new injected dependency. Those
were corrected before the full gate. The recheck found no other behavioral
drift in guard order, throw handling or acknowledgement. No further reviewer
cycle is planned for this slice.

This is a bounded first refactor, not the complete architecture proposed in
conversation. Start/Resume ownership still spans the product adapter and
controller, and teacher preset construction still spans the UI, product and
advisor runtime. Consolidating those later would require its own behavior
contract, fixtures and measured benefit. No development-speed or win-rate
improvement is measured by this candidate.

## Release boundary

The completed release waited for the user to report the ten-run cohort's
end. Repository candidate, tests and installed 369 baseline matched frozen
hashes before `install_slice.py` installed exactly these runtime files:
`Advisor/auto_run.lua`, `Core/auto_run_product.lua`,
`Core/auto_run_settlement.lua`, `Core/Brainstorm.lua`,
`steamodded_compat.lua`. The 90-file deployment and 106-file runtime freeze
match repository and installed bytes; configuration and all seven native
DLLs were preserved. Exact-installed validation passed the same 241 Lua
fixtures and 391 Python tests as the candidate. The backup is
`C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm\deployment-backups\advisor-20260923-121150`.
Installation still requires the user's normal restart for activation. No
post-repair game cohort is included.

No tool-started game action, hidden search, captured-state evaluation,
source-game component, complete simulation, GPU training, automation or new
experiment occurred. All historical experimental allowances remain closed.
