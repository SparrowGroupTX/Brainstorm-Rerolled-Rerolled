"""Audit preserved search/inspection receipts only; no native/source execution."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT/'tools/advisor_eval/runs/gold299_20260914'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def validate_job(name):
    folder = BASE/name;record = read(folder/'record.json');registration = read(folder/'registration.json')
    assert record['job'] == name and record['status'] == 'complete' and record['exit_code'] == 0
    assert record['one_use_spent'] and record['frozen_files_unchanged'] and record['external_files_unchanged']
    assert record['registration_sha256'] == sha(folder/'registration.json')
    assert record['trace_sha256'] == sha(folder/'trace.log')
    assert all(sha(folder/relative) == expected for relative, expected in registration['files'].items())
    return folder, record, registration

def create(path, value):
    with path.open('x', encoding='utf-8') as stream:
        json.dump(value, stream, indent=2, allow_nan=False);stream.write('\n')

def main():
    folder, record, registered = validate_job('S05')
    raw = read(folder/'raw_result.json');result = read(folder/'result.json');request = read(folder/'request.json')
    assert all(result[key] == value for key, value in raw.items())
    assert result['status'] == 'found' and result['seed'] == 'S7PXV521'
    assert result['screened'] == 156557312 and result['exact_candidates'] == 912 and result['threads'] == 32
    assert request['start_index'] == 2000000001 and request['max_indices'] == 10**12
    assert request['copy_alternatives'] is True and request['minimum_distinct'] == 0
    assert result['budget_ms'] == request['budget_ms'] == 27000 and result['search_calls'] == 1
    assert result['qualification'] is False and result['acquisition_retention_survival_verified'] is False
    selection_folder = ROOT/'tools/advisor_eval/development300/search05/selection'
    selection = read(selection_folder/'normal_seed_selection.json');recipe = read(selection_folder/'normal_opening_recipe.json')
    assert selection['seed'] == recipe['seed'] == result['seed'] and selection['unseen_holdout'] is False
    for name, digest in selection['search_evidence'].items():
        assert sha(folder/name) == digest and recipe['discovery']['evidence_sha256'][name] == digest
    assert recipe['filter_info']['filter_params'][22] is True
    assert [t['key'] for t in recipe['filter_info']['normal_opening']['targets']] == ['j_yorick','j_perkeo']
    assert recipe['filter_info']['collection_search']['observed_copy_key'] is None
    create(folder/'audit.json', {'schema': 1, 'status': 'found', 'job': 'S05', 'seed': result['seed'],
        'screened': result['screened'], 'exact_candidates': result['exact_candidates'], 'threads': result['threads'],
        'native_seconds': result['seconds'], 'native_call_wall_seconds': result['native_call_elapsed_seconds'],
        'worker_seconds': result['worker_elapsed_seconds'], 'outer_seconds': record['elapsed_seconds'],
        'native_budget_ms': 27000, 'outer_cap_seconds': 30, 'one_native_call': True,
        'frozen_inputs_trace_and_selection_verified': True,
        'policy_digest': registered['metadata']['policy_digest'],
        'selection_sha256': {p.name: sha(p) for p in selection_folder.iterdir() if p.is_file()},
        'scope': 'Prespecified selected-development native OR query; reported gate screening counts, not inferred index-ceiling traversal.',
        'copy_branch_observed': False, 'affordability_acquisition_retention_survival_verified': False,
        'unseen_holdout': False, 'complete_attempt': False, 'qualification': False,
        'source_attempt_authority': 'Any later attempt requires its own frozen registration; S05 grants no attempt lease.'})
    folder, record, registered = validate_job('M11')
    inspection = read(folder/'inspection/inspection.json');methods = inspection['methods']
    found = [m for m in methods if m['status'] == 'found'];missing = [m['name'] for m in methods if m['status'] != 'found']
    assert len(found) == 7 and missing == ['win_game']
    for method in found:
        assert method['truncated'] is False
        assert sha(folder/'inspection'/method['excerpt_file']) == method['excerpt_sha256'] == method['full_method_sha256']
    for site in inspection['game_update_callsites']:
        assert sha(folder/'inspection'/site['excerpt_file']) == site['sha256']
    create(folder/'audit.json', {'schema': 1, 'status': 'complete_read_only_inspection', 'job': 'M11',
        'outer_seconds': record['elapsed_seconds'], 'outer_cap_seconds': 30, 'source_files_read': 5,
        'methods_found': 7, 'methods_not_found': missing, 'all_found_methods_complete_untruncated': True,
        'frozen_inputs_trace_and_excerpt_hashes_verified': True,
        'evidence_sha256': {name: sha(folder/name) for name in ['record.json','registration.json','inspection/inspection.json']},
        'findings': [
            {'mechanic': 'loss_overlay', 'source': 'game.lua:3581-3626',
             'finding': 'On first GAME_OVER update, original loss bookkeeping runs, paused becomes true, original overlay_menu constructs create_UIBox_game_over with no_esc=true, then STATE_COMPLETE becomes true. Overlay creation is synchronous within this method.'},
            {'mechanic': 'loss_buttons', 'source': 'functions/UI_definitions.lua:2862-2931',
             'finding': 'The original loss UI offers notify_then_setup_run and go_to_menu. Presence of this UI alone does not qualify a winning outcome.'},
            {'mechanic': 'owned_dismissal', 'source': 'functions/button_callbacks.lua:1359-1371',
             'finding': 'Original exit_overlay_menu removes the overlay, clears G.OVERLAY_MENU, unpauses, and sets frame/frame_set input locks. A controller must wait for those locks to settle before dispatching a new search/run.'},
            {'mechanic': 'transition_callbacks', 'source': 'functions/button_callbacks.lua:2958-3002',
             'finding': 'Original start_run/go_to_menu clear the event queue and schedule wipe/delete/start or menu callbacks. This read-only inspection did not execute or qualify any automatic transition.'},
            {'mechanic': 'win_ui_identity', 'source': 'functions/UI_definitions.lua:2749-2800',
             'finding': 'Original create_UIBox_win gives its definition config.id=you_win_UI and an Endless exit_overlay_menu button. A label alone is insufficient to adopt an arbitrary later overlay.'}],
        'limits': ['M11 did not find global win_game in the two allowed members; no additional source was read under this lease.',
                   'The preserved earlier M02 state_events source reference separately shows win_game schedules its overlay in a later Event. This is not a new M11 observation.',
                   'Method inspection does not prove automatic gameplay, transitions, win rates or achievement completion.'],
        'source_execution': False, 'game_process_access': False, 'player_save_profile_access': False,
        'complete_attempt': False, 'qualification': False})
    print(json.dumps({'S05': 'audited found; branch/acquisition unknown', 'M11': 'audited seven complete methods; one missing'}))

if __name__ == '__main__':
    main()
