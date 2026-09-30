local original=dofile
function dofile(path)
  if path=='Brainstorm/Advisor/phase_copy.lua' then return original('tools/advisor_eval/development353/burnt_margin_component/Brainstorm/Advisor/phase_copy.lua') end
  if path=='Brainstorm/Advisor/growth.lua' then return original('tools/advisor_eval/development350/yorick_component/Brainstorm/Advisor/growth.lua') end
  return original(path)
end
return dofile('tools/advisor_eval/development353/burnt_margin_component/tests/advisor_burnt_margin.lua')
