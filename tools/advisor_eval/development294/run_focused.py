"""Run explicit ordinary fixtures with fresh, immutable runtime/test receipts."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import time

root=Path(__file__).resolve().parents[3]
folder=Path(__file__).resolve().parent
label=sys.argv[1]
if not label.isalnum(): raise ValueError('Use a simple fresh receipt label')
fixtures=sys.argv[2:]
if not fixtures: raise ValueError('Explicit synthetic fixtures are required')
out=folder/label;out.mkdir(exist_ok=False)
files=[]
for area in ('Advisor','Core','UI'):
    files.extend((root/'Brainstorm'/area).glob('*.lua'))
files.append(root/'Brainstorm/steamodded_compat.lua')
files.extend((root/'tests/support').glob('*.lua'))
files.extend(root/name for name in fixtures)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
hashes={str(p.relative_to(root)):sha(p) for p in sorted(set(files))}
command=[sys.executable,'-B','tests/run_lua_tests.py',*fixtures]
started=time.perf_counter()
try:
    result=subprocess.run(command,cwd=root,capture_output=True,text=True,timeout=60)
    code,stdout,stderr=result.returncode,result.stdout,result.stderr
except subprocess.TimeoutExpired as exc:
    code,stdout,stderr=None,exc.stdout or b'',exc.stderr or b''
stdout=stdout.decode(errors='replace') if isinstance(stdout,bytes) else stdout
stderr=stderr.decode(errors='replace') if isinstance(stderr,bytes) else stderr
elapsed=time.perf_counter()-started
unchanged=all(sha(root/name)==digest for name,digest in hashes.items())
status='passed' if code==0 and unchanged else 'timeout' if code is None else 'failed'
(out/'stdout.txt').write_text(stdout,encoding='utf-8')
(out/'stderr.txt').write_text(stderr,encoding='utf-8')
report={'status':status,'returncode':code,'seconds':elapsed,'timeout_seconds':60,'command':command,
        'sha256':hashes,'files_unchanged':unchanged,
        'scope':'Explicit ordinary synthetic fixtures only; no source component, captured replay, search, terminal attempt, game or save/profile operation.'}
(out/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'status':status,'seconds':elapsed,'files_unchanged':unchanged,'report':str(out/'report.json')}))
print(stdout);print(stderr)
raise SystemExit(0 if status=='passed' else code or 124)
