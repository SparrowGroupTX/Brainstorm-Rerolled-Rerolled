# Next priorities after 340

Fix the observed Amber Acorn Lucky-card stop using complete public-world score-floor comparisons.

Repair the observed Amber Acorn stop caused by a visible Lucky card. The existing complete public Joker-world planner now uses one supported random-score-floor pass for every subset/world when a Lucky card is present. The ordinary score cap, complete comparisons, hidden-identity exclusion and public reorder proof remain intact. Advice labels its random-floor scope, and existing invalid public-belief reasons reach the user instead of a generic missing-belief message. Full candidate and exact-installed regressions passed 194 Lua fixtures and 361 Python tests with unchanged frozen policy/test hashes. 2.140.0-alpha is installed; activation waits for the user's normal restart.

Read-only passive logs from loaded 2.138 show the original stop at sequence 4554 after decision 4547 rejected a Lucky Jack with a valid five-Joker/120-world belief. No captured policy was replayed. The manufactured Lucky fixture passes 26744 checks, including complete subsets/worlds, precise floor-call accounting, no mean or RNG fallback, inventory/resource preservation, reliable-bound requirements and a false-clear case whose floor is 112 while its expected score is 304 against 200. An independently manufactured five-Joker/eight-card case covers all 26,160 current-order comparisons inside the unchanged 140,000 cap. The component tests do not demonstrate that the logged run is rescued or that Amber Acorn is generally solved. Historical closed loss328 results remain three losses, one error, one timeout, one unsupported and zero wins under policies 327/329/331.

The change admits supported Lucky scoring only; unknown/hidden/destructible/held-reward card scopes, incomplete world families and unsupported ability changes remain explicit. It does not forecast Lucky outcomes, future hands/discards/uses or a complete blind win. All scoring inputs are detached public worlds, not hidden slot payloads. A later recorded uncertified manual drag and a checkpoint reload lacking pre-concealment inventory are separate limitations. A restart or restoration already inside Acorn cannot recreate public memory; use a checkpoint before selecting the blind so the advisor can observe the visible Joker inventory. No inferred movement origin, hidden-ID join, or saved-state equivalence is invented. Current settings, logs, native dependencies and all dirty/untracked work remain preserved; activation waits for the user normal restart.

All experiment allowances remain CLOSED. Release 340 performs read-only passive log/source analysis and routine manufactured fixture/regression validation only, with 60-second per-suite caps. Zero source components, captured-state policy replays, searches or complete attempts are started; no executable archive, player save/profile is read and no game is controlled. Historical loss328 counts/outcomes and 1,200 seconds reserved/685.3740000000689 seconds actual remain unchanged; unused P05/P06 and 60 seconds stay closed. No worker, source attempt, search or scheduled continuation is pending.

The current cycle is closed; its unused capacity remains closed and this installation grants no additional jobs.

Exact current-cycle evidence and authority references: `tools\advisor_eval\development340\release_final\context.json`.

# Priorities after 340

The logged Lucky-card Acorn stop is repaired. Activation and live confirmation
await the user's normal restart with public pre-shuffle inventory observed.
Keep uncertified drags, hidden-inventory reloads and unqualified transitions
explicit; never recover concealed identities through physical IDs or saves.

Remaining Acorn scope includes complete resource comparisons for Glass and
held rewards, larger public-world families without higher budgets, broader
qualified ability transitions and publicly certified movement observations.
Use specific passive evidence to prioritize these; do not remove guards just
to produce an action. No captured replay/source/search/attempt allowance renews.

Prior performance/speed work remains installed. The broader strategy backlog
in NEXT_PRIORITIES_338.md and source navigation in ARCHITECTURE_MAP_338.md remain
current for their scopes. Jokerless, Knife's Edge, twenty challenges and Gold
stickers are unfinished; no win odds or stronger-than-human result is established.


Read `SESSION_RESET_340.md`, relevant `ARCHITECTURE_MAP_340.md` sections and `ACORN_LUCKY_340.md`. This note grants no experiment authority. Routine fixtures and read-only analysis remain authorized.
