local original_dofile=dofile
local prefix='tools/advisor_eval/development299/drafts/perkeo_planets/'
dofile=function(path)
  local name=path:match('^Brainstorm/Advisor/([^/]+)%.lua$')
  if name=='gold_goal' or name=='gold_perkeo' or name=='snapshot' or name=='decision' then
    return original_dofile(prefix..name..'.lua')
  end
  return original_dofile(path)
end
original_dofile('tests/advisor_decision_budget.lua')
