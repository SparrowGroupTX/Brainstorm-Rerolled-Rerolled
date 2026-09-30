local original_dofile=dofile
local root='tools/advisor_eval/development342/presentation_component/'
local replacements={['Brainstorm/Advisor/acorn_public.lua']=true,['Brainstorm/Advisor/snapshot.lua']=true,
  ['Brainstorm/Advisor/gold_stickers.lua']=true}
function dofile(path)
  return original_dofile(replacements[path] and root..'before/'..path or path)
end
dofile(root..'tests/advisor_acorn_public.lua')
dofile(root..'tests/advisor_gold_stickers.lua')
