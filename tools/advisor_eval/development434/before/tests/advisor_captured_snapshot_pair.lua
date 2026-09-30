-- Synthetic driver protocol fixture, without source snapshots or policy runs.
local f=assert(io.open('tools/advisor_eval/captured_snapshot_pair.lua','rb'));local driver=f:read('*a');f:close()
local checks=0
local function check(v,why) checks=checks+1;assert(v,why) end
local preamble=[[
local snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local contract=dofile('tools/advisor_eval/engine_contract.lua')
local score_calls=0
local raw_score=function(s,indices) return {score=42,legal=true,uncertain=false} end
local modules={snapshot=snapshot,scoring={score=function() score_calls=score_calls+1;return 42 end},
  strategy={},consumables={}}
local decision={run=function(s,passed,...)
  assert(select('#',...)==0,'Changed product default options');assert(passed==modules)
  modules.scoring.score()
  return {action={kind='play',indices={1}},evaluations=1,
    two_hand_finish_diagnostics={complete=true,candidates={
      {worlds={{win=1,cash=7,population_after=52,actions={{kind='play'}}}}}
    }}}
end}
PROFILE_INPUT={phase='hand',hands_left=2,discards_left=1,hand={{id='a',rank=2,ability={}}}}
]]
local row=assert(loadstring(preamble..driver))()
check(row:find('"input_unchanged":true',1,true),'Input conservation missing')
check(row:find('"cash":7',1,true),'Full common-world evidence omitted')
check(row:find('"decision_elapsed_seconds":',1,true),'Timing absent')
check(row:find('"source_qualified":false',1,true),'Modeled audit confused with source qualification')
check(row:find('"score_calls":1',1,true),'Product/audit counters absent')
check(row:find('"status":"legal"',1,true),'Legal play failed modeled audit')
local forced=preamble:gsub("hand={{id='a',rank=2,ability={}}}","hand={{id='a',rank=2,ability={}},{id='b',rank=3,ability={forced_selection=true}}}")
check(assert(loadstring(forced..driver))():find('"status":"illegal"',1,true),'Omitted Bell card passed')
local nohands=preamble:gsub('hands_left=2','hands_left=0')
check(assert(loadstring(nohands..driver))():find('"status":"illegal"',1,true),'No-hands play passed')
local discard=preamble:gsub("kind='play',indices={1}","kind='discard',indices={1}"):gsub('discards_left=1','discards_left=0')
check(assert(loadstring(discard..driver))():find('"status":"illegal"',1,true),'No-discards discard passed')
local mutate=preamble:gsub('modules.scoring.score%(%)','s.hands_left=99;modules.scoring.score()')
local ok,why=pcall(assert(loadstring(mutate..driver)))
check(not ok and tostring(why):find('mutated its input',1,true),'Input mutation accepted')
local unsupported=preamble:gsub("kind='play',indices={1}","kind='use',indices={1}")
check(assert(loadstring(unsupported..driver))():find('"status":"unsupported"',1,true),'Other action audit was invented')
print('advisor_captured_snapshot_pair: '..checks..' checks passed')
