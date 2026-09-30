STRATEGY419_PATH='tools/advisor_eval/runs/repair418_candidate2/policy/Brainstorm/Advisor/strategy.lua'
local ok,why=pcall(dofile,'tests/advisor_shop_alignment419.lua')
assert(not ok and tostring(why):find('initial cheap stock bought at ante',1,true),'baseline must reproduce initial-stock rejection')
STRATEGY419_PATH=nil
GROWTH419_PATH='tools/advisor_eval/runs/repair418_candidate2/policy/Brainstorm/Advisor/growth.lua'
ok,why=pcall(dofile,'tests/advisor_retained_hiker419.lua')
assert(not ok and tostring(why):find('canonical Hiker/Stencil row',1,true),'baseline must reproduce additive-row exclusion')
print('Exact418 baseline independently fails both newly manufactured mechanism families as expected')
