"""Create standalone synthetic stage tests; no source/native execution."""
from pathlib import Path

HERE = Path(__file__).resolve().parent
prefix = (HERE/'tests/advisor_collection_product.lua').read_text(encoding='utf-8')
prefix = prefix[:prefix.index('do\n  for _,index in ipairs')]
prefix = prefix.replace('input=0,events={}}', 'input=0,events={},now=0,calls={}}', 1)
prefix = prefix.replace('      e.searches=e.searches+1;', '      e.calls[#e.calls+1]=copy(q)\n      e.searches=e.searches+1;', 1)
prefix = prefix.replace('    pending=function()return e.pending end,', '    now=function()return e.now end,pending=function()return e.pending end,', 1)
target = HERE/'tests/advisor_burnt_fallback.lua'
with target.open('x', encoding='utf-8', newline='\n') as stream:
    stream.write(prefix+(HERE/'fallback_cases.lua').read_text(encoding='utf-8'))
    stream.write("\nprint('advisor_burnt_fallback: '..checks..' checks passed')\n")
print(target)
