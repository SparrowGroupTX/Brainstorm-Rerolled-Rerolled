"""Pin and archive a public MIT simulator for inspection, without executing it."""
from pathlib import Path
import hashlib, io, json, urllib.request, zipfile

HERE = Path(__file__).resolve().parent
OUT = HERE / 'external'
OUT.mkdir(exist_ok=False)
def fetch(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'Balatro-advisor-research'})
    with urllib.request.urlopen(request, timeout=30) as response:
        data = response.read(30_000_001)
    if len(data) > 30_000_000:
        raise ValueError('Download exceeds fixed archive allowance')
    return data

metadata = fetch('https://api.github.com/repos/TylerFlar/jackdaw-balatro/commits/main')
commit = json.loads(metadata)['sha']
assert len(commit) == 40 and all(c in '0123456789abcdef' for c in commit)
archive_url = f'https://codeload.github.com/TylerFlar/jackdaw-balatro/zip/{commit}'
archive = fetch(archive_url)
(OUT / 'upstream_commit.json').write_bytes(metadata)
(OUT / 'upstream.zip').write_bytes(archive)
root = (OUT / 'jackdaw').resolve()
root.mkdir(exist_ok=False)
files = {}
with zipfile.ZipFile(io.BytesIO(archive)) as bundle:
    total = 0
    for item in bundle.infolist():
        if item.is_dir():
            continue
        total += item.file_size
        if total > 100_000_000 or item.file_size > 10_000_000:
            raise ValueError('Expanded archive exceeds fixed allowance')
        parts = item.filename.replace('\\', '/').split('/')[1:]
        if not parts or any(p in ('', '.', '..') or ':' in p for p in parts):
            raise ValueError('Unsafe archive path')
        target = root.joinpath(*parts).resolve()
        if not target.is_relative_to(root) or (item.external_attr >> 16) & 0o170000 == 0o120000:
            raise ValueError('Archive path or link escapes isolated directory')
        data = bundle.read(item)
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open('xb') as handle:
            handle.write(data)
        files['/'.join(parts)] = hashlib.sha256(data).hexdigest()
record = {'repository': 'https://github.com/TylerFlar/jackdaw-balatro',
          'commit': commit, 'archive_url': archive_url,
          'archive_sha256': hashlib.sha256(archive).hexdigest(),
          'files': files, 'executed': False, 'installed': False,
          'scope': 'Pinned source download for read-only inspection; no game connection'}
(OUT / 'provenance.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'commit': commit, 'files': len(files), 'archive_bytes': len(archive), 'path': str(root)}))
