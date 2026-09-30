#!/usr/bin/env python3
"""Bounded playing-card boss projection parity against installed Lua source.

Reads Balatro.exe only as a ZIP and executes extracted pure functions through
lua51.dll. No game executable, windows, saves or gameplay are accessed.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
from pathlib import Path
import re
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def function_source(source: str, signature: str) -> str:
    start = source.index(signature)
    following = re.search(r"\nfunction ", source[start + len(signature):])
    assert following, signature
    return source[start:start + len(signature) + following.start()]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    args = parser.parse_args()
    names = {'blind.lua': ['function Blind:debuff_card('],
             'card.lua': ['function Card:get_id(', 'function Card:is_face(', 'function Card:is_suit(', 'function Card:set_debuff('],
             'functions/misc_functions.lua': ['function find_joker(']}
    chunks = ['Card={}; Blind={}']
    with zipfile.ZipFile(args.install / 'Balatro.exe') as archive:
        for name, signatures in names.items():
            raw = archive.read(name)
            print(f'source {name} sha256={hashlib.sha256(raw).hexdigest()}', flush=True)
            chunks.extend(function_source(raw.decode(), signature) for signature in signatures)
    chunks.append(Path(__file__).with_suffix('.lua').read_text(encoding='utf-8'))
    spec = importlib.util.spec_from_file_location('lua_tests', ROOT / 'tests/run_lua_tests.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    runtime = module.LuaLibrary(args.install / 'lua51.dll')
    with tempfile.TemporaryDirectory(prefix='advisor-boss-parity-') as directory:
        fixture = Path(directory) / 'parity.lua'
        fixture.write_text('\n'.join(chunks), encoding='utf-8')
        return 0 if runtime.run(fixture) else 1


if __name__ == '__main__':
    raise SystemExit(main())
