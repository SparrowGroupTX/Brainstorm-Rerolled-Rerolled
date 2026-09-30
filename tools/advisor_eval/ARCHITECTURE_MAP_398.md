# 398 navigation — Acorn final-hand candidate

For the user's next Blueprint/Death work, begin with
`FRESH_CHAT_HANDOFF_399.md` rather than expanding this Acorn-only map or
repeating the entire historical handoff. It names the shop/pack/replacement,
consumable targeting and hand/discard routes plus relevant tests/evidence.

The installed checkpoint remains `SESSION_RESET_397.*` (2.192). The uninstalled
2.193 candidate, full gate and release steps are in
`CANDIDATE_CHECKPOINT_398.md` and `runs/acorn398_candidate/`. Next work is
`NEXT_PRIORITIES_398.md`; older installed/loaded claims in historical maps
are superseded by these records.

| Question | Narrow source/evidence |
| --- | --- |
| What was the observed Acorn gap? | `development396/REPORT.md` start 1 and `analysis/actions.json`, especially last-hand action 3371; WR-049. Immediate public-order play left three discards at the 102,610/400,000 loss. |
| How is a public row certified? | `Advisor/acorn_public.lua:sync`, `acorn_belief.lua:advance_public/validate`; source inventory and all retained slot orders, never the concealed live Joker row. |
| Where is the new decision? | `Advisor/decision.lua:public_joker_decision` charges the existing ordinary score allowance, `acorn_ordering.lua:suggest` ranks fixed last-hand plays, and `acorn_discard.lua:suggest` compares first discards/common redraws; `runtime.lua` loads and displays it. |
| How are effects and draws modeled? | `Advisor/scoring.lua:after_discard/lower_bound` supplies exact public discard effects/Yorick and supported score floors; `draws.lua:fill` handles supported replacement visibility. The new module rejects hidden outside composition, unsupported effects, divergent worlds and incomplete work. |
| What validates the boundary? | `tests/advisor_acorn_last_discard398.lua` has manufactured rescue, order/ID invariance, 120-order, Yorick, Purple, ability mismatch, malformed state and budget controls. Full candidate gate: `runs/acorn398_candidate/validation/report.json`. |
| What remains? | No full blind tree, held-consumable planning, Faceless posterior, loaded-2.193 outcome or demonstrated >50% win rate. |
