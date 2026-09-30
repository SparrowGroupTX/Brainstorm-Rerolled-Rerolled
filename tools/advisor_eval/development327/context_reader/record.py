"""Record this bounded tooling slice; manufactured tests and existing artifacts only."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    command = [sys.executable, '-m', 'unittest', 'tests.test_advisor_log_inspection',
               'tests.test_advisor_player_timing']
    start = time.monotonic()
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=60,
                            creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    elapsed = time.monotonic()-start
    log = result.stdout+'\n'+result.stderr
    with (HERE/'validation.log').open('x', encoding='utf-8', newline='\n') as output:
        output.write(log)
    report = json.loads((HERE/'captured_tail_report.json').read_bytes())
    entries = report['inputs']['rows']
    captured_unchanged = all(sha(ROOT/entry['path']) == entry['sha256'] for entry in entries)
    sources = ['tools/advisor_eval/inspect_player_log.py', 'tests/test_advisor_log_inspection.py',
               'tools/advisor_eval/read_player_log.py', 'tools/advisor_eval/analyze_player_timing.py',
               'tools/advisor_eval/development327/context_reader/README.md',
               'tools/advisor_eval/development327/context_reader/record.py',
               'tools/advisor_eval/development327/context_reader/validation.log',
               'tools/advisor_eval/development327/context_reader/captured_tail_report.json']
    manifest = {
        'schema': 1, 'created_utc': datetime.now(timezone.utc).isoformat(),
        'component': 'Bounded context inspection and exact selected-event extraction tooling',
        'owned_source_files': sources[:2], 'files': {path: sha(ROOT/path) for path in sources},
        'validation': {'command': command, 'exit_code': result.returncode, 'seconds': elapsed,
                       'tests': int(re.search(r'Ran (\d+) tests', log).group(1)),
                       'manufactured_data_only': True},
        'existing_copied_tail': {'files': len(entries), 'events': report['events'],
                                 'decoded_bytes': report['decoded_bytes'],
                                 'report_bytes': (HERE/'captured_tail_report.json').stat().st_size,
                                 'report_status': report['status'], 'captured_inputs_unchanged': captured_unchanged,
                                 'scope': 'Root authorized already-captured segments 000011–000014 only.'},
        'source_jobs': 0, 'search_jobs': 0, 'complete_attempt_jobs': 0, 'captured_gameplay_experiments': 0,
        'external_log_reads': 0, 'save_reads': 0, 'game_control': False,
        'original_logs_modified_or_removed': False, 'summary_replaces_originals': False,
        'all_historical_experiment_authority': 'closed',
        'reported_terminal_labels_are_not_verified_wins': True,
    }
    with (HERE/'manifest.json').open('x', encoding='utf-8', newline='\n') as output:
        json.dump(manifest, output, indent=2)
        output.write('\n')
    print(json.dumps({'manifest': str(HERE/'manifest.json'), 'sha256': sha(HERE/'manifest.json'),
                      'tests': manifest['validation']['tests'], 'passed': result.returncode == 0,
                      'captured_inputs_unchanged': captured_unchanged}))
    return int(result.returncode != 0 or not captured_unchanged)


if __name__ == '__main__':
    raise SystemExit(main())
