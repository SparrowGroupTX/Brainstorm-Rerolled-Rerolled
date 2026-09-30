-- Existing pure fixtures, with only the Growth module directed to the candidate.
local original=dofile
function dofile(path)
  if path=='Brainstorm/Advisor/growth.lua' then
    return original('tools/advisor_eval/development300/growth318/growth.lua')
  end
  return original(path)
end
for _,name in ipairs({'advisor_growth','advisor_growth_opportunities','advisor_growth_retained_steel',
  'advisor_weighted_growth','advisor_burnt_population','advisor_burnt_fallback'}) do
  original('tests/'..name..'.lua')
end
