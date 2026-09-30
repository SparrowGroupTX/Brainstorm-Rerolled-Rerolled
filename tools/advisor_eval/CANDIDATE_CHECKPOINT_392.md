# 392 candidate checkpoint — 2026-09-25

Repository candidate **2.190.0-alpha** is frozen and full-candidate-validated,
**not installed**. Installed baseline remains 2.184.0-alpha, exact receipt
`SESSION_RESET_386.json`, digest
`851a189fe212211b0d7ced23abf3276eb04089e7658536db950adea9feeb3ccc`.
The completed copied ten-start session is loaded-label 2.184 and win-first;
it cannot measure any 2.185–2.190 improvement. Its complete 25-segment
public copy is `development392/logs1` with hashes in `capture/`.

Candidate digest:
`d5e9b7288a8d5c88c870eec812470b9fd0e4b9309bb5e79fa212bd7aea4b5ac8`.
`runs/mouth_madness392_candidate/freeze.json` contains exact hashes for 108
runtime/dependency and 299 test files. The full candidate gate passed
**259 Lua fixtures and 392 Python tests**, with policy/test hashes unchanged.
The new repair closes one observed empty-deck Mouth stop and rejects a
destructive Madness purchase with a vulnerable win-first core. It incorporates
the already-validated, uninstalled 2.185–2.189 corrections; do not install
those separately. Exact diagnosis, limits and review anchors are in
`development392/REPORT.md`, WR-041/042 and
`runs/mouth_madness392_candidate/validation/`.

After the user's new sprint ends and they exit Balatro normally, reverify
installed 2.184 policy, current configuration hash without restoring it, all
seven DLLs, and frozen candidate/test hashes. Then use `install_slice.py` with
explicit backup and only these nine changed runtime paths:

- `Brainstorm/Advisor/acorn_belief.lua`
- `Brainstorm/Advisor/blind_finishing.lua`
- `Brainstorm/Advisor/decision.lua`
- `Brainstorm/Advisor/player_journal.lua`
- `Brainstorm/Advisor/search.lua`
- `Brainstorm/Advisor/shop_sequences.lua`
- `Brainstorm/Advisor/strategy.lua`
- `Brainstorm/Core/Brainstorm.lua`
- `Brainstorm/steamodded_compat.lua`

Freeze and run the required exact-installed gate, then verify all deployment
hashes and untouched current settings/seven native DLLs. Do not install
during the new batch. Installation does not establish activation, a rescued
Mouth/Acorn run or improved win rate; later normal user restart and public
play are needed to observe those.
