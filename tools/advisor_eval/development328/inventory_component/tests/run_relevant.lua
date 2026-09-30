local original=dofile
dofile=function(path)
  if path=='Brainstorm/Advisor/strategy.lua' then path='tools/advisor_eval/development328/inventory_component/Brainstorm/Advisor/strategy.lua' end
  return original(path)
end
for _,path in ipairs({
  'tests/advisor_strategy.lua',
  'tests/advisor_perkeo_timing.lua',
  'tests/advisor_perkeo_inventory.lua',
  'tests/advisor_shop_sequences.lua',
  'tests/advisor_shop_order.lua',
  'tests/advisor_owned_fool_shop.lua',
  'tests/advisor_shop_planet_ties.lua',
  'tests/advisor_catalog_replacements.lua'
}) do original(path) end
dofile=original
