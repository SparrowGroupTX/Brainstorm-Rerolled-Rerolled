# Slice 458 acceptance: booster opening order and independent source probe

Read-only original source in the pinned archive shows the stock loop at
`game.lua:3145-3159` and the Booster use branch body at
`functions/button_callbacks.lua:2241-2247`. The stock loop stores one key per
physical slot, skips `'USED'`, and assigns `booster_pos` after shop UI setup.
The use branch writes `'USED'` before drawing/opening the card.

Engineering acceptance before editing the overlay:

1. Preserve the exact 457 overlay/integration bytes under its frozen evidence
   directory before advancing either live file.
2. With a manufactured pack-open callback that reads `used_packs`, the old
   candidate exposes the pack key and the repaired candidate exposes `'USED'`
   for the physical position. Invalid phase, index and unaffordable actions
   leave the slot and cash unchanged. The settled 457 cases keep passing.
3. Prepare, but do not run, a one-use original-source probe containing the
   exact unmodified stock-loop bytes and exact use-branch body bytes.
   Prescribe pack results in the existing eight no-tag plain-price fixtures.
   Independently record draw count/order, persisted physical slots, offered
   key/order/position, and whether the opened callback sees `'USED'`.
4. Strictly parse complete records; reject duplicates, missing cases, extra
   get_pack calls, malformed fields, source errors and source/candidate/model
   mismatches. Manufacture parser success/failure cases without executing
   original source. Freeze exact archive/runtime/harness/candidate hashes.

The probe's original-source worker remains unstarted without a fresh one-use
approval for the exact caps in `SOURCE_EXECUTION_PROPOSAL.md`. The prepared
probe does not qualify full `Game:update_shop`, `G.FUNCS.use_card`, price
calculation, tags, RNG, purchase legality, Perkeo exit or whole-game behavior.
