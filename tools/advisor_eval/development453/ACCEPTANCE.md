# Round-end lifecycle slice 453: prospective acceptance

Later source inspection in slice 454 found that original rental payment is
queued by `ease_dollars`; the per-Joker cash snapshots below are projected
settlements, not source callback-timing evidence. The raw 453 receipt is
preserved with that narrower interpretation.

This slice was selected before editing the simulator overlay. It covers a
manufactured, plain-edition Perishable Juggler at its last tally, optionally
rental, with no other round-end callback or dollar-bonus Joker. The candidate is
the pinned Jackdaw `process_round_end_cards` path reached through the learning
overlay. The independent expectation is a small source-derived rule model, not
another call into Jackdaw and not an executed original-source comparison.

## Contract and fixture family

- Compare canonical JSON state: phase `round_end`, cash, hand capacity, ordered
  physical Joker identities, key, rental/Perishable flags, tally, debuff, and
  edition. Compare a settled maintenance boundary for each Joker, with its
  resource state before and after. This observes row order and boundary state,
  not callback timing or rent-versus-expiry timing within one Joker. Private
  RNG and deck order are absent.
- Main case: one active plain Juggler, tally 1, rental, cash 10, capacity 9
  including its passive +1. Expected after maintenance: cash 7, tally 0,
  debuffed, capacity 8, same owned Joker.
- Controls: tally 2 remains active/capacity 9; already expired/debuffed starts
  at capacity 8 and loses no second capacity; nonrental expiry retains cash.
- Held-out order: two expiring Jugglers around a nonexpiring rental ordinary
  Joker. Rent and capacity mutations must occur in row order, once each.
- Separate held Gold/Mime comparison is retained as **unsupported**. It is a
  boundary check, not part of this repair.

## Acceptance

1. The comparator is pure, gives the first differing event or state field,
   detects a deliberately reordered event list, and records case/manifest,
   common prefix, classification, and deterministic reproduction.
2. The old candidate fails the main case at hand capacity; the repaired
   candidate passes main, controls, and held-out row with exact integer fields
   and Joker identity/order. The original failing comparison is retained.
3. The overlay verifies exact upstream bytes and does not edit the pinned
   source. Ordinary manufactured tests do not initialize an episode, execute
   original-source callbacks, control Balatro, or read saves/profiles.
4. Existing broad audit censorship stays in force. The fix does not qualify
   negative edition slot behavior, sale/re-add, queued blind reset, callback
   interleaving, later dollar bonuses, held Mime, cash-out, shop, or next blind.
   Unsupported cases remain distinct from game losses.

Source inspected: retained original `card.lua` `set_debuff` lines 526-538,
`calculate_rental` 2271-2276, `calculate_perishable` 2278-2289, and the retained
`state_events` excerpt lines 97-110. Source `card.lua` SHA-256:
`5073d834e08119da9516f1795a8c3d93110669aeb409c29ad1b308e0eb0be453`.
Pinned `round_lifecycle.py` SHA-256:
`8297786eb523127fe95304f1de8829aa7d93fb56e2819b93aab8cb04862e85dd`.
