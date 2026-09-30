"""Version and freeze an agreed runtime slice; no installation or experiments."""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools/advisor_eval'))
from paired_policy_audit import freeze_product

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--previous', required=True)
parser.add_argument('--version', required=True)
parser.add_argument('--prefix', required=True)
args = parser.parse_args()
if not args.prefix.isalnum():
    raise ValueError('Require a simple contained fresh prefix')
destination = ROOT / 'tools/advisor_eval/runs' / (args.prefix + '_candidate')
if destination.exists():
    raise ValueError('Preserve the existing candidate; require a fresh destination')
files = [ROOT / 'Brainstorm/Core/Brainstorm.lua', ROOT / 'Brainstorm/steamodded_compat.lua']
before = [path.read_bytes() for path in files]
old, new = args.previous.encode('ascii'), args.version.encode('ascii')
if any(data.count(old) != 1 for data in before):
    raise ValueError('Both current version files must match exactly once')
for path, data in zip(files, before):
    path.write_bytes(data.replace(old, new))
destination.mkdir()
frozen = freeze_product(ROOT, destination / 'policy')
with (destination / 'freeze.json').open('x', encoding='utf-8') as stream:
    json.dump(frozen, stream, indent=2)
print(json.dumps({'version': args.version, 'candidate': str(destination), 'policy_digest': frozen['policy_digest']}))
