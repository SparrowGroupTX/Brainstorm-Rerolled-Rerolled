"""Read-only audit of completed M14 original-source startup comparison."""
from pathlib import Path
import hashlib
import json
import sys


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    folder = Path(sys.argv[1]).resolve()
    record = json.loads((folder/'record.json').read_text(encoding='utf-8'))
    registration = json.loads((folder/'registration.json').read_text(encoding='utf-8'))
    assert record['job'] == registration['job'] == 'M14'
    assert record['registration_sha256'] == sha(folder/'registration.json')
    assert record['trace_sha256'] == sha(folder/'trace.log')
    assert all(sha(folder/name) == expected for name, expected in registration['files'].items())
    rows = []
    for line in (folder/'trace.log').read_text(encoding='utf-8').splitlines():
        try:
            value = json.loads(line)
            if isinstance(value, dict): rows.append(value)
        except json.JSONDecodeError: pass
    of = lambda kind: [row for row in rows if row.get('type') == kind]
    verified = of('engine_collection_startup_verified')
    baseline = of('engine_collection_startup_baseline')
    blocked = of('engine_probe_blocked')
    stopped = of('engine_episode_stopped')
    actions = of('engine_episode_action')+of('engine_episode_decision')+of('engine_episode_score')
    passed = record['status'] == 'complete' and record['exit_code'] == 0 and len(verified) == len(baseline) == 1 and not blocked and not actions
    if passed:
        row = verified[0]
        assert row['calls'] == {'search_stand_in': 1, 'delete_run': 1, 'start_run': 1, 'back': 1,
            'settings_changed': 1, 'advisor_actions': 0, 'native_search': 0}
        assert row['actual_seed'] == 'S7PXV521' and row['initial_seed'] == 'STARTUP1'
        assert row['phase'] == 'blind' and row['round'] == 0 and row['ante'] == 1 and row['score_calls'] == 0
        assert row['deck'] == 'b_red' and row['stake'] == 8 and row['used_filter'] is True and row['seeded'] is False
        assert row['profile_counts'] == {'total': 150, 'missing': 150, 'complete': 0, 'unknown': 0}
        assert row['actual_small_tag'] == 'tag_charm' and row['boot_cache_preserved'] is True and row['baseline_preflight_rejected'] is True
        assert baseline[0]['ready'] is False and baseline[0]['searches'] == baseline[0]['launches'] == 0
        assert len(stopped) == 1 and stopped[0]['outcome'] == 'censored' and stopped[0]['decisions'] == 0
        assert stopped[0]['reason'] == 'development_collection_product_startup_boot_cache'
    audit = {'schema': 1, 'job': 'M14', 'status': 'startup_boot_cache_comparison_verified' if passed else 'startup_not_verified',
        'record_sha256': sha(folder/'record.json'), 'trace_sha256': sha(folder/'trace.log'),
        'worker_status': record['status'], 'worker_elapsed_seconds': record['elapsed_seconds'],
        'spent_once': record['one_use_spent'], 'frozen_inputs_verified': True,
        'baseline': baseline, 'verified_rows': verified, 'blocked': blocked, 'stopped': stopped,
        'actual_advisor_actions': len(actions), 'new_native_search_calls': 0,
        'interpretation': 'Only M13-proven boot-cache shape injected with inert font stand-in; original boot_timer not executed. Baseline preflight versus authentic repaired product startup, not an autonomous complete attempt.',
        'qualification': False, 'full_autoplay_qualified': False}
    with (folder/'audit.json').open('x', encoding='utf-8') as stream:
        json.dump(audit, stream, indent=2); stream.write('\n')
    print(json.dumps({'status': audit['status'], 'elapsed_seconds': record['elapsed_seconds'], 'blocked': blocked}))


if __name__ == '__main__':
    main()
