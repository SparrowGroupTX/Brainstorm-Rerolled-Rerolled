# 393 navigation — visible copy slot and preserved loss evidence

| Question | Source and evidence |
| --- | --- |
| What is the observed failure? | `development392/analysis/actions.json` linked public 25462 sale with Brainstorm follow-up, 25472 Buffoon open, 25483 Popcorn choice, 25506 shop exit; original 25 BRJ2 segments and hashes in `development392/logs1/` and `capture/`. |
| Where is the comparison? | `Brainstorm/Advisor/strategy.lua:best_shop_purchase` selects visible offers and packs, then `replacement_sale_plan` and `replacement_sale_advice` compare and describe sale-first endpoints. `shop_advice` recomputes after each settled action; `Core/auto_run_product.lua` executes one action at a time. |
| What changed? | `strategy.lua` adds last-ordinary-slot risk for known vanilla Buffoon packs to the existing bounded win-first durable-copy tie rule; candidate 2.191 version headers in `Core/Brainstorm.lua` and `steamodded_compat.lua`. |
| How was it checked? | `tests/advisor_copy_slot393.lua` 16 manufactured checks; existing `advisor_win_first_resources386.lua` cash protection; `runs/copy_slot393_candidate/{freeze.json,validation/}` 260 Lua/392 Python, unchanged hashes. Independent read-only review/recheck found no blocker. |
| What remains? | `WIN_RATE_RESEARCH.md` WR-043/044, `NEXT_PRIORITIES_393.md`, `CANDIDATE_CHECKPOINT_393.md`; candidate uninstalled during new sprint. |
