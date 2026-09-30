local old=dofile
dofile=function(p)if p=='Brainstorm/Advisor/gold_retention.lua'then p='tools/advisor_eval/development345/retention_component/Brainstorm/Advisor/gold_retention.lua'end;return old(p)end
dofile('tools/advisor_eval/development345/retention_component/tests/advisor_gold_retention.lua')
