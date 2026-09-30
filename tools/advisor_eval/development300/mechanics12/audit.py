"""Read-only completed M12 trace audit. Creates new audit; never dispatches."""
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
    assert record['job'] == registration['job'] == 'M12'
    assert record['registration_sha256'] == sha(folder/'registration.json')
    assert record['trace_sha256'] == sha(folder/'trace.log')
    assert all(sha(folder/name) == expected for name, expected in registration['files'].items())
    rows = []
    for line in (folder/'trace.log').read_text(encoding='utf-8').splitlines():
        try:
            value = json.loads(line)
            if isinstance(value, dict):
                rows.append(value)
        except json.JSONDecodeError:
            pass
    verified = [row for row in rows if row.get('type') == 'engine_collection_startup_verified']
    stopped = [row for row in rows if row.get('type') == 'engine_episode_stopped']
    blocked = [row for row in rows if row.get('type') == 'engine_probe_blocked']
    preflight = [row for row in rows if row.get('type') == 'engine_collection_startup_preflight']
    actions = [row for row in rows if row.get('type') in ('engine_episode_action', 'engine_episode_decision', 'engine_episode_score')]
    passed = record['status'] == 'complete' and record['exit_code'] == 0 and len(verified) == 1 and not blocked and not actions
    if passed:
        row = verified[0]
        assert row['calls'] == {'search_stand_in': 1, 'delete_run': 1, 'start_run': 1, 'back': 1,
            'settings_changed': 1, 'advisor_actions': 0, 'native_search': 0}
        assert row['actual_seed'] == 'S7PXV521' and row['initial_seed'] == 'STARTUP1'
        assert row['phase'] == 'blind' and row['round'] == 0 and row['ante'] == 1 and row['score_calls'] == 0
        assert row['deck'] == 'b_red' and row['stake'] == 8 and row['used_filter'] is True and row['seeded'] is False
        assert row['profile_counts'] == {'total': 150, 'missing': 150, 'complete': 0, 'unknown': 0}
        assert row['profile_unchanged'] is True and row['old_game_replaced'] is True
        assert len(stopped) == 1 and stopped[0]['outcome'] == 'censored' and stopped[0]['decisions'] == 0
        assert stopped[0]['reason'] == 'development_collection_product_startup'
    audit = {'schema': 1, 'job': 'M12', 'record_sha256': sha(folder/'record.json'),
        'trace_sha256': sha(folder/'trace.log'), 'registration_sha256': sha(folder/'registration.json'),
        'status': 'mechanical_startup_verified' if passed else 'mechanical_startup_not_verified',
        'worker_status': record['status'], 'worker_elapsed_seconds': record['elapsed_seconds'],
        'spent_once': record['one_use_spent'], 'frozen_inputs_verified': True,
        'verified_rows': verified, 'preflight': preflight, 'blocked': blocked, 'stopped': stopped,
        'actual_advisor_actions': len(actions), 'new_native_search_calls': 0,
        'interpretation': 'Observed-S05 receipt startup mechanic only. No full attempt, gameplay win, Soul acquisition, player progress or achievement inference.',
        'qualification': False, 'full_autoplay_qualified': False}
    with (folder/'audit.json').open('x', encoding='utf-8') as stream:
        json.dump(audit, stream, indent=2); stream.write('\n')
    print(json.dumps({'status': audit['status'], 'elapsed_seconds': record['elapsed_seconds'],
                      'blocked': blocked, 'preflight': preflight}))


if __name__ == '__main__':
    main()
