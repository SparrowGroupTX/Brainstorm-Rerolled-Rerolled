local original=dofile
dofile=function(path)
  if path=='Brainstorm/Advisor/shop_scoring.lua' or path=='Brainstorm/Advisor/blind_finishing.lua' or path=='Brainstorm/Advisor/shop_sequences.lua' then
    path='tools/advisor_eval/development299/drafts/shop_order/'..path:match('([^/]+)$')
  end
  return original(path)
end
original('tests/advisor_shop_scoring.lua')
