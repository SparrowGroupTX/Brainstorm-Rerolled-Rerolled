#!/usr/bin/env python3
"""Bounded source callback parity; reads Balatro.exe as ZIP, never launches it."""
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
def sha(data): return hashlib.sha256(data).hexdigest()

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--install', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    p.add_argument('--policy-root', type=Path, default=ROOT)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    out = a.output.resolve(); out.mkdir(parents=True, exist_ok=False)
    module = (a.policy_root / 'Brainstorm/Advisor/blind_start.lua').read_bytes()
    fixture = Path(__file__).with_suffix('.lua').read_bytes()
    adapter = Path(__file__).read_bytes()
    runner = (ROOT / 'tests/run_lua_tests.py').read_bytes()
    for name, data in [('blind_start.lua', module), ('blind_start_source_parity.lua', fixture),
                       ('blind_start_source_parity.py', adapter), ('run_lua_tests.py', runner)]:
        (out / name).write_bytes(data)
    with zipfile.ZipFile(a.install / 'Balatro.exe') as z:
        card = z.read('card.lua'); misc = z.read('functions/misc_functions.lua')
    chunks = ['Card={}']
    for sig in ('function Card:calculate_joker(', 'function Card:remove_from_deck('):
        chunks.append(function_source(card.decode(), sig))
    chunks.append(function_source(misc.decode(), 'function playing_card_joker_effects('))
    chunks.append('PROBE_MODULE=' + json.dumps(str(out / 'blind_start.lua').replace('\\', '/')))
    chunks.append(fixture.decode())
    harness = '\n'.join(chunks).encode(); (out / 'source_probe.lua').write_bytes(harness)
    report = {'schema': 1, 'policy_sha256': sha(module), 'policy_root': str(a.policy_root.resolve()),
              'source_card_sha256': sha(card), 'source_misc_sha256': sha(misc),
              'adapter_sha256': sha(adapter), 'fixture_sha256': sha(fixture),
              'runner_sha256': sha(runner), 'generated_probe_sha256': sha(harness),
              'source_execution': 'isolated lua51.dll', 'timeout_seconds': 30,
              'scope': 'original Joker callbacks and passive removal; bounded synthetic callback fixtures, no episodes or wins'}
    started = time.perf_counter()
    try:
        r = subprocess.run([sys.executable, str(out / 'run_lua_tests.py'), '--lua-library',
                            str(a.install / 'lua51.dll'), str(out / 'source_probe.lua')],
                           cwd=ROOT, capture_output=True, text=True, timeout=30,
                           creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        report['status'] = 'passed' if r.returncode == 0 else 'failed'; report['returncode'] = r.returncode
        log = r.stdout + r.stderr
        m = re.search(r'blind-start source parity: (\d+) cases, (\d+) comparisons', log)
        if m: report['cases'], report['comparisons'] = map(int, m.groups())
    except subprocess.TimeoutExpired as error:
        report['status'] = 'timeout'; log = str(error)
    report['wall_seconds'] = time.perf_counter() - started
    (out / 'output.log').write_text(log, encoding='utf-8')
    (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2), flush=True)
    return 0 if report['status'] == 'passed' else 1
if __name__ == '__main__': raise SystemExit(main())
