# Parent-only staging

No production files have been changed by this package preparation. The exact four production paths are:

- `Brainstorm/Core/collection_search_product.lua`
- `Brainstorm/Core/auto_run_product.lua`
- `tests/advisor_collection_product.lua`
- `tests/advisor_auto_run_product.lua`

Canonical test copies under `tests/` load production `Brainstorm/Core` paths. The similarly named files at this package root are detached fixture runners that load the draft and must not be copied to production tests.

From the repository root, inspect the guard with `python -B tools/advisor_eval/development300/start_status316/stage.py --describe`. Root may explicitly stage with the same command plus `--stage` instead of `--describe`. This helper has not been called with `--stage`. It verifies all four current base hashes, all four candidate hashes, preserved base bytes and test-record hash before any write, then creates a one-use staging receipt and rechecks each source/destination immediately before replacement. It refuses changed existing work and refuses replay after any receipt. It never installs or runs tests/workers. Partial failure preserves its receipt and existing base bytes without automatic rollback.

`stage_manifest.json` binds the file pairs; `base_bytes/` preserves the original uncommitted bytes. After staging, root should run the two canonical fixtures along with the complete release regression. No worker-loader change is included here; root owns that separate file.
