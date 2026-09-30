# Inventory reuse architecture — 337

| Layer | Current scope |
| --- | --- |
| General and clearing owned-use advice | `consumables.suggest` / `develop` lazily own one temporary preservation context per invocation. |
| Starting strategy | `strategy.preservation_context` computes the original profile and whole original inventory once. |
| Retained strategy | `preservation_cost` recomputes every retained pool under the original profile; copy-source guards and output tuple are unchanged. |
| Development | Target and gain calculations share the before profile while preserving each after-state effect. `choose_pack_targets` accepts that profile optionally. |
| Advice lifetime | Context is neither returned nor persisted. An actual action and next advice call rebuild all starting values. |
| Compatibility | Strategies without the optional context constructor retain their existing three-argument preservation/development calls. |
| Prior work | 334 adjacent duplicate grouping, 335 journal work and 336 scoring work remain separate preserved slices. |

Regression: `tests/advisor_inventory_reuse.lua`, with frozen before modules in `tests/fixtures/inventory337/`. Measured isolated evidence is under `development335/inventory_component/`. Component: `INVENTORY_REUSE_337.md`. Final session/release receipts own installation status and full-suite totals. This navigation grants no source/search/captured experiment authority.
