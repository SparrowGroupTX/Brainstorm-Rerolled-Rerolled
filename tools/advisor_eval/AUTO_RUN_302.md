# 302 explicit-start Completionist++ auto-run

This component adds a product-controlled loop that searches for a strong normal Gold Stake opening, starts the found run, executes fresh advisor suggestions, records observations and continues after an authenticated terminal result. It is activated only by the user's **Start auto-run + logging** click. Installation does not start the loop, resume an old session or activate a running game's newly installed code. The live game remains undisturbed by development tools; activation waits for the user's normal restart.

Candidate302 has policy digest `e3ab539e45ba25e97909a2dd91817fd252f1b668039b821fee10a485b2e0a9b9` under `runs/autorun302_candidate/candidate_record.json`. Full regression passed149 Lua fixtures and300 Python tests. M12 subsequently verified original-source product startup in0.39000000001396984s: actual Back and Game delete/start callbacks ran once, moving STARTUP1 to S7PXV521 RedGold with52 cards and an untouched first blind. Its native bridge deliberately supplied the already observed S05 receipt; zero advisor actions, score calls or new searches occurred. `runs/gold299_20260914/M12/audit.json` preserves exact evidence. The exact-installed record and release ledger establish installation separately; no activation or completed autonomous player run is claimed.

## Product controls and scope

The Gold auto-run page offers Red Deck or Zodiac Deck, Gold Stake, Yorick and Perkeo in the starting Charm pack, Burnt and either Brainstorm or Blueprint by Ante5, no perishable targets, and Maximum native CPU. The optional missing-Joker quota counts distinct conditional offers in the chosen Ante window. It does not prove affordability, acquisition, retention or Gold credit. A zero quota avoids unnecessarily restricting early collection searches. Fixed target and copy-alternative controls remain explicit.

Start copies the selected settings, enables ordinary-deck advice, the existing Gold objective and bounded player recording, logs that user choice, and closes the menu through the original callback. It performs no search or gameplay within that click. Separate settled updates arm the controller, dispatch one owned search, accept its exited result, and then start the exact found receipt. All loaded Gold records must be verified: unknown records prevent automatic continuation, and only zero missing plus zero unknown constitutes collection completion.

The UI exposes Stop, and the advisor HUD changes its action control to a latched Stop while auto-run is active. Physical keyboard/mouse input, manual Execute, checkpoint save/load and advisor/settings changes interrupt the mode. Changing the actual loaded profile table stops the loop even if its numeric profile id is unchanged. The session has no saved active flag and never resumes across a game restart or checkpoint restore. Checkpoint/retry journals retain their existing persistent caps.

## Runtime ownership and execution

`Brainstorm/Advisor/auto_run.lua` is the pure injected state machine. It has no game globals, RNG, filesystem, persistence or native calls. `Brainstorm/Core/auto_run_product.lua` adapts actual loaded game state, the native search facade, the existing advisor Execute gate and the player journal. `Brainstorm/Core/auto_terminal.lua` observes the original terminal/progress callbacks. Core loads these after Advisor, collection search and checkpoint initialization; `Brainstorm/UI/collection_run.lua` exposes the controls.

`Brainstorm.AutoRun` has colon methods `:start(options)`, `:stop(reason)`, `:manual(reason,kind)`, `:update()`, `:status()` and `:owned()`, with a user-visible `status_text`. The native collection facade keeps its dot API. Flat UI fields—including explicit false for interchangeable copies—are immutably forwarded into the controller's search request; conflicting duplicate nested settings are rejected.

Every execution requires an unchanged actual run, fresh public-state fingerprint, the matching published result/action token and retry generation, and the ordinary `A.can_execute` / `A.execute` checks. One attempted action is consumed before its callback. The same unchanged state cannot execute twice; an uncertain or failed callback stops further actions. Automatic play gets no exemption from unknown mechanics, cash, inventory, selection, boss, modal or score-budget guards. `player_log.source` is `auto_run` only around the owned Execute call and restores even when the callback throws.

The product facade preserves the actual native found receipt object across the pure controller's immutable copies. An uncertain native dispatch is cancelled and drained. Late results from a stopped request cannot start a run. A missing handle is considered drained only when both the runtime and product busy state confirm no remaining worker. A second search cannot start while cancellation is still draining.

## Original terminal and result-screen evidence

The terminal monitor binds one actual `G.GAME` table, loaded profile table, profile id and controller run id after successful product startup. It never writes progress itself. GAME_OVER takes precedence over incidental `GAME.won`. An accepted win requires final-boss context on an ordinary unseeded Gold run, ordered original `set_joker_win` then `set_deck_win` callbacks with positive loaded counter increments, and either the actual chip threshold or an observed same-round original saved callback. Buying, holding or predicting a Joker is not Gold credit.

Preserved M02 source references establish that global `win_game` performs those original counter updates and queues its result UI in a later event. The monitor binds the later original `create_UIBox_win` definition object to that verified accounting, consumes its exact identity at `G.FUNCS.overlay_menu`, and remembers only that resulting overlay. A shared `you_win_UI` id alone cannot authorize closing a menu. The next search waits until the actual result surface has appeared and been dismissed after its terminal log.

M11's complete `Game:update_game_over` excerpt shows the loss overlay is created synchronously inside that original method. The monitor captures only its newly created overlay for the armed GAME_OVER state. A later no-op update cannot adopt an unrelated menu. Dismissal uses the original `exit_overlay_menu`; both frame locks it sets must clear before the next search/run.

Source receipts are preserved under `runs/gold299_20260914/M02/state_events_source_references.json` and `M11/inspection/`. Source member `functions/state_events.lua` hash is `6c86aefb42d0323d737f87aaa84f53e42b755e72cd0bfd163b7d9cca5c0a99a9`. M11's complete loss-method hash is `9ebcb600dab8f462386e6e77a498f9976cc48d280eaba21591d1ff541022dd5d`; complete exit-overlay method hash is `46a9e22a79485b357bbb471bc2332391e787ec4e2f12e39811cb0aa612b4565f`. M11 did not find global `win_game` in the two members it searched; the earlier M02 state-events evidence supplies that method.

## Independent product bounds

| Limit | Default | Hard maximum |
|---|---:|---:|
| Each search | 30 seconds | 30 seconds |
| Unsupported/stalled transition | 30 seconds | 30 seconds |
| Actions per run | 500 | 500 |
| Time per run, including startup | 1800 seconds | 1800 seconds |
| Runs per explicit session | 25 | 100 |
| Total session time, including searches/startup | 21600 seconds | 21600 seconds |

The native request gets at most 27000 ms, leaving room within the independent outer 30-second search deadline. The controller checks actual monotonic time rather than treating a search estimate as a guarantee. Limits may be lowered; the UI offers 5, 10, 25, 50 or 100 runs. No class time, schedule or automation is embedded. These product limits are separate from the registered development experiment leases and never renew those leases.

The existing player journal is required and remains bounded: 2048 events and 32 MiB per process session, 128 MiB total storage, and 1 MiB per event. Auto-run does not reset or extend those bounds. Failure or exhaustion stops subsequent work. Records separate attempted actions and contemporaneous advice from observed state changes and original terminal evidence. Public snapshots preserve known deck/discard identities while redacting genuinely concealed identities and hidden ordering/RNG.

## Validation and practical limits

The pure controller fixture passed 312 synthetic checks; terminal and product facade fixtures passed 30 and 73 checks. They cover explicit-only startup, immutable settings, one action per changed fresh state, time/action/run caps, manual/profile/checkpoint interruption, reentrancy, cancellation ownership/draining, uncertain callback failures, logging failures, fresh known-zero completion, asynchronous win UI, exact one-use overlay identity, GAME_OVER precedence, loss continuation after frame locks clear, and action-source restoration on exceptions. Root additionally tests the actual HUD Stop and Core/UI integrations in routine regressions. Exact candidate/installed verification records are authoritative for aggregate totals.

These tests establish bounded control flow and guards; they do not demonstrate full live-game automation, achievement completion, optimal deck choice, stronger-than-human play or numerical win odds. C01's separately audited selected synthetic Red Gold win used frozen policy300 and missing-Gold objective context disabled; it is not an auto-run302 achievement result. Its acquisition/retention and strategic limitations are detailed in `GOLD_C01_POSTMORTEM_301.md`. The shop-order repair released alongside302 has separate component evidence and must not be credited as a demonstrated terminal improvement without its own complete-attempt result.
