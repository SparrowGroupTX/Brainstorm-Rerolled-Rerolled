# Journal work reuse — 335

This component avoids two calculations whose result cannot contribute to a
journal event. It preserves the complete logging contract and runtime advice
freshness checks. Final candidate, exact-installed and verification receipts own
the release status and full-suite totals. This note grants no experiment authority.

`player_journal.lua` previously gathered selected hand indices and callback input
details before `before()` discovered that recording was disabled, suppressed by
the owning action, or already stopped by a recorder error. Those scans and table
allocations now occur only when recording can consume them. The callback always
keeps its existing protected invocation, arguments, return tuple, exception and
result handling. Eligibility is checked again for every callback, including after
an enable or suppression transition; no result is cached.

Full journal observations still capture and detach the public snapshot. Advice
can be current only if a published key exists for that same game. Those two
cheap predicates now precede full fingerprinting. A same-game publication,
whether its key matches or differs, continues to require the complete fresh
fingerprint. Stale, computing and unavailable advice labels remain identical.

The new `tests/advisor_journal_reuse.lua` differential fixture compares complete
serialized event bytes, sequence links, counters, pending state, callback
results and errors against frozen release334 journal code. Its nine states are
disabled, suppressed, stopped, no key, different game, mismatching key, current,
computing and unavailable. Additional checks cover busy settlement, nested
owner suppression, registered outer hooks, repeated installation, callback
replacement and enable transitions. Fixed manufactured clocks permit byte-level
comparison without claiming identical real timing.

The production fixture has 236 checks. Across those manufactured cases, it
removes nine unused detail collections and sixteen full fingerprints, preserving
every complete snapshot. The component suite passes five fixtures and 443 checks:
the new differential fixture plus unchanged journal (25), timing (105), logger
hooks (17) and cooperative callback hooks (60) fixtures. These are saved-work
counts, not a live FPS benchmark, complete game or measured completion-time gain.

The frozen baseline is `tests/fixtures/journal_reuse335/player_journal334.lua`,
SHA-256 `eae2209780c9c7d97571c123cb5988a496a9b94fcf39345934a6c5c27265699b`.
Its adjacent `hashes.lua` records dependency and production-fixture hashes.
Neither dependency matches the runnable `tests/advisor_*.lua` glob, and both are
covered by the existing complete test/dependency inventory. The production test
has no dependency on mutable files under `development335`.

The candidate module hash is
`1d41e9fe61ee25c4397a8a3b5ce1e598f1410c3a3f7ff5277345301e2455962e`.
Preserved pre-change production/version bytes and integration hashes live under
`development335/journal_release/before` and `integration.json`. Component evidence
is `development335/runtime_component/validation.json`; complete release receipts
are `runs/journal335_candidate/validation/report.json`,
`runs/journal335_installed/record.json` and `policy/`,
`runs/journal335_installed_validation/report.json`, and
`runs/journal335_final/final_verification.json`.

Runtime and autoplay recapture/fingerprint checks between worker slices and at
selection/execution gates remain intact. They prevent stale advice after public
card, order, resource, phase, run or profile changes; no complete mutation signal
exists to justify cross-frame reuse. Retry validation, archive format, encoded
events, append verification, native code and prior333/334 changes are preserved.
Timing metrics measure actual remaining work, so fewer executed fingerprints
produce fewer corresponding samples without discarding existing information.

Scoring, inventory and economy redundancy candidates belong to separate audits
until separately reviewed and released. There is no new source/search/replay
authority and no source worker pending. Historical loss328 outcomes remain three
losses, one error, one timeout, one unsupported and zero wins, from four public
pairs and six source attempts. Its 1,200 reserved seconds, 685.3740000000689 actual
seconds and unused P05/P06/60 seconds remain closed. None is335 validation.

Activation and ordinary-play FPS recovery remain unconfirmed. Activation waits
for the user's normal restart. Keep the running game undisturbed and preserve
all logs, settings, saves, native files and tracked/untracked work.
