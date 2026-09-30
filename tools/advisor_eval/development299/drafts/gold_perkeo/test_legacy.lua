local original=dofile
dofile=function(path)
  if path=='Brainstorm/Advisor/gold_goal.lua' then
    path='tools/advisor_eval/development299/drafts/gold_perkeo/gold_goal.lua'
  end
  return original(path)
end
dofile('tests/advisor_gold_goal.lua')
