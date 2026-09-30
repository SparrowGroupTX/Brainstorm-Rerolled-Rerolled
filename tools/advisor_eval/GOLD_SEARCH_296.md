# Missing-Joker normal search preparation — 296

Completionist++ now links to **Find a missing Joker**, a separate **Gold search**
page using the existing bounded page holder. It lists only known missing vanilla
Jokers from the loaded active-profile tracker. User clicks prepare existing
normal reroll filters; no rendering, selection, preparation or restoration starts
search, changes deck/stake, changes seeded flags, launches a run or plays a move.

`Brainstorm/Advisor/gold_search.lua` is a pure preparation/binding helper.
`choices` returns canonical names and profile-bound tickets; `prepare` rechecks
the current profile, target identity/status and full progress/count contract.
`restore` returns an independent copy of the saved filters. Each requires an
explicit click and no active search. Plain finite filter metadata is copied with
a 4096-node cap. Existing unknown filter fields survive; unrelated advisor,
challenge, CPU and retry settings are outside the helper's mutation scope.

139 ordinary targets use the existing Ante1 early route, without forced edition,
voucher, pack, tag or unrelated filter criteria. Five Legendaries use the existing
single-Soul starting Charm route. Native source-name exceptions Canio, Séance and
Riff-Raff are explicit. This reuses the current native search; no DLL changed and
no search-speed measurement ran. Native search assumes complete profile unlocks;
the UI and returned instructions disclose that assumption. Gold history alone
does not verify the user's unlock flags or qualify native offers for a profile.

Six targets remain excluded from direct fresh-run search: Stone Joker, Steel
Joker, Glass Joker, Golden Ticket, Lucky Cat and Cavendish. The first five need a
corresponding enhancement; Cavendish needs Gros Michel's extinction. The current
normal native timeline does not simulate these eligibility changes. The UI
explains them, and `Core/Brainstorm.lua` now rejects all six in normal filter
validation before search starts. The separate challenge validator is preserved.
Stone has a separately labelled **Prepare Marble prerequisite only** button; it
searches Marble, never claims a Stone offer, and tells the user to find Stone
later during play. No unlock/progress bypass or native lock change was added.

`runtime.lua` loads the helper; `UI/advisor.lua` owns explicit configuration
callbacks and the target screen; `UI/ui.lua` adds navigation. The first prior
filter set is stored in the existing `collection_previous_filters`, shared with
the earlier Collection helper. Further preparations preserve that first backup;
explicit restoration clears it after restoring exact content. Profile switches,
new sticker completion, selection changes and changed filters invalidate stale
prepared descriptions. A stale prerequisite callback cannot fall back to a
different direct search. The longest route has a bounded compact layout; the
running game's UI was not inspected or controlled.

Evidence: `development295/helper_focused1` passed one read-only canonical-name
compatibility Python check and 7206 synthetic preparation checks. It binds all150
keys/names to the preserved source catalog and current native/UI names. Root
`development294/searchIntegrated1` passed seven relevant fixtures before the
last compact-layout refinement; the final frozen full candidate/installed
regressions include the refinement and its UI bound check under `search296`.
Related tests: `advisor_gold_search.lua`, `advisor_ui.lua`,
`advisor_collection_search_ui.lua`, `advisor_normal_stone_filter.lua`, existing
runtime/tracker and syntax fixtures. Source compatibility is not original-source
execution, full adapter qualification or an acquisition result.

No source component, replay, hidden search, terminal attempt, actual profile/save
inspection or game control ran. Settings and both native DLLs remain preserved.
Neither an offer nor passing tests proves acquisition, affordability, retention,
survival, completion speed or win odds. Full user workflow and limits are in
COMPLETIONIST_PLUS_PLUS_GUIDE.md. Runtime slices293–296 implement the current
normal-deck/Gold-sticker request; further empirical development remains bounded
by fresh prospective authorization, with no pending or renewed historical jobs.
