"""Run the detached writer/reader fixtures against the existing pure Lua fixture host."""
from pathlib import Path
import sys
import types
import unittest

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
module=types.ModuleType('detached_archive_fixtures')
module.__file__=str(ROOT/'tests/test_advisor_player_log_archive.py')
source=(HERE/'files/tests/test_advisor_player_log_archive.py').read_text(encoding='utf-8')
source=source.replace("ROOT / 'tools/advisor_eval/read_player_log.py'",repr(str(HERE/'files/tools/advisor_eval/read_player_log.py')))
source=source.replace("A=dofile('Brainstorm/Advisor/player_log_archive.lua')", "A=dofile('"+str(HERE/'files/Brainstorm/Advisor/player_log_archive.lua').replace('\\','/')+"')")
exec(compile(source,module.__file__,'exec'),module.__dict__)
result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromModule(module))
sys.exit(0 if result.wasSuccessful() else 1)
