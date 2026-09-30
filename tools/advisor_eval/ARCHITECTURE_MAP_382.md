# 382 Yorick discard navigation

This delta supplements `ARCHITECTURE_MAP_381.md` and its links.

| Question | Source and evidence |
| --- | --- |
| Which current clears enter an ordinary redraw comparison? | `Brainstorm/Advisor/decision.lua:early_yorick_comparison_available` sets `search_options.win_first_yorick_clear_discard` and disables fast-clear only for win-first Ante<=5 active Yorick X<=4. `Brainstorm/Advisor/search.lua:M.run` gates the early clear return and accepts only a completed 24-common-world, exact-transition, stage-tapered result. |
| Where are 5-card and resource preferences? | `Brainstorm/Advisor/search.lua:yorick_progress_bonus` admits only source-normal neutral cards, no paid/population/cash cost or Ramen/Green Joker; the premium applies only at the maximal sampled clear count. Original paired sampling and continuation arbitration remain. |
| Where is the retained-clear alternate? | `Brainstorm/Advisor/growth.lua:select_clear` scans already-scored reliable 105%-margin alternatives without resource regression; `suggest` still applies draw/order hazards and exact retained-clear proof within 12 scores. `Brainstorm/Advisor/decision.lua:consider_growth` passes the selected anchor once. |
| Where is the user-facing risk and final action receipt? | `Brainstorm/Advisor/decision.lua` reconciles search proposal with final specialist action; `Brainstorm/Advisor/runtime.lua` states when a certain clear is exchanged for a sampled redraw and that the sample percentage is uncalibrated. `Brainstorm/Advisor/player_journal.lua:compact_yorick_review` records bounded public scalar risk, anchor and growth-rejection fields. |
| What validates and releases it? | `tests/advisor_yorick_discard382.lua`, `development382/{SCOPE,REPORT}.md`, `runs/yorick382_candidate2/{freeze.json,validation/}`, `SESSION_RESET_382.json` and `runs/yorick382_final/final_verification.json`. Candidate and exact-installed gates passed; the first passing candidate is preserved and superseded. |

The frozen loaded-label-2.175 public prefix remains observational only; do not
run its captured states through policy/scorer or infer hidden draws. Preserve
70 fast-clear, 140000 ordinary and 12 growth score caps.
