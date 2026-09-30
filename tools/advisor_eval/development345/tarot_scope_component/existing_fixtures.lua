local open,dof=io.open,dofile
local path='tools/advisor_eval/development345/tarot_scope_component/Brainstorm/Advisor/gold_tarot_hold.lua'
io.open=function(p,...) return open(p=='Brainstorm/Advisor/gold_tarot_hold.lua' and path or p,...) end
dofile=function(p) return dof(p=='Brainstorm/Advisor/gold_tarot_hold.lua' and path or p) end
dofile('tests/advisor_gold_tarot_hold.lua')
dofile('tools/advisor_eval/development345/pin_component/tests/advisor_gold_tarot_hold_pin.lua')
dofile('tools/advisor_eval/development345/pin_component/tests/advisor_gold_acquisition_runtime.lua')
