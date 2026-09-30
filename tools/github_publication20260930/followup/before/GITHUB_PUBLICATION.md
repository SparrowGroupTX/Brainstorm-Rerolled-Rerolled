# Publishing this workspace to GitHub

The oversized files shown by GitHub Desktop are historical offline research
captures and analysis data. They are now preserved in lossless compressed archives
under [tools/repository_artifacts](tools/repository_artifacts/README.md), split into
pieces no larger than48MiB. Original files remain usable at their existing local
paths. Exact ignore rules keep those raw copies out of your next commit.

The `Brainstorm/` mod, native runtime DLLs/indexes, code, reports, fixtures and frozen
evidence definitions retain their existing layout. A normal mod installation does
not need the archived capture databases. A clone used for historical analysis can
restore them with one command:

```powershell
python -B tools/repo_artifacts.py restore
```

This restores the original bytes and paths, preserving historical SHA-256 receipts.
It does not execute any analysis, game, source probe or training job. It refuses to
overwrite an existing file whose bytes differ. See the archive README for selective
restoration and validation commands.

Before committing in GitHub Desktop:

```powershell
python -B tools/repo_artifacts.py check
```

Include the archive catalog and object pieces, root `.gitignore`/`.gitattributes`,
the packaging tool and its tests along with your other project changes. Leave the
ignored raw captures and Python caches out. Existing CSV research inputs remain
in Git LFS; keep their two exact `.gitattributes` rules. Desktop supports LFS;
command-line contributors use `git lfs install` and `git lfs pull`.

No commits were amended, history rewritten, files deleted, or changes pushed as
part of this preparation. The local branch was even with its upstream before this
work, and reachable Git history contained no ordinary blobs over100MiB.

## Upload this large update in batches

The captured update is also too large for GitHub's separate2GB push limit.
After committing the remaining changes in GitHub Desktop, use the supplied uploader
instead of sending this entire backlog as one Desktop push:

```powershell
# Read-only plan. Does not create commits or publish anything.
python -B tools/push_in_batches.py plan

# Upload committed data in bounded batches, then publish the original branch.
python -B tools/push_in_batches.py push
```

Each payload push contains at most512MiB of new uncompressed Git blob data plus
small tree/commit metadata. The uploader uses a uniquely named temporary
`codex/upload-*` branch to preload objects, then fast-forward pushes your original
commit and removes its own temporary branch. Your existing commit history and
working branch remain intact; there is no force push or history rewrite.
It refuses a dirty working tree, an oversized ordinary blob, or a destination
branch that cannot fast-forward. Interrupted uploads retain their temporary refs;
retrying discovers already uploaded objects after fetching remote refs.

Exact-byte preservation rules were added for frozen evidence. Existing tracked
evidence/test files were staged again without line-ending conversion, with an
index backup under `.git`. Include those staged changes in your next commit so a
fresh clone keeps the original hashes. No original working-file bytes changed.

The publication receipt lives under
[tools/github_publication20260930](tools/github_publication20260930/REPORT.md).
Simulator work remains paused at [checkpoint460](tools/advisor_eval/FRESH_CHAT_HANDOFF_460.md).
