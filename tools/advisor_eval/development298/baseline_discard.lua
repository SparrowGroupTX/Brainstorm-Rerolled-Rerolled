-- Ordinary synthetic regression against immutable installed297 policy bytes.
local read=dofile
dofile=function(path)
  if path=='Brainstorm/Advisor/growth.lua' or path=='Brainstorm/Advisor/search.lua' or path=='Brainstorm/Advisor/strategy.lua' then
    return read('tools/advisor_eval/runs/fix297_installed/policy/'..path)
  end
  return read(path)
end
read('tests/advisor_discard_investment.lua')
