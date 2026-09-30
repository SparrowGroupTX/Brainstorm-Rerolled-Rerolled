local original=dofile
dofile=function(path)
  if path=='Brainstorm/Advisor/snapshot.lua' then return original('tools/advisor_eval/development323/snapshot_idle/snapshot.lua') end
  return original(path)
end
return dofile('tools/advisor_eval/development323/snapshot_idle/test_advisor_snapshot_idle.lua')
