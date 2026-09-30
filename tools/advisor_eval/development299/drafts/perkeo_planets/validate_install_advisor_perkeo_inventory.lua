local original_dofile=dofile
local prefix='tools/advisor_eval/development299/drafts/perkeo_planets/'
dofile=function(path)
  local name=path:match('^Brainstorm/Advisor/([^/]+)%.lua$')
  if ({gold_goal=true,gold_perkeo=true,snapshot=true,decision=true,perkeo_inventory=true,gold_planet_policy=true})[name] then
    return original_dofile(prefix..name..'.lua')
  end
  return original_dofile(path)
end
original_dofile(prefix..'install_advisor_perkeo_inventory.lua')
