local real=dofile
dofile=function(path)
  if path=='Brainstorm/Advisor/growth.lua' then return real('tools/advisor_eval/development300/yorick_pair321/growth.lua') end
  return real(path)
end
for _,path in ipairs({'advisor_growth','advisor_growth_additive','advisor_growth_retained_steel',
  'advisor_growth_opportunities','advisor_weighted_growth'}) do dofile('tests/'..path..'.lua') end
