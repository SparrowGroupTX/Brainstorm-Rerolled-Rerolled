#!/usr/bin/env python3
"""Bounded Gold/Blue end-round parity from installed unmodified Lua source.

Reads Balatro.exe as a ZIP only. Executes lua51.dll, never the game executable.
The exact held-card loop and cashout source run with display/event/card-creation
doubles; no game window, profile, save, episode RNG or live action is involved.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import zipfile

from discard_source_parity import function_source

ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    args = parser.parse_args()
    chunks = ['Card={};G={FUNCS={}}']
    with zipfile.ZipFile(args.install / 'Balatro.exe') as archive:
        source = {}
        for name in ('card.lua', 'functions/common_events.lua', 'functions/state_events.lua'):
            raw = archive.read(name)
            print(f'source {name} sha256={hashlib.sha256(raw).hexdigest()}', flush=True)
            source[name] = raw.decode()
        for signature in ('function Card:get_end_of_round_effect(', 'function Card:calculate_seal(',
                          'function Card:calculate_joker(', 'function Card:calculate_perishable(',
                          'function Card:calculate_rental(', 'function Card:calculate_dollar_bonus(',
                          'function Card:set_debuff(', 'function Card:get_chip_h_mult(',
                          'function Card:get_chip_h_x_mult('):
            chunks.append(function_source(source['card.lua'], signature))
        chunks.append(function_source(source['functions/common_events.lua'], 'function eval_card('))
        state = source['functions/state_events.lua']
        start = state.index('for i=1, #G.hand.cards do', state.index('function end_round('))
        end = state.index('\n                delay(0.3)', start)
        chunks.append('function source_held_rewards()\n' + state[start:end] + '\nend')
        chunks.append(function_source(state, 'G.FUNCS.evaluate_round = function('))
    chunks.append(Path(__file__).with_suffix('.lua').read_text(encoding='utf-8'))
    spec = importlib.util.spec_from_file_location('lua_tests', ROOT / 'tests/run_lua_tests.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    runtime = module.LuaLibrary(args.install / 'lua51.dll')
    with tempfile.TemporaryDirectory(prefix='advisor-finish-rewards-parity-') as directory:
        path = Path(directory) / 'parity.lua'
        path.write_text('\n'.join(chunks), encoding='utf-8')
        return 0 if runtime.run(path) else 1


if __name__ == '__main__':
    raise SystemExit(main())
