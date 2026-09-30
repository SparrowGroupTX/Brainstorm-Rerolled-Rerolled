# Repair410: strong discard-before-clear preference

User observed a clear with three discards remaining, initially prohibited all such
plays, then revised this to rare exceptions with a below1% observed-rate target.
Implement a strong default in perkeo_yorick_win_v1: prefer a supported retained-clear
discard before ending a blind, independent of positive growth merit or future
development horizon. Do not claim the population target from manufactured tests.

Reuse bounded exact transitions, physical-card remapping, supported floors, draw
hazards, Glass/population/Arm protections and actual discard limits. Reconsider
after every real draw. Final arbitration must describe the action actually sent,
including explicit safety, legality, budget or public-model coverage exceptions.
Acorn and concealed-card states must never fall through to raw hidden scoring.
Preserve retry restrictions, current budgets and ordinary-profile behavior.

Baseline is exact installed409 2.196. Candidate becomes2.197 after manufactured
positive/negative integration, one source review and one focused recheck by the
same sole reviewer, new combined freeze and full candidate validation. No live
installation while PID31268 runs. No active journals, game control, saves/profiles,
captured-state scoring, new experiment or renewed historical allowance.

Required fixtures: no growth Joker, mature Yorick, final Boss, exact target,
empty deck, repeated exhaustion, resource retention, score-reducing discards,
forced selection, unsupported generation, final action vs stale proposal,
hidden/public paths, retry restrictions, deterministic inputs and all work caps.
