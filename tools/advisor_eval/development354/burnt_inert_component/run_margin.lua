local original=dofile
function dofile(path)
  if path=='Brainstorm/Advisor/growth.lua' then return original('tools/advisor_eval/development354/burnt_inert_component/Brainstorm/Advisor/growth.lua') end
  return original(path)
end
return dofile('tools/advisor_eval/development350/yorick_component/tests/advisor_yorick_margin.lua')
