local original=dofile
function dofile(path)
  if path=='Brainstorm/Advisor/growth.lua' then return original('tools/advisor_eval/development354/burnt_inert_component/before/growth.lua') end
  return original(path)
end
return dofile('tools/advisor_eval/development354/burnt_inert_component/tests/advisor_burnt_pair_inert.lua')
