GROWTH420_PATH='tools/advisor_eval/runs/repair420_candidate3/policy/Brainstorm/Advisor/growth.lua'
local ok,why=pcall(dofile,'tests/advisor_burnt_setup420.lua')
assert(not ok and tostring(why):find('one supported spare play',1,true),tostring(why))
GROWTH420_PATH=nil
PHASE420_PATH='tools/advisor_eval/runs/repair420_candidate3/policy/Brainstorm/Advisor/phase_copy.lua'
ok,why=pcall(dofile,'tests/advisor_burnt_setup420.lua')
assert(not ok and tostring(why):find('arrangement-time heuristic',1,true),tostring(why))
print('Exact candidate3 rejects both new manufactured Burnt behaviors')
