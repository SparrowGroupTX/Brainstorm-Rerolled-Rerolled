# 397 installed release checkpoint — 2026-09-26

**Installed 2.192.0-alpha** at 2026-09-26T00:28:03.5566146-05:00 in
`C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm`. Backup:
`deployment-backups/advisor-20260926-002802` within that installation.
Policy digest:
`e74633a088bdf3dfa15d1c87eed099b61ed280f427dfb953273a564d5e8d6e77`.
Installation does not prove activation; a normal user restart is required.
No loaded-2.192 gameplay or full-run benefit has been observed.

The six explicitly installed runtime files are `Advisor/acorn_belief.lua`,
`Advisor/concealed_belief.lua`, `Advisor/sampled_outcomes.lua`,
`Advisor/scoring.lua`, `Core/Brainstorm.lua`, and `steamodded_compat.lua`.
This release repairs the public Bull/Scholar Acorn post-play hard stop and
bounded concealed continuation omissions for a possible Purple Seal and
optional Lucky outcomes with owned Jokers. It preserves the original
8,000-score continuation cap and unsupported safeguards. It changes no
native DLL.

Before installation, all 92 installed deployment files matched the frozen
2.191 receipt, and repository 2.192, 302 frozen test files, current
`config.lua`, and all seven native DLLs were verified. After installation,
all **92 deployment** and **108 runtime/dependency** files matched repository
and installation. Both full candidate and exact-installed gates passed
**262 Lua fixtures and 392 Python tests** with unchanged frozen policy/test
hashes. Current settings and all seven DLLs were preserved. Raw validation
is in `runs/concealed396_{candidate,installed_validation}/`.

The latest user-completed public cohort is **loaded-label 2.191**, win-first:
all 27 source-matched BRJ2 segments of
`session-20260926T035918Z-1` are preserved under
`development396/logs1/` and `capture/`, with 24,635 consecutive events,
ten starts, **four verified wins, five verified losses and one nonterminal
unsupported**. The preceding separate loaded-label-2.191 cohort is under
`development395/`: ten starts, three wins/seven losses. Public labels do
not attest exact loaded bytes, and neither selected cohort is a calibrated
win rate. `development396/REPORT.md` has the evidence-ranked diagnosis,
sequence anchors and unresolved boundaries. No captured state was run
through policy/scorer, and no game process, save or profile was controlled.

Exact release evidence: `SESSION_RESET_397.json`,
`runs/concealed396_{candidate,installed,installed_validation,final}/`,
`development396/{preinstall.json,capture/}` and the backup deployment
receipt. Current work: `NEXT_PRIORITIES_397.md`, relevant
`ARCHITECTURE_MAP_397.md` sections and WR-045–048 in
`WIN_RATE_RESEARCH.md`. Earlier uninstalled/pending wording is historical.
Preserve all tracked/untracked work, settings, DLLs and journals; no
commit/reset/clean/deletion/PR. Historical tool-game experiment budgets
remain closed. Only routine manufactured fixtures and passive public
source/log analysis are authorized without fresh approval.
