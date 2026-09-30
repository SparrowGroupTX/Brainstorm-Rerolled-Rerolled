local real=dofile
dofile=function(path)
  if path=='Brainstorm/Advisor/growth.lua' then return real('tools/advisor_eval/development300/yorick_pair321/growth.lua') end
  return real(path)
end
dofile('tools/advisor_eval/development300/yorick_pair321/test_advisor_yorick_pair.lua')
