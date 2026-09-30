# Loaded Gold-sticker progress — 294

The opt-in Completionist++ page reads only the active profile already loaded in
the user-run product. It shows the 150 vanilla Jokers as complete, missing or
unknown, plus distinct missing keys currently held. A held or acquired Joker is
never counted as a completed sticker. No profile/save is loaded or changed by
the advisor. Tools validated synthetic tables only.

`Brainstorm/Advisor/gold_stickers.lua` interprets `joker_usage[key].wins[8]`
against a verified vanilla eight-stake catalog and exact vanilla Joker keys.
Absent entries in a valid loaded history are missing; malformed or unavailable
records remain unknown. Modified stake mappings and modified vanilla centers
are unsupported. Seeded/challenge/already-won/endless contexts receive no active
collection objective. Missing held inventory makes eligibility unknown.

`runtime.lua` adds this detached metadata to runtime snapshots only when enabled,
so profile switches and newly awarded stickers invalidate stale recommendations
and Execute tokens. Standalone source snapshots remain opt-out and clean.
Published advice reports collection status and discloses acquisition or sale
of a last missing copy; tactical rankings are unchanged in this slice.

`UI/advisor.lua` and `UI/ui.lua` add a Completionist++ page, pagination and an
explicit Enable Completionist++ action. Only that action sets advice enabled,
normal-deck advice enabled and tracking enabled. Rendering/paging never writes
configuration. Saved settings remain unchanged during installation.

Source navigation: preserved
`runs/planet_pool_source1/source/functions/misc_functions.lua` 1034–1069 records
held Joker wins and derives the sticker from recorded stakes; preserved
`runs/diagnostic287_20260913_222344/b_preparation2/source/functions/common_events.lua`
contains seeded/challenge progress guards. The vanilla stake schema is
corroborated by public upstream `game.lua`, not a new installed-source execution.
The 150-key list is checked against the preserved source-default catalog.

Tests: new `tests/advisor_gold_stickers.lua` covers 304 checks; runtime/UI and
collection navigation fixtures cover opt-in, profile switching, stale Execute,
distinct copies, unknown metadata, saved settings and read-only rendering.
Seven focused fixtures passed under `development294/integrated1`; full frozen
candidate and exact-installed results use the `gold294` evidence prefix.

No source component, captured replay, hidden search, terminal attempt or game
control ran. Both native DLLs and current settings are preserved. This is
progress tracking and disclosure, not yet a collection-aware action override
or evidence of Completionist++ speed, win odds or stronger-than-human play.
