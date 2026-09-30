# 393 candidate checkpoint — 2026-09-25

Repository **2.191.0-alpha** is frozen, full-candidate-validated and **not
installed**. It incorporates the uninstalled 2.185–2.190 work; do not
install any intermediate candidate. Installed baseline is still 2.184.0-alpha
under `SESSION_RESET_386.json`; public loaded label in the previous copied
cohort is 2.184, and exact loaded process bytes are unconfirmed. The user's
new ten-start sprint is running separately; preserve it and do not install
during play.

Candidate digest:
`704117c068d6e6a2c1bdce33e1698fbdb788d8df8f1579c80357ebaa45c9aad0`.
`runs/copy_slot393_candidate/freeze.json` freezes 108 runtime/dependency
hashes and 300 test hashes. The full candidate gate in `validation/` passed
**260 Lua fixtures / 392 Python tests**, with frozen policy/test hashes
unchanged. Only `strategy.lua` and the two version headers changed from the
frozen 2.190 candidate. The exact nine runtime paths changed from installed
2.184 are listed in `freeze.json` and remain the nine listed below:

- `Brainstorm/Advisor/acorn_belief.lua`
- `Brainstorm/Advisor/blind_finishing.lua`
- `Brainstorm/Advisor/decision.lua`
- `Brainstorm/Advisor/player_journal.lua`
- `Brainstorm/Advisor/search.lua`
- `Brainstorm/Advisor/shop_sequences.lua`
- `Brainstorm/Advisor/strategy.lua`
- `Brainstorm/Core/Brainstorm.lua`
- `Brainstorm/steamodded_compat.lua`

After normal user exit, first preserve the new sprint's completed public
segments and verify the exact installed 2.184 policy, current settings hash
without restoring old bytes, all seven native DLLs, and frozen candidate
and test hashes. Then use `install_slice.py` with explicit files and backup;
freeze and run exact-installed validation and verify all deployment hashes,
settings and native DLL preservation. Installation does not establish
activation, rescue of any recorded loss or a higher real-game win rate. See
`development393/REPORT.md`, WR-043/044 and `NEXT_PRIORITIES_393.md`.
