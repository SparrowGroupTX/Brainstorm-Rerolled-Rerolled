"""Seal staged acquisition implementation and manufactured evidence."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[4]
component = Path(__file__).resolve().parent
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
files = []
for relative in ('Brainstorm/Advisor/gold_acquisition.lua', 'tests/advisor_gold_acquisition.lua'):
    path = component / relative
    files.append({'destination': relative, 'staged_path': str(path.relative_to(root)),
                  'sha256': digest(path), 'new_file': True})
receipts = []
for path in sorted(component.glob('validation_*.json')):
    data = json.loads(path.read_text(encoding='utf-8'))
    receipts.append({'path': str(path.relative_to(root)), 'sha256': digest(path), 'exit_code': data['exit_code'],
                     'seconds': data['seconds'], 'inputs_unchanged': data['inputs_unchanged']})
result = {'schema': 1, 'release': 344, 'status': 'staged_review_ready', 'production_paths_written_by_component': False,
          'files': files, 'validation': receipts, 'latest_checks': 149, 'latest_score_floor_calls': 1690,
          'fixed_policy': 'Current physical Joker order, hold every original consumable; no generated copy is used or valued.',
          'declared_family': 'Hold, each admitted direct visible distinct-missing Joker buy, and each legal completed-original sale then buy; <=22 endpoints, <=3 offers and <=6 owned Jokers.',
          'boundary': 'Winning-Ante pre-Small/Big shops only. Complete four common public-composition worlds with >=1.25 actual next-blind target. This is not later-blind or terminal survival evidence.',
          'dependency': {'helper': 'gold_tarot_hold.certify', 'scope': 'fixed_hold_tarot_copy_score_equivalence_v1',
                         'held_inventory': 'Nonempty Perkeo uses the qualified mixed Magician/Hermit Tarot helper; all original inventory is retained unchanged.'},
          'accounting': 'One lower_bound call per scored subset; exact actual-call charge survives incomplete evidence, context mismatch or thrown comparison. Requested remaining shop allowance is capped at50000 with no separate extra allowance.',
          'failed_evidence': 'validation01/02 preserve fixture harness failures caused by using data-only Snapshot.copy for module tables; shallow module copying repaired the harness. Neither failure ran game/source workers.',
          'manufactured_main_case': 'Five completed Jokers, $170, fourteen mixed Negative Magician/Hermit Tarots, a visible missing Crazy Joker, and winning-Ante Big next. Old final-boss goal declines; complete new family selects a paid sale then fresh purchase while preserving every held Tarot.',
          'experiment_jobs': {'source_components': 0, 'captured_policy_replays': 0, 'searches': 0, 'complete_attempts': 0},
          'live_game_control': False, 'save_profile_reads': False,
          'promotion_note': 'Root owns runtime/decision/snapshot integration, production fixture path binding, versioning and candidate/exact-installed validation.'}
with (component / 'result.json').open('x', encoding='utf-8') as stream:
    json.dump(result, stream, indent=2)
    stream.write('\n')
print(json.dumps({'files': files, 'result_sha256': digest(component / 'result.json')}))
