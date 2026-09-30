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
from concurrent.futures import ThreadPoolExecutor
import ctypes
import glob
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parent.parent
BALATRO_DLL = Path(
    "C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll"
)
PARALLEL_SECONDS = 55


def fixture_batches(fixtures: list[Path], workers: int) -> list[list[Path]]:
    """Deterministic disjoint partition; no discovery or omission in children."""
    if workers not in (1, 2) or not fixtures or len(set(fixtures)) != len(fixtures):
        raise ValueError('Expected unique fixtures and one or two workers')
    return [fixtures[i::workers] for i in range(min(workers, len(fixtures)))]


def run_parallel(fixtures: list[Path], library_path: Path) -> int:
    """DLL-only child processes cannot leave an external Lua grandchild behind."""
    batches = fixture_batches(fixtures, 2)
    deadline = time.monotonic() + PARALLEL_SECONDS

    def child(batch):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return 0, False, 'Worker not started: shared deadline expired.\n'
        command = [sys.executable, '-B', str(Path(__file__).resolve()),
                   '--workers', '1', '--lua-library', str(library_path),
                   *[str(path) for path in batch]]
        try:
            result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                    timeout=remaining,
                                    creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        except subprocess.TimeoutExpired as error:
            # subprocess.run kills and reaps this child before raising.
            def decoded(value):
                return value.decode('utf-8', 'replace') if isinstance(value, bytes) else value or ''
            return 0, False, decoded(error.stdout)+decoded(error.stderr)+'\nWorker timed out at shared55-second deadline.\n'
        except OSError as error:
            return 0, False, str(error)+'\n'
        summaries = re.findall(r'^(\d+)/(\d+) fixtures passed\r?$', result.stdout, re.MULTILINE)
        valid = (len(summaries) == 1 and int(summaries[0][1]) == len(batch)
                 and 0 <= int(summaries[0][0]) <= len(batch))
        passed = int(summaries[0][0]) if valid else 0
        okay = valid and result.returncode == 0 and passed == len(batch)
        # Keep a single aggregate summary so existing gate parsers cannot mistake
        # one worker's success for success of the whole suite.
        output = re.sub(r'^\d+/\d+ fixtures passed\r?\n?', '', result.stdout, flags=re.MULTILINE)
        return passed, okay, output+result.stderr

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(child, batches))
    for i, (passed, okay, output) in enumerate(results, 1):
        print(f'Fixture worker {i}: {"passed" if okay else "failed"}', flush=True)
        print(output, end='' if output.endswith('\n') else '\n', flush=True)
    total = sum(row[0] for row in results)
    okay = all(row[1] for row in results) and total == len(fixtures)
    print(f'{total}/{len(fixtures)} fixtures passed', flush=True)
    return 0 if okay else 1


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
    parser.add_argument('--workers', type=int, choices=(1, 2), default=1,
                        help='Two isolated DLL workers share a55-second deadline; serial remains the default.')
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
    if args.workers == 2:
        if executable or not library_path:
            parser.error('Parallel fixtures require an explicit or discovered Lua library')
        return run_parallel(fixtures, library_path)

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
