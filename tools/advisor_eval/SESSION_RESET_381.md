# Release 381 checkpoint — 2026-09-24

Installed **2.179.0-alpha** at 2026-09-24T11:40:52.0422715-05:00 in
`C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm`. Backup:
`C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm\deployment-backups\advisor-20260924-114051`.
Policy digest:
`92bd817059146bd36f86238c2880c1ec3f8436dd55c7e3b7e70650f8be3d1c68`.
All **92 deployment files** and **108 frozen runtime/dependency files** match
the repository and installation. Full candidate and exact-installed gates
each passed **251 Lua fixtures / 392 Python tests** with matching frozen
policy and test hashes. Current configuration and all seven native DLLs were
preserved. Exact file hashes, installation receipt and both gates are in
`SESSION_RESET_381.json` and
`runs/engine381_final/final_verification.json`.

The only runtime changes are `Advisor/{strategy,player_journal}.lua`,
`Core/Brainstorm.lua` and `steamodded_compat.lua`. A bounded win-first shop
comparison now prefers an already-scored, admitted non-engine sale for the
same Perishable Joker when it preserves a no-worse four-world opening and
any complete whole-blind finish. The public replacement receipt records
the substitution and scalar compared openings. Exact scope, audit anchors,
manufactured fixture and independent review are in `development381/{SCOPE,REPORT}.md`
and `WIN_RATE_RESEARCH.md` WR-020. No discard or Joker-order policy changed.

The latest frozen public cohort remains the interrupted six-start prefix at
`win_rate_research/20260924_132921_interrupted/`, cutoff 2026-09-24T14:07:45Z,
sequence 13,931, public loaded label 2.175 and win-first profile. Outcomes:
two verified wins, one loss, two unsupported and one incomplete controller
error. No Blueprint sale appears there. Its 130 unused early discards are
not 130 proven safe growth actions. No new starts, captured-state replay or
game control occurred.

Balatro was not running during installation. Activation of 2.179 and any
real-game improvement are **unconfirmed**; a normal user restart is needed.
The previous 2.178 Acorn/retirement/manual-journal release remains in the
installed dependency set, but its real-game activation/benefit was never
observed. WR-014 seven-Joker Acorn and WR-001 qualified early-growth work
remain open. Read `ADVISOR_START_HERE.md`, this document/JSON,
`NEXT_PRIORITIES_381.md`, `ARCHITECTURE_MAP_381.md`,
`ADVISOR_RESUME_PROMPT.md` and the 381 report for current boundaries.
Preserve all workspace modifications, settings, saves, journals, DLLs and
closed experiment budgets. No old run allowance was renewed.
