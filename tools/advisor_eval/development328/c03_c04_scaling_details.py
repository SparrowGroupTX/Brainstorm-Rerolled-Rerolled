"""Extract a small, public-only supplement from already-completed C04 evidence."""
import json
from pathlib import Path

from paired_source_audit import BASE, load, pick, public_snapshot, sha
from stdout_transport import open_trace, verify_trace


def main():
    folder = BASE / 'C04'
    paired = BASE / 'paired_C03_C04_audit.json'
    record = load(folder / 'record.json')
    trace = (folder / record['trace_path']).resolve()
    trace.relative_to(folder.resolve())
    assert record['worker_reaped'] and record['stdout_drain_completed']
    assert sha(trace) == record['trace_sha256']
    decoded = verify_trace(trace, record['decoded_trace_bytes'], record['decoded_trace_sha256'])
    selected = {94, 95, 96, 97, 98, 101, 109, 116, 117, 119,
                121, 122, 123, 124, 125, 127, 128, 129, 130, 140, 146}
    observations = []
    with open_trace(trace) as stream:
        for raw in stream:
            try:
                row = json.loads(raw)
            except (json.JSONDecodeError, UnicodeDecodeError):
                continue
            if not isinstance(row, dict) or row.get('type') != 'engine_episode_decision_started' or row.get('step') not in selected:
                continue
            public, scope = public_snapshot(row['snapshot'])
            assert not scope['unclassified_top_fields']
            observations.append({
                'step': row['step'], 'phase': row['phase'],
                **pick(public, ['ante', 'round', 'dollars']),
                'blind': pick(public.get('blind', {}), ['key', 'name', 'chips']),
                'hand_levels': {name: pick(hand, ['level', 'chips', 'mult', 'played'])
                                for name, hand in public.get('hands', {}).items()
                                if hand.get('visible')},
                'hand': [pick(card, ['rank', 'suit', 'enhancement', 'seal', 'debuff', 'identity_redacted'])
                         for card in public.get('hand', [])],
                'jokers': [{'key': card.get('key'), 'ability': pick(card.get('ability', {}),
                            ['eternal', 'perishable', 'perish_tally', 'rental', 'x_mult', 'yorick_discards'])}
                           for card in public.get('jokers', [])],
                'consumables': [{'key': card.get('key'), 'negative': bool(card.get('edition', {}).get('negative'))}
                                for card in public.get('consumeables', [])],
                'offers': [{'key': card.get('key'), 'cost': card.get('cost'),
                            'ability': pick(card.get('ability', {}), ['eternal', 'perishable', 'rental'])}
                           for card in public.get('shop_jokers', [])],
            })
    out = {'schema': 1, 'kind': 'read_only_public_scaling_supplement',
           'paired_audit_sha256': sha(paired), 'record_sha256': sha(folder / 'record.json'),
           'trace_sha256': sha(trace), 'decoded_verification': decoded,
           'reader_sha256': sha(Path(__file__)), 'public_projection_sha256': sha(Path(__file__).with_name('paired_source_audit.py')),
           'observations': observations, 'new_experiment_jobs': 0,
           'new_source_or_policy_executions': 0, 'raw_fingerprint_decoding': False,
           'limits': 'Selected dependent source data; C04 remains timeout. Public observations do not prove optimality, terminal rescue or a player win rate.'}
    target = BASE / 'paired_C03_C04_scaling_details.json'
    with target.open('x', encoding='utf-8') as stream:
        json.dump(out, stream, indent=2, allow_nan=False)
        stream.write('\n')
    print(json.dumps({'path': str(target), 'sha256': sha(target), 'observations': len(observations)}))


if __name__ == '__main__':
    main()
