# Amber Acorn Lucky-card score floor - 340

Passive log decision 4547 (2026-09-15 23:58:25UTC, loaded 2.138) has a complete,
supported, state-valid public belief: five Jokers,120 possible orders, eight
visible cards, including one Lucky Jack. A blanket playing-card guard rejected
the hand. Sequence4554 stopped auto-run 30 seconds later with unsupported_stalled,
four hands, three discards and 0/400,000 chips. Exact closed-segment and stored-frame
hashes are in `development340/passive_log_analysis.json`. This is read-only
diagnosis, not a captured-policy replay or terminal counterfactual.

`acorn_ordering.lua` admits Lucky by requiring `scoring.lower_bound` for every
candidate/world, including subsets that leave the Lucky card held. Each legal
result needs a reliable finite supported floor, no uncertainty and no warnings.
Explicit illegality excludes that fixed action across worlds while all remaining
comparisons continue. One floor pass is charged once; no preceding average pass
or private outcome sampling is used. Complete family preflight and 140,000 ordinary
/30,000 order caps stay unchanged. Non-Lucky hands retain their existing scorer.

`decision.lua` charges floor calls through the shared budget, labels the
supported-random-floor scope and preserves the existing conservative public
world-floor proof. Exact-looking average Lucky triggers cannot certify a clear.
It also surfaces an existing explicit invalid-belief reason when available.

`tests/advisor_acorn_lucky.lua` passes 26744 manufactured checks: complete
world/subset counts, poisoned hidden payloads, no RNG/mean fallback, false-clear
prevention, complete robust reorder, fresh post-reorder advice, current row
resource/inventory preservation, unknown/unreliable bounds and unchanged
unsupported guards. The eight-card/five-Joker case covers 26,160 real floor calls.
Prior focused 310-check evidence remains preserved in the component directory.
Full candidate/exact-installed reports are under `runs/acorn340_candidate`,
`runs/acorn340_installed`, `runs/acorn340_installed_validation` and
`runs/acorn340_final`; final records own exact hashes, counts and installation.

Later passive events show supported belief after the first manual play, then an
uncertified Joker drag and a reload without public pre-concealment inventory.
Read-only source review does not establish an update race: ordinary controller
drag dispatch precedes advisor update. No uncertified movement or hidden identity
is recovered. A restart already inside the blind has no observed pre-shuffle
inventory; continue from before blind selection to establish public memory.
The separate Glass/population, Blue/Gold reward, larger world-family and unknown
ability-transition limits remain. No full blind continuation or rescued run is
claimed. All experiment allowances stay closed; current logs, settings and native
files are preserved, and tools leave the running game undisturbed.
