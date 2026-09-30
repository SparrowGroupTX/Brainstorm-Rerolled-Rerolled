local original=dofile
dofile=function(path)
  if path=='Brainstorm/Advisor/blind_routing.lua' then
    return original('tools/advisor_eval/development322/bell_routing/blind_routing.lua')
  end
  return original(path)
end
return dofile('tools/advisor_eval/development322/bell_routing/test_advisor_bell_routing.lua')
