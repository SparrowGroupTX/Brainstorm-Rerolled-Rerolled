# Publishing this project to GitHub

The mod, runtime DLLs/indexes, code, reports, fixtures and model receipts keep their
existing layout. Historical capture databases and large analysis data are optional
release downloads, so normal Git updates do not carry their1.52GiB archive payload.
The catalog and tools stay in Git; every compressed piece is at most48MiB.

A normal mod installation does not need historical research captures. From a clone,
use Python3.10 or newer when a historical analysis needs them:

```powershell
# Download optional pieces, verifying sizes and SHA-256; completed pieces resume.
python -B tools/repo_artifacts.py fetch
# Restore exact original bytes/paths, refusing to overwrite different local files.
python -B tools/repo_artifacts.py restore
```

Both commands accept exact catalog paths for selective downloads/restoration.
Local originals remain intact. The optional data collection is at
[Historical research downloads](https://github.com/SparrowGroupTX/Brainstorm-Rerolled-Rerolled/releases/tag/research-archives-20260930).
It becomes available when its separate asset upload finishes. This is a data release;
it does not change the current mod release, installation, or simulator qualification.

Old automatic journal copies listed in
[OMITTED_OLD_JOURNALS.json](tools/github_publication20260930/followup/OMITTED_OLD_JOURNALS.json)
are local only. Frozen fixtures, current451 captures, research reports and decoded
archives remain. Fresh clones do not include the omitted old raw segments. The
already ignored `tools/advisor_eval/runs/` experiment output and generated Immolate
build output are also local only. Both shared feature CSVs keep their existing
Git LFS rules; command-line clones use `git lfs install` and `git lfs pull`.

## Updating code

```powershell
python -B tools/repo_artifacts.py check
```

Commit the code, catalog, download metadata, tools and documentation in Desktop.
Do not force-add ignored originals or archive object pieces. Ordinary updates can
use Desktop's normal push. A very large committed code backlog can use:

```powershell
python -B tools/push_in_batches.py plan --batch-mib 128
python -B tools/push_in_batches.py push --batch-mib 128
```

Each payload carries at most128MiB of new uncompressed blobs;64MiB is also available.
The uploader uses temporary payload branches and verifies the original destination
commit before cleanup. It never force pushes or publishes local backup refs. It
excludes completed objects by identity, checks advertised heads rather than stale
tracking refs, and skips automatic maintenance during fetch. Smaller batches improve
recovery; they do not increase network bandwidth.

## Updating optional research data

After archiving new immutable data, choose a new collection tag in
`tools/repository_artifacts/downloads.json` and commit its catalog/metadata/tools.
Publish that code commit first, then run:

```powershell
python -B -m tools.publish_research_assets plan
python -B -m tools.publish_research_assets push
```

The asset publisher uses Git credential manager without writing credentials to
files. It uploads through four connections with bounded request pacing, verifies
GitHub's SHA-256 receipts, retains completed assets for recovery and publishes the
data release only after every expected piece verifies. Existing assets are never
overwritten. A different catalog needs a fresh collection tag.

## Recovery and evidence

Only the unpublished Desktop update was rebuilt on top of existing published
history. Original commits/indexes and the full-archive snapshot remain recoverable
through refs recorded in [BACKUP.json](tools/github_publication20260930/followup/BACKUP.json)
and [OPTIONAL_LAYOUT.json](tools/github_publication20260930/followup/OPTIONAL_LAYOUT.json).
No checkout replacement, worktree cleaning, physical file deletion, or force push
was used. See [publication receipts](tools/github_publication20260930/followup/REPORT.md).
Simulator work remains paused at [checkpoint460](tools/advisor_eval/FRESH_CHAT_HANDOFF_460.md).
