STRATEGY420_PATH='tools/advisor_eval/runs/repair419_candidate3/policy/Brainstorm/Advisor/strategy.lua'
local ok,why=pcall(dofile,'tests/advisor_burnt_value420.lua')
assert(not ok and tostring(why):find('Polychrome Burnt outranks',1,true),tostring(why))
print('Exact419 fails the manufactured Polychrome Burnt versus Red Card choice')
