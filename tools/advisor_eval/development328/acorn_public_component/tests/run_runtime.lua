-- Existing manufactured runtime regression, redirected to this detached patch.
local base='tools/advisor_eval/development328/acorn_public_component/Brainstorm/Advisor/'
local open=io.open
io.open=function(path,mode)
  if path=='Brainstorm/Advisor/acorn_public.lua' or path=='Brainstorm/Advisor/acorn_public_hooks.lua'then
    return open(base..path:match('[^/]+$'),mode)
  elseif path=='Brainstorm/Advisor/acorn_belief.lua' or path=='Brainstorm/Advisor/acorn_ordering.lua'then
    return open('tools/advisor_eval/development328/acorn_belief_component/'..path:match('[^/]+$'),mode)
  end
  if path=='Brainstorm/Advisor/execution.lua' or path=='Brainstorm/Advisor/snapshot.lua' or path=='Brainstorm/Advisor/gold_stickers.lua'then
    return open(base..path:match('[^/]+$'),mode)
  end
  return open(path,mode)
end
local original=dofile
dofile=function(path)
  if path=='Brainstorm/Advisor/runtime.lua'then return original(base..'runtime.lua')end
  return original(path)
end
local source=assert(open('tests/advisor_runtime.lua','rb'));local text=source:read('*a');source:close()
local extra=assert(open('tools/advisor_eval/development328/acorn_public_component/tests/runtime_public_append.lua','rb'))
text=text..'\n'..extra:read('*a');extra:close()
assert(loadstring(text,'@manufactured_acorn_runtime_regression'))()
