"""Pure receipt checks. These helpers never import or execute a source adapter."""
from pathlib import Path
import hashlib
import json
import re


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def verify_manifest(folder, registration, record, expected_policy):
    issues = []
    def check(ok, reason):
        if not ok: issues.append(reason)
    def read(name): return json.loads((folder / name).read_text())
    installed = read('installed_policy_record.json')
    final = read('installed_final_verification.json')
    validation = read('installed_validation.json')
    spent = read('spent.json')
    policy = installed['policy']
    check(record.get('job') == registration.get('job') == spent.get('job') == 'C09', 'Wrong job identity')
    check(spent.get('one_use') is True and spent.get('registration_sha256') == sha(folder / 'registration.json'), 'Spent receipt differs')
    check(installed.get('version') == final.get('version') == '2.121.0-alpha', 'Installed checkpoint differs')
    check(policy['policy_digest'] == digest(policy['policy_files']) == final.get('policy_digest') == validation.get('policy_digest') == expected_policy, 'Exact installed policy records differ')
    frozen = {key[7:]: value for key, value in registration['files'].items() if key.startswith('policy/')}
    check(frozen == policy['policy_files'] == validation.get('policy_files'), 'Whole frozen policy manifest differs')
    check(final.get('installed_matches') is True and final.get('native_unchanged') is True and final.get('config_restored_or_modified_by_finalizer') is False, 'Installed final verification failed')
    check(final.get('installed_report') == sha(folder / 'installed_validation.json'), 'Exact-installed regression report hash differs')
    check(validation.get('passed') is True and validation.get('policy_unchanged') is True and validation.get('tests_unchanged') is True, 'Exact-installed regression evidence failed')
    metadata = registration['metadata']
    check(metadata.get('checkpoint') == 321 and metadata.get('maximum_actions') == 500 and metadata.get('outer_seconds') == 180, 'Registered attempt limits differ')
    check(metadata.get('installed_final_verification_sha256') == sha(folder / 'installed_final_verification.json'), 'Registered installed final hash differs')
    recipe = read('normal_opening_recipe.json'); selection = read('normal_seed_selection.json')
    check(recipe.get('seed') == selection.get('seed') == metadata.get('seed') == 'M4BVSY11', 'Observed S04 seed differs')
    check(recipe.get('discovery', {}).get('job') == selection.get('source_search_job') == 'S04', 'Observed selection job differs')
    check(recipe.get('qualification') is False and selection.get('qualification') is False and selection.get('unseen_holdout') is False, 'Development selection scope differs')
    prior = read('source_C07_registration.json')
    check(all(sha(folder / name) == prior['files'][name] for name in ('normal_opening_recipe.json', 'normal_seed_selection.json')), 'Original S04/C07 recipe bytes differ')
    check(all(sha(folder / ('observed_S04_' + name)) == expected for name, expected in selection['search_evidence'].items()), 'Observed S04 receipt bytes differ')
    expected_binaries = {'balatro.exe', 'lua51.dll', Path(metadata['python_executable']).name.lower()}
    check({Path(name).name.lower() for name in registration['external_files']} == expected_binaries, 'External source/runtime/Python set differs')
    check(registration['external_files'].get(metadata['python_executable']) is not None, 'Registered Python runtime missing')
    return issues


def verify_wiring(receipt, source_path):
    issues = []; wiring = receipt.get('wiring', {})
    source = Path(source_path).read_text()
    edges_block = source.split('local edges={', 1)[1].split('local secondary=', 1)[0]
    expected_edges = [{'from': a, 'to': b} for a, b in re.findall(r"\{'([^']+)','([^']+)'\}", edges_block)]
    required = re.findall(r"'([^']+)'", source.split('local required={', 1)[1].split('local edges=', 1)[0])
    secondary = re.findall(r"'([^']+)'", source.split('local secondary=', 1)[1].split('local excluded=', 1)[0])
    expected_modules = sorted(required + secondary + ['gold_goal'])
    if wiring.get('kind') != 'complete_source_policy_wiring_c07_v1': issues.append('Wrong C07 wiring contract')
    if wiring.get('connections') != expected_edges or len(expected_edges) != 34: issues.append('Full34 module edges differ')
    if wiring.get('modules') != expected_modules or 'hand_copy_preflight' not in expected_modules: issues.append('Whole required module set differs')
    for field in ('retry_enabled', 'checkpoint_restore_enabled', 'runtime_ui_execution', 'qualification'):
        if wiring.get(field) is not False: issues.append('Live/retry wiring scope differs: ' + field)
    return issues


def verify_gold_callbacks(callbacks, terminals, contexts, saved_rows):
    issues = []; checked = []; deck_progress = False; joker_progress = False
    awarded = set()
    for row in callbacks:
        name = row.get('callback'); before = row.get('before', {}); after = row.get('after', {})
        eligible = all(side.get('stake') == 8 and side.get('seeded') is False and not side.get('challenge') for side in (before, after))
        if not eligible: issues.append('Progress callback is not an eligible synthetic Red Gold run')
        if before.get('deck') != 'b_red' or after.get('deck') != 'b_red': issues.append('Progress callback deck differs')
        if name == 'set_deck_win':
            changed = type(before.get('deck_wins')) is int and type(after.get('deck_wins')) is int and after['deck_wins'] > before['deck_wins']
            deck_progress = deck_progress or changed
            deltas = {'b_red': after.get('deck_wins', 0) - before.get('deck_wins', 0)}
        elif name == 'set_joker_win':
            old, new = before.get('jokers', {}), after.get('jokers', {})
            changed = all(type(n) is int and type(new.get(key)) is int and new[key] > n for key, n in old.items())
            deltas = {key: new.get(key, 0) - n for key, n in old.items()}
            if set(old) != set(new): issues.append('Joker callback changed held membership')
            awarded.update(key for key, n in old.items() if n == 0 and new.get(key, 0) > 0)
            joker_progress = joker_progress or changed
        else:
            issues.append('Unknown original progress callback'); continue
        if row.get('progress_verified') is not changed: issues.append('Original callback delta disagrees with its receipt')
        checked.append({'callback': name, 'eligible': eligible, 'progress_verified': changed, 'deltas': deltas})
    terminal_goal = contexts[0].get('snapshot', {}).get('completionist_goal') if len(contexts) == 1 else None
    if len(terminals) == 1:
        terminal = terminals[0]; evidence = terminal.get('normal_progress', {})
        if evidence.get('deck_progress') is not deck_progress or evidence.get('joker_progress') is not joker_progress:
            issues.append('Terminal progress flags differ from independent callback deltas')
        represented = [{'name': r['callback'], 'before': r['before'], 'after': r['after'], 'progress_verified': r['progress_verified']} for r in callbacks]
        # The source trace serializes an empty Lua table as {}, including arrays.
        if (evidence.get('callbacks') or []) != represented: issues.append('Terminal callbacks differ from original trace callbacks')
        if evidence.get('source_saved'):
            final = evidence.get('final_context', {})
            if not any(row.get('ante') == final.get('ante') and row.get('chips') == final.get('chips') and row.get('target') == final.get('target') for row in saved_rows):
                issues.append('Under-target saved exception has no matching original calculation receipt')
        if terminal_goal:
            counts = terminal_goal.get('counts', {})
            expected_counts = {'complete': len(awarded), 'missing': 150 - len(awarded), 'unknown': 0, 'total': 150}
            if counts != expected_counts: issues.append('Terminal Gold counts differ from original callback awards')
            actual_complete = {t['key'] for t in terminal_goal.get('targets', []) if t.get('status') == 'complete'}
            if actual_complete != awarded: issues.append('Terminal Gold identities differ from callback awards')
        elif terminal.get('outcome') == 'win': issues.append('Winning terminal has no captured Gold objective')
    return {'callbacks': checked, 'deck_progress': deck_progress, 'joker_progress': joker_progress,
            'synthetic_first_gold_keys': sorted(awarded), 'synthetic_first_gold_count': len(awarded),
            'terminal_captured_goal': terminal_goal,
            'player_profile_or_achievement_affected': False,
            'scope': 'Original source callback deltas in the declared fresh synthetic profile only; no awarded progression inferred from acquisition.'}, issues
