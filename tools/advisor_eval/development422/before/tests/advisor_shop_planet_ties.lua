local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Finish=dofile('Brainstorm/Advisor/blind_finishing.lua')
Strategy.consumables=dofile('Brainstorm/Advisor/consumables.lua')
Strategy.liquidity=dofile('Brainstorm/Advisor/liquidity.lua')
Strategy.liquidity.snapshot=Snapshot
for _,name in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards'}) do
  Finish[name]=dofile('Brainstorm/Advisor/'..name..'.lua')
end
Finish.strategy=Strategy;Shop.blind_finishing=Finish;Shop.strategy=Strategy
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local copy=Snapshot.copy
local function planet(key,hand,cost)
  return {id=key,key=key,name=key,cost=cost or 3,ability={set='Planet',consumeable={hand_type=hand}}}
end
local function state()
  local s={phase='shop',challenge='c_jokerless_1',ante=2,dollars=5,bankrupt_at=0,jokers={},joker_limit=0,
    consumeables={},consumable_limit=2,hand={},deck={},playing_cards={},hand_size=8,hand_limit=5,
    hands={Pair={played=3,level=2,chips=25,mult=3},Straight={played=3,level=2,chips=60,mult=7},
      Flush={played=3,level=2,chips=50,mult=6}},
    shop_jokers={planet('c_jupiter','Flush')},shop_vouchers={},
    shop_booster={{id='unknown-arcana',key='p_arcana_normal_1',cost=4,ability={set='Booster'}}},
    round_resets={hands=4,discards=3},current_round={},probabilities={normal=1},modifiers={},
    next_blind={key='bl_goad',chips=1600},next_blind_chips=1600}
  for i=1,8 do s.playing_cards[i]={id='tied:'..i,key='c_base',rank=i+1,nominal=i+1,suit='Hearts',ability={}} end
  return s
end
local function finishing(progress,cash)
  local worlds,total,clears={},0,0
  for i=1,4 do
    worlds[i]={progress=progress[i],hands_used=progress[i]==1 and 3 or 4,discards_used=2,
      dollars_after=cash,population_loss=0,finish_reward=progress[i]==1 and 1 or 0}
    total=total+progress[i];if progress[i]==1 then clears=clears+1 end
  end
  return {complete=true,supported=true,known_mechanics=true,samples=4,
    selected={worlds=worlds,mean_progress=total/4,clearing_samples=clears}}
end
local function paired(s,change)
  local calls,paid=0,{}
  local ctx={compare=function(self,before,after)
    calls=calls+1;paid[#paid+1]=copy(after)
    local left=finishing({.31875,1,.785,.444375},before.dollars)
    local right=finishing({.31875,1,.965,.621875},after.dollars)
    right.selected.worlds[2].hands_used=2;right.selected.worlds[2].finish_reward=2
    local e={samples=4,complete_finishing=true,before_target=1600,after_target=1600,
      before_finishing=left,after_finishing=right,blind='bl_goad',adjustment=0,reason='Complete synthetic paired outcomes.',
      before_readiness={supported=true,status='sampled_deficit',target=1600,opening_mean=300,discards=3,reason='Synthetic shortfall.'},
      after_readiness={supported=true,status='sampled_deficit',target=1600,opening_mean=350,discards=3}}
    if change then change(e,self,after,calls) end
    return e
  end}
  return Strategy.advise(s,{shop_scoring=ctx}),function() return calls end,paid
end
local random,randomseed=math.random,math.randomseed
math.random=function() error('No live RNG in equal-history development') end
math.randomseed=function() error('No live reseeding in equal-history development') end
do
  local s=state();local before=Snapshot.fingerprint(s)
  check(Strategy.advise(s).action.kind=='open','without paired evidence the unknown pack keeps its existing rating')
  local r,calls,paid=paired(s)
  check(r.action.kind=='buy' and r.action.area=='shop_jokers' and r.action.index==1,
    'a complete paid level-up overcomes the arbitrary equal-history prior')
  local d=r.shop_planet_commitment
  check(d and d.complete and d.credit==47 and d.history_tied_with=='Pair' and d.hand=='Flush',
    'credit is exactly bounded by the existing 69 versus 22 priority gap')
  check(math.abs(d.before_mean_progress-.63703125)<1e-10 and math.abs(d.after_mean_progress-.72640625)<1e-10,
    'diagnostic uses capped complete progress, not forecast win odds')
  check(d.cash_after_purchase==2 and d.cost==3 and d.reserve==0,'actual price and remaining cash are explicit')
  check(calls()==1 and #paid==1 and paid[1].hands.Flush.level==3 and paid[1].dollars==2,
    'exactly the existing purchased-use comparison pays and levels the candidate')
  check(Snapshot.fingerprint(s)==before,'input cash, deck, hand histories and inventory are unchanged')
  check(Snapshot.fingerprint(r)==Snapshot.fingerprint(paired(s)),'the complete choice is deterministic')
end
for _,case in ipairs({
  {'incomplete pair',function(e) e.incomplete=true end},
  {'uncertain pair',function(e) e.uncertain=true end},
  {'cutoff',function(e,ctx) ctx.truncated=true end},
  {'unknown finishing',function(e) e.after_finishing.known_mechanics=false end},
  {'missing final world',function(e) e.after_finishing.selected.worlds[4]=nil end},
  {'mismatched target',function(e) e.after_target=1700 end},
  {'nonfinite target',function(e) e.before_target=math.huge;e.after_target=math.huge end},
  {'Arm permanent levels',function(e) e.blind='bl_arm' end},
  {'one crossed progress world',function(e) e.after_finishing.selected.worlds[1].progress=.3 end},
  {'extra played hand',function(e) e.after_finishing.selected.worlds[1].hands_used=5 end},
  {'extra discard',function(e) e.after_finishing.selected.worlds[1].discards_used=3 end},
  {'extra population loss',function(e) e.after_finishing.selected.worlds[1].population_loss=1 end},
  {'lost finishing reward',function(e) e.after_finishing.selected.worlds[2].finish_reward=0 end},
  {'cash loss beyond price',function(e) e.after_finishing.selected.worlds[1].dollars_after=1 end},
  {'no strict progress gain',function(e)
    for i=1,4 do e.after_finishing.selected.worlds[i].progress=e.before_finishing.selected.worlds[i].progress end
  end},
}) do
  local r=paired(state(),case[2]);check(not r.shop_planet_commitment,case[1]..' cannot earn the history credit')
end
for _,case in ipairs({
  {'different play count',function(s) s.hands.Flush.played=2 end},
  {'different level',function(s) s.hands.Flush.level=1 end},
  {'no played commitment',function(s) for _,h in pairs(s.hands) do h.played=0 end end},
  {'owned Joker',function(s) s.jokers={{id='j_joker',key='j_joker',ability={set='Joker'}}} end},
  {'Observatory',function(s) s.used_vouchers={v_observatory=true} end},
  {'voucher alternative Observatory',function(s) s.vouchers={v_observatory=true} end},
  {'unaffordable purchase',function(s) s.shop_jokers[1].cost=6 end},
  {'full inventory',function(s) s.consumeables={planet('c_mercury','Pair'),planet('c_pluto','High Card')} end},
  {'unfunded paid-discard reserve',function(s) s.modifiers.discard_cost=1 end},
}) do
  local s=state();case[2](s);check(not paired(s).shop_planet_commitment,case[1]..' preserves the existing choice')
end
do
  local s=state();s.shop_jokers[2]=planet('c_saturn','Straight')
  local r,calls=paired(s,function(e,ctx,after,n) if n==2 then e.incomplete=true end end)
  check(not r.shop_planet_commitment and calls()==2,'later incomplete tied candidate blocks the whole priority override')
  r,calls=paired(s,function(e,ctx,after,n) if n==2 then e.before_finishing.selected.worlds[1].progress=.1 end end)
  check(not r.shop_planet_commitment and calls()==2,'tied family must share the exact baseline worlds')
  local ordinary=state();ordinary.challenge=nil
  check(paired(ordinary).shop_planet_commitment~=nil,'the mechanism is independent of challenge identity')
  ordinary=state();ordinary.hands={['High Card']={played=3,level=2},['Two Pair']={played=3,level=2}}
  ordinary.shop_jokers={planet('c_uranus','Two Pair')}
  check(paired(ordinary).shop_planet_commitment.hand=='Two Pair','the mechanism generalizes to another tied hand family')
  local held=state();held.consumeables={planet('c_pluto','High Card')};held.consumeables[1].edition={negative=true};held.consumable_limit=3
  local before=Snapshot.fingerprint(held.consumeables)
  local result,_,endpoints=paired(held)
  check(result.shop_planet_commitment and #endpoints[1].consumeables==1 and endpoints[1].consumable_limit==3 and
    Snapshot.fingerprint(endpoints[1].consumeables)==before and Snapshot.fingerprint(held.consumeables)==before,
    'owned Negative inventory and contributed slot remain intact')
  local debt=state();debt.bankrupt_at=-2;debt.modifiers.discard_cost=1
  check(paired(debt).shop_planet_commitment.reserve==3,'a real Credit Card allowance can fund the conservative reserve')
end
do
  local s=state();s.round_resets={hands=1,discards=0};s.next_blind={key='bl_small',chips=1600}
  local unchanged=Shop.new(s,Scorer);local control=Strategy.advise(s,{shop_scoring=unchanged})
  check(not unchanged.truncated and not control.shop_planet_commitment,
    'real stronger unchanged Straight Flush cannot give a weaker Planet spurious credit')
  for i,rank in ipairs({2,4,6,8,10,12,14,3}) do s.playing_cards[i].rank=rank;s.playing_cards[i].nominal=math.min(rank,10) end
  local ctx=Shop.new(s,Scorer);local r=Strategy.advise(s,{shop_scoring=ctx})
  check(not ctx.truncated and r.shop_planet_commitment and r.action.kind=='buy',
    'real complete paid scoring admits a realizable tied hand')
  check(ctx.evaluations<=50000,'the complete real comparison respects the existing shop cap')
  print('advisor_shop_planet_ties real score calls: '..ctx.evaluations..'/'..unchanged.evaluations)
end
do
  local Decision=dofile('Brainstorm/Advisor/decision.lua')
  local Sequences=dofile('Brainstorm/Advisor/shop_sequences.lua')
  Strategy.conditional_value=dofile('Brainstorm/Advisor/conditional_value.lua')
  Strategy.conditional_value.liquidity=Strategy.liquidity
  Strategy.paid_reroll=dofile('Brainstorm/Advisor/paid_reroll.lua')
  Strategy.paid_reroll.liquidity=Strategy.liquidity
  Shop.liquidity=Strategy.liquidity
  local modules={strategy=Strategy,scoring=Scorer,shop_scoring=Shop,consumables=Strategy.consumables,
    shop_sequences=Sequences,economy=dofile('Brainstorm/Advisor/economy.lua')}
  local s=state();s.round_resets={hands=1,discards=0};s.next_blind={key='bl_small',chips=1600}
  s.reroll_cost=5;s.shop_forecast={discount_percent=0,inflation=0}
  local negative=Decision.run(s,modules)
  check(not negative.shop_diagnostics.truncated and negative.action.kind=='open',
    'full decision preserves the ordinary pack choice when paid Planet use adds no progress')
  for i,rank in ipairs({2,4,6,8,10,12,14,3}) do s.playing_cards[i].rank=rank;s.playing_cards[i].nominal=rank==14 and 11 or math.min(rank,10) end
  local before=Snapshot.fingerprint(s)
  local result=Decision.run(s,modules)
  check(not result.shop_diagnostics.truncated and result.action.kind=='buy' and
    result.action.area=='shop_jokers' and result.action.index==1,
    'full decision still buys the improving paid Planet after economy, sequences and shortfall handling')
  check(result.shop_diagnostics.sequences and result.shop_diagnostics.sequences.complete,
    'the full visible continuation comparison completes before keeping the buy recommendation')
  check(result.evaluations<=50000 and Snapshot.fingerprint(s)==before,
    'full decision respects the shared cap and preserves its input')
  check(Snapshot.fingerprint(result)==Snapshot.fingerprint(Decision.run(s,modules)),
    'the integrated recommendation is deterministic')
  local fallback=Decision.run(s,modules,nil,{shop_scoring={max_evaluations=1}})
  check(fallback.shop_diagnostics.truncated and fallback.action.kind=='open' and not fallback.strategy.shop_planet_commitment,
    'whole-decision cutoff removes the incomplete tie credit')
  print('advisor_shop_planet_ties full decision score calls: '..result.evaluations..'/'..negative.evaluations)
end
math.random,math.randomseed=random,randomseed
print('advisor_shop_planet_ties: '..checks..' checks passed')
