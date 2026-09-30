# Current architecture —327

Current installation, outcomes, exact hashes and authority: `SESSION_RESET_327.md`
and `.json`. Current work: `NEXT_PRIORITIES_327.md`. Later status supersedes
historical pending wording. This navigation grants no experiment authority.

Changed-source/test/component scope: `LOG_DIAGNOSTICS_327.md`.

# Navigation additions for 327

Read `LOG_DIAGNOSTICS_327.md` for the complete component and evidence map. Runtime freeze analysis now includes the same detached worker path for hand, shop, pack and blind decision phases. `snapshot.phase` supplies a pure phase classifier to avoid full runtime captures outside decision phases; `snapshot.capture` remains the complete internal-state capture for callers that need it. The journal's separate `public_snapshot` function applies concealed-identity redaction for public observations. `decision.lua` passes cooperative yields into blind routing without changing explicit caller options or score caps.

`Brainstorm/Core/auto_run_product.lua` remains the boundary between the controller’s exact internal state identity and public player observations. Its prospective journal export hashes internal `fingerprint`, `before`, `after` and interrupted-action identity strings while retaining full redacted public snapshots. Internal comparisons and execution recaptures are unchanged. Hash failure is explicit and never falls back to raw identity text.

The journal continues to use BRJ2 with its validating `read_player_log.py` decoder. `analyze_player_timing.py` is restored byte-for-byte to its pre-327 source after the deferred BRJ3 compatibility investigation. `inspect_player_log.py` composes those existing readers into a bounded context index and exact hash-bound event extraction. Its manufactured tests are `tests/test_advisor_log_inspection.py`; the fixed runtime is covered by `tests/advisor_runtime.lua`, `advisor_phase_yield.lua` and product/journal fixtures.

Current diagnostic evidence lives under `development327/`: explicit read/capture/analysis plans, stable `captured_logs/`, `capture.json`, `audit.json`, `events_index.json`, `refresh_fix/`, `fingerprint_fix/`, and `context_reader/`. The detached `archive_codec/` and `context_reader/brj3_followup_deferred/` remain development evidence, not deployed code or unfinished authority. Final candidate/install/exact-regression evidence uses `runs/log327_*`; final hashes and release facts belong to generated records.


Preserved earlier navigation: `ARCHITECTURE_MAP_326.md`; read only
relevant sections. Earlier documents and their verification receipts remain
intact. They are not current installation or experiment authority.
