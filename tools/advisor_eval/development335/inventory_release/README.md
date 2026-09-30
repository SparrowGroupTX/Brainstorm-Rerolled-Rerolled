Prepared only; do not execute until root has reviewed the slice and completed scoring336 installation. Product and existing tests were not changed during preparation.

1. Root runs `prepare_release.py` once. It requires the complete current policy to match `runs/scoring336_installed/record.json`, verifies both exact source baselines, adds the new fixture and its two baseline dependencies, preserves replaced bytes, stamps 2.137.0-alpha and freezes `runs/inventory337_candidate/policy`.
2. Root runs the normal candidate `validate_checkpoint.py` with 60 seconds per suite, then `prepare_context.py`.
3. Root installs the explicit strategy/consumables slice using the established installer/record/finalization flow with prefix `inventory337` and release 337. Candidate preparation itself does not install anything.

The prior final context is `development335/scoring_release/release_final/context.json`. All current experiment counts are zero and historical closed records carry forward unchanged. New differential-test baseline dependencies live under `tests/fixtures/inventory337/`; no production fixture refers to development paths.
