"""Bounded manufactured acquisition validation; no live game or captured replay."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[4]
component = Path(__file__).resolve().parent
number = 1
while (component / f'validation_{number:02d}.json').exists():
    number += 1
fixture = component / 'tests/advisor_gold_acquisition.lua'
command = [sys.executable, 'tests/run_lua_tests.py', str(fixture.relative_to(root))]
inputs = list((component / 'Brainstorm').rglob('*.lua')) + [fixture]
inputs += list((root / 'tools/advisor_eval/development344/tarot_hold_component').glob('*.lua'))
inputs += [root / 'Brainstorm/Advisor' / name for name in
           ('gold_goal.lua', 'shop_scoring.lua', 'scoring.lua', 'strategy.lua', 'shop_sequences.lua',
            'liquidity.lua', 'gold_perkeo.lua', 'snapshot.lua')]
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
receipt = {'kind': 'manufactured_fixture', 'source_execution': False, 'captured_replay': False,
           'live_game_control': False, 'max_seconds': 60, 'command': command,
           'inputs': {str(path.relative_to(root)): digest(path) for path in inputs}}
start = time.monotonic()
try:
    result = subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=60,
                            creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
    receipt.update(exit_code=result.returncode, stdout=result.stdout, stderr=result.stderr)
except subprocess.TimeoutExpired as error:
    receipt.update(exit_code=None, timeout=True, stdout=str(error.stdout or ''), stderr=str(error.stderr or ''))
receipt['seconds'] = time.monotonic() - start
receipt['inputs_unchanged'] = all(digest(root / path) == value for path, value in receipt['inputs'].items())
with (component / f'validation_{number:02d}.json').open('x', encoding='utf-8') as stream:
    json.dump(receipt, stream, indent=2)
    stream.write('\n')
print(json.dumps(receipt))
raise SystemExit(0 if receipt.get('exit_code') == 0 and receipt['inputs_unchanged'] else 1)
