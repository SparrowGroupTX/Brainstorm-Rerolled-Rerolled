# Release 375 checkpoint — 2026-09-23

**Installed 2.174.0-alpha** at 2026-09-23T15:31:24.6529419-05:00 in
`C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm`. The backed
installation is
`C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm\deployment-backups\advisor-20260923-153123`.
Policy digest: `95707f4e76a652c043220c1a7f7598b73b40388ee5d2f249343ce4b7d5b02408`.
All 91 deployment and 107 frozen runtime/dependency files match the
repository and exact installation. Candidate and exact-installed gates each
passed **246 Lua fixtures and 391 Python tests**, with identical frozen
policy/test hashes. Current `config.lua` and all seven existing native DLLs
match the prior 371 checkpoint. No native DLL changed. Installation does
not activate a running game; **2.174 activation is unconfirmed** and waits
for the user's normal restart. No measured speedup or improved win rate is
claimed.

This release combines the prior validated but uninstalled 2.173 128x/256x
speed menu and guarded one-pass event cadence with a new bounded copy-target
rating repair. `strategy.lua` now recognizes an active, developed public
Yorick with no explicit incompatibility as a Blueprint/Brainstorm scoring
target even if a snapshot omits `blueprint_compat`. The actual shop scorer,
complete replacement family, cash/survival gates and score budgets remain
unchanged. Exact changed runtime files are `Advisor/strategy.lua`,
`Core/Brainstorm.lua`, new `Core/event_cadence.lua`, `UI/game_speed.lua`
and `steamodded_compat.lua`. Versions 2.172 and 2.173 were never installed;
their frozen candidate evidence is preserved, not a separate live stratum.

The latest observed public cohort loaded **label 2.171** in all recorded
version stamps: ten distinct searched Red Deck / Gold Stake Yorick + Perkeo
win-first starts, **two verified wins, seven verified losses and one
unsupported Ante 8 Amber Acorn retirement**. It ran from 2026-09-23T18:27:19Z
through 19:26:13Z (sequence 19,427). Public stamps and profile projections
do not attest exact loaded bytes. The 25 original journal segments and their
SHA256-bound frozen copies, compact readers, report and causal findings are
under `win_rate_research/20260923_182719_ten_start/`. Do not count the
unsupported stop as a loss, infer a population win rate, or claim 2.174
full-run benefit from this pre-release cohort.

Navigation: `ADVISOR_START_HERE.md`, this document and
`SESSION_RESET_375.json`, `NEXT_PRIORITIES_375.md`,
`ARCHITECTURE_MAP_375.md`, canonical `WIN_RATE_RESEARCH.md`,
`development375/ACORN_REVIEW.md`, and
`runs/marathon375_final/final_verification.json`. `development374/FAST_EVENT_CADENCE.md`
describes the speed candidate's exact guards and remaining timing limits;
its pending-release wording is historical. The 371 map and checkpoint remain
the unchanged baseline reference. `ADVISOR_RESUME_PROMPT.md` retains the
mandatory execution, preservation, authorization and validation boundaries.

Evidence: `runs/marathon375_candidate/freeze.json` and `validation/`,
`runs/marathon375_installed/record.json` and `policy/`,
`runs/marathon375_installed_validation/`, and
`runs/marathon375_final/`. Current settings, saves, profile files, journals,
seven native DLLs and all tracked/untracked work were preserved. No game
process, hidden seed search, captured-state scorer/policy replay, complete
simulation, source-game execution, GPU training, scheduled job or new run was
started by tools. Historical experimental allowances remain CLOSED.
