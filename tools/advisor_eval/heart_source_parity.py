#!/usr/bin/env python3
"""Bounded original-source Crimson Heart resource transition parity; DLL only, no game process.

The original consumable/Joker callback functions run with presentation and area
movement test doubles. This validates selected mutations, not episode fidelity.
"""
from pathlib import Path
import hashlib
import importlib.util
import tempfile
import zipfile
from discard_source_parity import function_source

ROOT = Path(__file__).resolve().parents[2]
INSTALL = Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro')

def main():
    chunks = ['Card={}; Blind={}; G={FUNCS={}}']
    with zipfile.ZipFile(INSTALL / 'Balatro.exe') as archive:
        for filename, signatures in {
            'card.lua': ['function Card:set_debuff(', 'function Card:add_to_deck(', 'function Card:remove_from_deck('],
            'blind.lua': ['function Blind:drawn_to_hand('],
        }.items():
            raw=archive.read(filename)
            print(f'source {filename} sha256={hashlib.sha256(raw).hexdigest()}', flush=True)
            chunks.extend(function_source(raw.decode(), signature) for signature in signatures)
    chunks.append(Path(__file__).with_suffix('.lua').read_text(encoding='utf-8'))
    spec=importlib.util.spec_from_file_location('lua_tests', ROOT / 'tests/run_lua_tests.py')
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    runtime=module.LuaLibrary(INSTALL / 'lua51.dll')
    with tempfile.TemporaryDirectory(prefix='advisor-heart-parity-') as directory:
        path=Path(directory)/'parity.lua'
        path.write_text('\n'.join(chunks), encoding='utf-8')
        return 0 if runtime.run(path) else 1

if __name__=='__main__':
    raise SystemExit(main())
