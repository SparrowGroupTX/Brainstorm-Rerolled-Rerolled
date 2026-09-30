local original_open=io.open
local original_dofile=dofile
local module='tools/advisor_eval/development345/pin_component/before/Brainstorm/Advisor/gold_tarot_hold.lua'
io.open=function(path,...) if path=='Brainstorm/Advisor/gold_tarot_hold.lua' then path=module end;return original_open(path,...) end
dofile=function(path) if path=='Brainstorm/Advisor/gold_tarot_hold.lua' then path=module end;return original_dofile(path) end
dofile('tools/advisor_eval/development345/pin_component/tests/advisor_gold_tarot_hold_pin.lua')
