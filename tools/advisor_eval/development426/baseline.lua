local original=dofile
function dofile(path)
 if path=='Brainstorm/Advisor/strategy.lua' or path=='Brainstorm/Advisor/joker_retirement.lua' then
  return original('tools/advisor_eval/runs/repair425_installed/policy/'..path)
 end
 return original(path)
end
SOUL_BASELINE426=true
dofile('tests/advisor_soul_vacancy426.lua')
