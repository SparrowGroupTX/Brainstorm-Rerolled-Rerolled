# Speed option architecture - 339

- `Brainstorm/UI/game_speed.lua`: extends the existing change_gamespeed control
  with 8/16/32/64; preserves value-based mapping, labels and native persistence.
- `Brainstorm/Core/Brainstorm.lua`: unchanged module loading; version stamp only.
- `Brainstorm/steamodded_compat.lua`: matching version stamp.
- `tests/advisor_game_speed.lua`: full selection/persistence and callback guards.
- `ANIMATION_SPEED_339.md`: current component evidence; `ANIMATION_SPEED_318.md`
  retains original implementation and existing source-mechanics observations.
- `ARCHITECTURE_MAP_338.md`: current advisor redundancy/strategy source/test map.

All prior advisor runtime changes remain intact. This navigation grants no
experiment authority; activation waits for the user's normal restart.
