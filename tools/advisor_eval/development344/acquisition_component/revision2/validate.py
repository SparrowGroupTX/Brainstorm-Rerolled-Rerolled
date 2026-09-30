"""Preserved v1 coroutine failure versus revised yield-safe manufactured fixture."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[5]
revision = Path(__file__).resolve().parent
component = revision.parent
number = 1
while (revision / f'validation_{number:02d}_current.json').exists():
    number += 1
wrapper = revision / 'before_coroutine.lua'
if not wrapper.exists():
    wrapper.write_text("ACQUISITION_TEST_MODULE='tools/advisor_eval/development344/acquisition_component/Brainstorm/Advisor/gold_acquisition.lua'\n"
                       "dofile('tools/advisor_eval/development344/acquisition_component/revision2/tests/advisor_gold_acquisition_runtime.lua')\n", encoding='utf-8')
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
for name, fixtures in [('before', [wrapper]), ('current', sorted((revision / 'tests').glob('*.lua')))]:
    command = [sys.executable, 'tests/run_lua_tests.py', *[str(p.relative_to(root)) for p in fixtures]]
    inputs = sorted((root / 'Brainstorm/Advisor').glob('*.lua')) + fixtures
    inputs += [component / 'Brainstorm/Advisor/gold_acquisition.lua', revision / 'Brainstorm/Advisor/gold_acquisition.lua']
    record = {'kind': 'manufactured_coroutine_runtime_fixture', 'expected_failure': name == 'before',
              'source_execution': False, 'captured_replay': False, 'live_game_control': False, 'max_seconds': 60,
              'command': command, 'inputs': {str(p.relative_to(root)): digest(p) for p in inputs}}
    start = time.monotonic()
    try:
        result = subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=60,
                                creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        record.update(exit_code=result.returncode, stdout=result.stdout, stderr=result.stderr)
    except subprocess.TimeoutExpired as error:
        record.update(exit_code=None, timeout=True, stdout=str(error.stdout or ''), stderr=str(error.stderr or ''))
    record['seconds'] = time.monotonic() - start
    record['inputs_unchanged'] = all(digest(root / path) == value for path, value in record['inputs'].items())
    with (revision / f'validation_{number:02d}_{name}.json').open('x', encoding='utf-8') as stream:
        json.dump(record, stream, indent=2)
        stream.write('\n')
    print(json.dumps({k: v for k, v in record.items() if k != 'inputs'}))
    if name == 'current' and (record.get('exit_code') != 0 or not record['inputs_unchanged']):
        raise SystemExit(1)
