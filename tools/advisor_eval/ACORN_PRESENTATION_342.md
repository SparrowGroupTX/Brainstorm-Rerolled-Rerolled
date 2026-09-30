# Public Joker presentation lifecycle - 342

The passive session documented in AUTO_RUN_TERMINAL_341.md confirms loaded
2.140. Its last blind played four hands for 147,894/400,000 and lost at zero
hands, leaving three discards. Five public Jokers retained 120 possible orders;
four action completions and zero public effect observations were recorded.
The five-run cap and prematurely dismissed loss overlay were fixed in 341.

Read-only preserved source card.lua lines 4113-4142 shows Card:flip assigning
flipping='f2b'/'b2f', while Card:update changes sprite_facing and pinch.x=false
without clearing flipping. common_events.lua lines779-785/875-917 supplies
attention_text's major/text/backdrop_colour after focus redirection. Exact
source hashes and ranges are sealed in development342/presentation_component/
result.json and validation_01_evidence.json. No executable ZIP was read or
original source executed. The passive log lacks the full live presentation
fields, so this is a concrete source mismatch rather than proof that every
missing popup had this single cause.

Advisor/acorn_public.lua now qualifies a directed flip as settled only when
its direction is recognized, logical/rendered facings both match its target,
and pinch.x is explicitly false. That shared local predicate controls shuffle
settling, visible-front memory, hidden redaction, display-slot observation,
public reorder authorization and drag-origin certification. Nil-direction
legacy cards remain supported unless pinch is active or malformed. Unknown,
missing and mismatched directed-flip fields remain blocked.

Advisor/snapshot.lua uses the same presentation predicate before reading Joker
identity. Advisor/gold_stickers.lua uses its equivalent through raw get, retaining
opt-in and hidden-row public-inventory fallback. Settled fronts are no longer
permanently unavailable after a back-to-front flip. Actual backs stay redacted.
No new identity join, RNG read, scoring budget, inference class or loader
dependency is introduced.

tests/advisor_acorn_public.lua adds source-shaped flip/settle fixtures leaving
flipping nonnil: six worlds narrow to two from a rendered X4 event; juice stays
non-identifying; settled backs authorize existing public proofs and observed
drag; revealing fronts remain hidden until settled, then retire belief and
can be remembered before a later concealment. Poisoned concealed identity
fields are never read. Snapshot and Gold tests cover front recovery, explicit
redaction, active/nil/unknown/malformed transition fields and Gold rawget safety.
The original modules fail at the expected six-versus-two assertion; staged
modules pass 190 Acorn and 334 Gold checks. Full candidate/exact-installed reports
are under runs/presentation342_candidate, presentation342_installed,
presentation342_installed_validation and presentation342_final.

The change restores supported public observations. It does not demonstrate a
rescued blind, improved terminal outcomes or calibrated win odds. Complete
discard/consumable/hand planning, broader resources and unknown ability
transitions remain outside current Acorn support. All experiment budgets stay
closed; no source/search/replay/attempt worker ran. Current configuration, logs,
native files and all earlier evidence remain preserved. Tools did not control
the game; installed 342 activates at the user's normal restart.
