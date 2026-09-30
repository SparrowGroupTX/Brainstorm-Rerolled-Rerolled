"""Validate detached bytes; stage only with the parent's explicit --stage call."""
from pathlib import Path
import argparse
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--stage', action='store_true')
args = parser.parse_args()
manifest = json.loads((HERE / 'integration_manifest.json').read_text(encoding='utf-8'))
for name, digest in manifest['files'].items():
    path = (HERE / name).resolve()
    assert path.is_relative_to(HERE) and sha(path) == digest, f'Detached input changed: {name}'
base = json.loads((HERE / 'base_manifest.json').read_text(encoding='utf-8'))
for name, digest in base['files'].items():
    assert sha(ROOT / name) == digest, f'Production dependency changed: {name}'
assert not (ROOT / manifest['production_test_must_be_absent_before_stage']).exists(), 'New production test already exists'
for name, target in manifest['production_mapping'].items():
    path = (ROOT / target).resolve()
    assert path.is_relative_to(ROOT), 'Production path escaped repository'
    assert name in {'auto_run_product.lua', 'advisor_auto_observation.lua'}, 'Unexpected stage input'
    assert target in {'Brainstorm/Core/auto_run_product.lua', 'tests/advisor_auto_observation.lua'}, 'Unexpected stage target'
assert len(manifest['production_mapping']) == 2
if args.stage:
    for name, target in manifest['production_mapping'].items():
        (ROOT / target).write_bytes((HERE / name).read_bytes())
    assert all(sha(ROOT / target) == sha(HERE / name) for name, target in manifest['production_mapping'].items())
print(json.dumps({'staged': args.stage, 'integration_manifest_sha256': sha(HERE / 'integration_manifest.json'),
                  'production_mapping': manifest['production_mapping']}))
