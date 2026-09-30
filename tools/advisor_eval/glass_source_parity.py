#!/usr/bin/env python3
"""Bounded Glass destruction parity with untouched installed-source snippets.

Uses lua51.dll only, never the game process. The destruction loop, callback
routing, face tests, and full-deck removal come directly from the source ZIP.
Presentation and event scheduling are explicit test doubles. This verifies the
post-scoring boundary, not complete scoring, phase parity, or run win rates.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import zipfile

from discard_source_parity import function_source, ROOT


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    args = parser.parse_args()
    chunks = ['Card={}; G={FUNCS={}}']
    with zipfile.ZipFile(args.install / 'Balatro.exe') as archive:
        sources = {}
        for name in ['card.lua', 'functions/state_events.lua', 'functions/misc_functions.lua']:
            raw = archive.read(name)
            print(f'source {name} sha256={hashlib.sha256(raw).hexdigest()}', flush=True)
            sources[name] = raw.decode()
        for signature in ['function Card:calculate_joker(', 'function Card:get_id(', 'function Card:is_face(']:
            chunks.append(function_source(sources['card.lua'], signature))
        chunks.append(function_source(sources['functions/misc_functions.lua'], 'function find_joker('))
        events = sources['functions/state_events.lua']
        start = events.index('        local cards_destroyed = {}')
        end = events.index('        local glass_shattered = {}', start)
        chunks.append('function source_destroy(scoring_hand)\n' + events[start:end] + '\nreturn cards_destroyed\nend')
        card = sources['card.lua']
        start = card.index('    if G.playing_cards then', card.index('function Card:remove()'))
        end = card.index('    remove_all(self.children)', start)
        chunks.append('function source_population_remove(self)\n' + card[start:end] + '\nend')
    chunks.append(Path(__file__).with_suffix('.lua').read_text(encoding='utf-8'))
    spec = importlib.util.spec_from_file_location('lua_tests', ROOT / 'tests/run_lua_tests.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    runtime = module.LuaLibrary(args.install / 'lua51.dll')
    with tempfile.TemporaryDirectory(prefix='advisor-glass-parity-') as directory:
        fixture = Path(directory) / 'parity.lua'
        fixture.write_text('\n'.join(chunks), encoding='utf-8')
        return 0 if runtime.run(fixture) else 1


if __name__ == '__main__':
    raise SystemExit(main())
