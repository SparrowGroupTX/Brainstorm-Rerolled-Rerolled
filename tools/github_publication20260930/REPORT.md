# GitHub publication preparation — 2026-09-30

This is the first preparation receipt. The later request for smaller transfers and
further compaction is recorded in [followup/REPORT.md](followup/REPORT.md); it changes
the batch default and recoverably rebuilds the unpublished update. The statements
below describe the original preparation stage.

The large update is represented losslessly without changing the mod layout or
deleting research evidence. **78 raw capture/analysis files, totaling15.963771GiB,
are stored as1.468461GiB of compressed data in83 pieces capped at48MiB.** Their
original paths remain usable locally; exact `.gitignore` entries keep those raw
copies out of ordinary Git. The two existing large feature CSVs retain Git LFS.

The isolated conservative pack measured3,819,922,660 bytes, also above GitHub's
separate2GB push cap. [push_in_batches.py](../push_in_batches.py) therefore preloads
missing objects in pushes of at most512MiB of uncompressed new blobs plus small
metadata, then publishes the original branch without rewriting history. It was
tested with four payload pushes and a final branch push against a temporary local
bare remote, followed by temporary-ref cleanup. No real GitHub push was performed.

The [catalog](../repository_artifacts/catalog.json) records every original path,
size/SHA-256 and compressed piece hash. [repo_artifacts.py](../repo_artifacts.py)
supports list/pack/verify/restore/check with only Python's standard library.
The [publication guide](../../GITHUB_PUBLICATION.md) explains GitHub Desktop use
and the one-command restore for fresh clones.

## Validation

- All78 compressed archives were decoded and checked against their original
  size/hash; all78 untouched local originals matched those hashes too.
- The largest actual file, a633,839,616-byte SQLite database, was restored from
  two pieces into a separate directory. Its SHA-256 matched and SQLite
  `PRAGMA quick_check` returned `ok`. See [RESTORE_VALIDATION.json](RESTORE_VALIDATION.json).
- Nine manufactured tests passed, including incompressible multi-piece restoration,
  truncation/corruption, decoded-size limits, existing-file refusal, path traversal,
  case collisions and a real Windows directory-junction refusal control.
- The uploader's batch partition and actual local multi-push tests passed; the
  remote received the exact original commit and files, with unchanged local history.
- Working candidate checks and actual staged-blob checks found zero ordinary Git
  files above100MiB. Existing LFS-filtered CSVs remain small pointers in Git.
- Reachable Git history had no ordinary blobs above100MiB, and the branch was even
  with its upstream before this work. No history rewrite was needed.
- One read-only packaging reviewer assessed the implementation and rechecked the
  specific path-validation fixes; no remaining blocking issue was found.

Binary archive pieces disable text normalization/diffs/merges. Evaluation,
learning and test files disable line-ending conversion because frozen receipts
pin their original bytes. Source, runtime assets and old receipts retain their
paths. No historical database was regenerated or vacuumed.

An isolated temporary Git index/object directory was used to examine a proposed
commit without committing through this tool. GitHub Desktop concurrently
updated the real staging area; the first measurement stopped at its conservative
index-unchanged assertion after packing. The current real index passed the size
check. The final [Git preflight receipt](GIT_PREFLIGHT.json) records the repeated
isolated measurement and its actual bundle size; [VALIDATION.json](VALIDATION.json)
records final hashes and preservation checks.

After the user committed the update and attribute rules during preparation,
existing tracked evidence/test files were staged without text normalization to
preserve original byte hashes. The index was backed up first; no working file or
commit was changed. [BYTE_PRESERVATION.json](BYTE_PRESERVATION.json) lists those
staged paths. Commit these and the remaining helper/receipt files before invoking
the real uploader. Both user-created commits remain intact.

Pre-edit config/documentation bytes and inventory are preserved in
[BEFORE.json](BEFORE.json) and [before/](before/). Original raw data, installed451,
player settings/saves/profiles, DLLs, paused simulator458 and its frozen source
manifest were not changed. No source probe, game, training job, commit or push
was performed for this publication task. Temporary restoration/preflight data
remains isolated under `.git` and is not part of the publishable tree.
