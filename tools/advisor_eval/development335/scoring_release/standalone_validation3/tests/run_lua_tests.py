#!/usr/bin/env python3
"""Run standalone advisor Lua fixtures without requiring Python dependencies.

From the repository root: python tests/run_lua_tests.py
Or select fixtures: python tests/run_lua_tests.py tests/advisor_engine.lua

Uses LuaJIT/Lua from PATH, or Balatro's Lua 5.1 library on Windows. Override
the runtime with --lua or --lua-library. Every fixture gets a fresh Lua state
and runs with the repository root as its working directory.
"""

from __future__ import annotations

import argparse
import ctypes
import glob
import os
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parent.parent
BALATRO_DLL = Path(
    "C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll"
)


class LuaLibrary:
    """The small, portable Lua 5.1 C API subset needed to run a fixture."""

    def __init__(self, path: Path):
        self.library = ctypes.CDLL(str(path.resolve()))
        self.library.luaL_newstate.argtypes = []
        self.library.luaL_newstate.restype = ctypes.c_void_p
        self.library.luaL_openlibs.argtypes = [ctypes.c_void_p]
        self.library.luaL_openlibs.restype = None
        self.library.luaL_loadfile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
        self.library.luaL_loadfile.restype = ctypes.c_int
        self.library.lua_pcall.argtypes = [
            ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int
        ]
        self.library.lua_pcall.restype = ctypes.c_int
        self.library.lua_tolstring.argtypes = [
            ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)
        ]
        self.library.lua_tolstring.restype = ctypes.c_void_p
        self.library.lua_close.argtypes = [ctypes.c_void_p]
        self.library.lua_close.restype = None

    def run(self, path: Path) -> bool:
        state = self.library.luaL_newstate()
        if not state:
            raise RuntimeError("Lua could not allocate a state")
        try:
            self.library.luaL_openlibs(state)
            # Lua 5.1 uses the platform C runtime to open filenames.
            encoding = "mbcs" if sys.platform == "win32" else "utf-8"
            status = self.library.luaL_loadfile(
                state, str(path).encode(encoding)
            )
            if status == 0:
                status = self.library.lua_pcall(state, 0, 0, 0)
            if status != 0:
                length = ctypes.c_size_t()
                error = self.library.lua_tolstring(state, -1, ctypes.byref(length))
                message = (
                    ctypes.string_at(error, length.value).decode("utf-8", "replace")
                    if error else "Lua raised a non-string error"
                )
                print(message, file=sys.stderr, flush=True)
            return status == 0
        finally:
            self.library.lua_close(state)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("fixtures", nargs="*", help="Lua paths or glob patterns")
    runtimes = parser.add_mutually_exclusive_group()
    runtimes.add_argument("--lua", help="Lua/LuaJIT executable")
    runtimes.add_argument("--lua-library", type=Path, help="Lua 5.1 shared library")
    args = parser.parse_args()

    os.chdir(ROOT)
    fixtures: list[Path] = []
    for pattern in args.fixtures or ["tests/advisor_*.lua"]:
        matches = sorted(Path(match).resolve() for match in glob.glob(pattern))
        matches = [match for match in matches if match.is_file()]
        if not matches:
            parser.error(f"No fixtures match {pattern!r}")
        fixtures.extend(match for match in matches if match not in fixtures)

    executable = args.lua
    library_path = args.lua_library
    if not executable and not library_path:
        executable = shutil.which("luajit") or shutil.which("lua")
        if not executable and sys.platform == "win32" and BALATRO_DLL.is_file():
            library_path = BALATRO_DLL
    if not executable and not library_path:
        parser.error("Install Lua/LuaJIT or specify --lua-library with a Lua 5.1 library")

    try:
        library = LuaLibrary(library_path) if library_path else None
    except (OSError, AttributeError) as error:
        parser.error(
            f"Cannot load Lua 5.1 library {library_path}: {error}. "
            "Python and the library must have matching 32/64-bit architecture."
        )

    print(f"Lua runtime: {library_path or executable}", flush=True)
    failed = 0
    for fixture in fixtures:
        label = fixture.relative_to(ROOT) if fixture.is_relative_to(ROOT) else fixture
        print(f"Running {label}", flush=True)
        try:
            passed = (
                library.run(fixture) if library else
                subprocess.run([executable, str(fixture)], cwd=ROOT).returncode == 0
            )
        except (OSError, RuntimeError) as error:
            print(str(error), file=sys.stderr, flush=True)
            passed = False
        print(f"{'PASS' if passed else 'FAIL'} {label}", flush=True)
        failed += not passed
    print(f"{len(fixtures) - failed}/{len(fixtures)} fixtures passed", flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
