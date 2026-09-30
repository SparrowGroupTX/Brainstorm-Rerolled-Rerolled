local original=io.open
io.open=function(path,...)
  if path=='Brainstorm/Advisor/gold_tarot_hold.lua' then path='tools/advisor_eval/development345/row_component/Brainstorm/Advisor/gold_tarot_hold.lua' end
  return original(path,...)
end
dofile('tools/advisor_eval/development345/cartomancer_component/tests/advisor_gold_cartomancer.lua')
