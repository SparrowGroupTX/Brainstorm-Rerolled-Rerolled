"""Create integration-ready test copies only; never execute game source."""
from pathlib import Path
import ast

h = Path(__file__).resolve().parent
root = h.parents[4]
t = (h / 'test_archive.py').read_text(encoding='utf-8')
helper = (h.parent / 'shop_order/lua_bytes.py').read_text(encoding='utf-8')
t = t.replace('ROOT = HERE.parents[4]', 'ROOT = HERE.parent')
t = t.replace("Reader = load('archive_reader_tested', HERE / 'read_player_log.py')",
              "Reader = load('archive_reader_tested', ROOT / 'tools/advisor_eval/read_player_log.py')")
t = t.replace("LuaBytes = load('archive_lua_bytes', HERE.parent / 'shop_order/lua_bytes.py')",
              helper + '\nclass LuaBytes:\n    lua_value = staticmethod(lua_value)\n')
t = t.replace('tools/advisor_eval/development299/drafts/journal_v2/player_log_archive.lua', 'Brainstorm/Advisor/player_log_archive.lua')
t = t.replace('tools/advisor_eval/development299/drafts/journal_v2/player_journal.lua', 'Brainstorm/Advisor/player_journal.lua')
ast.parse(t)
with (h / 'test_player_log_archive.py').open('x', encoding='utf-8', newline='\n') as out:
    out.write(t)
old = (root / 'tests/advisor_player_journal.lua').read_text(encoding='utf-8')
old = old.replace("dofile('Brainstorm/Advisor/player_journal.lua')",
                  "dofile('tools/advisor_eval/development299/drafts/journal_v2/player_journal.lua')")
with (h / 'legacy_journal_fixture.lua').open('x', encoding='utf-8', newline='\n') as out:
    out.write(old)
