# Cash-out to settled shop-entry slice 455: prospective acceptance

Selected before the candidate repair. This slice starts at a manufactured
`ROUND_EVAL` state with a prescribed, already-evaluated earnings total and ends
at the stable `SHOP` bookkeeping boundary. It does not qualify reward
calculation, shop stock generation, tags, blind changes, shuffle/RNG, or event
frame timing. Cases have no Boss defeat, awarded tags, or RNG. Shop population
is replaced with an empty recording sink solely to observe the state passed
to that boundary.

Actual original `functions/button_callbacks.lua:2912-2956` shuffles, queues
shop entry, queues `ease_dollars(current_round.dollars)`, then records
`previous_round.dollars`. Shop entry resets `jokers_purchased` to 0,
`discards_left` to `max(0, round_resets.discards + round_bonus.discards)`,
`hands_left` to `max(1, round_resets.hands + round_bonus.next_hands)`, and
clears `shop_free` and `shop_d6ed`. The source assigns the dollars field in
`previous_round`, preserving other fields. Original `ease_dollars` queues
the cash mutation; only settled cash is compared.

The pinned Jackdaw `game._handle_cash_out` pays the stored earnings and
enters SHOP but leaves shop-entry hands/discards/purchase count stale, leaves
`shop_free` set, and replaces the whole `previous_round` dictionary. The
candidate under test is that actual handler reached through `game.step`
with `CashOut()`, not a copied payout formula.

## Frozen fixture family

1. Minimal mismatch: cash 7, earnings +1, old hands/discards 0/0,
   reset base 4/3, purchase count 2. Settled SHOP expects cash 8,
   hands/discards 4/3 and purchase count 0.
2. Already-correct control: current resources 4/3, reset base 4/3;
   no spurious changes to other current-round counters.
3. Bonus composition: reset base 4/3 and bonuses +2/+1 yield hands/discards
   6/4 at the shop boundary.
4. Clamp control: combined hands below 1 and discards below 0 yield 1/0.
5. Held-out: nonzero old hands/discards, zero payout, `shop_free` set and a
   retained non-dollar `previous_round` field. The field survives cash-out.
6. Negative payment control: a prescribed -3 earnings total lowers cash by
   exactly 3 while shop-entry counters still reset.

## Acceptance

- Preserve the unpatched mismatch at its first ordered state/event field
  with full fixture and dependency hashes. Repair only the supported
  cash-out bookkeeping cause in an in-memory overlay; leave the pinned
  upstream and installed runtime unchanged.
- Use a separate handwritten source-derived reference and the pure lifecycle
  comparator. Compare settled cash, SHOP phase, resources, purchase count,
  `shop_free`/`shop_d6ed` clearing, `previous_round` fields, and the state
  passed to the empty shop-population boundary. A deliberately swapped pair
  of comparison observations must fail without mutating either input; these
  observations do not establish source event-frame order.
- Main, negative controls and held-out case must agree. Existing 453/454
  tests and the near-expiry learning guard must remain intact.
- No original-source worker, full game, training, Balatro control, save/profile
  read, product install or historical budget renewal is part of this
  manufactured qualification. Source execution would require its own newly
  registered bounded proposal and fresh authority.

Read-only source archive SHA-256:
`0d75fe164accf3312734d4b37ac98788dd15f0b8e4f9bb8b7f90c4e59de93f47`.
`functions/button_callbacks.lua` SHA-256:
`c88a74ca3a8fa8ace0ce46ad10a97238f347c292842c9164d11136fe9952c101`.
`functions/common_events.lua` SHA-256:
`522ea0810101de1004685e13e7ed05a750b4e115e5231dca2cbc97aeb8c3e5fc`.
