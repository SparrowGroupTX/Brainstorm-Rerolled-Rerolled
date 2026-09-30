local original_dofile=dofile
local changed={multi_discard=true,blind_finishing=true,shop_scoring=true,pack_survival=true}
dofile=function(path)
 local name=path:match('^Brainstorm/Advisor/(.+)%.lua$')
 if name and changed[name]then return original_dofile('tools/advisor_eval/development300/pack_five319/'..path)end
 return original_dofile(path)
end
dofile('tests/advisor_blind_finishing.lua')
