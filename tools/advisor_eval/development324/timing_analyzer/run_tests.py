"""Load only detached analyzer/test source; fixtures create their own temp files."""
from pathlib import Path
import importlib.util
import sys
import unittest
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
sys.path.insert(0,str(ROOT))
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec)
    sys.modules[name]=module;spec.loader.exec_module(module);return module
load('tools.advisor_eval.analyze_player_timing',HERE/'analyze_player_timing.py')
tests=load('timing_analyzer_tests',HERE/'test_advisor_player_timing.py')
result=unittest.TextTestRunner(verbosity=1).run(unittest.defaultTestLoader.loadTestsFromModule(tests))
raise SystemExit(0 if result.wasSuccessful() else 1)
