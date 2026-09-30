"""Preserve the invalidated comment-only freeze, then freeze held290 bytes."""
from pathlib import Path
import hashlib
import json
import sys
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools/advisor_eval'))
from paired_policy_audit import freeze_product
old = ROOT / 'tools/advisor_eval/runs/fool290_candidate'
old_bytes = (old / 'policy/Brainstorm/Advisor/pack_scoring.lua').read_bytes()
current_bytes = (ROOT / 'Brainstorm/Advisor/pack_scoring.lua').read_bytes()
assert old_bytes.splitlines()[2:] == current_bytes.splitlines()[2:]
value = {'reason': 'A final accurate module header was edited after candidate freeze. Both full suites passed, but policy_unchanged=false correctly invalidated this freeze; not installed.',
         'before_sha256': hashlib.sha256(old_bytes).hexdigest(),
         'after_sha256': hashlib.sha256(current_bytes).hexdigest(),
         'before_header': old_bytes.splitlines()[:2].__str__(), 'after_header': current_bytes.splitlines()[:2].__str__(),
         'replacement': 'fool290_candidate2', 'experiment': False}
with (old / 'freeze_change_explanation.json').open('x', encoding='utf-8') as stream:
    json.dump(value, stream, indent=2)
destination = ROOT / 'tools/advisor_eval/runs/fool290_candidate2'
destination.mkdir()
frozen = freeze_product(ROOT, destination / 'policy')
with (destination / 'freeze.json').open('x', encoding='utf-8') as stream:
    json.dump(frozen, stream, indent=2)
print(frozen['policy_digest'])
