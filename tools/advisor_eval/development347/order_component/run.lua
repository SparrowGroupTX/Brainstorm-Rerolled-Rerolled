local old=dofile
dofile=function(path)
 if path=='Brainstorm/Advisor/gold_order.lua'then path='tools/advisor_eval/development347/order_component/Brainstorm/Advisor/gold_order.lua'end
 return old(path)
end
dofile('tools/advisor_eval/development347/order_component/tests/advisor_gold_order.lua')
