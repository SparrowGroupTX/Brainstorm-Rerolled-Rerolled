local original=dofile
local before='tools/advisor_eval/development343/objective_component/before/'
dofile=function(path)
 if path=='Brainstorm/Advisor/gold_goal.lua' or path=='Brainstorm/Advisor/perkeo_inventory.lua' then return original(before..path) end
 return original(path)
end
original('tests/advisor_perkeo_inventory.lua')
