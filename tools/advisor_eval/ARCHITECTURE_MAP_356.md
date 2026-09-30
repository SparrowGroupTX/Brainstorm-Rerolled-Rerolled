# Current architecture —356

Current installation, outcomes, exact hashes and authority: `SESSION_RESET_356.md`
and `.json`. Current work: `NEXT_PRIORITIES_356.md`. Later status supersedes
historical pending wording. This navigation grants no experiment authority.

Changed-source/test/component scope: `TEACHER_COLLECTION_356.md`.

# Teacher collection 356 source / tests / component navigation

- Advisor/snapshot.lua: route_blinds and route_ante across all run phases, with
  per-row ante/state and visible targets/restrictions; legacy next_blind phase
  contract retained. tests/advisor_snapshot.lua covers each decision phase and
  unknown unsupported target scaling.
- Advisor/runtime.lua: temporary perkeo_yorick_win_v1 profile retains the public
  ledger under collection_progress while disabling optional collection trades;
  records freshly published advice. tests/advisor_runtime.lua covers restoration.
- Advisor/decision.lua: teacher profile suppresses generic speed-oriented blind
  routing; normal/opening advice, growth, phase-copy and all score caps remain.
- Core/auto_run_product.lua: explicit teacher preset, bounded search/launch,
  journal reset API, public progress-key cache, independently verified retirement
  receipt, opaque private-fingerprint export and end-of-session restoration.
  tests/advisor_auto_run_product.lua covers preset/search/recording integration.
- Advisor/auto_run.lua: ten actual starts, thirty-second public progress watchdog,
  safely deferred retirement, terminal priority, separate outcomes and durable
  in-memory Stop/Resume caps. tests/advisor_teacher_batch356.lua plus existing
  advisor_auto_run fixture cover the manufactured lifecycle and error families.
- Advisor/player_journal.lua and player_log_archive.lua: teacher state/advice
  references, actual action callback linkage, bounded warning cadence, closed
  writer and contained observation-only cleanup. tests/advisor_teacher_journal356.lua
  plus existing journal/archive fixtures cover correctness and preservation.
- UI/collection_run.lua: one explicit labeled teacher start button. Existing
  advisor_gold_layout, startup/input/status fixtures cover bounded menu geometry.
- tools/advisor_learning/public_context.py and its tests: versioned causal public
  context for future demonstrations, separate from legacy355 tensors/checkpoint.
  teacher_demonstrations.py validates and links ordered JSONL/BRJ2 records.
  tests/test_advisor_teacher_encoding.py includes all30manufactured contracts in
  the full regression. development356/encoding/COMPONENT.md documents the schema
  and CLI; development356/tooling freezes these tools and their exact dependencies.
- TEACHER_COLLECTION_356.md and development356: scope, authority, prepared-only
  outcome record, finite prospective budget and release receipts.

Read SESSION_RESET_355.md / ARCHITECTURE_MAP_355.md for closed learning pilot
provenance and rejected checkpoint; ARCHITECTURE_MAP_354.md and its relevant
links retain current growth/copy/reroll/retirement navigation. No historical
unchecked item or unused quota creates new experiment authority.


Preserved earlier navigation: `ARCHITECTURE_MAP_354.md`; read only
relevant sections. Earlier documents and their verification receipts remain
intact. They are not current installation or experiment authority.
