# Current architecture —314

Current installation, outcomes, exact hashes and authority: `SESSION_RESET_314.md`
and `.json`. Current work: `NEXT_PRIORITIES_314.md`. Later status supersedes
historical pending wording. This navigation grants no experiment authority.

Changed-source/test/component scope: `PACK_COMPARISON_314.md`.

Paths in the table are relative to Brainstorm/; tests are relative to tests/.
Component notes are in tools/advisor_eval/. Read the current checkpoint before
using a historical component's installation or experiment status.

| Area | Runtime source | Relevant fixtures | Component/evidence |
| --- | --- | --- | --- |
| Entry, capture and fresh advice | Advisor/runtime.lua, snapshot.lua, decision.lua | advisor_runtime.lua, advisor_snapshot.lua | Current checkpoint; CLEAR_BUDGET_303.md, GOLD_COMPARISONS_308.md |
| Exact scoring and bounded search | Advisor/scoring.lua, score_cache.lua, search.lua | advisor_scoring.lua, advisor_score_cache.lua | Existing source/mechanics and scoring bounds in ARCHITECTURE_MAP_281.md |
| Hands/discards/owned consumables | Advisor/resource_finish.lua, two_hand_finish.lua, multi_discard.lua, consumables.lua | Corresponding advisor_*.lua fixtures | Existing finite complete-world and population guards; current tests define scope |
| Yorick, Burnt and phase copies | Advisor/growth.lua, phase_copy.lua, ordering.lua | advisor_growth.lua, advisor_burnt_population.lua, advisor_phase_copy.lua | C01/C03/C04 preserved development post-mortems; neither forced five-card discards nor fixed long-term hand |
| Paid/shop/pack decisions | Advisor/strategy.lua, shop_scoring.lua, shop_sequences.lua, economy.lua, liquidity.lua | advisor_shop_scoring.lua, advisor_shop_sequences.lua, advisor_shop_order.lua | GOLD_COMPARISONS_308.md; fixed common-world Joker order and actual setup cost |
| First-blind generation | Advisor/certificate.lua, blind_start.lua, blind_finishing.lua | advisor_certificate.lua, advisor_blind_start.lua, advisor_blind_finishing.lua | CERTIFICATE_COMPARISONS_309.md; active-cycle M15/M16 source text |
| Gold collection comparisons | Advisor/gold_stickers.lua, gold_goal.lua, gold_perkeo.lua, bell_opening.lua | advisor_gold_goal.lua, advisor_gold_perkeo.lua, advisor_bell_opening.lua | GOLD_COMPARISONS_308.md; acquisition is not a sticker award |
| Search query and route | Advisor/collection_search.lua, gold_search.lua, normal_opening.lua; Core/collection_search_product.lua, collection_search_runtime.lua, collection_search_worker.lua | advisor_collection_query.lua, advisor_collection_product.lua, advisor_collection_runtime.lua, advisor_collection_worker.lua | ADAPTIVE_QUOTA_306.md, BURNT_FALLBACK_307.md; source S03/S04/S05; full150 route remains unfinished |
| Start buttons and auto-run | UI/collection_run.lua; Advisor/auto_run.lua; Core/auto_run_product.lua, auto_terminal.lua | advisor_collection_status.lua, advisor_auto_run.lua, advisor_auto_run_product.lua, advisor_auto_terminal.lua | STARTUP_READINESS_304.md, BURNT_FALLBACK_307.md; M18 UI startup audit |
| Public logs and user checkpoints | Advisor/player_journal.lua, player_log_archive.lua; Core/checkpoint_store.lua, checkpoint_runtime.lua | advisor_checkpoint_store.lua, advisor_checkpoint_runtime.lua and archive/journal fixtures | Current source guards; read_player_log.py decodes archived public logs; never use player saves for evaluation |
| Persistent manual retry | Advisor/retry_memory.lua, retry_policy.lua, retry_journal.lua | Corresponding advisor_retry_*.lua fixtures |270 persistent five-report cap; disabled clean source context |

Current native loader/file/hash is in SESSION_RESET. Native work requires the
existing sidecar/evidence gate. An installed native file or static offer proves
neither affordable acquisition nor run survival.

Evaluation and release tools:

- development299/cycle.py: atomic one-use registration/dispatch and closed
  historical-budget protection. The active cycle's authority/records are under
  runs/gold299_20260914; exact slots and expiry come from its latest context.
- engine_probe.py / frozen engine_run.lua adapters: experimental original-source
  ZIP + isolated Lua execution. Never launch the executable. New module wiring
  requires an explicit frozen graph; merely freezing a module is insufficient.
- development299/trace_brief.py and trace_costs.py: read-only summaries of the
  preserved synthetic traces. C01 win, C03 loss, C02/C04 timeouts remain distinct.
- install_slice.py: explicit runtime files, backup, current settings/native
  preservation, verified deployment. checkpoint_record.py freezes installed
  bytes; validate_checkpoint.py runs bounded full fixture/regression checks.
- finalize_runtime_checkpoint.py: binds exact reports, documentation and budget
  context. Its optional architecture note keeps navigation compact while linking
  preserved history; it never modifies runtime/settings or grants source jobs.

Unchanged challenge architecture/source/test navigation remains in the relevant
ARCHITECTURE_MAP_281.md sections. Jokerless and Knife's Edge are still requested;
no verified Jokerless win or stronger-than-human performance is demonstrated.

Pack survival311: Advisor/pack_survival.lua, strategy.lua, blind_finishing.lua and runtime.lua; tests/advisor_pack_survival.lua; PACK_SURVIVAL_311.md. Every complete finishing trajectory now carries an optional bounded endpoint receipt; the pack override remains narrow and adds no scores.

Perkeo Planet312: Advisor/perkeo_inventory.lua, gold_planet_policy.lua, gold_goal.lua, gold_perkeo.lua, snapshot.lua, decision.lua and runtime.lua. New fixtures advisor_perkeo_inventory.lua and advisor_gold_planet_policy.lua. PERKEO_PLANET_FAMILY_312.md records whole-inventory source proof, complete bounded use families and actual final-blind delivery. Arbitrary Tarot copying and unsupported metadata still decline.

Auto-only Legendary313: Advisor/collection_search.lua; Core/collection_search_product.lua and auto_run_product.lua; UI/collection_run.lua. Fixtures advisor_legendary_opening.lua and advisor_legendary_auto.lua. AUTO_LEGENDARY_313.md records unchanged manual/strict recipes, exact alternate opening binding and the unsupported six prerequisite targets.

Pack comparison314: Advisor/pack_survival.lua; tests/advisor_pack_comparison.lua; PACK_COMPARISON_314.md. Complete bounded policy/world equality retains every field and existing resource/Yorick guards. Prospective captured M21 binds exact installed312/314; no terminal outcome follows from fixtures.


Preserved earlier navigation: `ARCHITECTURE_MAP_313.md`; read only
relevant sections. Earlier documents and their verification receipts remain
intact. They are not current installation or experiment authority.
