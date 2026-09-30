# Architecture navigation after 371

Post-checkpoint speed/cadence candidate: `UI/game_speed.lua` extends native
`change_gamespeed` choices, `Core/event_cadence.lua:update` adjusts only the
native event-manager pass interval at 128x/256x under RUN/paused/overlay/
screenwipe and manager-ownership guards, and `Core/Brainstorm.lua:Game:update`
invokes it before the native update. `tests/advisor_game_speed.lua`,
`advisor_event_cadence374.lua` and `advisor_frame_timing.lua` are the
manufactured control/cadence/integration fixtures.
`development374/FAST_EVENT_CADENCE.md` records timing paths, limits, frozen
2.173 candidate and post-cohort release gate; `development373/SPEED_OPTIONS.md`
preserves the superseded 2.172 menu-only candidate. Installed 371 runtime
still matches the checkpoint below.

Use `ARCHITECTURE_MAP_370.md` and its linked 369 map for the full runtime,
auto-run and diagnostic architecture. The release 371 paths are:

| Question | Runtime anchor | Focused evidence |
|---|---|---|
| Visible funded Joker purchase and complete sale family | `Brainstorm/Advisor/strategy.lua:replacement_sale_plan` | WR-010; `tests/advisor_funded_copy371.lua` |
| Burglar's future Yorick/Burnt opportunity | `Brainstorm/Advisor/strategy.lua:burglar_discard_horizon_cost`, `joker_value`; `blind_start.lua` for actual transition | WR-011; `tests/advisor_burglar_horizon371.lua` |
| Safe-current-blind future Joker reroll | `Brainstorm/Advisor/strategy.lua:shortfall_reroll`; `paid_reroll.lua:development_suggest` | WR-012; `tests/advisor_proactive_reroll371.lua` |
| Shared shop score/common worlds and output | `Brainstorm/Advisor/shop_scoring.lua`, `decision.lua:run` | `runs/engine371_candidate/validation/`, `runs/engine371_installed_validation/` |
| Source metadata and cash reserves | `Brainstorm/Advisor/snapshot.lua:shop_forecast`, `catalog_joker.lua`, `liquidity.lua` | mixed-source, debt and interest cases in proactive fixture |
| Public cohort and canonical findings | `win_rate_research/20260923_2_169_ten_start/REPORT.md`, `WIN_RATE_RESEARCH.md` | loaded 2.169 only; no captured-state evaluation |
| Release and exact installed bytes | `install_slice.py`, `checkpoint_record.py`, `validate_checkpoint.py` | `SESSION_RESET_371.json`, `runs/engine371_final/final_verification.json` |
| Passive decision and action wall timing, journal sidecar join and score-body target | `performance.lua`, `player_journal.lua:207-216`, `score_cache.lua`, `scoring.lua`, `search.lua`, `shop_scoring.lua` | `analyze_teacher_decision_timing.py`, `development372/wall_time_decomposition.py`, `development372/PERFORMANCE_AUDIT.md`, focused Python tests |

Release 371 changes gameplay policy and diagnostics but no auto-run lifecycle,
native DLL, search recipe or teacher settings. Its activation is not observed.
