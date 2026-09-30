# 387 candidate checkpoint — 2026-09-25

Repository candidate: **2.185.0-alpha**, uninstalled. Installed checkpoint:
**2.184.0-alpha** (exact hash receipt `SESSION_RESET_386.json`). Frozen
candidate digest `bf09ad12fcd2327850d02c0e6dd8c308f952c93c26e8f3341aeaa9ccd99fb1b2`.
Changed runtime files: `Brainstorm/Advisor/{search,decision,player_journal}.lua`,
`Brainstorm/Core/Brainstorm.lua`, `Brainstorm/steamodded_compat.lua`.
`runs/yorick387_candidate/freeze.json` and `validation/report.json` attest
108 frozen runtime/dependency and 295 test hashes; full candidate gate passed
255 Lua fixtures and 392 Python tests with unchanged hashes. No exact-installed
gate exists because no installation occurred.

Evidence and limits: `development387/{SCOPE,REPORT}.md`,
`capture/manifest.json`, `analysis/loaded_2184_prefix.json`,
`analysis/loaded_2183_complete.json`; WR-032 in `WIN_RATE_RESEARCH.md`.
The frozen 2.184 public prefix covers completed segments 1–7/7,143 events,
one win, one loss and an unfinished third start. Later events and current
batch completion were not audited. Public loaded label is not loaded-byte
provenance. No real-game gain from 2.185 is demonstrated.

Do not install while the user's current ten-start batch remains unverified as
ended. After normal user completion/exit, compare installed baseline, current
settings, seven native DLLs, frozen candidate and tests; use `install_slice.py`
with exactly the five changed runtime files and backup, then validate frozen
exact-installed bytes. No restart or game control by tools. Preserve every
journal and all tracked/untracked work.
