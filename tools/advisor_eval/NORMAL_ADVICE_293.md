# Normal-deck advisor availability — 293

The user requested normal-deck advice and a system to help finish Completionist++.
The existing advisor already has a normal-run path, gated by the saved
`advisor.challenge_only` option. This slice makes that support discoverable; it
does not pretend a new normal-deck engine was implemented.

`Brainstorm/Advisor/runtime.lua` now defaults missing `challenge_only` settings
to false. Existing true/false values, disabled-advisor and HUD preferences are
preserved. `Brainstorm/UI/advisor.lua` calls the feature Run Advisor and offers
**Enable normal-deck advice** in settings and the inactive advice panel. A user
click changes only `enabled=true` and `challenge_only=false`, writes config once,
and invalidates stale advice, published tokens and transient generations.
Persistent retry limits, journal data, caches and the queued-action duplicate
latch remain intact. The click starts no search, scoring or gameplay action.
Ordinary ready/lock checks control subsequent advice. Installation changes no
current configuration; activation waits for the user's normal restart.

Current normal-deck mechanics use observed cards, hands, discards, slots, money,
modifiers, vouchers and back key. Plasma balancing is already in `scoring.lua`;
Green unused-resource income is already in `finish_rewards.lua`. High-stake
rental/perishable/Eternal handling remains in its existing modules. Custom
deck callbacks are not fully captured, and enabling normal advice does not
qualify them. Whole-blind forecasting still has bounded size/resource scopes;
ordinary scoring support is not full-run qualification for all 15 decks.

Tests: `tests/advisor_runtime.lua` and `tests/advisor_ui.lua` exercise fresh
defaults, preserved settings, normal decision publication, explicit activation,
stale-action rejection and retry/duplicate-action protection. Five focused
fixtures passed 800 behavioral checks plus syntax validation under
`runs/normal293_development/focused2/`. The original focused1 failure is retained:
a historical fixture assumed the former challenge-only default; it now selects
that preference explicitly for the same stale-advice check.

Candidate/installed/final evidence uses the `normal293` run prefix. Both native
DLLs and current settings are preserved. There were no source components,
captured replays, searches, complete attempts, game control or save/profile
reads. Gold progress and objective planning are the next separately tested
slice, not behavior attributed to 293.

The user reported obtaining Completionist after the collection helper, then
Completionist+ after advice about its delayed trigger; they subsequently said
only Gold-stickering Jokers remains after the Flushed instructions. These are
user reports, not instrumented runs, proof of search optimality or Jokerless
terminal evidence. No player collection file was inspected.
