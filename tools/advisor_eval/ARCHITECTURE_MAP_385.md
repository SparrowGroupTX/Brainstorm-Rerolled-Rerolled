# 385 cash-fallback architecture delta

Read `ARCHITECTURE_MAP_384.md` for other subsystems. Release 385 changes
only the shop decision handoff:

| Question | Source/evidence |
| --- | --- |
| Where does score truncation discard shop candidates? | `Brainstorm/Advisor/decision.lua:run` calls `Strategy.advise` without a scoring context after any incomplete shop comparison. The 385 branch clears abandoned reroll diagnostics and invokes only `Strategy.surplus_reroll` against that complete fallback. |
| What qualifies the unscored opportunity? | `Brainstorm/Advisor/strategy.lua:surplus_reroll` is exported without changing its source-catalog, cash, interest, purchase, slot, cash-scaling, fee≤$12 or unsupported gates. It accepts only fallback `leave_shop`. |
| How is final admission reported? | `Brainstorm/Advisor/player_journal.lua:compact_reroll_review` reads the final diagnostic; 385 clears stale pre-fallback reroll receipts. |
| What is independently checked? | `tests/advisor_proactive_reroll371.lua` has a real manufactured truncated 500-score context and negative fallback/exclusion contrasts. `development385/capture/` indexes the passive public evidence; `runs/cash385_candidate/` freezes exact candidate bytes and validation. |

No game/save/profile access, captured-policy/scorer run, native change or
increase to the 50,000-shop score cap belongs to this slice.
