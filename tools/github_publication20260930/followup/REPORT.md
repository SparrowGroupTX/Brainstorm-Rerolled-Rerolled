# Smaller, recoverable GitHub publication

The user subsequently selected a lighter main repository with optional historical
downloads. [OPTIONAL_LAYOUT.json](OPTIONAL_LAYOUT.json) records the additional
backup and139 archive pieces removed only from the Git index. Those local pieces
remain intact. The catalog/download tools stay in Git; release assets carry the
data independently. The paused four completed payloads are retained for recovery.
The remainder of this receipt records the preceding compact-Git preparation stage.

The user requested smaller transfers, further compaction, and removal of obsolete
automatic-game logs where appropriate. The active GitHub Desktop push was stopped
by terminating only its identified Git push process tree. The destination branch
still pointed at the previously published `1fb4267701fc0545b5a3fd9148587505381e36ba`.

## Data decisions

- The original78 archives remain. Another57 historical JSON/JSONL/SQLite files,
  totaling1,446,017,194 bytes, are stored losslessly in59,690,980 unique compressed
  bytes. All original local files retain their bytes. The combined catalog now
  represents135 originals in139 pieces no larger than48MiB.
- 1,123 old automatic-journal copies (2,401,620,238 physical bytes) are omitted from
  the publication tree. They remain locally and in the original backup commits.
  These are copied logs from development350..450, excluding frozen directories,
  manual-session journals, codec fixtures, win-rate research and current451.
  Their decoded databases, analysis archives, reports and outcome/failure records
  remain available. Fresh clones do not contain the omitted raw segments; historical
  verifiers needing them must use the local originals or backup commits.
- The user's300-entry list includes140 already ignored experiment/build outputs,
  111 archived originals,34 bounded archive pieces,2 existing LFS CSVs,11 retained
  runtime/reproducibility assets and2 other retained research files. Physical
  directory size is not the Git upload size.
- Repeated DLL/index snapshots remain: Git already deduplicates identical bytes.
  Runtime assets, model receipts, current451 and simulator453..458 evidence are
  preserved. No original working file was physically deleted or regenerated.

See [COMPACTION.json](COMPACTION.json), [ADDITIONAL_JSON.json](ADDITIONAL_JSON.json),
[OMITTED_OLD_JOURNALS.json](OMITTED_OLD_JOURNALS.json), and
[USER_LARGE_FILE_TRIAGE.json](USER_LARGE_FILE_TRIAGE.json) for exact paths/hashes.

## History and upload

The two unpublished Desktop commits already contain old raw logs. A later deletion
alone would still transfer those objects. Only that unpublished update is rebuilt
as a compact snapshot on top of the existing published history. Its original tip
and index are preserved in [BACKUP.json](BACKUP.json); the backup ref stays local
and is never included in uploader refspecs. No checkout replacement, worktree
cleaning, published-history rewrite or force push is used.

[push_in_batches.py](../../push_in_batches.py) now defaults to128MiB of new
uncompressed Git blobs per payload, with configurable `--batch-mib` (for example64).
Every successful payload is retained remotely. A later invocation fetches remote
refs and sends only missing objects. Per-push Git compression is9; persistent
configuration is unchanged. Temporary payload refs are removed after the original
publication branch is verified. The primary branch advances only after all data
has arrived; failures retain recovery refs and stop without automatic retries.

The publication command is `python -B tools/push_in_batches.py push`.
The [main guide](../../../GITHUB_PUBLICATION.md) documents restoration and upload.

## Checks and limits

The packaging/uploader suite passed13 manufactured tests, including real pushes
to a local bare remote, transfer failure, history preservation, corruption/path
controls and the configurable cap. Original-source execution was not used.
The prepared458 integrity check passed without executing Lua. One read-only
reviewer assessed old-journal selection and the history/asset preservation risks.
Current simulator work remains paused; installed451, configuration and game data
are untouched. No game, source worker or training job was started.

Actual snapshot/upload outcomes are recorded after validation. Successful Git
publication does not establish simulator lifecycle fidelity or training readiness.

While the real transfer ran, an additional local mid-transfer test completed two
payloads and injected a failure on the third. It exposed duplicate retry accounting
when remote payloads use different paths. The uploader now excludes already held
object IDs explicitly and checks advertised heads to reject stale tracking refs.
The new test also proves that only three of five payloads remain and a restart
publishes the exact original commit. All five uploader tests passed after this
repair; the nine packaging tests had already passed. The first failure is preserved
in [PARTIAL_RESUME_BEFORE_FIX.log](PARTIAL_RESUME_BEFORE_FIX.log), with exact helper
hashes and controls in [RESUME_VERIFICATION.json](RESUME_VERIFICATION.json).
The repair is a small follow-up commit to the frozen publication snapshot.

## Published lightweight project

The intended commit `bd8e8e83cdf357b2291a1fe5a9bfc7bc80b903ef` was published
and independently verified through GitHub's advertised branch hash. Its tree is
`6c33ef36c60ba6adf4a2ebf62c08a0daef9e3310`, containing no optional archive pieces.
All11 bounded blob payloads completed. [PUBLICATION_RESULT.json](PUBLICATION_RESULT.json)
records the final480,640-byte pack and its hash; the destination update used no force.
Both previous temporary remote upload branches were removed only after matching
their expected hashes. Local payload history remains in backup refs recorded in
[TEMPORARY_REF_CLEANUP.json](TEMPORARY_REF_CLEANUP.json).

A real local Git pack check exposed final-step retransmission of already held
blobs when their containing trees differ. An exact-tree bridge alone also failed
that check; its failure is preserved in [TREE_BRIDGE_FAILURE.log](TREE_BRIDGE_FAILURE.log).
Two GitHub tree API attempts returned502, including a smaller metadata request;
those failures and the undeployed experiment are retained here. No project branch
was changed by those attempts. That route was stopped.

The delivered repair builds a local reachability bitmap with `git repack -a -b`
and enables bitmap use for the final push. It retains every previous pack and
reference, does not garbage collect or prune, and leaves working files untouched.
The added test uses real Git with an incompressible256KiB blob: ordinary traversal
resends it, while bitmap traversal produces a pack below1KiB. All six uploader
tests passed after this repair. The unchanged eleven packaging/fetch tests and
two optional-asset publisher tests had already passed for their exact dependencies.

The actual project finalization then sent only about470KiB. The optional139-piece
data release is a separate next step; it is not yet claimed published by this receipt.
