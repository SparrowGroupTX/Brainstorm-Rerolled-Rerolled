local old=dofile
local P='tools/advisor_eval/development300/legendary_opening312/'
function dofile(path)
 if path=='Brainstorm/Advisor/collection_search.lua' then return old(P..'collection_search.lua') end
 if path=='Brainstorm/Core/collection_search_product.lua' then return old(P..'collection_search_product.lua') end
 if path=='Brainstorm/Core/auto_run_product.lua' then return old(P..'auto_run_product.lua') end
 return old(path)
end
dofile('tests/advisor_burnt_fallback.lua')
