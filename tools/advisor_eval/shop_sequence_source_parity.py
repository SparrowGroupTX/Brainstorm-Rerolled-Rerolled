#!/usr/bin/env python3
"""Bounded original-source purchase/resource/pricing parity; never launches the game."""
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
    hashes = {}
    for name in ('shop_sequences', 'strategy', 'consumables', 'shop_scoring'):
        data = (args.policy_root / f'Brainstorm/Advisor/{name}.lua').read_bytes()
        (output / f'{name}.lua').write_bytes(data)
        hashes[name] = sha(data)
    fixture = Path(__file__).with_suffix('.lua').read_bytes()
    runner = (ROOT / 'tests/run_lua_tests.py').read_bytes()
    (output / 'run_lua_tests.py').write_bytes(runner)
    (output / 'shop_sequence_source_parity.py').write_bytes(Path(__file__).read_bytes())
    (output / 'shop_sequence_source_parity.lua').write_bytes(fixture)
    chunks = ['Card={}; G={FUNCS={}}']
    source_hashes = {}
    sources = {'card.lua': ('function Card:set_cost(', 'function Card:add_to_deck(',
                            'function Card:remove_from_deck(', 'function Card:sell_card(',
                            'function Card:calculate_joker('),
               'functions/button_callbacks.lua': ('G.FUNCS.check_for_buy_space = function(',
                                                   'G.FUNCS.buy_from_shop = function(')}
    with zipfile.ZipFile(args.install / 'Balatro.exe') as archive:
        for name, signatures in sources.items():
            raw = archive.read(name)
            source_hashes[name] = sha(raw)
            chunks.extend(function_source(raw.decode(), signature) for signature in signatures)
    chunks.append('PROBE_ROOT=' + json.dumps(str(output).replace('\\', '/')))
    chunks.append(fixture.decode())
    harness = '\n'.join(chunks).encode()
    (output / 'source_probe.lua').write_bytes(harness)
    report = {'schema': 1, 'policy_hashes': hashes, 'original_source_hashes': source_hashes,
              'policy_root': str(args.policy_root.resolve()), 'lua_runner_sha256': sha(runner),
              'adapter_sha256': sha(Path(__file__).read_bytes()), 'fixture_sha256': sha(fixture),
              'generated_probe_sha256': sha(harness), 'timeout_seconds': 30,
              'scope': 'visible purchase/sale/resource/inflation callback fixtures; no episodes or win claims',
              'source_execution': 'isolated lua51.dll'}
    started = time.perf_counter()
    try:
        result = subprocess.run([sys.executable, str(output / 'run_lua_tests.py'),
                                 '--lua-library', str(args.install / 'lua51.dll'), str(output / 'source_probe.lua')],
                                cwd=ROOT, capture_output=True, text=True, timeout=30,
                                creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        report['status'] = 'passed' if result.returncode == 0 else 'failed'
        report['returncode'] = result.returncode
        log = result.stdout + result.stderr
        match = re.search(r'shop sequence source parity: (\d+) cases, (\d+) comparisons', log)
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
