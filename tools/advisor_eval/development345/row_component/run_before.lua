local original=dofile
dofile=function(path)
  if path=='Brainstorm/Advisor/gold_tarot_hold.lua' then path='Brainstorm/Advisor/gold_tarot_hold.lua' end
  return original(path)
end
dofile('tools/advisor_eval/development345/row_component/tests/advisor_gold_tarot_rows.lua')
