# Architecture navigation after release 378

This is a delta map. Use `ARCHITECTURE_MAP_377.md` and linked 376/375/371/
370/369 sections for the broader advisor, auto-run, search, release and
score-budget structure.

Pending uninstalled 379 navigation: `Advisor/manual_run_log.lua` owns
human-run identity, source-confirmed terminal receipts, 10/10 retention and
recoverable pruning; `Advisor/player_log_archive.lua` selects separate
literal auto/manual namespaces; `Advisor/player_journal.lua` supplies the
shared linked public event schema and callback wrappers; `Core/auto_terminal.lua`
exposes a passive source listener from the existing hook chain;
`Core/auto_run_product.lua:is_auto_game` prevents relabeling auto GAMEs.
`Advisor/performance.lua` emits bounded windows through the selected journal
in `Core/Brainstorm.lua`. Evidence and tests:
`development379/SCOPE.md`, `tests/advisor_manual_run_log379.lua` and
`runs/manual379_candidate2/`.

| Question | Runtime/source anchor | Evidence |
|---|---|---|
| Where is the visible copy exception? | `Brainstorm/Advisor/strategy.lua:copy_replacement_exception` and `replacement_sale_plan` | WR-017; `tests/advisor_copy_acquisition378.lua` (37 checks) |
| How are cash, rental and survival protected? | `strategy.lua:copy_replacement_exception`, `liquidity.lua:estimate`, `shop_scoring.lua:compare`, `blind_finishing.lua:forecast` | Full-family, actual-cash and four-world negatives in the fixture; reviewer findings in `development378/SCOPE.md` |
| Why did the bounded optional engine reroll decline? | `strategy.lua:shortfall_reroll`, `paid_reroll.lua:development_suggest`; scalar statuses in `context.reroll_development_diagnostics` | `tests/advisor_proactive_reroll371.lua` (24 checks) |
| What reaches public journals? | `decision.lua:shop_diagnostics`, `player_journal.lua:compact_replacement_review`, `compact_reroll_review`, `observe` | Explicit allowlists; no catalog, world assignments or hidden identities |
| Where is the motivating real-game evidence? | `win_rate_research/20260924_032258_ten_start/{REPORT.md,copy_opportunities.json,capture/manifest.json}` | Loaded-label-2.175 action 9566; qualifying four-world finish unknown |
| How were exact bytes released? | `install_slice.py`, `validate_checkpoint.py`, `development378/release.py` | `SESSION_RESET_378.json`; `runs/copy378_{candidate,installed,installed_validation,final}/` |

No new scorer calls, score-cap increase, auto-run lifecycle change, native
DLL, configuration or save access belongs to this slice. Installation
requires the user's normal restart for activation; it does not demonstrate
full-run improvement.
