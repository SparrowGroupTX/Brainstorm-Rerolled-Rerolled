"""Read-only C08 provenance and actual-transition projections; no policy imports."""
from pathlib import Path
import hashlib
import json
import math


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def verify_graph_receipt(folder, registration, expected_policy):
    issues = []
    def check(ok, reason):
        if not ok:
            issues.append(reason)
    def read(name):
        return json.loads((folder / name).read_text())
    graph = read('installed_graph_check.json')
    raw = read('inert_graph_raw.json')
    check(graph.get('kind') == 'c07_complete_installed_graph_check' and graph.get('passed') is True,
          'Whole current runtime graph receipt is unavailable')
    check(graph.get('policy_digest') == digest(graph.get('policy_files')) == expected_policy,
          'Graph frozen whole policy digest differs')
    registered = {key[7:]: value for key, value in registration['files'].items() if key.startswith('policy/')}
    check(graph.get('policy_files') == registered, 'Graph and registered whole policy file sets differ')
    check(graph.get('graph') == raw and graph.get('raw_report_sha256') == sha(folder / 'inert_graph_raw.json'),
          'Inert full graph raw receipt differs')
    check(graph.get('stdout_sha256') == sha(folder / 'inert_graph_stdout.log'), 'Graph stdout hash differs')
    check(all(registration['files'].get(name) == value for name, value in graph.get('adapter_files', {}).items()),
          'Graph adapter bytes differ')
    check(registration['metadata'].get('installed_graph_check_sha256') == sha(folder / 'installed_graph_check.json'),
          'Registered full graph hash differs')
    check(raw.get('kind') == 'c07_inert_current_runtime_graph' and raw.get('passed') is True
          and raw.get('source_initialized') is False and raw.get('policy_decisions') == 0
          and raw.get('retry_enabled') is False and raw.get('gold_objective_enabled') is True,
          'Inert graph boundary differs')
    check(len(raw.get('modules', [])) == 49 and len(raw.get('connections', [])) == 40,
          'Full current module or edge counts differ')
    check({'growth', 'pack_survival', 'multi_discard', 'certificate', 'bell_opening',
           'hand_copy_preflight', 'perkeo_inventory', 'gold_perkeo'}.issubset(raw.get('modules', [])),
          'Current growth/pack/copy modules absent from graph')
    required = read('required_features.json')
    check(required.get('required_checkpoint') == 320 and required.get('required_version') == '2.120.0-alpha',
          'Required feature checkpoint differs')
    check(required.get('files') == registration['metadata'].get('reviewed_feature_files')
          and all(registered.get(name) == value for name, value in required.get('files', {}).items()),
          'Reviewed exact feature bytes differ')
    check(sha(folder / 'authority.json') == registration.get('authority_sha256'), 'Frozen authority digest differs')
    reservation = folder.parent / 'C08_reservation.json'
    check(reservation.is_file() and sha(reservation) == registration.get('reservation_sha256'),
          'Fresh C08 reservation digest differs')
    if reservation.is_file():
        value = json.loads(reservation.read_text())
        check(value.get('job') == 'C08' and value.get('timeout_seconds') == 180 and value.get('one_use') is True,
              'Fresh C08 reservation limits differ')
    return {'passed': not issues, 'policy_digest': expected_policy,
            'manifest_modules': len(raw.get('modules', [])), 'manifest_edges': len(raw.get('connections', [])),
            'root_bindings': raw.get('root_bindings'), 'recorded_inert_checks': raw.get('checks'),
            'graph_receipt_sha256': sha(folder / 'installed_graph_check.json'),
            'required_feature_files': required.get('files'),
            'scope': 'Hash and structural verification of the registered inert current-runtime comparison. No module, source or adapter was executed by this audit.'}, issues


def card_summary(card):
    return {key: card.get(key) for key in ('id', 'key', 'enhancement', 'seal', 'edition', 'rank', 'suit')} | {
        'ability': card.get('ability', {})}


def yoricks(snapshot):
    return {str(card.get('id')): {'id': card.get('id'), 'debuff': card.get('debuff', False),
                                'ability': card.get('ability', {})}
            for card in snapshot.get('jokers', []) if card.get('key') == 'j_yorick'}


def finite_number(value):
    return type(value) in (int, float) and math.isfinite(value)


def actual_mechanics(index, completed, contexts):
    issues = []
    discards, growth, perkeo, packs = [], [], [], []
    for step in completed:
        snapshot = index['started'][step]['snapshot']
        result = index['decision'][step]['result']
        action_row = index['action'][step]
        action = action_row['action']
        next_started = index['started'].get(step + 1)
        after = next_started['snapshot'] if next_started else (
            contexts[0]['snapshot'] if len(contexts) == 1 and contexts[0].get('step') == step else None)
        if action['kind'] == 'discard':
            count = len(action.get('indices', []))
            row = {'step': step, 'ante': snapshot.get('ante'), 'round': snapshot.get('round'),
                   'physical_cards_discarded': count, 'indices': action.get('indices'),
                   'selected_cards': [card_summary(snapshot['hand'][i - 1]) for i in action.get('indices', [])
                                      if type(i) is int and 1 <= i <= len(snapshot.get('hand', []))],
                   'yorick_before': yoricks(snapshot), 'yorick_after': yoricks(after) if after else None,
                   'after_observed': after is not None, 'checks': []}
            if after:
                for key, old in row['yorick_before'].items():
                    if old['debuff']:
                        continue
                    ability = old['ability']; extra = ability.get('extra', {})
                    actual = row['yorick_after'].get(key)
                    supported = isinstance(extra, dict) and all(finite_number(v) for v in (
                        ability.get('yorick_discards'), ability.get('x_mult'), extra.get('discards'), extra.get('xmult')))
                    if not supported or actual is None:
                        row['checks'].append({'id': old['id'], 'checked': False,
                                              'reason': 'Required actual identity or live growth fields unavailable'})
                        continue
                    countdown, xmult = ability['yorick_discards'], ability['x_mult']
                    increments = 0
                    for _ in range(count):
                        if countdown <= 1:
                            countdown = extra['discards']; xmult += extra['xmult']; increments += 1
                        else:
                            countdown -= 1
                    matches = (actual['ability'].get('yorick_discards') == countdown
                               and actual['ability'].get('x_mult') == xmult)
                    row['checks'].append({'id': old['id'], 'checked': True, 'matched': matches,
                                          'actual_card_count': count, 'threshold_increments': increments,
                                          'expected_countdown': countdown, 'expected_x_mult': xmult})
                    if not matches:
                        issues.append({'step': step, 'reason': 'Actual physical Yorick discard transition differs'})
            discards.append(row)
        if result.get('growth'):
            projection = result['growth']
            matches = projection.get('action') == action
            if not matches:
                issues.append({'step': step, 'reason': 'Growth recommendation differs from executed action'})
            growth.append({'step': step, 'action': action, 'same_selected_action': matches,
                           'growth': projection, 'yorick_before': yoricks(snapshot),
                           'yorick_after': yoricks(after) if after else None,
                           'scope': 'Observed executed action plus its local forecast; no alternative continuation executed.'})
        if action['kind'] == 'leave_shop' and any(c.get('key') == 'j_perkeo' for c in snapshot.get('jokers', [])):
            old = {str(c.get('id')): c for c in snapshot.get('consumeables', [])}
            new = {str(c.get('id')): c for c in after.get('consumeables', [])} if after else None
            additions = [card_summary(c) for key, c in new.items() if key not in old] if new is not None else None
            removals = [card_summary(c) for key, c in old.items() if key not in new] if new is not None else None
            perkeo.append({'step': step, 'ante': snapshot.get('ante'), 'row_before': [card_summary(c) for c in snapshot.get('jokers', [])],
                           'inventory_before': [card_summary(c) for c in old.values()],
                           'inventory_after': [card_summary(c) for c in new.values()] if new is not None else None,
                           'actual_added': additions, 'actual_removed': removals, 'after_observed': after is not None,
                           'negative_added': sum(c.get('edition', {}).get('negative') is True for c in (additions or []) if isinstance(c.get('edition'), dict)),
                           'scope': 'Actual before/after inventory changes; no copy, retention or award is inferred when the next state is absent.'})
        if snapshot.get('phase') == 'pack':
            diag = action_row.get('pack_diagnostics') or {}
            packs.append({'step': step, 'action': action, 'pack_type': snapshot.get('pack_type'),
                          'pack_choices': snapshot.get('pack_choices'),
                          'selected_key': action_row.get('card_key'),
                          'survival_priority': diag.get('survival_priority'),
                          'actual_jokers_after': [card_summary(c) for c in after.get('jokers', [])] if after else None,
                          'scope': 'Actual choice and retained row; any pack discard-history comparison is a frozen-policy receipt, not a source-executed future discard.'})
    return {'actual_discards': discards, 'actual_growth_actions': growth, 'actual_perkeo_shop_exits': perkeo,
            'actual_pack_outcomes': packs,
            'counts': {'discard_actions': len(discards), 'physical_discarded_cards': sum(r['physical_cards_discarded'] for r in discards),
                       'growth_actions': len(growth), 'observed_perkeo_exits': len(perkeo), 'pack_actions': len(packs)},
            'future_actions_or_absent_outcomes_imputed': False}, issues
