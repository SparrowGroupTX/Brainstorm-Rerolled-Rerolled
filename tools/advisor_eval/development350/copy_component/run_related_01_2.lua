local map={["Brainstorm/Advisor/decision.lua"]="tools/advisor_eval/development350/copy_component/Brainstorm/Advisor/decision.lua",["Brainstorm/Advisor/concealed_belief.lua"]="tools/advisor_eval/development350/copy_component/Brainstorm/Advisor/concealed_belief.lua",["Brainstorm/Advisor/phase_copy.lua"]="tools/advisor_eval/development350/copy_component/Brainstorm/Advisor/phase_copy.lua"}
local old=dofile;dofile=function(p)return old(map[p]or p)end
dofile("tests/advisor_concealed_nine_card.lua")
