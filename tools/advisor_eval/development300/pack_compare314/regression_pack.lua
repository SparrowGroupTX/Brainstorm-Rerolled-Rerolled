local old=dofile
function dofile(path)
 if path=='Brainstorm/Advisor/pack_survival.lua' then return old('tools/advisor_eval/development300/pack_compare314/pack_survival.lua') end
 return old(path)
end
dofile('tests/advisor_pack_survival.lua')
