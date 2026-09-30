# Architecture delta424

Includes ARCHITECTURE_MAP_423.md in full. Incremental behavior:

- search.lua: qualifying neutral five-card Yorick growth can bypass only the
  utility taper when a complete family of at least24 samples all clears and its
  minimum certified sampled score reaches105% of the remaining target. Existing
  resource/population/conflict guards, positive growth, eligibility, caller caps,
  fast-clear choices and remaining-blind continuation veto remain unchanged.
- player_journal.lua: bounded full_batch_preference scalar in risk receipts.
  It describes admission of a search proposal; selected/final_action_kind/matches
  distinguish a final discard from a later veto. No extra score work or worlds.
- advisor_discard_aggression424.lua:93 manufactured assertions, synthetic score
  surfaces with actual after_discard transitions and production arbitration.
  Baseline423 decline reproduced; positive margin and negative boundary cases.
- Core/Brainstorm.lua and steamodded_compat.lua: combined version2.207.0-alpha.
