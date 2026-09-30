-- Pure manufactured tests against the detached candidate, without editing runtime files.
local original=dofile
function dofile(path)
  if path=='Brainstorm/Advisor/growth.lua' then
    return original('tools/advisor_eval/development300/growth318/growth.lua')
  end
  return original(path)
end
original('tools/advisor_eval/development300/growth318/advisor_growth_additive.lua')
