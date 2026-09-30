# Current architecture —339

Current installation, outcomes, exact hashes and authority: `SESSION_RESET_339.md`
and `.json`. Current work: `NEXT_PRIORITIES_339.md`. Later status supersedes
historical pending wording. This navigation grants no experiment authority.

Changed-source/test/component scope: `ANIMATION_SPEED_339.md`.

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


Preserved earlier navigation: `ARCHITECTURE_MAP_338.md`; read only
relevant sections. Earlier documents and their verification receipts remain
intact. They are not current installation or experiment authority.
