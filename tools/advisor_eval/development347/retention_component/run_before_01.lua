local paths={["Brainstorm/Advisor/gold_retention.lua"]="tools/advisor_eval/development347/retention_component/before/Brainstorm/Advisor/gold_retention.lua",["Brainstorm/Advisor/gold_order.lua"]="tools/advisor_eval/development347/order_component/Brainstorm/Advisor/gold_order.lua",["Brainstorm/Advisor/shop_scoring.lua"]="tools/advisor_eval/development347/preflight_component/Brainstorm/Advisor/shop_scoring.lua"}
local old=dofile;dofile=function(p)return old(paths[p] or p)end
local opened=io.open;io.open=function(p,...)return opened(paths[p] or p,...)end
dofile('tools/advisor_eval/development347/retention_component/tests/advisor_gold_retention_order.lua')
