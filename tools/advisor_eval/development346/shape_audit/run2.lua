local old=dofile
dofile=function(p) if p=='Brainstorm/Advisor/gold_tarot_hold.lua' then p='tools/advisor_eval/development346/constructor_component/Brainstorm/Advisor/gold_tarot_hold.lua' end;return old(p)end
dofile('tools/advisor_eval/development346/shape_audit/tests/advisor_gold_tarot_lifecycle_shape.lua')
