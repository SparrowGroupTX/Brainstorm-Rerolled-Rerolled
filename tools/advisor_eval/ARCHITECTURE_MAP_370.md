# Architecture navigation after 370

Use `ARCHITECTURE_MAP_369.md` for the full policy/runtime/test map; the
following are the affected paths and current diagnostic entry points.

| Question | Runtime anchor | Evidence and focused tests |
|---|---|---|
| Auto-run controller, freshness, acknowledgement | `Brainstorm/Advisor/auto_run.lua` | `development370/AUTO_RUN_ARCHITECTURE.md`; `tests/advisor_auto_run.lua` |
| Pre-dispatch shop settlement and adapter wiring | `Brainstorm/Core/auto_run_settlement.lua`, `auto_run_product.lua`, `Brainstorm.lua` | `tests/advisor_auto_run_settlement.lua`, `advisor_auto_run_product.lua`, `advisor_shop_settlement357.lua` |
| Teacher mode and public journal | `Brainstorm/UI/collection_run.lua`, `Brainstorm/Advisor/runtime.lua`, `Brainstorm/Advisor/player_journal.lua` | `win_rate_research/20260923_2_169_ten_start/capture/`, `checkpoint.json` |
| Shop scoring, replacement, cash and stock | `Brainstorm/Advisor/strategy.lua:1301-1665`, `paid_reroll.lua` | WR-010/WR-012 in `WIN_RATE_RESEARCH.md`; `actions.json`, `copy_opportunities.json` |
| Burglar/discard transition and growth | `Brainstorm/Advisor/blind_start.lua:132-170`, `strategy.lua:383-391`, `growth.lua` | WR-011; `rounds.json`, run6 action6651 |
| Late consumable/hand decisions | `Brainstorm/Advisor/decision.lua`, `consumables.lua`, `scoring.lua` | cohort `deep_dive.json`, `arithmetic.json`; WR-001/002/007 |
| Release | `tools/advisor_eval/install_slice.py`, `checkpoint_record.py`, `validate_checkpoint.py` | `runs/auto_arch370_candidate/`, `auto_arch370_installed/`, `auto_arch370_installed_validation/`, `auto_arch370_final/` |

The loaded 2.169 cohort and installed 2.170 architecture bytes are separate
strata. Public version labels do not attest exact loaded bytes. No new policy
strategy or native change is included in release 370.
