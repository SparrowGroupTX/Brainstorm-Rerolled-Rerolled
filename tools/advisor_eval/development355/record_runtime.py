"""Read-only dependency fingerprint; no GPU operations or simulator execution."""
import hashlib
import importlib.metadata
import json
from pathlib import Path
import sys

root = Path(sys.executable).parent
site = root / 'Lib/site-packages'
paths = {Path(sys.executable), root/'python312.dll'}
for package in ('torch','numpy'):
    paths.update((site/package).rglob('*.pyd'))
    paths.update((site/package).rglob('*.dll'))
    paths.update((site/(package+'.libs')).glob('*.dll'))
    for info in site.glob(package+'-*.dist-info'):
        paths.update(info/name for name in ('METADATA','RECORD') if (info/name).exists())
files = {}
for path in sorted(paths):
    if not path.is_file(): continue
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(4*1024*1024), b''): digest.update(block)
    files[str(path)] = {'sha256':digest.hexdigest(),'bytes':path.stat().st_size}
result = {'python':sys.version,'executable':sys.executable,
          'packages':{k:importlib.metadata.version(k) for k in ('torch','numpy')},
          'files':files,'training':False,'gpu_operations':False,'simulator_episodes':0}
destination = Path(__file__).with_name('runtime_provenance.json')
with destination.open('x',encoding='utf-8') as stream:
    json.dump(result,stream,indent=2);stream.write('\n')
print(json.dumps({'fingerprinted_files':len(files),'bytes':sum(x['bytes'] for x in files.values())}))
