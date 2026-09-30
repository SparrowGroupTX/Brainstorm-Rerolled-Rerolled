#!/usr/bin/env python3
"""Source parity for supported skip callbacks, tags and Throwback refresh.

Balatro.exe is read as a ZIP only. Lua runs through lua51.dll with explicit
display/event doubles. No game executable/window, save or live play is touched.
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
    following = re.search(r'\n[ \t]*(?:function |G\.FUNCS\.\w+\s*=\s*function)', source[start + len(signature):])
    assert following
    return source[start:start + len(signature) + following.start()]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    args = parser.parse_args()
    chunks = ['Card={};Tag={};G={FUNCS={}}']
    with zipfile.ZipFile(args.install / 'Balatro.exe') as archive:
        source = {}
        for name in ('card.lua', 'tag.lua', 'functions/button_callbacks.lua', 'functions/UI_definitions.lua'):
            raw = archive.read(name)
            print(f'source {name} sha256={hashlib.sha256(raw).hexdigest()}', flush=True)
            source[name] = raw.decode()
        chunks.append(function_source(source['card.lua'], 'function Card:calculate_joker('))
        chunks.append(function_source(source['tag.lua'], 'function Tag:apply_to_run('))
        chunks.append(function_source(source['functions/UI_definitions.lua'], 'function add_tag('))
        chunks.append(function_source(source['functions/button_callbacks.lua'], 'G.FUNCS.skip_blind = function('))
        # This is the unchanged Card:update refresh block. Calling all of
        # Card:update would require unrelated animation/UI/world simulation.
        snippet = re.search(r"if self\.ability\.name == 'Throwback' then\s+self\.ability\.x_mult = 1 \+ G\.GAME\.skips\*self\.ability\.extra\s+end", source['card.lua'])
        assert snippet
        chunks.append('function source_refresh_throwback(self)\n' + snippet.group(0) + '\nend')
    chunks.append(Path(__file__).with_suffix('.lua').read_text(encoding='utf-8'))
    spec = importlib.util.spec_from_file_location('lua_tests', ROOT / 'tests/run_lua_tests.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    runtime = module.LuaLibrary(args.install / 'lua51.dll')
    with tempfile.TemporaryDirectory(prefix='advisor-routing-parity-') as directory:
        path = Path(directory) / 'parity.lua'
        path.write_text('\n'.join(chunks), encoding='utf-8')
        return 0 if runtime.run(path) else 1


if __name__ == '__main__':
    raise SystemExit(main())
