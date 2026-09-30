local original=dofile
function dofile(path)
  if path=='Brainstorm/Advisor/paid_reroll.lua' then
    return original('tools/advisor_eval/development350/reroll_component/Brainstorm/Advisor/paid_reroll.lua')
  end
  return original(path)
end
return dofile('tools/advisor_eval/development350/reroll_component/tests/advisor_gold_reroll.lua')
