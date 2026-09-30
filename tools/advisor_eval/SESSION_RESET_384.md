# Release 384 checkpoint — 2026-09-25

Installed **2.182.0-alpha** at 2026-09-25T11:35:56.0108851-05:00 in
`C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm`. Backup:
`C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm\deployment-backups\advisor-20260925-113555`.
Policy digest:
`71a50538faf9af0c0208244165ae466b9ebc55a28cff4b9a930b5c5f50d14a6d`.
All **92 deployment** and **108 runtime/dependency** files match repository
and installation. Full frozen candidate and exact-installed gates each passed
**254 Lua fixtures / 392 Python tests**, with identical policy/test hashes.
Current config and all seven native DLLs were preserved. Exact hashes,
receipts and counts are in `SESSION_RESET_384.json`,
`runs/win384_installed/record.json` and
`runs/win384_final/final_verification.json`.

Nine explicit runtime files changed from installed 2.180:
`Advisor/{acorn_belief,decision,deck_development,player_journal,search,strategy}.lua`,
`Core/{Brainstorm,event_cadence}.lua`, `steamodded_compat.lua`. The 2.181
64x cadence candidate was incorporated unchanged and never separately
installed. `development383/{SCOPE,REPORT}.md` retains its independent
review and source limits. `development384/{SCOPE,REPORT}.md` and WR-022–027
in `WIN_RATE_RESEARCH.md` describe the six new behavior corrections and
their manufactured counterexamples. No native work or settings change is
part of this release.

The latest frozen ten-start user batch is public loaded-label **2.180**,
win-first Red Deck/Gold Stake, session `session-20260925T144723Z-1`, cutoff
2026-09-25T15:28:39Z, sequence 18,179: **one win, eight losses, one
unsupported Amber Acorn stop**. Ten distinct observed seeds are not a
calibrated independent population. The exact 24 BRJ2 segment hashes and
passive extraction are under `development384/logs1/` and `capture/`. No
captured state was run through policy/scorer, and no hidden RNG or save was
read. Earlier pending/unchecked wording is superseded by this checkpoint.

The game process was absent for installation and was not controlled through
tools. **Activation of 2.182 and any run-speed or win-rate benefit are
unconfirmed**. A normal user restart is needed. For next work read
`ADVISOR_START_HERE.md`, this `.md` and `.json`, `NEXT_PRIORITIES_384.md`,
`ARCHITECTURE_MAP_384.md`, and current boundaries in
`ADVISOR_RESUME_PROMPT.md`. Preserve all workspace changes, current settings,
saves, journals, seven DLLs and CLOSED experimental budgets. No old start or
worker allowance was renewed.
