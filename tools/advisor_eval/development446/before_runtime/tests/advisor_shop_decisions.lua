local S=dofile('Brainstorm/Advisor/strategy.lua')
local C=dofile('Brainstorm/Advisor/consumables.lua')
local D=dofile('Brainstorm/Advisor/decision.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(value,message) assert(value,message);checks=checks+1 end
local function joker(key,cost,ability)
  ability=ability or {};ability.set='Joker'
  return {key=key,cost=cost or 0,ability=ability,sell_cost=2}
end
local function state()
  local s={phase='shop',ante=3,dollars=25,bankrupt_at=0,joker_limit=5,consumable_limit=2,
    jokers={joker('j_joker',0,{mult=4})},consumeables={},hand={},deck={},playing_cards={},
    shop_jokers={joker('j_blackboard',6,{extra=3}),joker('j_popcorn',5,{mult=20})},
    shop_booster={},shop_vouchers={},hand_size=8,hand_limit=5,
    hands={Pair={level=1,played=6},Flush={level=1,played=0}},
    round_resets={hands=4,discards=3},current_round={hands_left=0,discards_left=0,hands_played=4},
    hands_left=0,discards_left=0,hands_played=4,blind={key='bl_eye',name='The Eye',hands={Flush=true}},
    modifiers={},probabilities={normal=1},interest_cap=25,reroll_cost=5}
  for i=1,52 do s.playing_cards[i]={id='test:'..i,rank=2+(i-1)%13,suit='Hearts',ability={}} end
  return s
end
local modules={strategy=S,consumables=C,scoring=Scoring,shop_scoring=Shop}
do
  local s=state();local before=Snapshot.fingerprint(s)
  local old=S.advise(s)
  check(old.action.kind=='buy' and old.action.index==1,'regression starts with heuristic preference for inactive Blackboard')
  local result=D.run(s,modules)
  check(result.action.kind=='buy' and result.action.index==2,'actual all-red deck scoring prefers functional Popcorn')
  check(result.evaluations>0 and not result.shop_diagnostics.truncated,'comparison completed within shared budget')
  check(result.strategy.scoring_evidence and result.strategy.scoring_evidence.after_mean>
    result.strategy.scoring_evidence.before_mean,'purchase exposes its actual paired scoring gain')
  check(Snapshot.fingerprint(s)==before,'shop decision never mutates live-detached input')
  local repeat_result=D.run(s,modules)
  check(Snapshot.fingerprint(repeat_result)==Snapshot.fingerprint(result),'shop decision is deterministic')
end
do
  local s=state();local baseline=S.advise(s)
  local result=D.run(s,modules,nil,{shop_scoring={max_evaluations=1}})
  check(result.shop_diagnostics.truncated,'too-small shared scoring budget is disclosed')
  check(result.action.kind==baseline.action.kind and result.action.index==baseline.action.index,
    'budget cutoff discards all partial purchase adjustments')
end
do
  local s=state();s.shop_jokers={joker('j_stuntman',4,{extra={chip_mod=250,h_size=2}})}
  local seen
  local ctx={compare=function(_,before,after)
    seen={before=before.hand_size,after=after.hand_size,cash=after.dollars}
    return {adjustment=1,ratio=2,before_mean=100,after_mean=200,samples=4,reason='Paired test evidence.'}
  end}
  S.advise(s,{shop_scoring=ctx})
  check(seen and seen.before==8 and seen.after==6,'purchase preview applies Stuntman hand-size cost')
  check(seen.cash==21 and s.dollars==25 and s.hand_size==8,'preview spends cash without changing original resources')
end
do
  local s=state();s.modifiers={minus_hand_size_per_X_dollar=5}
  s.shop_jokers={joker('j_popcorn',5,{mult=20})}
  local size
  S.advise(s,{shop_scoring={compare=function(_,before,after)
    size=after.hand_size
    return {adjustment=1,ratio=2,before_mean=100,after_mean=200,samples=4,reason='Paired test evidence.'}
  end}})
  check(size==9,'Luxury Tax preview returns the hand-size point freed by spending')
end

do
  local s=state();s.joker_limit=1
  s.jokers={joker('j_joker',0,{mult=4,perishable=true,perish_tally=0})}
  s.jokers[1].debuff=true
  s.shop_jokers={joker('j_golden',1,{extra=4})}
  local original=Snapshot.fingerprint(s)
  local baseline=S.advise(s)
  check(baseline.action.kind=='sell' and baseline.action.index==1,
    'pure-income upgrade starts with a concrete heuristic replacement')
  local comparisons=0
  local result=S.advise(s,{shop_scoring={compare=function(_,before,after)
    comparisons=comparisons+1
    check(#before.jokers==1 and before.jokers[1].key=='j_joker' and
      #after.jokers==1 and after.jokers[1].key=='j_golden',
      'income replacement compares the complete old and combined resulting rows')
    check(after.dollars==26,'replacement preview includes sale proceeds and purchase cost')
    -- The context owns scoring. A loss reported by that context must veto a
    -- replacement even though the incoming income Joker has no scoring effect.
    return {adjustment=0,ratio=0.5,before_mean=100,after_mean=50,samples=4,reason='Paired test loss.'}
  end}})
  check(comparisons==1,'pure-income replacement receives the whole-row scoring check')
  check(result.action.kind~='sell','whole-row loss veto applies to an incoming pure-income Joker')
  check(Snapshot.fingerprint(s)==original,'vetoed replacement leaves the original row and cash intact')
end

do
  local s=state();s.challenge='c_omelette_1';s.joker_limit=2;s.dollars=0
  s.jokers={joker('j_egg',0,{extra=3}),joker('j_campfire',0,{x_mult=1.25,extra=0.25,eternal=true})}
  s.jokers[1].sell_cost=15
  s.shop_jokers={joker('j_popcorn',5,{mult=20})}
  local original=Snapshot.fingerprint(s)
  local whole_rows=0
  local result=S.advise(s,{shop_scoring={compare=function(_,before,after)
    check(#after.jokers==2 and after.jokers[1].key=='j_campfire' and
      after.jokers[2].key=='j_popcorn','Egg preview contains the retained Campfire and funded purchase')
    check(after.jokers[1].ability.x_mult==1.5,'selling one Egg grows retained Campfire exactly once')
    check(after.dollars==10,'Egg sale preview spends its actual proceeds on the purchase')
    if before.jokers[1].key=='j_egg' then
      whole_rows=whole_rows+1
      check(before.jokers[2].ability.x_mult==1.25,'whole-row baseline preserves Campfire before the sale')
    end
    return {adjustment=1,ratio=2,before_mean=100,after_mean=200,samples=4,reason='Paired test gain.'}
  end}})
  check(result.action.kind=='sell' and result.action.index==1 and result.action.followup.index==1,
    'funded Omelette upgrade recommends the concrete Egg sale')
  check(whole_rows==1,'Egg upgrade also receives one original-to-combined-row comparison')
  check(Snapshot.fingerprint(s)==original and s.jokers[2].ability.x_mult==1.25,
    'Egg sale preview never grows or removes live-detached Jokers')
end
print('advisor_shop_decisions: '..checks..' checks passed')
