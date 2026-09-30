"""Preserve the exact pre-repair workspace and historical release inputs."""
from pathlib import Path
import json, shutil, sys
H=Path(__file__).resolve().parent;E=H.parent;R=E.parents[1];sys.path.insert(0,str(E))
from benchmark import file_digest, policy_hashes
from validate_checkpoint import test_manifest, provenance
P=json.loads((H/'prework.json').read_text());F=P['candidate_freeze']
assert policy_hashes(R)==F['candidate_policy_files']
assert test_manifest()==F['test_files']
assert provenance()==F['validation_provenance']
files={**policy_hashes(R),**test_manifest()}
for rel,h in files.items():
    dest=H/'before_runtime'/rel;dest.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(R/rel,dest);assert file_digest(dest)==h
prior={p.relative_to(R).as_posix():file_digest(p) for d in ('development445','runs/repair445_candidate1')
       for p in (E/d).rglob('*') if p.is_file() and '__pycache__' not in p.parts}
with (H/'repair_prework.json').open('x') as f:
    json.dump({'before_files':files,'prior_files':prior,'provenance':provenance()},f,indent=2);f.write('\n')
print(len(files),len(prior))
