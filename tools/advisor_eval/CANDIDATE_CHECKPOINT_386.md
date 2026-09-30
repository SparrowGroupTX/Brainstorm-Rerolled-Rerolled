# 386 candidate checkpoint — 2026-09-25

**Historical candidate record.** The frozen bytes were installed and
exact-installed-validated as 2.184.0-alpha after the user-started batch
finished. Current status and hashes: `SESSION_RESET_386.md`/`.json` and
`runs/resources386_final/final_verification.json`. The pre-install wording
below describes the earlier candidate stage.

Repository **2.184.0-alpha** is a frozen, full-regression-passing candidate;
installed **2.183.0-alpha** remains unchanged while the user-started batch
runs. Current public observations carry the loaded **2.183 label** and
win-first teacher profile, but no exact loaded-byte hash. Do not install or
change the running cohort's policy. No ten-start outcome is inferred from the
partial prefix.

Candidate digest:
`851a189fe212211b0d7ced23abf3276eb04089e7658536db950adea9feeb3ccc`.
`runs/resources386_candidate/{freeze.json,validation/report.json}` freezes
108 runtime/dependency and 295 test hashes. Full candidate validation passed
255 Lua fixtures and 392 Python tests, with matching frozen policy/test bytes.
Only `Brainstorm/Advisor/strategy.lua`, `Brainstorm/Core/Brainstorm.lua` and
`Brainstorm/steamodded_compat.lua` differ from the installed 385 manifest.
The installed 385 hashes, backup, config and seven native DLLs remain in
`SESSION_RESET_385.json` and `runs/cash385_final/final_verification.json`.

Behavior/evidence: `development386/REPORT.md`, exact completed public
segments and `capture/manifest.json`, WR-029–031 in `WIN_RATE_RESEARCH.md`.
Source navigation: `ARCHITECTURE_MAP_386.md`; next steps:
`NEXT_PRIORITIES_386.md`. The current ten-start session is still active as of
this checkpoint; only segments 1–16 were frozen and the writable tail was
excluded. Do not reinterpret 13,054 events as a complete batch.

After the user's normal game exit, first inspect the complete public cohort
without policy/scorer replay. Before installation, verify installed policy
against `SESSION_RESET_385.json`, recheck current config hash without
restoring any old bytes, and verify all seven DLLs and frozen candidate/test
hashes. If any source/test bytes changed, freeze and validate a new candidate.
Only then use `install_slice.py` with the three explicit changed files and
backup. Freeze exact installed bytes and run the required exact-installed
regression. Installation does not prove activation or real-game benefit.

All preservation, public-information, experimental-budget and game-control
restrictions in `ADVISOR_RESUME_PROMPT.md` remain binding. No new experimental
allowance follows from this candidate.
