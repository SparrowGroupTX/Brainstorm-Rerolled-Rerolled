#!/usr/bin/env python3
"""Bounded original-source outcome extrema for supported random score effects.

Runs extracted Card methods through lua51.dll, never the game process. The
fixture assembles a one-card High Card scoring boundary with explicit callback
contexts and arithmetic; it does not qualify complete phase/episode parity.
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
    chunks = ['Card={};G={}']
    with zipfile.ZipFile(args.install / 'Balatro.exe') as archive:
        for name, signatures in {
            'card.lua': ['function Card:calculate_joker(', 'function Card:get_id(', 'function Card:is_face(',
                         'function Card:is_suit(', 'function Card:get_chip_mult(', 'function Card:get_p_dollars('],
            'functions/misc_functions.lua': ['function find_joker('],
        }.items():
            raw = archive.read(name)
            print(f'source {name} sha256={hashlib.sha256(raw).hexdigest()}', flush=True)
            chunks.extend(function_source(raw.decode(), signature) for signature in signatures)
    chunks.append(Path(__file__).with_suffix('.lua').read_text(encoding='utf-8'))
    spec = importlib.util.spec_from_file_location('lua_tests', ROOT / 'tests/run_lua_tests.py')
    module = importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    runtime = module.LuaLibrary(args.install / 'lua51.dll')
    with tempfile.TemporaryDirectory(prefix='advisor-score-bound-parity-') as directory:
        fixture = Path(directory) / 'parity.lua'
        fixture.write_text('\n'.join(chunks), encoding='utf-8')
        return 0 if runtime.run(fixture) else 1


if __name__ == '__main__':
    raise SystemExit(main())
