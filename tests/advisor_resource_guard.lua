local Search=dofile('Brainstorm/Advisor/search.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local copy=Snapshot.copy
local function state()
  return {jokers={},discards_left=3,used_vouchers={},vouchers={}}
end
local function branch(kind,values)
  local out={kind=kind,worlds={}}
  for i,value in ipairs(values) do
    out.worlds[i]={utility=value,win=value==1 and 1 or 0,score=value*600,turns=3}
  end
  return out
end
local function prior() return branch('discard',{1,.8,.3,.2}) end
local function dominance() return branch('play',{1,.9,.4,.2}) end
local function crossed() return branch('play',{.9,1,.5,.4}) end
local function rejected(s,a,b,label)
  local valid,reason=Search.resource_override_supported(s,a,b)
  check(not valid,label)
  check(type(reason)=='string' and #reason>0,label..' has a reviewable reason')
end
do
  local s,a,b=state(),prior(),dominance()
  local original=Snapshot.fingerprint({s,a,b})
  check(Search.resource_override_supported(s,a,b),'non-worsening paired progress permits the existing override threshold')
  check(Search.resource_override_supported(s,a,branch('play',{1,.8,.3,.2})),
    'equal worlds defer the meaningful-gain threshold to ordinary search')
  rejected(s,a,crossed(),'higher aggregate progress cannot erase a lost paired clear')
  local weak=branch('discard',{.6,.2,.2,.2})
  rejected(s,weak,branch('play',{.5,.8,.8,.8}),
    'a crossed nonclearing world still blocks aggregate-only play preference')
  local lost=dominance();lost.worlds[1].win=0
  rejected(s,a,lost,'equal capped progress cannot hide a lost clear flag')
  check(Snapshot.fingerprint({s,a,b})==original,'the certificate is detached and does not alter branch outcomes')
end
for _,case in ipairs({
  {'one remaining discard',function(s) s.discards_left=1 end},
  {'no remaining discard',function(s) s.discards_left=0 end},
  {'owned scoring Joker',function(s) s.jokers={{key='j_banner',ability={set='Joker'}}} end},
  {'owned debuffed Joker',function(s) s.jokers={{key='j_burnt',debuff=true,ability={set='Joker'}}} end},
  {'Observatory used-voucher inventory',function(s) s.used_vouchers.v_observatory=true end},
  {'Observatory alternative voucher inventory',function(s) s.vouchers.v_observatory=true end},
}) do
  local s=state();case[2](s)
  check(Search.resource_override_supported(s,prior(),crossed()),case[1]..' preserves the existing policy')
end
do
  local s=state();local a=prior();a.kind='play'
  check(Search.resource_override_supported(s,a,crossed()),'an ordinary play preference is not a discard veto')
  local b=crossed();b.kind='discard'
  check(Search.resource_override_supported(s,prior(),b),'a stronger discard candidate retains existing comparison rules')
end
for _,case in ipairs({
  {'missing prior worlds',function(a,b) a.worlds=nil end},
  {'missing play worlds',function(a,b) b.worlds=nil end},
  {'mismatched world counts',function(a,b) b.worlds[4]=nil end},
  {'fewer than four complete worlds',function(a,b) a.worlds[4]=nil;b.worlds[4]=nil end},
  {'missing progress',function(a,b) b.worlds[2].utility=nil end},
  {'missing clear flag',function(a,b) a.worlds[3].win=nil end},
  {'nonfinite prior progress',function(a,b) a.worlds[1].utility=math.huge end},
  {'nonfinite play progress',function(a,b) b.worlds[1].utility=-math.huge end},
  {'NaN progress',function(a,b) b.worlds[1].utility=0/0 end},
  {'nonfinite clear flag',function(a,b) b.worlds[1].win=math.huge end},
  {'NaN prior clear flag',function(a,b) a.worlds[1].win=0/0 end},
}) do
  local a,b=prior(),dominance();case[2](a,b)
  rejected(state(),a,b,case[1]..' cannot certify a narrow play-now override')
end
-- A finite public population makes the opposite control independent of every
-- sampled draw order. Spending a hand on the enhanced Ace preserves enough
-- Kings for two pairs; discarding it removes that real contribution. The new
-- uncertainty guard must still admit this complete no-Joker dominance.
do
  local function card(id,rank,suit)
    return {id=id,rank=rank,nominal=rank==14 and 11 or math.min(rank,10),
      suit=suit or 'Spades',enhancement='c_base',ability={}}
  end
  local s={phase='hand',hand={card('held-ace',14),card('held-king',13,'Hearts')},deck={},
    jokers={},consumeables={},hands={},modifiers={},blind={chips=170},chips=0,dollars=20,
    hand_size=2,hand_limit=5,hands_left=3,hands_played=0,discards_left=3,discards_used=0,
    current_round={hands_left=3,hands_played=0,discards_left=3,discards_used=0},probabilities={normal=1}}
  s.hand[1].ability.perma_bonus=38
  for i=1,4 do s.deck[i]=card('remaining-king-'..i,13,i%2==0 and 'Spades' or 'Hearts') end
  local before=Snapshot.fingerprint(s)
  local no_continuation=Search.run(s,Scoring,{resource_samples=0})
  check(no_continuation.kind=='discard','the immediate-only policy prefers its stronger first pair')
  local old_random,old_seed=math.random,math.randomseed
  math.random=function() error('Resource guard consumed global RNG') end
  math.randomseed=function() error('Resource guard reseeded global RNG') end
  local result=Search.run(s,Scoring,{samples=24,candidates=16,max_evaluations=140000})
  local repeated=Search.run(s,Scoring,{samples=24,candidates=16,max_evaluations=140000})
  math.random,math.randomseed=old_random,old_seed
  check(result.kind=='play' and result.resource_comparison and result.resource_comparison.best.kind=='play',
    'real paired dominance retains the valid play-first continuation')
  check(result.resource_comparison.play.probability==1 and result.resource_comparison.prior_discard.probability==0,
    'every deterministic population world separates the retained clear from the discard loss')
  check(not result.resource_comparison.override_rejected,'the guard does not reject a noncrossing exact population comparison')
  check(result.evaluations<=140000,'the actual comparison remains within the unchanged shared scoring allowance')
  check(Snapshot.fingerprint(s)==before and Snapshot.fingerprint(result)==Snapshot.fingerprint(repeated),
    'real comparison repeats deterministically without modifying the detached observation')
  print('advisor_resource_guard real score calls: '..result.evaluations)
end
print('advisor_resource_guard: '..checks..' checks passed')
