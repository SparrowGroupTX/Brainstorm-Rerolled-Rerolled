local original=dofile
function dofile(path)
 if path=='Brainstorm/Advisor/concealed_belief.lua' then return original('tools/advisor_eval/development328/nine_card_component/concealed_belief.lua') end
 return original(path)
end
original('tests/advisor_concealed_belief.lua')
