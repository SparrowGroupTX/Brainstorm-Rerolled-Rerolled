local D=dofile('Brainstorm/Advisor/decision.lua')
local checks=0
local function check(v,l) checks=checks+1;assert(v,l) end
local two,multi=0,0
local base={kind='discard',play={score=1,indices={1}},discard={indices={2}},evaluations=5}
local m={search={run=function() return {kind=base.kind,play=base.play,discard=base.discard,evaluations=5,fast_clear=base.fast_clear} end},
  two_hand_finish={suggest=function() two=two+1;return {action={kind='play',area='hand',indices={1}}},10,{complete=true} end},
  multi_discard={suggest=function() multi=multi+1;return nil,3,{} end}}
local s={phase='hand',hands_left=2,consumeables={},jokers={}}
local r=D.run(s,m)
check(r.action.kind=='play' and r.two_hand_finish_diagnostics.complete,'Two-hand proposal overrides only the first action')
check(two==1 and multi==0 and r.evaluations==15,'Two-hand and last-hand specialists share a mutually exclusive route')
s.hands_left=1;r=D.run(s,m)
check(two==1 and multi==1,'Last-hand route is preserved')
s.hands_left=2;base.fast_clear={};r=D.run(s,m)
check(two==1 and multi==1 and r.evaluations==5,'Fast clears skip both expensive specialists')
check(r.fast_clear.specialists_skipped and r.fast_clear.post_clear_limit==34,'Existing fast-clear allowances remain intact')
print('advisor_finish_integration: '..checks..' checks passed')
