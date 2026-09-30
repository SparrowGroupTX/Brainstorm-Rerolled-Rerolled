#!/usr/bin/env python3
"""Bounded source-generation parity, with no game executable/window/save access.

Runs original Lua from the installed executable ZIP inside its LuaJIT DLL. Uses
the existing read-only adapter to initialize each real challenge, then generates
one fixture opening and uses its two Soul cards. This is not a win-rate test.
"""
from __future__ import annotations
import argparse
import ctypes
import hashlib
import json
import os
import shutil
from pathlib import Path
import struct
import time
import zipfile

ROOT = Path(__file__).resolve().parents[2]
IDS = ["omelette", "city", "rich", "knife", "xray", "mad_world", "luxury",
       "non_perishable", "medusa", "double_nothing", "typecast", "inflation",
       "bram_poker", "fragile", "monolith", "blast_off", "five_card", "golden_needle", "cruelty"]

def literal(data: bytes) -> bytes:
    separator = b"="
    while b"]" + separator + b"]" in data:
        separator += b"="
    return b"[" + separator + b"[" + data + b"]" + separator + b"]"

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install", type=Path, default=Path("C:/Program Files (x86)/Steam/steamapps/common/Balatro"))
    parser.add_argument("--native", type=Path, default=ROOT / "Immolate/build-v2.16-challenge-portable/Immolate.dll")
    args = parser.parse_args()
    started = time.perf_counter()
    with zipfile.ZipFile(args.install / "Balatro.exe") as archive:
        sources = {name: archive.read(name) for name in archive.namelist() if name.endswith(".lua")}
        dimensions = {}
        for name in archive.namelist():
            if name.endswith(".png"):
                with archive.open(name) as image:
                    header = image.read(24)
                if header[:8] == b"\x89PNG\r\n\x1a\n":
                    dimensions[name] = struct.unpack(">II", header[16:24])
    core = (ROOT / "Brainstorm/Core/Brainstorm.lua").read_bytes()
    hook = core[core.index(b"function Brainstorm.createCharmArcanaCard("):core.index(b"function Brainstorm.init()")]
    bootstrap = (ROOT / "tools/advisor_eval/engine_probe.lua").read_bytes()
    payload = Path(__file__).with_suffix(".lua").read_bytes()
    opening_module = (ROOT / "Brainstorm/Core/challenge_opening.lua").read_bytes()
    base = [b"PROBE_PNG={}"]
    for name, (width, height) in dimensions.items():
        base.append(b"PROBE_PNG[ " + literal(name.encode()) + b" ]={" + str(width).encode() + b"," + str(height).encode() + b"}")
    for name, source in sources.items():
        base.append(b"package.preload[ " + literal(name[:-4].encode()) + b" ]=assert(loadstring(" + literal(source) + b"," + literal(b"@installed/" + name.encode()) + b"))")
    base += [b"package.preload.probe_challenge_opening=assert(loadstring(" + literal(opening_module) + b",'@current_challenge_opening.lua'))",
             b"PROBE_CHARM_HOOK=" + literal(hook), b"PROBE_SEED='I1L21111'", b"PROBE_EPISODE=" + literal(payload)]
    os.environ["BRAINSTORM_THREADS"] = "1"
    os.environ["BRAINSTORM_SEARCH_LIMIT"] = "1"
    dll_directories = []
    if os.name == "nt":
        dll_directories.append(os.add_dll_directory(str(args.native.resolve().parent)))
        compiler = shutil.which("g++")
        if compiler:
            dll_directories.append(os.add_dll_directory(str(Path(compiler).resolve().parent)))
    native = ctypes.CDLL(str(args.native.resolve()))
    native.brainstorm_challenge_opening_v1.argtypes = [ctypes.c_char_p] * 3
    native.brainstorm_challenge_opening_v1.restype = ctypes.c_void_p
    native.free_result.argtypes = [ctypes.c_void_p]
    lua = ctypes.CDLL(str((args.install / "lua51.dll").resolve()))
    lua.luaL_newstate.restype = ctypes.c_void_p
    lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
    lua.luaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
    lua.luaL_loadbuffer.restype = ctypes.c_int
    lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    lua.lua_pcall.restype = ctypes.c_int
    lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
    lua.lua_tolstring.restype = ctypes.c_void_p
    lua.lua_close.argtypes = [ctypes.c_void_p]
    print(json.dumps({"type": "source_challenge_opening_provenance", "seed": "I1L21111",
                      "scope": "generation_only_not_win_rate", "hook_sha256": hashlib.sha256(hook).hexdigest(),
                      "bootstrap_sha256": hashlib.sha256(bootstrap).hexdigest(),
                      "opening_module_sha256": hashlib.sha256(opening_module).hexdigest(),
                      "native_sha256": hashlib.sha256(args.native.read_bytes()).hexdigest(),
                      "source_sha256": {name: hashlib.sha256(sources[name]).hexdigest() for name in
                         ("game.lua", "card.lua", "challenges.lua", "functions/common_events.lua", "functions/misc_functions.lua")}}), flush=True)
    cases = [("c_" + name + "_1", True) for name in IDS] + [("c_jokerless_1", True), ("c_omelette_1", False)]
    for challenge, exception in cases:
        raw = native.brainstorm_challenge_opening_v1(b"I1L21111", challenge.encode(), b"")
        assert raw, "Native allocation failed"
        result = json.loads(ctypes.string_at(raw)); native.free_result(raw)
        if challenge == "c_jokerless_1":
            assert result["status"] == "invalid"
        else:
            assert result["status"] == "found" and result["seed"] == "I1L21111"
            assert result["legendary_jokers"] == ["j_yorick", "j_perkeo"]
        code = b"\n".join(base + [b"PROBE_CHALLENGE=" + literal(challenge.encode()),
                                 b"PROBE_MULTI_SOUL=" + (b"true" if exception else b"false"),
                                 b"PROBE_NATIVE_JSON=" + literal(json.dumps(result).encode()), bootstrap])
        state = lua.luaL_newstate()
        assert state, "Lua allocation failed"
        try:
            lua.luaL_openlibs(state)
            status = lua.luaL_loadbuffer(state, code, len(code), b"@source_challenge_opening_probe")
            if not status:
                status = lua.lua_pcall(state, 0, 0, 0)
            if status:
                length = ctypes.c_size_t()
                error = lua.lua_tolstring(state, -1, ctypes.byref(length))
                raise RuntimeError(challenge + ": " + ctypes.string_at(error, length.value).decode("utf8", "replace"))
        finally:
            lua.lua_close(state)
        print(json.dumps({"type": "source_challenge_opening_pass", "challenge": challenge,
                          "exception": exception, "native": result}), flush=True)
    print(json.dumps({"type": "source_challenge_opening_complete", "cases": len(cases),
                      "elapsed_seconds": round(time.perf_counter() - started, 3)}), flush=True)

if __name__ == "__main__":
    main()
