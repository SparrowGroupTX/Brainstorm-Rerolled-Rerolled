"""Manufactured Lua stdout ordering across the native/Python boundary."""
from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[3]
RUNNER = ROOT / "tests/run_lua_tests.py"
LUA51 = Path("C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll")


@unittest.skipUnless(LUA51.is_file(), "Lua 5.1 DLL is unavailable")
class RunnerCaptureTests(unittest.TestCase):
    def run_case(self, source: str) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory(prefix="advisor_runner_457_") as folder:
            fixture = Path(folder) / "manufactured.lua"
            fixture.write_text(source, encoding="utf-8")
            return subprocess.run(
                [sys.executable, "-B", str(RUNNER), "--lua-library",
                 str(LUA51), str(fixture)], cwd=ROOT, capture_output=True,
                text=True, timeout=15,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            )

    def test_large_success_record_precedes_python_status(self):
        result = self.run_case('print("BEGIN" .. string.rep("x", 12000) .. "END")\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count("BEGIN"), 1)
        self.assertEqual(result.stdout.count("END"), 1)
        self.assertLess(result.stdout.index("END"), result.stdout.index("PASS "))
        self.assertLess(result.stdout.index("PASS "),
                        result.stdout.index("1/1 fixtures passed"))

    def test_large_error_record_precedes_python_failure_status(self):
        result = self.run_case(
            'print("BEGIN_ERROR" .. string.rep("y", 12000) .. "END_ERROR")\n'
            'error("manufactured failure")\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn("manufactured failure", result.stderr)
        self.assertEqual(result.stdout.count("BEGIN_ERROR"), 1)
        self.assertEqual(result.stdout.count("END_ERROR"), 1)
        self.assertLess(result.stdout.index("END_ERROR"), result.stdout.index("FAIL "))
        self.assertLess(result.stdout.index("FAIL "),
                        result.stdout.index("0/1 fixtures passed"))


if __name__ == "__main__":
    unittest.main()
