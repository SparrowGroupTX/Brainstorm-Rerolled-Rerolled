local original=dofile
dofile=function(path)
  if path=='Brainstorm/Advisor/snapshot.lua' then return original('tools/advisor_eval/development323/snapshot_idle/snapshot.lua') end
  return original(path)
end
dofile('tests/advisor_snapshot.lua')
dofile('tests/advisor_gold_stickers.lua')
return dofile('tests/advisor_perkeo_inventory.lua')
