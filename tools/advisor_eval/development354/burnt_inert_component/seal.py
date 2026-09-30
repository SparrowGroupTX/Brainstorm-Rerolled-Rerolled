"""Seal the already-completed staged manufactured component without running work."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


labels = ('baseline01', 'baseline02', 'candidate01', 'pair01', 'margin01')
results = []
for label in labels:
    path = HERE / label / 'report.json'
    report = json.loads(path.read_text(encoding='utf-8'))
    assert report['inputs_unchanged']
    assert report['seconds'] < report['cap_seconds'] == 60
    assert report['status'] == ('failed' if label.startswith('baseline') else 'passed')
    results.append({
        'label': label,
        'report': path.relative_to(ROOT).as_posix(),
        'report_sha256': sha(path),
        'status': report['status'],
        'seconds': report['seconds'],
        'inputs_unchanged': report['inputs_unchanged'],
        'fixture_sha256': sha(HERE / label / 'input_fixture.lua'),
        'output_sha256': sha(HERE / label / 'output.log'),
    })

files = [
    'Brainstorm/Advisor/growth.lua', 'tests/advisor_yorick_pair.lua',
    'tests/advisor_burnt_pair_inert.lua', 'before/growth.lua',
    'before/advisor_yorick_pair.lua', 'prepare_receipt.json', 'validate.py',
    'run_baseline.lua', 'run_candidate.lua', 'run_pair.lua', 'run_margin.lua',
    'README.md', 'seal.py',
]
receipt = {
    'status': 'staged_manufactured_component_complete_not_promoted',
    'scope': 'Post-first-discard inert Burnt support only; no new experiment workers.',
    'baseline': 'Frozen 353 margin candidate; shared runtime was not mutated by this task.',
    'files': {name: sha(HERE / name) for name in files},
    'results': results,
    'source_grounding': {
        'path': 'tools/advisor_eval/runs/planet_pool_source1/source/card.lua',
        'sha256': sha(ROOT / 'tools/advisor_eval/runs/planet_pool_source1/source/card.lua'),
        'mode': 'Previously preserved source read only; no original-source execution.',
    },
    'limits': 'No complete outcome or win/sticker improvement demonstrated.',
}
with (HERE / 'component_receipt.json').open('x', encoding='utf-8') as handle:
    json.dump(receipt, handle, indent=2)
    handle.write('\n')
print(json.dumps({'receipt_sha256': sha(HERE / 'component_receipt.json'), 'files': receipt['files'], 'results': results}, indent=2))
