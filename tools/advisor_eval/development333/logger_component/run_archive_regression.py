"""Existing archive roundtrip/failure tests with only detached journal substituted."""
from pathlib import Path
import importlib.util
import unittest

ROOT = Path(__file__).resolve().parents[4]
spec = importlib.util.spec_from_file_location('existing_archive', ROOT / 'tests/test_advisor_player_log_archive.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.SETUP = module.SETUP.replace(
    b"J=dofile('Brainstorm/Advisor/player_journal.lua')",
    b"J=dofile('tools/advisor_eval/development333/logger_component/player_journal.lua')")
result = unittest.TextTestRunner(verbosity=1).run(unittest.defaultTestLoader.loadTestsFromModule(module))
raise SystemExit(0 if result.wasSuccessful() else 1)
