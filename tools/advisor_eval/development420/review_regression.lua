CONSUMABLES420_PATH='tools/advisor_eval/runs/repair420_candidate2/policy/Brainstorm/Advisor/consumables.lua'
local ok,why=pcall(dofile,'tests/advisor_death_discard420.lua')
assert(not ok and tostring(why):find('previously held Gold or Blue',1,true),tostring(why))
print('Exact candidate2 fails the held Gold/Blue compact-anchor control')
