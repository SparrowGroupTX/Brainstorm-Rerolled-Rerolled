"""Bind the reviewed objective slice and its manufactured evidence."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[4]
component = Path(__file__).resolve().parent
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
before = json.loads((component / 'before_hashes.json').read_text(encoding='utf-8-sig'))
files = []
for relative, expected in sorted(before.items()):
    saved = component / 'before' / relative
    assert digest(saved) == expected
    files.append({'path': relative, 'kind': 'runtime' if relative.startswith('Brainstorm/') else 'test',
                  'before_sha256': expected, 'after_sha256': digest(root / relative)})
receipts = []
for receipt in sorted(component.glob('validation_*.json')):
    record = json.loads(receipt.read_text(encoding='utf-8'))
    receipts.append({'path': str(receipt.relative_to(root)), 'sha256': digest(receipt),
                     'exit_code': record.get('exit_code'), 'expected_failure': record.get('expected_failure'),
                     'seconds': record.get('seconds'), 'inputs_unchanged': record.get('inputs_unchanged')})
result = {
    'schema': 1, 'status': 'production_edits_review_ready', 'release': 343,
    'scope': 'Strictly more distinct missing Jokers may trade surplus sampled score above the existing final-boss margin.',
    'files': files, 'validation': receipts,
    'checks': {'advisor_gold_goal': 101, 'advisor_bell_opening': 146,
               'advisor_perkeo_inventory': 153, 'advisor_gold_planet_policy': 194, 'total': 594},
    'preserved_contracts': [
        'Every admitted endpoint and every declared paired world/forced branch completes within the unchanged shared budget.',
        'Every resulting sampled score is at least 1.25 times the supported final boss target; uncertain evidence still rejects the family.',
        'Whole inventory, borrowing, rental reserves, protected population, Eternal/Negative legality and source qualification remain unchanged.',
        'Explicit protected Perkeo references retain one fixed policy dominating its entire own hold/use family; fresh delivery defaults protect all references.',
        'Only one actual first action is published; fresh manufactured sell/buy/blind delivery preserves physical identity and inventory.'
    ],
    'limitations': [
        'No live run rescue, sticker award, calibrated win probability or general performance improvement is demonstrated.',
        'Final pre-boss Vessel/Leaf/Bell only; one buy and one original sale, <=3 offers and <=6 owned Jokers.',
        'Nonempty Perkeo goal comparisons still require <=8 homogeneous qualified Planets; Tarot/mixed inventory remains outside scope.',
        'No missing visible offer means this objective cannot add cargo; no reroll/search/earlier-shop expansion occurs here.'
    ],
    'experiment_jobs': {'source_components': 0, 'captured_policy_replays': 0, 'searches': 0, 'complete_attempts': 0},
    'live_game_control': False, 'save_profile_reads': False,
    'installation': 'Root owns version, candidate/exact-installed verification and installation.'
}
with (component / 'result.json').open('x', encoding='utf-8') as stream:
    json.dump(result, stream, indent=2)
    stream.write('\n')
print(json.dumps({'files': files, 'checks': result['checks'], 'result_sha256': digest(component / 'result.json')}))
