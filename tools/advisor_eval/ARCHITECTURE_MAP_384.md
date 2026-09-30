# 384 behavior and evidence navigation

This delta supplements `ARCHITECTURE_MAP_383.md` and the subsystem maps
linked by `ADVISOR_START_HERE.md`.

| Question | Current source and evidence |
| --- | --- |
| What happened in the ten starts? | `development384/logs1/manifest.json` fixes 24 public segments. `capture/{manifest,summary}.json` checks 18,179 consecutive events; `actions.json`, `rounds.json`, `runs.json`, `diagnostic.json` are passive compact projections. `REPORT.md` gives limitations and outcome classification. |
| Why did Acorn retire? | `Advisor/acorn_belief.lua:stable_opaque_ability/advance_public`, `Advisor/acorn_public.lua` and `Advisor/decision.lua:public_joker_decision`. `tests/advisor_acorn_belief.lua` covers 120 worlds and strict five-Joker ability shapes. Seven-Joker support remains separate. |
| What trades a clear for Yorick? | `Advisor/decision.lua:early_yorick_comparison_available`, `Advisor/search.lua:risky_yorick_clear/trial`, `Advisor/growth.lua:suggest`. `tests/advisor_yorick_discard382.lua` covers complete 24-world late floor/neutral-resource contrasts. |
| How is cash invested? | `Advisor/strategy.lua:shortfall_reroll/surplus_reroll`, `Advisor/paid_reroll.lua`, `Advisor/liquidity.lua`, `Advisor/catalog_joker.lua`, `Advisor/player_journal.lua:compact_reroll_review`. `tests/advisor_proactive_reroll371.lua` covers additive reserves, full-row witnesses and exclusions. |
| How are Perkeo and Hanged handled? | `Advisor/strategy.lua:inventory_value/manage_teacher_stock/needs_death_source/booster_value`, `Advisor/deck_development.lua:M.apply/M.targets`, `tests/advisor_win_first384.lua` and `tests/advisor_deck_development.lua`. |
| What speed candidate shipped? | `Core/event_cadence.lua` requests 1/120 at 64x under native RUN guards. Source proof/review remain in `development383/{SCOPE,REPORT}.md`; it was incorporated unchanged in 2.182. |
| How was release attested? | `development384/{freeze,preinstall,release}.py`, `runs/win384_candidate/`, `runs/win384_installed/`, `runs/win384_installed_validation/`, `runs/win384_final/`, `SESSION_RESET_384.json`. |

Routine manufactured fixtures and passive source/log analysis only. Do not
evaluate the captured public states with a policy/scorer or run the game.
