# Bounded finishing and concealed-card scope after 2.48

This inspection reads the current source; it does not infer population wins or
use game state, saves, live actions or hidden future draw order.

`search.lua` already compares a current play and selected current discards with
remaining-blind score accumulation, but explicitly sets `future_discards=false`.
`multi_discard.lua` requires exactly one playable hand. The independent
`two_hand_finish.lua` slice tests the uncovered decision of keeping a discard
available for the final hand when exactly two hands remain. It requires an
existing complete two-hand play-only comparison that is not already a sampled
certain finish. It shares the existing 12,000-score specialist ceiling, runs
mutually exclusively with final-hand multi_discard, and does no fast-clear work.

The scope is two first actions (the existing current play and discard), four
composition-based outer worlds, and at most one conditional final-hand discard
selected from two candidates using four fresh conditional inner worlds. The
later action can depend on its observed hand but not its future draws. Every
compared hand exhaustively checks legal subsets of at most eight held cards.
Exact existing after_play/after_discard and sampled draw transitions carry
growth, paid discards, population removal and Glass outcomes. Unknown generation,
random scoring, concealed future observations and incomplete comparisons fail
closed. This is not a general joint optimizer, an owned-consumable planner, or a
population blind-win probability. It does not expand the ordinary search budget.

## Concealed-card blocker

Current snapshots retain real rank/suit/enhancement and physical identity even
for face-down held cards. The scorer explicitly warns when it uses those
identities; the current obvious/discard candidate builders also rank by them.
`draws.lua` rejects challenge flipped-card visibility, while Wheel visibility
already has its own sampled effect channel. Merely adding a challenge flip roll
would leave the current hidden-identity oracle in candidate generation.

A correct next slice needs a sanitized observation and belief population:

- Keep visible held and already observed discarded/played information fixed.
- Reassign unseen composition among hidden held slots and remaining deck before
  candidate selection; physical IDs must not preserve the real assignment.
- Condition the assignment on what visibility reveals. The Mark hides faces
  (with Pareidolia/Stone rules), while House/Fish and Wheel/challenge randomness
  carry different information. Original `Blind:stay_flipped` and the independent
  `flipped_card` draw in `CardArea:draw_card_from` establish these differences.
- Fix each observable action across common belief worlds. Never choose a
  separate action after seeing that world's hidden identities.
- Verify action invariance when actual hidden assignments are permuted while
  public observations and total unseen composition remain unchanged.

That observation/conditioning work is a prerequisite to useful concealed-card
forecasts. This slice leaves concealed states explicit instead of adding an
optimistic visibility-only patch.
