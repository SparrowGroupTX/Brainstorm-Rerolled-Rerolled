# Optional historical research data

The catalog maps135 historical database/analysis originals to lossless compressed
pieces no larger than48MiB. The payloads are optional GitHub release assets, excluded
from Git; source, reports, fixtures and the download/restore tools remain in Git.
A normal mod installation does not need this research data.

```powershell
python -B tools/repo_artifacts.py list
# Download all, or append an exact catalog path for only the required data.
python -B tools/repo_artifacts.py fetch
python -B tools/repo_artifacts.py restore
python -B tools/repo_artifacts.py verify --originals
```

Downloads verify each piece and retain completed pieces across an interruption.
Restoration checks the complete original byte count and SHA-256 before making the
file visible. Matching local originals are verified/skipped; different files are
never overwritten. No database regeneration, VACUUM, row deletion or lossy conversion
is involved. Local originals and already prepared archive pieces remain intact.

The download metadata links to
[the optional collection](https://github.com/SparrowGroupTX/Brainstorm-Rerolled-Rerolled/releases/tag/research-archives-20260930).
The release becomes available after its independent upload verifies. See the
[publication guide](../../GITHUB_PUBLICATION.md) for updating code and research assets.

Old copied automatic journals listed in
[OMITTED_OLD_JOURNALS.json](../github_publication20260930/followup/OMITTED_OLD_JOURNALS.json)
are retained locally and in backup commits, but are not part of this catalog or a
fresh clone. Frozen fixtures, current451, reports, decoded data and model receipts
remain. The two shared feature CSVs retain Git LFS.

The standard-library packaging helper supports adding new untracked evidence via
`pack`; it does not rewrite history or modify the index. Commit updated catalog and
metadata, then publish a fresh data collection tag. Never force-add object pieces.
Restoring data does not execute analysis, original source, gameplay or training.
Simulator work remains paused at checkpoint460.
