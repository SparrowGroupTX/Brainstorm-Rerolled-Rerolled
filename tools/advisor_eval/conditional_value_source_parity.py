#!/usr/bin/env python3
"""Bounded conditional-cashout parity. Reads Balatro.exe as a ZIP; never runs it.

Freezes the advisor module, source callbacks and probe in a fresh output folder.
Only the independent Lua 5.1 DLL is used, with a 30-second child-process limit.
No game window, gameplay, user profile or save is read or changed.
"""
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


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--policy-root', type=Path, default=ROOT)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    module = (args.policy_root / 'Brainstorm/Advisor/conditional_value.lua').read_bytes()
    (output / 'conditional_value.lua').write_bytes(module)
    fixture_path = Path(__file__).with_suffix('.lua')
    fixture = fixture_path.read_bytes()
    (output / 'conditional_value_source_parity.py').write_bytes(Path(__file__).read_bytes())
    (output / 'conditional_value_source_parity.lua').write_bytes(fixture)
    runner = (ROOT / 'tests/run_lua_tests.py').read_bytes()
    (output / 'run_lua_tests.py').write_bytes(runner)
    with zipfile.ZipFile(args.install / 'Balatro.exe') as archive:
        source = archive.read('card.lua')
    chunks = ['Card={}']
    for signature in ('function Card:calculate_dollar_bonus(', 'function Card:calculate_joker(',
                      'function Card:calculate_perishable(', 'function Card:calculate_rental(',
                      'function Card:set_debuff(', 'function Card:get_id('):
        chunks.append(function_source(source.decode(), signature))
    chunks.append('PROBE_MODULE=' + json.dumps(str(output / 'conditional_value.lua').replace('\\', '/')))
    chunks.append(fixture.decode())
    harness = '\n'.join(chunks).encode()
    (output / 'source_probe.lua').write_bytes(harness)
    started = time.perf_counter()
    report = {'schema': 1, 'policy_sha256': sha(module), 'original_card_lua_sha256': sha(source),
              'policy_root': str(args.policy_root.resolve()), 'lua_runner_sha256': sha(runner),
              'adapter_sha256': sha(Path(__file__).read_bytes()), 'fixture_sha256': sha(fixture),
              'generated_probe_sha256': sha(harness), 'source_execution': 'isolated lua51.dll',
              'scope': 'cashout and resale timing fixtures; no episodes or measured wins', 'timeout_seconds': 30}
    try:
        result = subprocess.run([sys.executable, str(output / 'run_lua_tests.py'),
                                 '--lua-library', str(args.install / 'lua51.dll'), str(output / 'source_probe.lua')],
                                cwd=ROOT, capture_output=True, text=True, timeout=30,
                                creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        report['status'] = 'passed' if result.returncode == 0 else 'failed'
        report['returncode'] = result.returncode
        log = result.stdout + result.stderr
        match = re.search(r'conditional source parity: (\d+) cases, (\d+) comparisons', log)
        if match:
            report['cases'], report['comparisons'] = map(int, match.groups())
    except subprocess.TimeoutExpired as error:
        report['status'] = 'timeout'
        log = str(error)
    report['wall_seconds'] = time.perf_counter() - started
    (output / 'output.log').write_text(log, encoding='utf-8')
    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2), flush=True)
    return 0 if report['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
