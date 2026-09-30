# Maintenance405: public-journal analysis integrity and current documentation

The user requested more code/docs/bug work while starting a new game. This new
slice is separate from completed404. Keep runtime/install/config/DLLs intact;
do not inspect the active run, control the game or execute captured policy,
scorer, native/source components, training or a new experiment.

Confirmed source defect: individually valid BRJ2 files from the same declared
session can have adjacent logical sequences but a broken predecessor chain.
The timing analyzer (and inspection index that uses it) currently merges them
into one scope without checking cross-file predecessor/segment identity.
The low-level reader intentionally supports independently decoded fragments;
that behavior must remain. Validate only links between supplied consecutive
frames. A standalone later fragment remains valid with an unverified predecessor.
Require strictly increasing segment IDs across supplied files, not consecutive
IDs: empty rotations may consume segment numbers. Distinct sessions remain
independent; no complete-session or terminal correctness claim is added.

Acceptance: real manufactured BRJ2 framing/checksums; correct links, wrong
links, reused/regressed IDs, allowed empty-rotation gaps, later standalone
fragments, interleaved sessions, independent JSONL, malformed/truncated prefix,
no input/output overwrite and unchanged existing timing/inspection behavior.
Reject the first bad link before adding its counters, windows or examples.
Preserve initial failing tests and exact pre-edit helper/doc bytes.

Fix the eval README's obsolete current2.65/deferred16-worker assertions and
document supplied-fragment versus whole-session integrity clearly. Historical
checkpoint265 and closed experiment results stay available as history.

One primary implementer, existing read-only reviewer: one substantive review
and at most one focused recheck. Targeted/full Python regression appropriate
to tooling changes; no unchanged Lua/runtime gate or runtime version/install.
Record tooling/tests/provenance hashes separately from immutable installed404.

The snapshot-cap partial-commit source concern is unreachable with current
public caps (100000 snapshots and100000 events). It is not a demonstrated
current truncation defect and is not included in this repair.
