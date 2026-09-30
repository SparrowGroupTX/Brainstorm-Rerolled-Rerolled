# Checkpoint 371 — 2026-09-23

Post-checkpoint note: a frozen, validated 2.173.0-alpha **repository candidate**
adds 128x/256x Game speed and a guarded 120/240 Hz native event cadence in
an unpaused run. It is not installed while the user-started newer marathon
may still run. See `development374/FAST_EVENT_CADENCE.md` and
`runs/speed374_candidate2/`. The prior 2.172 menu-only and first 2.173
candidate evidence are preserved as superseded. The installed 371 hashes
and evidence below remain the verified installation checkpoint.

Installed **2.171.0-alpha** at 2026-09-23T13:09:31.7985068-05:00 using
`install_slice.py` with exactly `Advisor/strategy.lua`,
`Advisor/paid_reroll.lua`, `Advisor/decision.lua`, `Core/Brainstorm.lua` and
`steamodded_compat.lua`. Backup:
`C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm\deployment-backups\advisor-20260923-130930`.
Policy digest:
`5aaf16bc787131d788788b425600c3ddb0234af571f1d9b9c0a8cd4935cf6ba5`.
All 90 deployment files and 106 runtime/dependency files matched repository
and installation. Candidate and exact-installed gates each passed **244 Lua
fixtures and 391 Python tests** with unchanged frozen policy/test hashes.
Current configuration and all seven native DLLs were preserved; no native
file changed. Exact evidence is in `SESSION_RESET_371.json` and
`runs/engine371_{candidate,installed,installed_validation,final}/`.

This release repairs three defect classes from the last loaded-public-label
2.169 ten-start diagnosis: a visible sale-funded copy purchase with a free
Joker slot was never compared (WR-010); Burglar's rating omitted future
Yorick/Burnt discard opportunity (WR-011); and a supported safe next blind
could never enter a bounded proactive engine-reroll comparison (WR-012).
`development371/SCOPE.md` gives the acceptance, exact supported scope,
independent review and fixture counts. These are local policy repairs, not
replays of the ten captured games. The new reroll values only the first
ordinary unstickered source-catalog slot, charged miss, complete paired hit
endpoints, cash/interest, horizon and action cost. It may still hold with
ordinary pool proportions; it is no win probability.

The latest actually loaded public cohort remains **2.169 win-first**: two
verified wins, eight losses, zero hard stops across ten distinct searched
Red Deck/Gold Stake Yorick + Perkeo starts. Cutoff 2026-09-23T16:36:58Z,
sequence 17189; original evidence and analysis are in
`win_rate_research/20260923_2_169_ten_start/`. Public version stamps do not
attest loaded bytes. **Activation of 2.170 or 2.171 has not been confirmed**;
installation waits for the user's normal restart. No 2.171 real-game benefit
is demonstrated.

Preserve every tracked/untracked change, journal, setting, save and native
file. No commit, reset, clean, deletion, PR, fresh checkout, old-settings
restore or log purge is authorized. Never launch, restart, foreground, stop
or control Balatro through tools; do not read/modify player saves or replay
captured states through policy/scorer. No hidden seed search, original-game-
source execution, complete simulation, training, scheduled job, tool-started
cohort or historical budget rollover is authorized. Preserve existing
action/session/log bounds, deterministic sampling, complete common-world
comparisons, unsupported-mechanics guards, physical/population conservation
and 140000/50000/25000/70/12 score caps. Read the complete standing rules in
`ADVISOR_RESUME_PROMPT.md` and the prior 370 reset; this short checkpoint does
not replace them. Later verified status supersedes historical pending wording.
