# Read-only review405

The same existing reviewer performed one substantive source review and one
focused recheck for this new user-authorized maintenance slice. It did not
edit files, run tests, read active journals or execute gameplay/policy/scorers.

Substantive finding: `read_player_log.records` deliberately allows each file's
first predecessor to lie outside its fragment, but the aggregate timing/index
consumers joined supplied files by session/sequence without verifying the
available predecessor hash or segment order. It recommended positive and
negative cross-file witnesses while retaining standalone fragment admission.

Focused recheck: no code blocker. Hash/segment validation precedes accepted
aggregates; interleaved sessions, skipped empty rotations and unknown outside
predecessors are handled. Existing bounded/exclusive output and exact extraction
safeguards remain. Primary validation logs were reviewed, not rerun.

The recheck found a remaining README sentence calling bounded headless episodes
"Current work." Primary replaced it with the current manufactured/passive-only
scope, and corrected the same guide's obsolete per-feature installation and
subjective-estimate instructions against the mandatory root release boundaries.
No further independent review allowance is claimed or used.

The review also distinguished a hypothetical snapshot-cap partial commit from
a current reachable defect: both public event and unique-snapshot hard caps are
100000, so event admission rejects first. It was not changed or presented as an
observed production bug. No strategy or win-rate finding follows from this audit.
