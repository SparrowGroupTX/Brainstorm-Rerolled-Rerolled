local original=dofile
dofile=function(path)
  if path=='Brainstorm/Advisor/blind_routing.lua' then
    return original('tools/advisor_eval/development322/bell_routing/blind_routing.lua')
  end
  return original(path)
end
return dofile('tests/advisor_blind_routing.lua')
