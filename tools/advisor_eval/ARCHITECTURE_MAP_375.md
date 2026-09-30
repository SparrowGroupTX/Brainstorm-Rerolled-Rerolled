# Architecture navigation after release 375

This is a short delta. Use `ARCHITECTURE_MAP_371.md` and its linked 370/369
maps for the wider advisor, product auto-run, search and release structure.
The new cohort's passive extraction scripts and evidence are under
`win_rate_research/20260923_182719_ten_start/`; the canonical status and
priority ledger is `WIN_RATE_RESEARCH.md`.

| Question | Runtime/source anchor | Focused evidence |
|---|---|---|
| Developed Yorick copy-offer rating and full-row sale | `Brainstorm/Advisor/strategy.lua:joker_value`, `replacement_build_value`, `replacement_sale_plan`; `snapshot.lua:card` can omit compatibility flag | WR-013; `tests/advisor_copy_target_rating375.lua`, `advisor_funded_copy371.lua`; public action 16710 |
| Actual paired shop score, order and survival | `Brainstorm/Advisor/shop_scoring.lua:compare`; `strategy.lua:shop_score_evidence` | Four common-world receipt in run 9; unchanged scorer/budgets |
| Fool/Planet stock and shop sequence bounds | `Brainstorm/Advisor/shop_sequences.lua:suggest`, `pack_scoring.lua:owned_fool_candidate/project_owned_fool`, `consumables.lua:apply`, `strategy.lua:manage_teacher_stock` | WR-015; `fool_context.json` and run 9 A8 actions |
| Public Amber Acorn order belief | `Brainstorm/Advisor/acorn_public.lua`, `acorn_belief.lua`, `acorn_ordering.lua`, `acorn_public_hooks.lua` | WR-014; `development375/ACORN_REVIEW.md`; run 6 sequences 12649, 12662–12665 |
| 128x/256x menu and guarded native event pass cadence | `Brainstorm/UI/game_speed.lua`, `Core/event_cadence.lua`, `Core/Brainstorm.lua:Game:update` | `development374/FAST_EVENT_CADENCE.md`; `tests/advisor_event_cadence374.lua`, `advisor_game_speed.lua`, `advisor_frame_timing.lua` |
| Runtime release and verification | `tools/advisor_eval/install_slice.py`, `validate_checkpoint.py`, `development375/freeze.py`, `record_installed.py` | `SESSION_RESET_375.json`; `runs/marathon375_{candidate,installed,installed_validation,final}/` |

Release 375 changes one shop rating branch and installs the already frozen
speed candidate. It does not change auto-run lifecycle, searched opening,
teacher profile, score caps, native DLL, configuration or game saves. The
new cohort predates release 375; its public 2.171 stamps do not verify 2.174
activation or measure 2.174 win rate or acceleration.
