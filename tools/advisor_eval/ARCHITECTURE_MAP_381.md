# Architecture navigation for release 381

This is a delta map. `ARCHITECTURE_MAP_380.md` and its linked maps retain the
broader Acorn, auto-run, shop and teacher architecture.

| Question | Source and evidence |
| --- | --- |
| Where is the win-first temporary-offer selection? | `Brainstorm/Advisor/strategy.lua:replacement_sale_plan`; compare existing `eligible` endpoints and retain the same offered Joker. `shop_scoring.lua:compare` provides four common worlds and paired finishing evidence. |
| Where is the bounded public receipt? | `Brainstorm/Advisor/player_journal.lua:compact_replacement_review`; only scalar opening/selection fields are published. |
| What validates the selection? | `tests/advisor_engine_retention381.lua` and existing replacement/sequence fixtures; `development381/{SCOPE,REPORT}.md` has acceptance and public anchors. |
| Where is the exact release? | `development381/{freeze,release}.py`, `runs/engine381_{candidate,installed,installed_validation,final}/`, `SESSION_RESET_381.json`. |
| Where are the separate discard/order boundaries? | `Brainstorm/Advisor/growth.lua:drawn_hazard/accept`, `ordering.lua`, `phase_copy.lua`; the frozen audit is `development381/REPORT.md`. No 381 policy edit there. |

Never use the frozen public observations as policy/scorer inputs or infer
concealed identities from later events. The complete original journal is
preserved under `win_rate_research/20260924_132921_interrupted/capture/`.
