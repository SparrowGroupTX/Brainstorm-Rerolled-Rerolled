-- Existing fixture bodies, redirected only to the detached search/decision
-- changes. No source adapter, captured snapshot or game initialization.
local P='tools/advisor_eval/development299/drafts/hand_copy_preflight315/'
local original=dofile
dofile=function(path)
  local module=path:match('^Brainstorm/Advisor/(search)%.lua$') or path:match('^Brainstorm/Advisor/(decision)%.lua$')
  if module then return original(P..module..'.lua') end
  return original(path)
end
for _,name in ipairs({'advisor_decision_budget','advisor_decision_integration','advisor_search_efficiency',
  'advisor_fast_clear','advisor_fast_clear_retention','advisor_phase_copy','advisor_discard_state'}) do
  original('tests/'..name..'.lua')
end
dofile=original
print('Seven existing fixture bodies passed against detached preflight search/decision changes')
