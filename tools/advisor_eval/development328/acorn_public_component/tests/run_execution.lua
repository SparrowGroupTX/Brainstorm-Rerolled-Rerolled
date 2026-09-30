local original=dofile
dofile=function(path)
  if path=='Brainstorm/Advisor/execution.lua'then
    return original('tools/advisor_eval/development328/acorn_public_component/Brainstorm/Advisor/execution.lua')
  end
  return original(path)
end
dofile('tests/advisor_execution.lua')
