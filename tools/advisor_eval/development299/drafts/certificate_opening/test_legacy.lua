local original=dofile
local files={snapshot=true,shop_scoring=true,blind_finishing=true,multi_discard=true}
dofile=function(path)
  local name=path:match('^Brainstorm/Advisor/([a-z_]+)%.lua$')
  if files[name] then path='tools/advisor_eval/development299/drafts/certificate_opening/'..name..'.lua' end
  return original(path)
end
for _,path in ipairs({'tests/advisor_blind_finishing.lua','tests/advisor_shop_scoring.lua',
  'tests/advisor_blind_start.lua','tests/advisor_multi_discard.lua','tests/advisor_gold_goal.lua'}) do
  dofile(path)
end
