local original=dofile
dofile=function(path)
  if path=='Brainstorm/Advisor/snapshot.lua' or path=='Brainstorm/Advisor/gold_stickers.lua'then
    return original('tools/advisor_eval/development328/acorn_public_component/Brainstorm/Advisor/'..path:match('[^/]+$'))
  end
  return original(path)
end
dofile('tests/advisor_snapshot.lua')
dofile('tests/advisor_gold_stickers.lua')
