# Exact-five Yorick pack continuation and discard history — 320

One-choice Buffoon pack comparisons with an already owned active Yorick can now
compare a third fixed policy: one observed discard of exactly five eligible
cards, then supported plays. The two existing policies remain. The root declares
the family once, and baseline/every offered endpoint uses that same family across
the same four composition worlds. It selects from the current observed hand,
includes forced cards, preserves Purple cards in the Certificate family and
does not force a discard when a current play already clears.

A concrete integration defect also blocked otherwise valid discarded trajectories:
the exact scorer marks ability.discarded=true, but the resource comparison treated
that history flag as a physical card mutation. The flag is now retained in the
explicit per-card history receipt. Actual pre-discard physical IDs are recorded;
each endpoint must preserve every nil/false/true marker except those exact IDs
becoming true. Missing/duplicate/unknown identities, invented or reversed marks,
and all unrelated physical changes still reject.

Every admitted policy must complete. The original shared50,000 shop-score cap,
four-play/one-discard/one-setup limits, cash, Blue generation, whole inventory,
population, surviving successful-world rewards and Yorick development guards
remain. The new family does not independently grant permission to buy Card Sharp
or ignore Certificate generation. Failed/partial comparisons keep the fallback.

Changed modules: Advisor/multi_discard.lua, blind_finishing.lua, shop_scoring.lua
and pack_survival.lua, plus version metadata. New fixture: advisor_pack_five.lua.
Detached source/fixture/staging provenance is development300/pack_five319,
manifest SHA25617b360a8e6e8772e897ef97e566ee49c5bab1acc43b06569b5b41a503e5ed5c3.
Its historical directory319 does not identify this runtime release.
Independent review: development300/reviews/pack_five319.json,
SHA256f74b00fb6af4dd4b4ea631137e7fa59c059d44b0c3dc63d0af59f392341e35a4.
The initial reviewed validator lacked a four-play bound; its bytes are preserved
under review_revisions/before_four_play_guard. Final fixtures reject forged five
and six plays as well as malformed policies/history/resource receipts.

Focused validation: five suites,1,449 checks. A manufactured ordinary52-card
Pair-level3/Yorick-five-to-upgrade case completes the full family in6,406 scores.
The added Card Sharp policy clears all four worlds at the constructed1,809-chip
threshold; the older two Card Sharp policies leave some worlds uncleared.
The complete unchanged resource selector chooses that policy. This is a unit
fixture, not a recorded blind, rescued run, terminal result or win-rate estimate.

Full candidate/exact-installed validation and exact hashes are in
runs/pack320_candidate, pack320_installed, pack320_installed_validation and
pack320_final. No source/search/captured/complete worker was used for this runtime
slice. Existing8x/16x menu choices and319 growth repair remain included; this
installation activates only after a normal user restart.
