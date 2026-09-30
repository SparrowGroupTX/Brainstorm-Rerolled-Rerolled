# Discard visibility repair — 2.66, 2026-09-11

The user reported Fragile showing “Concealed-card advice unavailable” despite
all held cards being visible. They initially thought it affected the first hand,
then clarified: a new round was fine, and ordinary discards triggered the refusal.

Original CardArea:align_cards turns every front-facing discard card to its back
for display. Snapshot copied that orientation into the playing-card population;
concealed_belief.has_hidden treated those nondrawable cards as unknown identities.
On an ordinary blind, admission then failed because there was no concealment
source. This was a generic discard regression, not unsupported Fragile scoring.

Snapshot.capture now interprets the original source observation marker only for
exact card objects in G.discard.cards. Without ability.wheel_flipped, a discarded
card has a publicly known identity despite its back-facing display. With that
marker, it remains unknown and joins the existing conditioned posterior. The
source's remaining-deck display uses the same marker. Disabling a supported
concealment boss clears it and changes the publicly displayed remaining pool.
The disabled flag by itself is never used as permission to reveal an identity.

Raw M.card, held cards, draw-pile cards and arbitrary outside cards retain their
existing facing/unknown behavior. No live data is changed. Population size and
nondrawable membership are conserved. There are no challenge or seed branches,
no scoring/budget changes, and no weakening of concealed observation-history
guards. Glass destruction and the existing finishing/growth protections remain.

## Evidence

- runs/discard_visibility266_previous_repro records the new regression failing
  against the frozen 2.65 snapshot, as expected. It is an intentional old-policy
  failure, not a failed current release or a game outcome.
- runs/discard_visibility266_validation1: eight Lua fixtures / 1,407 checks pass
  within the hidden 60-second cap, unchanged hashes. New discard fixture: 73
  checks including real Decision/Search/Scoring for ordinary and Glass decks.
- runs/discard_visibility266_source1: 44 original-source cases / 680 comparisons
  pass in 0.091 seconds under a 30-second cap. Actual emplace, align_cards, draw,
  flip and disable methods run in isolated lua51.dll. Source, policy, harness and
  DLL hashes are frozen. Covers five blinds, challenge flips, Glass, known and
  concealed discards, initial draws and reveal/disable transitions.
- The previous concealed263 source check stubbed align_cards and therefore
  missed the automatic discard flip. Its historical result is preserved; the
  new source fixture closes that specific coverage gap.
- runs/fragile266_readonly_belief_audit independently excludes unsupported
  Fragile scoring and verifies the zero-score admission failure mechanism.
- Final exact installed-policy suite: runs/development266_installed_validation.

Only Advisor/snapshot.lua was selected for install_slice.py; the installer also
stamped the two version files. Runtime 2.66.0-alpha installed at 10:17:10 CDT,
backup deployment-backups/advisor-20260911-101709. Both native DLLs unchanged.
No game process/window, live gameplay or saves were touched. Activation waits
for the user's normal restart; this does not patch the currently loaded Lua.
Settings were verified unchanged during this installation. Their current hash
differs from the historical 2.65 checkpoint; no configuration was overwritten.

These fixtures establish the repaired mechanics, not measured challenge wins.
The broader full-attempt pilot remains deferred before execution.
