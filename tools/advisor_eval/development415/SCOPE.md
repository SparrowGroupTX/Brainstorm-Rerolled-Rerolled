# Passive monitoring415 — current2.199 session

User explicitly requested: "monitor the current run now. Seems like it's failing,
try to figure out the reason(s) why." This authorizes passive active-public-journal
reads and a thread heartbeat for this session, superseding earlier local
no-active-journal/automation wording only within this monitoring scope.

Target: session-20260926T235238Z-1, process49852 (started2026-09-26 18:50:48 local).
Installed/runtime baseline remains4142.199, digest
606bfc455694d79ec25c4996413e4246229f4b66c83b1f0b94b76ec8f165d9fc.
Capture bounded immutable prefixes and decode verified complete frames. An
unfinished live frame is not a corrupt game or normal terminal result. Preserve
every capture; inspect only copies. Track run outcomes, resource histories and
the observation→advice→request→callback→physical-state chain. Late failure alone
does not prove earlier choices wrong, and callback acceptance is not settlement.

No game control/foreground/launch/stop, save/profile reads, captured-state policy
or scorer replay, source-engine execution, new attempt/search experiment, runtime
edit/installation or caps increase. One primary and same sole read-only reviewer
for a concrete diagnosis, one substantive review plus one focused recheck maximum;
no recursive delegation. This is an evidence/diagnosis slice, not a repair release.

Heartbeat monitor-current-balatro-session checks every2 minutes while the current
session remains active. Stay quiet absent meaningful findings, end state or
required user action. Stop/disable when this session ends, its process exits,
or the user stops monitoring; do not carry monitoring into another session.
Never infer normal exit or completed game outcome from process disappearance.

Use capture.py for fresh bounded copies. Each captures/NNN/ directory contains
raw logs, manifest, verified events.sqlite3 and summary. Do not edit old captures.
LATEST.json points at the newest capture; monitoring notes/findings are separate.
No repeated whole-cohort evaluation or unchanged test runs are needed.
