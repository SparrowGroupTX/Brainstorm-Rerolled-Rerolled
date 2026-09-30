"""Preserve the installed 444 baseline before the Acorn continuity repair."""
from pathlib import Path
from datetime import datetime, timezone
import json, shutil, subprocess, sys
H = Path(__file__).resolve().parent
E = H.parent
R = E.parents[1]
sys.path.insert(0, str(E))
from benchmark import policy_hashes, file_digest
from validate_checkpoint import test_manifest, provenance

def read(p): return json.loads(p.read_text(encoding='utf-8'))
B = read(E / 'INSTALLED_CHECKPOINT_444.json')
F = read(E / 'runs/repair444_candidate1/freeze.json')
P = read(E / 'development444/prework.json')
assert policy_hashes(R) == B['policy_files'] == policy_hashes(Path(B['installed']).parent)
assert test_manifest() == F['test_files'] and provenance() == F['validation_provenance']
prior = dict(P['prior_files'])
for folder in ('development444', 'runs/repair444_candidate1', 'runs/repair444_installed'):
    for p in (E / folder).rglob('*'):
        if p.is_file(): prior[p.relative_to(R).as_posix()] = file_digest(p)
for rel, sha in prior.items(): assert file_digest(R / rel) == sha, rel
nav = P['navigation']
before = {}
files = set(B['policy_files']) | set(test_manifest()) | set(nav)
files |= {'tools/advisor_eval/DECISION_REVIEW.md', 'tests/run_lua_tests.py', 'tools/advisor_eval/validate_checkpoint.py'}
for rel in sorted(files):
    dest = H / 'before' / rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(R / rel, dest)
    before[rel] = file_digest(dest)
record = {'created_utc': datetime.now(timezone.utc).isoformat(), 'installed': B,
          'runtime_files': B['policy_files'], 'test_files': F['test_files'],
          'provenance': provenance(), 'prior_files': prior, 'before_files': before,
          'navigation': nav, 'native_files': B['native_files_preserved'],
          'config_sha256': file_digest(Path(B['installed']) / 'config.lua')}
with (H / 'prework.json').open('x') as f: json.dump(record, f, indent=2); f.write('\n')
(H / 'git_status_before.txt').write_text(subprocess.run(['git','status','--short','--untracked-files=all'],cwd=R,capture_output=True,text=True,check=True).stdout)
print(json.dumps({'prior_files':len(prior),'before_files':len(before),'installed':B['version']}))
