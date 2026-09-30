local original=dofile
function dofile(path)
 if path=='Brainstorm/Advisor/strategy.lua' then
  return original('tools/advisor_eval/development328/replacement_evidence_component/strategy.lua')
 end
 return original(path)
end
original('tests/advisor_shop_sequences.lua')
