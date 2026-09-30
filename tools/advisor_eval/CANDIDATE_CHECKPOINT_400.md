# Release completed — 2026-09-26

2.194 was installed after explicit normal user-exit confirmation. Both full
gates passed 265 Lua / 392 Python tests; 93 deployment/109 runtime files,
current config and seven DLLs verified. Exact receipt: `SESSION_RESET_400.json`
and `runs/copydeath400_final/final_verification.json`. Activation awaits the
next normal user game start. The frozen-candidate record below is historical;
its pending-release steps are complete and must not be repeated.

# 400 checkpoint — frozen Blueprint/Death candidate

2026-09-26: **2.194.0-alpha, full-candidate-validated, NOT installed.**
Installed 2.192 remains exact baseline `SESSION_RESET_397.json`, digest
`e74633a088bdf3dfa15d1c87eed099b61ed280f427dfb953273a564d5e8d6e77`.
Normal game exit has not been confirmed. Recheck the process passively;
never launch, focus, stop or control it. Process absence is insufficient
evidence of normal exit.

Final candidate digest:
`97711915fc9705a40f7d0c4f2ac04ed5a6de2210c1efdc34f1eadf9226b61980`.
`runs/copydeath400_candidate2/freeze.json` lists all 109 runtime/dependency
and 305 test hashes. Its full `validation/report.json` passed **265 Lua
fixtures / 392 Python tests** with unchanged hashes. The failed first freeze
in `runs/copydeath400_candidate/` is preserved, not releasable. The old
uninstalled 2.193 Acorn repair is incorporated; do not install it separately.

Compared with installed 2.192, the exact ten runtime paths are:

- `Brainstorm/Advisor/acorn_discard.lua`
- `Brainstorm/Advisor/acorn_ordering.lua`
- `Brainstorm/Advisor/consumables.lua`
- `Brainstorm/Advisor/decision.lua`
- `Brainstorm/Advisor/growth.lua`
- `Brainstorm/Advisor/player_journal.lua`
- `Brainstorm/Advisor/runtime.lua`
- `Brainstorm/Advisor/strategy.lua`
- `Brainstorm/Core/Brainstorm.lua`
- `Brainstorm/steamodded_compat.lua`

The new portion prioritizes supported visible copy acquisition before broad
shop work, strengthens funded Buffoon exploration with a practical $15 plus
cost reserve, evaluates Death's best directed source with contextual stacked
properties, and compares safe public source-fishing before optional use.
Known survival, complete-world, inventory, Glass and aggregate work guards
remain. The scope and limitations are in `development400/REPORT.md` and
`ARCHITECTURE_MAP_400.md`; WR-050/051 distinguish local repair from loaded
benefit. No chance of finding Blueprint or drawing a source is guaranteed.

Latest captured public session has label 2.192: ten starts, four wins, five
losses and one unsupported. Exact loaded bytes and 2.194 outcomes are
unproven. Public session stop 23430 is not a normal game-process exit receipt.

After confirmed normal user exit, preserve any newer public journals; verify
installed 2.192's 92 deployment/108 runtime hashes, current config without
restoring earlier settings, all seven DLL hashes, and the final candidate/test
hashes. Install exactly the ten paths above with `install_slice.py`, version
2.194.0-alpha and backup, inspect its receipt, freeze exact installed bytes,
run the full exact-installed gate, and verify every deployment/config/DLL
hash. No native changes are needed. Any runtime/test change before release
requires a new combined exact freeze and gate. Installation does not prove
activation; await a normal user restart and public loaded evidence.

Keep all workspace work and prior evidence. Full execution/preservation and
closed-budget rules in `ADVISOR_RESUME_PROMPT.md` remain mandatory. Next
work is `NEXT_PRIORITIES_400.md`, not a new experiment or second repair slice.
