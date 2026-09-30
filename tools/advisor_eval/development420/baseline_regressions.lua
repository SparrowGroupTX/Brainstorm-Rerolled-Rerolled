STRATEGY420_PATH='tools/advisor_eval/runs/repair419_candidate3/policy/Brainstorm/Advisor/strategy.lua'
local ok,why=pcall(dofile,'tests/advisor_death_progression420.lua')
assert(not ok and tostring(why):find('visible Death is acquired',1,true),'exact419 must reproduce missed useful Death acquisition')
STRATEGY420_PATH=nil
GROWTH420_PATH='tools/advisor_eval/runs/repair419_candidate3/policy/Brainstorm/Advisor/growth.lua'
ok,why=pcall(dofile,'tests/advisor_death_discard420.lua')
assert(not ok and tostring(why):find('canonical Seltzer row',1,true),'exact419 must reproduce Seltzer discard exclusion')
print('Exact419 independently fails both newly manufactured mechanism controls')
