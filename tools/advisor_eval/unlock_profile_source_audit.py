#!/usr/bin/env python3
"""Audit original-source profile pool gates without consulting any saved profile."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import zipfile

from discard_source_parity import function_source

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--install', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    args = parser.parse_args(); output = args.output.resolve(); output.mkdir(parents=True, exist_ok=False)
    sha = lambda data: hashlib.sha256(data).hexdigest()
    with zipfile.ZipFile(args.install / 'Balatro.exe') as archive:
        game = archive.read('game.lua'); common = archive.read('functions/common_events.lua')
    # Preserve each original one-line Joker prototype as the audit input. The
    # probe executes the original pool callback; this parser only inventories
    # explicit source-default flags and never infers a user's unlock state.
    prototypes = [(m[1], m[2]) for m in re.finditer(r'^\s+(j_\w+)\s*=\s*(\{.*\}),?\s*$', game.decode(), re.M)
                  if "set = 'Joker'" in m[2] or 'set = "Joker"' in m[2]]
    if len(prototypes) != 150:
        raise ValueError('Original Joker prototype layout changed; do not guess source flags')
    inventory = [{'key': key, 'unlocked_default': re.search(r'\bunlocked\s*=\s*(true|false)', value)[1] == 'true',
                  'rarity': int(re.search(r'\brarity\s*=\s*(\d+)', value)[1])} for key, value in prototypes]
    callback = function_source(common.decode(), 'function get_current_pool(')
    fixture = Path(__file__).with_suffix('.lua').read_bytes()
    harness = (callback + '\n' + fixture.decode()).encode()
    runner = (ROOT / 'tests/run_lua_tests.py').read_bytes()
    for name, value in (('probe.lua', harness), ('run_lua_tests.py', runner), ('workflow.py', Path(__file__).read_bytes()),
                        ('fixture.lua', fixture)):
        (output / name).write_bytes(value)
    (output / 'default_joker_inventory.json').write_text(json.dumps(inventory, indent=2) + '\n')
    report = {'schema': 1, 'qualification': False, 'source_execution': 'isolated lua51.dll; original pool callback',
              'game_sha256': sha(game), 'common_events_sha256': sha(common),
              'runtime_sha256': sha((args.install / 'lua51.dll').read_bytes()), 'probe_sha256': sha(harness),
              'workflow_sha256': sha(Path(__file__).read_bytes()), 'runner_sha256': sha(runner),
              'default_jokers': len(inventory),
              'default_unlocked_jokers': sum(row['unlocked_default'] for row in inventory),
              'default_locked_jokers': sum(not row['unlocked_default'] for row in inventory),
              'limits': ['No actual user profile was read or inferred', 'Pool-gate fixture audit does not qualify the episode adapter'],
              'timeout_seconds': 15}
    started = time.perf_counter()
    try:
        result = subprocess.run([sys.executable, str(output / 'run_lua_tests.py'), '--lua-library',
                                 str(args.install / 'lua51.dll'), str(output / 'probe.lua')],
                                cwd=ROOT, capture_output=True, text=True, timeout=15,
                                creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        log = result.stdout + result.stderr; report['exit_code'] = result.returncode
        report['outcome'] = 'passed' if result.returncode == 0 else 'failed'
    except subprocess.TimeoutExpired as error:
        log = str(error); report['outcome'] = 'timeout'
    report['elapsed_seconds'] = time.perf_counter() - started
    (output / 'output.log').write_text(log, encoding='utf-8')
    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2)); return 0 if report['outcome'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
