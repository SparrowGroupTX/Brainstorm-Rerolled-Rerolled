#!/usr/bin/env python3
"""Bounded discard parity using unmodified functions read from Balatro's ZIP.

Runs only Lua through lua51.dll. No game executable, windows, saves or RNG-based
episode campaign. Display, event scheduling and card-area movement are explicit
test doubles; callback routing, poker classification, level arithmetic and the
discard action/counters/cost execute installed source unchanged.
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
    following = re.search(r"\n(?:function |G\.FUNCS\.\w+\s*=\s*function)", source[start + len(signature):])
    assert following, f"Missing next function after {signature}"
    return source[start:start + len(signature) + following.start()]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install", type=Path, default=Path("C:/Program Files (x86)/Steam/steamapps/common/Balatro"))
    args = parser.parse_args()
    names = {
        "card.lua": ["function Card:calculate_joker(", "function Card:get_id(", "function Card:get_nominal(", "function Card:is_face(", "function Card:is_suit("],
        "functions/common_events.lua": ["function level_up_hand("],
        "functions/misc_functions.lua": ["function find_joker(", "function evaluate_poker_hand(", "function get_flush(", "function get_straight(", "function get_X_same(", "function get_highest("],
        "functions/state_events.lua": ["G.FUNCS.get_poker_hand_info = function(", "G.FUNCS.discard_cards_from_highlighted = function("],
    }
    chunks = ["Card={}; G={FUNCS={}}"]
    with zipfile.ZipFile(args.install / "Balatro.exe") as archive:
        for name, signatures in names.items():
            raw = archive.read(name)
            print(f"source {name} sha256={hashlib.sha256(raw).hexdigest()}", flush=True)
            source = raw.decode()
            chunks.extend(function_source(source, signature) for signature in signatures)
    chunks.append((Path(__file__).with_suffix(".lua")).read_text(encoding="utf-8"))
    spec = importlib.util.spec_from_file_location("lua_tests", ROOT / "tests/run_lua_tests.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    runtime = module.LuaLibrary(args.install / "lua51.dll")
    with tempfile.TemporaryDirectory(prefix="advisor-discard-parity-") as directory:
        fixture = Path(directory) / "parity.lua"
        fixture.write_text("\n".join(chunks), encoding="utf-8")
        return 0 if runtime.run(fixture) else 1


if __name__ == "__main__":
    raise SystemExit(main())
