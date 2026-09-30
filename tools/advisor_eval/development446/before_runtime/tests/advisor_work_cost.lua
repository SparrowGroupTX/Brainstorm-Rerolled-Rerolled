local W=dofile('Brainstorm/Advisor/work_cost.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local C=dofile('Brainstorm/Advisor/scoring.lua')
local S=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local ready={supported=true,target=500,hands=1,discards=3,opening_scores={100,100,100,100}}
local a={hand_size=8,ante=2};local b={hand_size=9,ante=2}
check(W.plays(8)==218 and W.plays(9)==381,'Work count uses the complete legal subset population')
local extra=W.compare(a,b,ready,ready)
check(extra.adjustment<0 and extra.extra_seconds>0,'Larger unresolved hands pay a bounded estimated time cost')
check(extra.adjustment>=-8 and not extra.calibrated,'Time preference is bounded and honestly uncalibrated')
check(W.compare(a,b,ready,ready,0).adjustment==0,'Coefficient zero removes the preference')
check(W.compare(b,a,ready,ready).adjustment>0,'Equivalent cheaper decisions earn the reverse preference')
local safe=S.copy(ready);safe.opening_scores={600,600,600,600}
check(math.abs(W.compare(a,b,safe,safe).adjustment)<.001,'Clearing openings do not pay hypothetical full nonclear work')
check(W.compare(a,b,ready,safe).adjustment>0,'An upgrade that avoids expensive nonclear work retains value')
check(not W.estimate(a,{supported=false}),'Unsupported readiness cannot invent time savings')
local s={phase='shop',ante=2,dollars=12,bankrupt_at=0,joker_limit=5,consumeables={},jokers={},
  hand_size=8,hand_limit=5,playing_cards={},hands={},round_resets={hands=1,discards=3},
  modifiers={},probabilities={normal=1},next_blind={key='bl_small',name='Small Blind',chips=3000}}
for i=1,40 do s.playing_cards[i]={id='time:'..i,rank=2+(i*3)%13,suit=({'Hearts','Spades','Clubs','Diamonds'})[i%4+1],ability={}} end
local after=S.copy(s);after.hand_size=9
local original=S.fingerprint(s)
local plain=assert(Shop.new(s,C):compare(s,after))
Shop.work_cost=W
local timed_context=Shop.new(s,C)
local timed=assert(timed_context:compare(s,after))
check(timed_context.metrics.coefficient_opportunities.computation_cost_scale==1 and
  timed_context.metrics.coefficient_opportunities.shop_scoring_gain_weight==1,'Calibration sees actual nonzero gain and work opportunities')
check(timed.work_cost and timed.work_cost.adjustment<0,'Actual shop comparison carries the cost of enlarged nonclearing hands')
check(math.abs(timed.adjustment-plain.adjustment-timed.work_cost.adjustment)<1e-9,'Cost reaches the shared purchase/pack/sequence evidence')
local scale=1
Shop.policy_weights={get=function(key) return key=='shop_scoring_gain_weight' and 1.5 or scale end}
local weighted=assert(Shop.new(s,C):compare(s,after))
check(math.abs(weighted.adjustment-plain.adjustment*1.5-weighted.work_cost.adjustment)<1e-9,'Calibration changes actual tactical gain rather than only metadata')
scale=0
local disabled=assert(Shop.new(s,C):compare(s,after))
check(disabled.work_cost.adjustment==0,'Numeric compute coefficient reaches the actual comparison')
check(S.fingerprint(s)==original,'Costing leaves state and resource forecasts unchanged')
print('work cost: '..checks..' checks passed')
