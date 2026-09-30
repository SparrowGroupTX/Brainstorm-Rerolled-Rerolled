# User strategy preferences retained for simulator coverage and later policy work

These preferences explain what matters to the user. They are policy objectives,
not replacements for actual game rules, legal information or survival evidence.
Latest user corrections take precedence over early absolute statements. The
current primary task is simulator fidelity, not simultaneous implementation of
every preference below. Do not assume each preference is completely implemented.

## Objective and opening

Immediate objective: strong actual Red Deck/Gold Stake win-first play with the
searched Perkeo/Yorick opening. A reliable teacher and real public demonstrations
support future training. The longer-term Completionist++ goal concerns new distinct
Gold stickers per real time, including losing runs, search/retries, computation,
animations and actions. Win-first mode deliberately suppresses optional sticker
trades; do not use the old355 sticker reward by accident.

The searched Charm/Soul opening must follow its actual tag/routing. Do not assume
every first Small Blind has a Charm Tag or a synthetic post-Soul state reproduces
the opening seed/RNG history. Blueprint or Brainstorm by around the end of Ante5
is an important preference. Burnt is useful/optional, with search cost considered.
User requested maximum native CPU product mode, not unlimited agents/experiments.

## Discards are the strongest stated priority

The user repeatedly emphasized using all worthwhile discards, preferably five
cards each, to scale Yorick. Finishing immediately while several discards remain
is a critical suspect pattern. The user later allowed genuinely rare exceptions,
targeting fewer than1% of clears retaining discards; this target is not achieved
or established. Do not enforce an unsafe unconditional discard that destroys a
supported win path or ignores payment, visibility, held-card or forced-card rules.

Requested benchmark: average at least12 discarded cards per round when3 discards
are available, plus4 cards per extra available discard (4 ->16,5 ->20). Report
eligible round populations, missing/censored joins and zero-discard rounds
explicitly. Cards per discard and discards used are separate metrics. Do not reward
the training policy simply for discard count at the expense of eventual wins.

Optional Tarot development should generally wait until discard opportunities
have been used; applying Hierophant/Empress early can lock policy into preserving
an inferior held hand. Death can expand feasible discard/deck-development plans,
but unseen future cards are not guaranteed. Phase-specific survival proof matters.

## Copy Jokers and shop economy

Blueprint/Brainstorm acquisition is a major target. Open Joker packs when sensible
to find them, including while protecting a useful acquisition reserve. Avoid
unnecessary pedestrian early Joker purchases that prevent later copies; the user
specifically disliked Trading Card's one-card-discard incentive. Joker value must
depend on the actual run, rank-repeat hands and sometimes1–3 scoring cards.

Yorick is a core engine and should not be sold casually. Perkeo can be sold for
Blueprint/Brainstorm before the final boss when copying a strong Yorick is worth
more and actual inventory/economy/horizon exceptions are considered. This is not
blanket permission to sell Perkeo early for inferior purchases.

Explicit cash-spend preferences, subject to useful/legal purchases and essential
engine preservation: any time above$50; from Ante4 above$35; at Ante5 above$40 was
also separately requested; from Ante7 above$25. The later Ante4+35 rule is stricter
than the earlier Ante5+40 statement. Preserve both history and effective policy;
do not accidentally relax a later rule. Spending does not justify selling an
essential Joker to buy an inferior one merely to burn cash. Check actual current
implementation thresholds when relevant rather than assuming this file proves them.

Keep a useful Perkeo copying pool. Early even a weak Planet can be better than an
empty slot; later replace weak templates with relevant Planets/Tarots. The user
favored 3OAK/4OAK Planets over redundant Judgement, using/selling Judgement when
supported to improve copying. A shop reroll or Tarot pack can be useful when the
only template is poor. Wild-card Tarot is usually low priority, not forbidden in
every context. Avoid fixed scalar Joker/consumable rankings overriding actual runs.

## Death and playing-card development

Strong Death sources should be selected deliberately, including fishing through
discards when safe. Playing-card packs can reveal a stronger source; move to it
when worthwhile rather than preserving a mediocre template indefinitely. User
preferences, conditioned on actual effects and legal/public context:

| Dimension | Strongest to weaker |
|---|---|
| Abilities/editions, most important | Glass, Polychrome, Steel, Foil, Holographic, Mult(+4), Bonus(+30 chips) |
| Rank | King, Queen, Ace,10,Jack |
| Suit, much less important | Club, Spade, Diamond, Heart |
| Seals | Red, Blue; Purple/Gold useful but lower priority |

Glass may break and should not be played unnecessarily. This is the user's default
ordering, not a mathematical dominance relation: holding Steel, retriggers, hand
levels, bosses, preservation and actual score can change the best target. Negative
consumables, Observatory and full Perkeo source value must remain represented.

## Burnt and phase ordering

Use all worthwhile discards even when the desired first-discard hand is not yet
available. If safe, a non-winning setup play can fish for a better first Burnt
discard. Temporarily stop copying Yorick when its extra score would prematurely
clear; retain those copies if necessary for expected survival. Copy Burnt for the
first discard and Yorick for scoring; copy Perkeo before leaving the shop.
Different phases may need different physical Joker orders. Correct timing and
order are simulator requirements as well as policy concerns.

## The Fool

Fool may become a useful template after a good Tarot/Planet is used. Do not assume
multiple Fools can be used back-to-back after just one target use: after using
Fool, the last-use state matters. To repeat the intended card, the appropriate
sequence is target -> Fool -> created target -> next Fool when legal and useful.
Model actual creation, capacity, last-used state and settlement; do not invent
the future target or ignore a blocked slot.

## Other observations and reporting preferences

Investigate skipped Invisible Joker, inferior Joker-pack choices (including a
reported polychrome Burnt), expired-Joker replacement, insufficient discards and
Amber Acorn stalls. User reports are useful hypotheses; verify against linked
public observation/candidates/value/admission/budget/arbitration/settled action.
One reported Mr. Bones purchase blocking Blueprint was not confirmed: that
journal showed a pack Mr. Bones then successful$1 rental Blueprint, and the user
accepted the correction. Do not preserve a disproven hypothesis as fact.

The user wants candid results, decisive authorized work, preservation before logs
can be cleared, and no repetitive closure-confirmation questions. Never claim
50% wins, all issues fixed or optimal decisions without appropriate loaded-game
evidence. Good documentation should reduce the next chat's required context.
