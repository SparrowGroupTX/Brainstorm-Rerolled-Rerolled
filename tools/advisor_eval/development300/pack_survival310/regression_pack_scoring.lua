local old=dofile
local P='tools/advisor_eval/development300/pack_survival310/'
local C='tools/advisor_eval/development299/drafts/certificate_opening/'
local pack=old(P..'pack_survival.lua')
function dofile(path)
 if path=='Brainstorm/Advisor/strategy.lua' then local m=old(P..'strategy.lua');m.pack_survival=pack;return m end
 if path=='Brainstorm/Advisor/blind_finishing.lua' or path==C..'blind_finishing.lua' then local m=old(P..'blind_finishing.lua');m.pack_survival=pack;return m end
 return old(path)
end
dofile('tests/advisor_pack_scoring.lua')
