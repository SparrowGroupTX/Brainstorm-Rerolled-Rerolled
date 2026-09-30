# 386 installed release checkpoint — 2026-09-25

**Installed 2.184.0-alpha** at 2026-09-25T13:45:28.1516366-05:00 in
`C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm`. Backup:
`deployment-backups/advisor-20260925-134527` within that installation.
Policy digest: `851a189fe212211b0d7ced23abf3276eb04089e7658536db950adea9feeb3ccc`.
Installation does not establish activation; the user's next normal restart is
required. No loaded-2.184 outcome or win-rate benefit has been observed.

Exactly three runtime files changed: `Advisor/strategy.lua`,
`Core/Brainstorm.lua`, and `steamodded_compat.lua`. The 2.183 installed
baseline matched all 92 deployment and 108 runtime/dependency hashes before
installation. The frozen 2.184 candidate and 295 test hashes matched the
repository; both full candidate and exact-installed gates passed **255 Lua
fixtures and 392 Python tests** with unchanged policy/test hashes. The
installed 92 deployment and 108 runtime/dependency files matched the
repository, candidate and installation receipt. Current `config.lua` and all
seven DLLs were preserved; no native file was released.

The just-finished user-started public cohort is **loaded-label 2.183**, not a
2.184 test. Its 27 archived segments contain 22,754 consecutive events and
ten starts: **three verified wins, six verified losses, one unsupported stop**.
The exact first 16 segments remain in `development386/logs1/`, the final 11
in `development386/logs_complete_tail/`, and all hashes, profile, lifecycle
and outcome anchors are in `development386/completed/manifest.json`. The
public label is not an exact loaded-byte attestation. These selected starts
are not a calibrated population win rate. No captured state was run through
the policy/scorer, and no game process was controlled.

Exact release evidence is `SESSION_RESET_386.json`,
`runs/resources386_{candidate,installed,installed_validation,final}/`,
`development386/{preinstall.json,REPORT.md}`, and the deployment receipt in
the backup. WR-029–031 in `WIN_RATE_RESEARCH.md` remain locally fixed but
unvalidated in post-install play. The next work is deeper passive analysis of
this completed 2.183 cohort, then a separately scoped held-consumable-aware
discard comparison if evidence supports it. No new gameplay experiment,
batch, hidden search or training budget follows from this release.
