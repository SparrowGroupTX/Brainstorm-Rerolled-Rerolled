local original=dofile
dofile=function(path) if path=='Brainstorm/Advisor/strategy.lua' then return original('tools/advisor_eval/development328/scaling_component/strategy_candidate.lua') end;return original(path)end
original('tests/advisor_shop_decisions.lua')
