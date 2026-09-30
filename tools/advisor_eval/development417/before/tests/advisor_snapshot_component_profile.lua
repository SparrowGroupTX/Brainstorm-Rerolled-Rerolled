-- Small protocol fixture only: no real source snapshot or game actions.
local f=assert(io.open('tools/advisor_eval/snapshot_component_profile.lua','rb'))
local profiler=f:read('*a');f:close()
local preamble=[[
local scoring={classify=function() return 'High Card' end}
local score_calls=0
scoring.score=function() score_calls=score_calls+1;scoring.classify();return 10 end
local snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local modules={snapshot=snapshot,scoring=scoring,strategy={},consumables={}}
local decision={run=function(s,passed,...)
  assert(select('#',...)==0,'Profiling changed default options')
  assert(passed==modules and s.marker==42,'Profiler did not preserve input/modules')
  assert(modules.scoring.score()==10)
  return {action={kind='play',indices={1}},evaluations=1}
end}
PROFILE_INPUT={step=75,decision_started={snapshot={phase='hand',marker=42}},
  source_action={kind='play',indices={1}},source_profile={score_calls=1,evaluations=1}}
]]
local result=assert(loadstring(preamble..profiler))()
assert(result:find('"input_unchanged":true',1,true),'Missing input conservation')
assert(result:find('"complete":true',1,true),'Missing exact source parity')
assert(result:find('"score_classify":',1,true),'Missing classification component')
assert(result:find('"score_calls":1',1,true),'Missing score counter')
local changed=preamble:gsub('score_calls=1,evaluations=1','score_calls=2,evaluations=2')
local mismatch=assert(loadstring(changed..profiler))()
assert(mismatch:find('"score_calls_match":false',1,true),'Mismatch was hidden')
assert(mismatch:find('"complete":false',1,true),'Mismatch became parity')
local mutate=preamble:gsub('assert%(modules.scoring.score%(%)==10%)','s.marker=43;assert(modules.scoring.score()==10)')
local ok,err=pcall(assert(loadstring(mutate..profiler)))
assert(not ok and tostring(err):find('mutated its input',1,true),'Input mutation passed')
print('advisor_snapshot_component_profile: 7 checks passed')
