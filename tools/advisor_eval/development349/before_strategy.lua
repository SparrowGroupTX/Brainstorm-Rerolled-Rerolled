-- The new manufactured routing assertion must catch the preserved old policy.
local original=dofile
dofile=function(path)
  if path=='Brainstorm/Advisor/strategy.lua' then path='tools/advisor_eval/development349/before/Brainstorm/Advisor/strategy.lua' end
  return original(path)
end
dofile('tests/advisor_gold_slot_strategy.lua')
