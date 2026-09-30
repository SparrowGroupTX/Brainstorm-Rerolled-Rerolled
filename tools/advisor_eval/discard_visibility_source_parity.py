#!/usr/bin/env python3
"""Check discard display orientation versus public concealment using source Lua.

Reads Balatro.exe as a ZIP only. One fresh, capped hidden lua51.dll worker; no
game launch, saves, gameplay episode, or win evidence. Source area callbacks and
flip logic execute unchanged; display geometry, unlocks, and events are stubs.
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
def sha(data): return hashlib.sha256(data).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    parser.add_argument('--policy-root', type=Path, default=ROOT)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve(); out.mkdir(parents=True, exist_ok=False)
    paths = {
        'snapshot.lua': args.policy_root/'Brainstorm/Advisor/snapshot.lua',
        'concealed_belief.lua': args.policy_root/'Brainstorm/Advisor/concealed_belief.lua',
        'discard_source_parity.py': ROOT/'tools/advisor_eval/discard_source_parity.py',
        'discard_visibility_source_parity.py': Path(__file__),
        'discard_visibility_source_parity.lua': Path(__file__).with_suffix('.lua'),
        'run_lua_tests.py': ROOT/'tests/run_lua_tests.py',
    }
    files = {name: path.read_bytes() for name, path in paths.items()}
    for name, data in files.items(): (out/name).write_bytes(data)
    signatures = {
        'cardarea.lua': ['function CardArea:emplace(', 'function CardArea:remove_card(',
                         'function CardArea:draw_card_from(', 'function CardArea:align_cards('],
        'card.lua': ['function Card:flip(', 'function Card:set_card_area(', 'function Card:remove_from_area(',
                     'function Card:is_face(', 'function Card:get_id('],
        'blind.lua': ['function Blind:stay_flipped(', 'function Blind:disable('],
        'functions/misc_functions.lua': ['function find_joker('],
    }
    with zipfile.ZipFile(args.install/'Balatro.exe') as archive:
        source = {name: archive.read(name) for name in [*signatures, 'functions/UI_definitions.lua', 'challenges.lua']}
    chunks = ['Card={};CardArea={};Blind={}']
    for name, terms in signatures.items():
        chunks.extend(function_source(source[name].decode(), term) for term in terms)
    # This exact public deck-preview predicate distinguishes displayed backs
    # in the discard from identities still included in the unknown population.
    predicate = re.search(r'if (\(v\.area and v\.area == G\.deck\) or v\.ability\.wheel_flipped) then',
                          source['functions/UI_definitions.lua'].decode()).group(1)
    chunks.append('function source_unknown_population(v) return not not ('+predicate+') end')
    chunks.append('PROBE_DIRECTORY='+json.dumps(str(out).replace('\\', '/')))
    chunks.append(files['discard_visibility_source_parity.lua'].decode())
    harness = '\n'.join(chunks).encode(); (out/'source_probe.lua').write_bytes(harness)
    report = {'schema': 1, 'frozen_sha256': {k: sha(v) for k,v in files.items()},
              'source_sha256': {k: sha(v) for k,v in source.items()},
              'generated_probe_sha256': sha(harness), 'lua_runtime_sha256': sha((args.install/'lua51.dll').read_bytes()),
              'timeout_seconds': 30, 'source_execution': 'isolated lua51.dll',
              'scope': 'Actual source discard alignment, draw visibility, reveal and disable markers versus Snapshot capture; synthetic source mechanics only.'}
    start = time.perf_counter()
    try:
        result = subprocess.run([sys.executable, str(out/'run_lua_tests.py'), '--lua-library',
                                 str(args.install/'lua51.dll'), str(out/'source_probe.lua')], cwd=ROOT,
                                capture_output=True, text=True, timeout=30,
                                creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        report.update(status='passed' if result.returncode == 0 else 'failed', returncode=result.returncode)
        log = result.stdout+result.stderr
        match = re.search(r'discard visibility source parity: (\d+) cases, (\d+) comparisons', log)
        if match: report['cases'], report['comparisons'] = map(int, match.groups())
    except subprocess.TimeoutExpired as error:
        report['status'] = 'timeout'; log = str(error)
    report['wall_seconds'] = time.perf_counter()-start
    report['frozen_inputs_unchanged'] = all(sha((out/name).read_bytes()) == sha(data) for name, data in files.items())
    (out/'output.log').write_text(log, encoding='utf-8')
    (out/'report.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report, indent=2), flush=True)
    return 0 if report['status'] == 'passed' and report['frozen_inputs_unchanged'] else 1

if __name__ == '__main__': raise SystemExit(main())
