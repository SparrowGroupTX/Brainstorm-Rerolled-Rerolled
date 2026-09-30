# 391 candidate checkpoint — 2026-09-25

Repository candidate **2.189.0-alpha** is frozen, full-candidate-validated
and **not installed**. The verified installed baseline remains 2.184.0-alpha,
receipt `SESSION_RESET_386.json`, digest
`851a189fe212211b0d7ced23abf3276eb04089e7658536db950adea9feeb3ccc`.
The old preserved public cohort labels loaded 2.184, win-first, but does not
attest exact process bytes. A newer user-started sprint is underway; its loaded
version and outcomes have not been inspected here. Do not alter its settings,
logs, game process or installation while it runs.

Final candidate digest:
`03266454ae9cf9aeb1d6260dc295fba2adc824f7670be8167562eae8ba96696a`.
`runs/hand391_verified_candidate/freeze.json` has exact hashes for 108
runtime/dependency and 298 test files. Relative to installed 2.184, install
only these eight runtime paths after the user finishes/exits normally:

- `Brainstorm/Advisor/acorn_belief.lua`
- `Brainstorm/Advisor/blind_finishing.lua`
- `Brainstorm/Advisor/decision.lua`
- `Brainstorm/Advisor/player_journal.lua`
- `Brainstorm/Advisor/search.lua`
- `Brainstorm/Advisor/strategy.lua`
- `Brainstorm/Core/Brainstorm.lua`
- `Brainstorm/steamodded_compat.lua`

The final frozen gate at `runs/hand391_verified_candidate/validation/` passed
**258 Lua fixtures and 392 Python tests**, with unchanged policy/test hashes.
The older passing 2.188 stage is `runs/audit390_candidate/`; the first 2.189
gate failure against mature Flush/Jupiter stock is preserved at
`runs/hand391_candidate/validation/` and superseded by the narrowed, passing
candidate. Intermediate 2.185–2.188 versions must not be installed
separately. The review, exact public cohort audit, defect scope and limits are
in `development390/REPORT.md`, `development391/REPORT.md` and WR-035–040 in
`WIN_RATE_RESEARCH.md`.

After normal game exit, verify exact installed 2.184 policy, configuration
and seven native DLL hashes, plus frozen candidate/test hashes. Use
`tools/advisor_eval/install_slice.py` with only the eight explicit files,
backup, and verified hashes; then freeze and run the required exact-installed
gate. Installation does not itself establish activation, an Acorn rescue or
improved win rate. No native DLL, setting, save or player journal is changed
by this candidate preparation.
