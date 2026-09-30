This directory stages internal336 / version2.136.0-alpha with runs prefix
`scoring336`, after the exact installed335 / `journal335` checkpoint.
The agent has not executed production promotion, version stamping, installation
or context publication.

Root review/execution order:

1. Finish and verify journal335, including
   `runs/journal335_installed/record.json`, its complete frozen policy and
   `development335/journal_release/release_final/context.json`.
2. Review and execute `prepare_release.py`. It verifies all previous installed
   policy bytes against the worktree, checks final candidate and fixture seals,
   preserves the scoring/version before bytes, promotes only scoring.lua and
   the two version fields, adds an independent production fixture plus its
   before-module dependency under tests, and freezes `scoring336_candidate`.
3. Run routine full candidate validation with the existing 60-second suite caps.
4. Execute `prepare_context.py` after candidate validation; it carries forward
   the closed335 experiment record and adds all-zero current release counts.
5. Root's existing install, exact-installed validation, final binder and
   finalizer bind actual suite totals and deployment status. Use release336,
   previous335, prefixscoring336 and component `SCORING_REUSE_336.md`, with the
   scoring_release `release_context` notes and finalized context.

The manufactured production-shaped test passed independently in
`standalone_validation3/receipt.json`: 3,402 checks, 476 cases. The test loads
the runtime source and `tests/fixtures/advisor_scoring_reuse336/scoring_before.lua`;
it has no development-directory dependency. Instrumentation is embedded in the
test itself. `validate_checkpoint.py` recursively hashes Lua files under tests,
so the baseline dependency is frozen alongside the test. Runtime helper
dependencies are covered by the complete policy manifest.

Final staged scoring SHA-256:
`f625c294eb5ba9cf0b6da5eb8f871c58be0835aecf92396c09151becef1c80e9`

Final production fixture SHA-256:
`9bbe84a8b4119c82bb788792789d1cbd3896ce179c484586da8f0fd94a998fee`

Before-module SHA-256:
`b77a211cf2480d55008dc96e993b66d380a92e4e466d44f58b25a9e9bc0a11cf`

Earlier candidates, fixtures and receipts remain preserved. These scripts do
not grant or run source/search/replay/complete-attempt experiments, control the
game, read player saves/profiles or modify current settings/native files.
