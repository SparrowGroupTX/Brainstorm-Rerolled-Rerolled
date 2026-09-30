local root='tools/advisor_eval/development324/frame_hooks/'
local original_open,original_dofile=io.open,dofile
io.open=function(path,...)
  if path=='Brainstorm/Core/Brainstorm.lua' then path=root..'Brainstorm.lua' end
  return original_open(path,...)
end
dofile=function(path)
  if path=='Brainstorm/UI/advisor.lua' then path=root..'advisor.lua' end
  return original_dofile(path)
end
dofile(root..'test_advisor_frame_timing.lua')
