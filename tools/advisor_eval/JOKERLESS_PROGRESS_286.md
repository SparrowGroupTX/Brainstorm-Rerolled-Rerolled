# 286 — bounded search scheduling and visible progress

The Jokerless opening runtime can now process several existing batches per product callback, and its existing attention box shows the tested count against the current job limit. The menu separately displays elapsed wall time, wall throughput and detached search computation. This accompanies the separate Lua predicate-gating work in `Core/jokerless_opening.lua`.

## Scheduling

`Core/jokerless_search_runtime.lua` retains the normal 512-index batch and 1,000,000-index job limit. A callback performs at least its next complete batch, then may continue while fewer than eight batches have completed and less than 0.006 seconds have elapsed since callback entry. The time budget is checked between complete batches. A single batch can exceed 6ms; this is not a measured or guaranteed frame-latency bound.

Every batch executes the existing fresh-catalogue, catalogue-signature and game-identity validation. Cancellation, error, first match or exhausted job limit stops the callback immediately. A final partial batch respects the remaining job limit. Timing only changes the yield boundary: ascending seed indices, the in-flight predicate, accepted first match and persistent cursor do not depend on the clock. An absent, nonfinite or regressing observed clock conservatively limits the callback to one batch. The maximum of eight also bounds a callback when a valid clock does not advance.

The implementation does not start work when loaded or rendered. Only the existing explicit user start schedules the product search. It does not increase the number of indices authorized by that click or alter the product's existing matched-run replacement operation.

## Timing and display

The record adds `session_limit`, `elapsed_wall_seconds` and `seeds_per_second`. Wall timing begins at the user-start handler before its catalogue validation and runs through the latest observed batch timestamp, including time waiting between callbacks and catalogue work before each batch. It excludes later gameplay and is not a complete cost-to-win estimate. A zero elapsed interval has no throughput estimate. Unknown or backward timestamps make wall timing and throughput nil for the remainder of that job. A locally valid search-call interval does not restore invalid wall timing.

`compute_seconds` retains its previous meaning: the sum of the intervals around detached `opening.search` calls. It excludes frame waiting and surrounding catalogue checks. The menu labels computation separately from elapsed wall throughput. It shows no ETA, match probability or expected time to a match.

Persistent state strings update the existing menu's `G.UIT.T` references and the attention box's `DynaText` reference; no UI is recreated each batch. The attention box shows only `Jokerless: tested / limit`, at scale 0.55 and maximum width 8. Other reroll attention remains unchanged. These reference APIs are supported by the [Steamodded UI guide](https://github.com/Steamodded/smods/wiki/UI-Guide), the [Balatro-Preview interface](https://github.com/DivvyCr/Balatro-Preview/blob/main/src/Interface.lua), and [Talisman's dynamic scoring text](https://github.com/SpectralPack/Talisman/blob/main/talisman.lua). These are UI API references, not source-mechanics parity or gameplay evidence. No live viewport or running-game check was performed.

## Focused evidence and scope

`runs/jokerless286_progress_development/focused2/report.json` records the final passing 60-second-bounded routine fixture invocation: 91 runtime checks and 72 UI checks, 0.09048009995603934 seconds. The fake opening search and controlled clocks verify full wall versus compute costs, zero/unknown/backward clocks including regression at the scheduling check, eight-batch and 6ms yield boundaries, exact capped final batch, first-match application once, cancellation, catalogue/game replacement, stable cursor/predicate behavior and persistent UI reference updates. Inputs and source hashes, stdout and stderr are preserved there. `focused1` also passed and is preserved as superseded evidence before the immediate display refresh for a clock regression at the between-batch check. There was no failed focused invocation.

Files owned by this component are `Brainstorm/Core/jokerless_search_runtime.lua`, `Brainstorm/UI/challenge_opening.lua`, the minimal attention callsite in `Brainstorm/Core/Brainstorm.lua`, and the existing fixtures `tests/advisor_jokerless_search_runtime.lua` and `tests/advisor_challenge_opening_ui.lua`. The coordinator records the full candidate and exact-installed release evidence separately; the focused report's Core hash precedes the coordinator's release-version bump.

No product search, hidden search, original-source component, complete attempt, native build, save access or live game action was executed by these fixtures. No actual throughput improvement, new search yield, early survival, completed Jokerless win or player win rate has been measured here. Both native DLLs remain unchanged.
