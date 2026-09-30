# Auto-run terminal screen and run cap - 341

The passive session session-20260916T005407Z-1 ran loaded 2.140. Its final
Amber Acorn attempt played four hands for 147,894/400,000 chips and lost at
zero hands, leaving three discards. Loss sequence4572 preceded run_limit
sequence4575 at five runs (one win/four losses). These are passive session
records, not new simulated trials. Exact read-only anchors and byte hashes are
in development341/log_analysis/acorn_session_audit.json. The last segment was
append-active; its hash identifies only the bytes observed during that audit.

Core/auto_run_product.lua previously dismissed the owned terminal overlay
before Advisor/auto_run.lua could check its fresh terminal observation against
the cap. It now ticks the controller first and closes only if still active in
terminal state, with controls settled. The controller checks fresh collection
metadata, completion, then run cap before readiness for another search. The
result remains visible for terminal stops. Below-cap continuation still closes
the original owned result surface, then starts a new search on a later update.

Controller status exposes max_runs and run_limit_reached. The product explains
the reached count and win/loss counts. Existing stop/resume, cap, ownership,
logging-before-transition, collection metadata and session-time protections
remain. No counters, user settings or exhausted allowances are reset.

tests/advisor_auto_run_product.lua adds manufactured coverage alongside the
existing controller fixtures for the final five-run overlay, below-cap continuation, fresh complete
or unknown metadata, delayed result UI, foreign overlays, outcome uniqueness,
Stop/Resume, logging failure and session deadline. The preserved baseline
fails the expected final-cap assertion. Candidate component evidence is in
development341/terminal_component; full candidate and exact-installed evidence
is under runs/terminal341_candidate, terminal341_installed,
terminal341_installed_validation and terminal341_final.

This is a presentation/transition repair, not a strategy win. The same passive
blind had zero Joker activation observations. Preserved source Card:update
leaves flipping nonnil after facing/sprite_facing and pinch settle; the observer
treats it as perpetually busy. That separate mismatch is being prepared for a
subsequent fixture-tested slice. Discard/consumable joint planning remains
unfinished, as do unsupported Acorn resources and ability transitions.

No source worker, captured replay, seed search, complete attempt, save/profile
read or live game control occurred. All historical experiment budgets remain
closed. Current settings, logs and every native dependency are preserved.
