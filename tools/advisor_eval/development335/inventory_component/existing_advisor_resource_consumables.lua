-- Existing manufactured regression, redirected only to this isolated candidate.
local original=dofile
function dofile(path)
  if path=='Brainstorm/Advisor/consumables.lua' then return original('tools/advisor_eval/development335/inventory_component/consumables.lua') end
  if path=='Brainstorm/Advisor/strategy.lua' then return original('tools/advisor_eval/development335/inventory_component/strategy.lua') end
  return original(path)
end
dofile('tests/advisor_resource_consumables.lua')
