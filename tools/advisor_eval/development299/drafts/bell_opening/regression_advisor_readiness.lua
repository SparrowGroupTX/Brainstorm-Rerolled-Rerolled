local original_dofile=dofile
local prefix='tools/advisor_eval/development299/drafts/bell_opening/'
dofile=function(path)
  local module=path:match('^Brainstorm/Advisor/([^/]+)%.lua$')
  if module=='shop_scoring' or module=='shop_sequences' or module=='gold_goal' then
    local value=original_dofile(prefix..module..'.lua')
    if module=='shop_scoring' then value.bell_opening=original_dofile(prefix..'bell_opening.lua') end
    return value
  end
  return original_dofile(path)
end
original_dofile('tests/advisor_readiness.lua')
