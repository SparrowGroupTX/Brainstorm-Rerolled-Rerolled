local old=dofile
local map={
['Brainstorm/Advisor/gold_tarot_hold.lua']='tools/advisor_eval/development346/constructor_component/Brainstorm/Advisor/gold_tarot_hold.lua',
['Brainstorm/Advisor/perkeo_inventory.lua']='tools/advisor_eval/development346/constructor_component/before/Brainstorm/Advisor/perkeo_inventory.lua'
}
dofile=function(p)return old(map[p]or p)end
dofile('tools/advisor_eval/development346/constructor_component/tests/advisor_consumable_constructor_params.lua')
