# Shop callback settlement repair

The read-only development log audit identified an asynchronous execution error,
independent of the quality of the strategic recommendation. A purchase callback
was accepted while its cash and card transfer effects were still queued. Another
public state change allowed auto-run to acknowledge the purchase, issue another
purchase against stale cash, and even buy the same still-visible card twice.

The parent audit binds the original observation files and event sequences. Its
specific example is development seed S7PXV521: Judgement purchase at sequence
4552, Droll at 4561, unrelated prior cash change acknowledged at 4568, repeat
Droll purchase at 4570, Arcana purchase at 4579, and cash -8 by 4584. This is
development evidence, not a holdout or a counterfactual outcome claim.

## Change

`Brainstorm/Core/auto_run_product.lua` now observes outstanding blocking events
in the game's base event queue before considering a shop state settled. It does
not run, edit, clear, or retime any event. Nonblocking visual events alone do not
block readiness; malformed queue structures fail closed. The scan is bounded at
2,048 entries and stops as soon as an outstanding blocking event is found.

Ordinary card/voucher purchases and pack opens additionally bind the exact live
card, original area, run identity, and pre-dispatch cost. A receipt releases only
after the expected cash debit and the corresponding physical transition:

- Ordinary purchase: the exact card leaves its shop and enters the owned area.
- Voucher: the card leaves its shop and its public used-voucher flag is present.
- Pack: the card leaves its shop, the phase is a pack, and choices are populated.

Both observation readiness and the final Execute gate enforce this barrier.
Unrelated snapshot changes cannot acknowledge an unfinished transaction or
dispatch the next action. Zero-cost purchases still require transfer, and
legitimate negative cash under the existing borrowing rules is supported.

The receipt survives ordinary user input and explicit Stop/Resume. It is cleared
for a different run or a verified checkpoint-loaded notification. A confirmed
runtime preflight rejection releases it; a callback that may have queued work
does not. Existing callback legality, capacity, borrowing, inventory, profile,
logging, action freshness, and session-limit checks remain in force.

## Evidence and limits

Read-only preserved original source inspected, without extracting the executable
or executing original-source callbacks:

- `runs/shop_sequences_source_20260910_02/source_probe.lua`,
  `G.FUNCS.buy_from_shop`: delayed transfer, later cash debit, queued repricing.
- `runs/chicot_order_source1/source/engine/event.lua`: blocking base events remain
  queued until their completion/time conditions are met.
- `runs/chicot_order_source1/source/card.lua`: pack population, voucher redemption.

Manufactured regression `tests/advisor_shop_settlement357.lua` passes 37 checks,
including transfer-before-cash, cash-before-transfer, unrelated changes,
duplicate prevention, affordability after settlement, zero-price and borrowed
purchases, vouchers, pack population, event-queue shapes, checkpoint/run changes,
and preflight versus uncertain callback failures. Existing product (1,147 checks)
and teacher controller (248 checks) fixtures also pass. These are fixture checks,
not original-source components, captured-state policy comparisons, or matches.

No live game, save, profile, search, source component, or complete attempt was
executed. No win-rate or rescued-run claim follows. Other actions continue to use
their existing phase/lock readiness; the new base-queue shop gate also covers
their outstanding blocking shop effects. This does not declare arbitrary modded
nonblocking effects qualified. Full candidate/installed validation belongs to the
parent release record.
