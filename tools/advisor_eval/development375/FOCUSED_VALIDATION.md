# Focused manufactured validation (2026-09-23)

This fixture was created from an independent full-row Joker family, not a
captured state. It includes developed Yorick, Perkeo, Rocket, Mr. Bones and
Supernova, with one visible Blueprint offer. Its exact original source and
final source are the current `tests/advisor_copy_target_rating375.lua` except
for the recorded changes below. No game or captured-state policy/scorer ran.

1. Before the rating edit, `python tests/run_lua_tests.py
   tests/advisor_copy_target_rating375.lua` failed the assertion
   `developed public Yorick makes the funded Blueprint replacement worthwhile`.
   Output: `FAIL tests\advisor_copy_target_rating375.lua` and
   `0/1 fixtures passed`.
2. The first implementation attempted to call `expired` before its local
   definition. The focused fixture failed with
   `Brainstorm/Advisor/strategy.lua:412: attempt to call global 'expired' (a nil value)`.
   This intermediate defect was corrected with a direct public perishable
   guard; it was never released.
3. The initial manufactured victim's +12 Mult yielded a supported Blueprint
   score ratio 2.0612 but merit 18.5685, below the existing threshold 26.
   To test the intended accepted case without weakening that threshold, the
   independent Supernova victim was set to +4 Mult. The resulting complete
   receipt had merit 28.2726 and selected sale/purchase. The fixture retained
   explicit incompatibility and undeveloped x1 controls. No captured state
   was tuned or replayed.
4. Final focused command ran five relevant fixtures with **5/5 passed**:
   `advisor_copy_target_rating375.lua` (6 checks), `advisor_shop_copy.lua`
   (43), `advisor_funded_copy371.lua` (13), `advisor_event_cadence374.lua`
   (101) and `advisor_game_speed.lua` (781).

Full frozen candidate and exact-installed raw Lua/Python logs and reports
are under `runs/marathon375_candidate/validation/` and
`runs/marathon375_installed_validation/`. Both passed 246 Lua fixtures and
391 Python tests; intermediate focused failures above are preserved and
superseded by the validated final candidate.
