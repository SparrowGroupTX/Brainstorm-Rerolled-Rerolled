local original_dofile=dofile
dofile=function(path)
 if path=='Brainstorm/Advisor/search.lua' then path='tools/advisor_eval/development328/pillar_component/search.lua' end
 return original_dofile(path)
end
original_dofile('tools/advisor_eval/development328/pillar_component/advisor_discard_search.lua')
original_dofile('tests/advisor_resource_decisions.lua')
original_dofile('tests/advisor_resource_guard.lua')
original_dofile('tests/advisor_discard_state.lua')
