# 387 discard-comparison architecture delta

Read `ARCHITECTURE_MAP_386.md` and its referenced subsystem maps for the
unchanged shop, consumable, recorder and deployment paths. The frozen 2.185
candidate changes the win-first known-clear discard decision only.

| Question | Source / evidence |
| --- | --- |
| How is the win-first comparison entered? | `Advisor/decision.lua:early_yorick_comparison_available/run` enables the ordinary bounded `Advisor/search.lua:run` path for a supported Yorick clear through Ante 8. Other fast-clear paths keep their 70-score contract. |
| Where is the complete-world budget reserved? | `Advisor/search.lua` builds a deterministic per-size shortlist, computes a conservative per-trial play/floor/Hook cost, reserves supported continuation/growth work, then bounds samples before sampling. An unaffordable 24-round comparison leaves the certain play. |
| Which discard can replace the clear? | `Advisor/search.lua:risky_yorick_clear` checks each complete candidate's sampled survival, late supported 105% floor, exact transition, physical Yorick and neutral cash/population terms. Equal best sampled survival favors more physical cards. The continuation prior is the selected candidate and cannot substitute an uncertified alternate. |
| How is final advice reported? | `Advisor/decision.lua:stamp_yorick_choice` reconciles search with specialist/clear-shortcut action; `Advisor/player_journal.lua:compact_yorick_review` exposes scalar coverage and selected-card counts, not sampled deck identities. |
| What is still out of scope? | `Advisor/growth.lua:drawn_hazard` keeps draw-sensitive retained-score guards. `Advisor/consumables.lua` and `Advisor/strategy.lua` still handle current-hand Tarot/Planet and shop/pack choices separately; ordinary post-draw search does not model future owned-consumable use. |

Exact files, manufactured fixture and frozen validation:
`development387/REPORT.md`, `tests/advisor_yorick_discard382.lua`,
`runs/yorick387_candidate/{freeze.json,validation/}`. This candidate is not
installed; later public play on loaded 2.184 does not validate it.
