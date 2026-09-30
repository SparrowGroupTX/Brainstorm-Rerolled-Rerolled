local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Finish=dofile('Brainstorm/Advisor/blind_finishing.lua')
Strategy.consumables=dofile('Brainstorm/Advisor/consumables.lua')
for _,name in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards'}) do
  Finish[name]=dofile('Brainstorm/Advisor/'..name..'.lua')
end
Finish.strategy=Strategy;Shop.blind_finishing=Finish;Shop.strategy=Strategy
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local copy=Snapshot.copy
local function planet(key,hand,cost)
  return {id=key,key=key,name=key,cost=cost or 3,
    ability={set='Planet',consumeable={hand_type=hand}}}
end
local function state()
  local s={phase='shop',ante=2,dollars=20,bankrupt_at=0,jokers={},joker_limit=5,
    consumeables={},consumable_limit=2,hand={},deck={},playing_cards={},hand_size=8,hand_limit=5,
    hands={['Four of a Kind']={played=1,level=1}},
    shop_jokers={planet('c_mars','Four of a Kind'),planet('c_uranus','Two Pair')},
    shop_booster={},shop_vouchers={},round_resets={hands=1,discards=0},
    current_round={},probabilities={normal=1},modifiers={},
    next_blind={key='bl_small',chips=600},next_blind_chips=600}
  for i,rank in ipairs({2,2,4,4,6,6,8,8}) do
    s.playing_cards[i]={id='shop-commitment:'..i,key='c_base',rank=rank,nominal=rank,
      suit=({'Spades','Hearts','Diamonds','Clubs'})[(i-1)%4+1],ability={}}
  end
  return s
end
local function finishing(progress,cash)
  local worlds={}
  for i=1,4 do worlds[i]={progress=progress,hands_used=1,discards_used=0,
    dollars_after=cash,population_loss=0,finish_reward=0} end
  return {complete=true,supported=true,known_mechanics=true,samples=4,
    selected={worlds=worlds,mean_progress=progress,clearing_samples=progress==1 and 4 or 0}}
end
local function paired(s,change)
  local calls=0
  local ctx={compare=function(self,before,after)
    calls=calls+1
    local better=((after.hands or {})['Two Pair'] or {}).level==2
    local left,right=finishing(.2,before.dollars),finishing(better and .7 or .4,after.dollars)
    local e={samples=4,complete_finishing=true,before_target=600,after_target=600,
      before_finishing=left,after_finishing=right,blind='bl_small',adjustment=0,reason='Complete synthetic outcomes.',
      before_readiness={supported=true,status='sampled_deficit',target=600,opening_mean=120,reason='Synthetic shortfall.'},
      after_readiness={supported=true,status='sampled_deficit',target=600,opening_mean=better and 420 or 240}}
    if change then change(e,better,self,after) end
    return e
  end}
  return Strategy.advise(s,{shop_scoring=ctx}),function() return calls end
end
local random,randomseed=math.random,math.randomseed
math.random=function() error('Shop commitment must not sample game RNG') end
math.randomseed=function() error('Shop commitment must not reseed game RNG') end
do
  local s=state();local before=Snapshot.fingerprint(s)
  check(Strategy.advise(s).action.index==1,'without evidence prior remains unchanged')
  local r,calls=paired(s)
  check(r.action.kind=='buy' and r.action.index==2,'complete paid endpoints reject a dominated historical hand')
  check(calls()==2,'uses exactly the existing two purchased-use comparisons')
  check(r.shop_planet_dominance and r.shop_planet_dominance.complete and
    r.shop_planet_dominance.rejections[1].key=='c_mars','shop rejection records exact visible identities')
  check(r.shop_planet_dominance.previous_score>r.shop_planet_dominance.selected_score,
    'complete evidence defeats a larger raw played-hand prior')
  check(r.scoring_evidence.planet_use,'purchase preview retains exact Planet-use semantics')
  check(Snapshot.fingerprint(s)==before,'purchase comparison leaves source cash/population/inventory unchanged')
  check(Snapshot.fingerprint(r)==Snapshot.fingerprint(paired(s)),'complete shop choice is deterministic')
end
for _,case in ipairs({
  {'later incomplete family',function(e,better) if better then e.incomplete=true end end},
  {'later scoring cutoff',function(e,better,ctx) if better then ctx.truncated=true end end},
  {'unknown mechanics',function(e,better) if better then e.after_finishing.known_mechanics=false end end},
  {'missing world',function(e,better) if better then e.after_finishing.selected.worlds[4]=nil end end},
  {'different baseline',function(e,better) if better then e.before_finishing.selected.worlds[1].progress=.1 end end},
  {'Arm permanent levels',function(e) e.blind='bl_arm' end},
  {'worse world',function(e,better) if better then e.after_finishing.selected.worlds[4].progress=.3 end end},
  {'worse action cost',function(e,better) if better then e.after_finishing.selected.worlds[1].hands_used=2 end end},
  {'worse cash',function(e,better) if better then e.after_finishing.selected.worlds[1].dollars_after=16 end end},
  {'worse population',function(e,better) if better then e.after_finishing.selected.worlds[1].population_loss=1 end end},
  {'worse reward',function(e,better) if not better then e.after_finishing.selected.worlds[1].finish_reward=1 end end},
  {'nonfinite target',function(e) e.before_target=math.huge;e.after_target=math.huge end},
}) do
  local r=paired(state(),case[2]);check(not r.shop_planet_dominance,case[1]..' cannot establish dominance')
end
for _,key in ipairs({'j_perkeo','j_yorick','j_burnt','j_hiker','j_wee','j_unknown'}) do
  local s=state();s.jokers={{id=key,key=key,name=key,ability={set='Joker'}}}
  check(not paired(s).shop_planet_dominance,key..' whole future development stays protected')
end
do
  local s=state();s.used_vouchers={v_observatory=true}
  check(not paired(s).shop_planet_dominance,'Observatory held-inventory tradeoff abstains')
  s=state();s.shop_jokers[2].cost=21
  check(paired(s).action.index==1,'unaffordable stronger Planet cannot be selected')
  s=state();s.shop_jokers[2].cost=4
  check(not paired(s).shop_planet_dominance,'higher purchase cost blocks strict cash dominance')
  s=state();s.consumeables={planet('c_pluto','High Card')};s.consumeables[1].edition={negative=true};s.consumable_limit=3
  local before=Snapshot.fingerprint(s.consumeables)
  check(paired(s).action.index==2 and Snapshot.fingerprint(s.consumeables)==before and s.consumable_limit==3,
    'existing Negative inventory and its contributed capacity are retained')
end
-- Same generic opposite controls as the revealed pack mechanism, now paying
-- the observed price. The full scorer supplies outcomes, not a hand-name rule.
do
  local s=state();local ctx=Shop.new(s,Scorer);local r=Strategy.advise(s,{shop_scoring=ctx})
  check(not ctx.truncated and r.action.kind=='buy' and r.action.index==2,
    'real paired purchased-use outcomes preserve realizable development')
  local count=ctx.evaluations
  local rare=state();rare.hands={['Two Pair']={played=1,level=1}}
  for i,c in ipairs(rare.playing_cards) do c.rank=i<=4 and 7 or 9;c.nominal=c.rank end
  rare.next_blind.chips=1400;rare.next_blind_chips=1400
  local other=Shop.new(rare,Scorer);local result=Strategy.advise(rare,{shop_scoring=other})
  check(not other.truncated and result.action.kind=='buy' and result.action.index==1,
    'real duplicate-rich deck still develops its viable high-rank hand')
  print('advisor_shop_planet_commitment real score calls: '..count..'/'..other.evaluations)
end
math.random,math.randomseed=random,randomseed
print('advisor_shop_planet_commitment: '..checks..' checks passed')
