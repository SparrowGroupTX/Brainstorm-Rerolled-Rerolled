local old,open=dofile,io.open
local map={
['Brainstorm/Advisor/gold_tarot_hold.lua']='tools/advisor_eval/development346/constructor_component/Brainstorm/Advisor/gold_tarot_hold.lua',
['Brainstorm/Advisor/perkeo_inventory.lua']='tools/advisor_eval/development346/constructor_component/Brainstorm/Advisor/perkeo_inventory.lua',
}
dofile=function(p)return old(map[p]or p)end
io.open=function(p,...)return open(map[p]or p,...)end
dofile('tests/advisor_gold_cartomancer.lua')
