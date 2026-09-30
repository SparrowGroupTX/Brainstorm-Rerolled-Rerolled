# Physical shop ordering navigation347

- Advisor/gold_order.lua: pure<=720 legal physical permutations,<=6 canonical
  current/copy-target rows; stable-ID ties, pinned/visibility/copy-cycle guards,
  detached actual reorder projection and stale-receipt rejection.
- Advisor/gold_acquisition.lua: exact reorder/sale/buy projection, whole-family
  preflight and current-row budget fallback before scoring; actual reorder as
  first action with fresh advice before any paid continuation.
- Advisor/gold_retention.lua: complete paid incumbent versus current/canonical
  held rows; zero-action current hold first, actual reorder otherwise.
- Advisor/shop_scoring.lua: context:preflight_family exact prepared-key cost,
  up to128states, successful cache reuse and explicit failed-cache rejection.
- Advisor/runtime.lua and decision.lua: dependency wiring and protection of
  qualified retained reorder/exit from unrelated phase-copy postprocessing.
- Advisor/player_journal.lua and tests/advisor_gold_journal.lua: bounded flat
  row counts, actual arrangement count, complete cost and fallback diagnostics;
  candidate arrays and receipts stay outside observation events.
- tests/advisor_gold_order.lua, advisor_shop_family_preflight.lua,
  advisor_gold_acquisition_order.lua, advisor_gold_retention_order.lua and
  advisor_gold_retention_order_runtime.lua: manufactured mechanics/accounting
  and actual Decision integration; no captured player replay.
- development347/{order_component,preflight_component,retention_component,
  root_component}: staged changes, immutable receipts and preserved failures.
- GOLD_SHOP_ORDER_347.md: scope, evidence and exact release limitations.
- ARCHITECTURE_MAP_346.md: constructor validation/source-shaped inventory
  navigation; prior architecture maps remain available through it.

Navigation is not experimental authority.
