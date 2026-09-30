local original=dofile
dofile=function(path)
  if path=='Brainstorm/Advisor/shop_scoring.lua' then return original('tools/advisor_eval/development347/preflight_component/Brainstorm/Advisor/shop_scoring.lua') end
  return original(path)
end
dofile('tools/advisor_eval/development347/preflight_component/tests/advisor_shop_family_preflight.lua')
