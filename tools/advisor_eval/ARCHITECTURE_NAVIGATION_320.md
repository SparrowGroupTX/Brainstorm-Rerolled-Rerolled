Unchanged architecture inherits ARCHITECTURE_MAP_319.md. Current additions:

| Area | Runtime source relative to Brainstorm/ | Tests relative to tests/ | Evidence |
| --- | --- | --- | --- |
| Optional exact-five observed discard | Advisor/multi_discard.lua, blind_finishing.lua | advisor_pack_five.lua, advisor_multi_discard.lua, advisor_blind_finishing.lua | FIVE_CARD_PACK_320.md |
| Shared complete root family | Advisor/shop_scoring.lua, pack_survival.lua | advisor_pack_five.lua, advisor_certificate.lua, advisor_pack_survival.lua | development300/pack_five319/integration_manifest.json |
| Physical discard history | Advisor/blind_finishing.lua producer; pack_survival.lua consumer | advisor_pack_five.lua | Actual IDs and exact monotonic boolean history; original resource guards preserved |
| Additive scoring growth | Advisor/growth.lua | advisor_growth_additive.lua | ADDITIVE_GROWTH_319.md |
|8x/16x Game speed | UI/game_speed.lua; Core loader | advisor_game_speed.lua | ANIMATION_SPEED_318.md |

The pack family remains bounded by the same shared50k scoring ledger, at mostfour
plays/one discard/one setup, four common worlds and complete-family admission.
Fixtures are manufactured and do not qualify whole-game survival. Proposed C07
must freeze the final exact installed full graph, while live UI speed/startup
remains outside original-source action dispatch. Release tools are unchanged.
