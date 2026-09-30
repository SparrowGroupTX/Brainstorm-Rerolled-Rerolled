"""Derive future-use adapter code; no experiment, policy execution or case reads."""
from pathlib import Path
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
source=(EVAL/'development435/adapter.lua').read_text()
source=source.replace('local M={}','local M={}\n-- Caller injects exact frozen reporting code; no filesystem or runner here.\nlocal function evidence()return assert(M.evidence,"Evidence module required")end',1)
source=source.replace(" assert(input.mode=='continuation','Unknown mode')", " assert(input.mode=='continuation','Unknown mode')\n assert(integer(input.action_cap)and input.action_cap>=1 and input.action_cap<=16,'Invalid bounded action cap')")
source=source.replace("local function stop(status,reason,complete)","local function stop(status,reason,complete,diagnostic)\n  row.unsupported=diagnostic")
source=source.replace("local floor=A.scoring.lower_bound(s,a.indices)","local diagnostic=evidence().unsupported('play',e,actual)\n    local floor=A.scoring.lower_bound(s,a.indices)")
source=source.replace("'Final transition/resources unresolved: '..tostring(e),false)","'Final transition/resources unresolved: '..diagnostic.reason,false,diagnostic)")
source=source.replace("return stop('unsupported',tostring(e),false)","return stop('unsupported',diagnostic.reason,false,diagnostic)")
source=source.replace("M.copy=copy", "-- Produce all bounded frames before a caller writes any of the result.\nfunction M.run_frames(A,input)\n return evidence().frames(M.run(A,input),A.player_journal.encode)\nend\nM.copy=copy")
with(EVAL/'continuation_adapter.lua').open('x',encoding='utf-8')as f:f.write(source)
setup=(EVAL/'development435/frozen/module_setup.lua').read_text()
with(ROOT/'tests/fixtures/modules436.lua').open('x',encoding='utf-8')as f:
 f.write("-- Standalone manufactured fixtures only.\nlocal A,cache={},{}\nlocal function module(name)\n if not cache[name]then cache[name]=dofile('Brainstorm/Advisor/'..name..'.lua')end;return cache[name]\nend\n"+setup+'\nreturn A\n')
