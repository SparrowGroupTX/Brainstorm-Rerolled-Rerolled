# Architecture navigation after release 376

This is a delta map. Use `ARCHITECTURE_MAP_375.md` and its linked 371/370/369
maps for the wider advisor, auto-run, search, speed and release structure.

| Question | Runtime/source anchor | Evidence |
|---|---|---|
| Where does public Fool source identity enter the hand snapshot? | `Brainstorm/Advisor/snapshot.lua:fool_source` and `snapshot`; Jupiter center descriptor only in hand phase | `tests/advisor_snapshot.lua`; `development376/SCOPE.md` |
| How is one Fool-to-Jupiter cycle projected? | `Brainstorm/Advisor/consumables.lua:project_fool_jupiter`, existing `apply`; capacity, last-used key, usage and Flush level | `tests/advisor_fool_stock376.lua` (43 manufactured checks) |
| How is stock use chosen against holding? | `Brainstorm/Advisor/consumables.lua:fool_jupiter_stock`; `strategy.lua:inventory_value`, `preservation_cost`, `development_gain` | WR-015 ledger; full inventory/action/cash comparisons in fixture |
| Where does it enter hand arbitration? | `Brainstorm/Advisor/decision.lua` after normal selected play; specialist actions and supported clears retain priority | `tests/advisor_fool_stock376.lua`; `development376/REVIEW.md` |
| Which operating profile reaches this path? | `Brainstorm/Advisor/runtime.lua` attaches `teacher_profile` to snapshot for the existing win-first control | Frozen cohort profile projections; reviewer static check |
| What remains outside this slice? | `shop_sequences.lua:suggest`, `pack_scoring.lua:owned_fool_candidate`, other consumable source keys, Observatory and unknown Joker callbacks | `NEXT_PRIORITIES_376.md`; WR-014/015 |
| How were exact bytes released? | `tools/advisor_eval/install_slice.py`, `validate_checkpoint.py`, `development376/release.py` | `SESSION_RESET_376.json`; `runs/fool376_{candidate,installed,installed_validation,final}/` |

The hand path uses no extra scorer calls and changes no ordinary/shop/
consumable/fast-clear/growth score caps. It does not change auto-run lifecycle,
the searched opening, native DLLs, configuration or saves. Installation is
not activation, and the preceding loaded-label-2.171 cohort cannot measure
2.175 full-run benefit.
