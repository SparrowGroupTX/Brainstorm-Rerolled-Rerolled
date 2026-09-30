local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Finish=dofile('Brainstorm/Advisor/blind_finishing.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
Strategy.consumables=dofile('Brainstorm/Advisor/consumables.lua')
Strategy.pack_scoring=dofile('Brainstorm/Advisor/pack_scoring.lua')
for _,name in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards'}) do
  Finish[name]=dofile('Brainstorm/Advisor/'..name..'.lua')
end
Finish.strategy=Strategy;Shop.blind_finishing=Finish;Shop.strategy=Strategy
local modules={strategy=Strategy,scoring=Scorer,shop_scoring=Shop,
  consumables=Strategy.consumables,pack_scoring=Strategy.pack_scoring}
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local function copy(v) return Snapshot.copy(v) end
local function planet(key,hand)
  return {id=key,key=key,name=key,cost=3,
    ability={name=key,set='Planet',consumeable={hand_type=hand}}}
end
local function state()
  local s={phase='pack',ante=2,dollars=0,bankrupt_at=0,jokers={},joker_limit=5,
    consumeables={},consumable_limit=2,hand={},deck={},playing_cards={},hand_size=8,hand_limit=5,
    hands={['Four of a Kind']={played=1,level=1}},
    pack_cards={planet('c_mars','Four of a Kind'),planet('c_uranus','Two Pair')},
    round_resets={hands=1,discards=0},current_round={},probabilities={normal=1},modifiers={},
    next_blind={key='bl_small',chips=600},next_blind_chips=600}
  for i,rank in ipairs({2,2,4,4,6,6,8,8}) do
    s.playing_cards[i]={id='commitment:'..i,key='c_base',rank=rank,nominal=rank,
      suit=({'Spades','Hearts','Diamonds','Clubs'})[(i-1)%4+1],ability={}}
  end
  return s
end
local function world(progress)
  return {progress=progress,hands_used=1,discards_used=0,dollars_after=0,population_loss=0,finish_reward=0}
end
local function finishing(progress)
  return {complete=true,supported=true,known_mechanics=true,samples=4,
    selected={worlds={world(progress),world(progress),world(progress),world(progress)}}}
end
local function evidence(progress)
  return {complete_finishing=true,samples=4,before_target=600,after_target=600,
    before_finishing=finishing(0.2),after_finishing=finishing(progress),
    adjustment=0,reason='Complete synthetic paired policies.'}
end
local function paired(s,change)
  local calls=0
  local context={compare=function(self,before,after)
    calls=calls+1
    local developed=((after.hands or {})['Two Pair'] or {}).level==2
    local e=evidence(developed and 0.6 or 0.4)
    if change then change(e,developed,self) end
    return e
  end}
  local result=Strategy.advise(s,{shop_scoring=context})
  return result,calls
end
local random,randomseed=math.random,math.randomseed
math.random=function() error('Planet commitment must not sample game RNG') end
math.randomseed=function() error('Planet commitment must not reseed game RNG') end
local s=state();local original=Snapshot.fingerprint(s)
local legacy=Strategy.advise(s)
check(legacy.action.index==1,'one past rare hand receives the old strategic preference without paired evidence')
local result,calls=paired(s)
check(result.action.index==2 and calls==2,'complete better Planet outcomes override historical preference without extra comparisons')
check(result.pack_diagnostics.planet_dominance.complete and #result.pack_diagnostics.planet_dominance.rejections==1,
  'complete Planet rejection is reviewable')
check(result.pack_diagnostics.offers[1].planet_dominated_by==2 and result.pack_diagnostics.offers[1].score>result.pack_diagnostics.offers[2].score,
  'strict paired evidence can defeat the larger raw prior without erasing its rating')
check(Snapshot.fingerprint(s)==original and Snapshot.fingerprint(result)==Snapshot.fingerprint(paired(s)),
  'selection is deterministic and preserves snapshot, hand history and inventory')
local reversed=copy(s);reversed.pack_cards={reversed.pack_cards[2],reversed.pack_cards[1]}
check(paired(reversed).action.index==1,'candidate source order does not decide a strict dominance')
local symmetric=copy(s);symmetric.hands={['Two Pair']={played=1,level=1}}
local reverse_result=Strategy.advise(symmetric,{shop_scoring={compare=function(_,before,after)
  return evidence(((after.hands or {})['Four of a Kind'] or {}).level==2 and 0.6 or 0.4)
end}})
check(reverse_result.action.index==1,'the same mechanism favors a realizable rare hand when its paired evidence is stronger')
local no_dominance={
  {'one weaker world',function(e,better) if better then e.after_finishing.selected.worlds[4].progress=0.3 end end},
  {'more hands',function(e,better) if better then e.after_finishing.selected.worlds[2].hands_used=2 end end},
  {'more discards',function(e,better) if better then e.after_finishing.selected.worlds[2].discards_used=1 end end},
  {'less cash',function(e,better) if better then e.after_finishing.selected.worlds[2].dollars_after=-1 end end},
  {'more population loss',function(e,better) if better then e.after_finishing.selected.worlds[2].population_loss=1 end end},
  {'less finishing reward',function(e,better) if not better then e.after_finishing.selected.worlds[2].finish_reward=1 end end},
  {'no strict progress gain',function(e) for _,w in ipairs(e.after_finishing.selected.worlds) do w.progress=0.4 end end},
  {'both policies already clear',function(e) for _,w in ipairs(e.after_finishing.selected.worlds) do w.progress=1 end end},
  {'different targets',function(e,better) if better then e.before_target=500;e.after_target=500 end end},
  {'nonfinite target',function(e) e.before_target=math.huge;e.after_target=math.huge end},
  {'permanent Arm level damage',function(e) e.blind='bl_arm' end},
  {'changed baseline world',function(e,better) if better then e.before_finishing.selected.worlds[2].progress=0.1 end end},
  {'unknown mechanics',function(e,better) if better then e.after_finishing.known_mechanics=false end end},
  {'incomplete policy',function(e,better) if better then e.after_finishing.complete=false end end},
  {'uncertain scoring',function(e,better) if better then e.uncertain=true end end},
  {'missing fourth world',function(e,better) if better then e.after_finishing.selected.worlds[4]=nil end end},
  {'nonfinite outcome',function(e,better) if better then e.after_finishing.selected.worlds[2].progress=0/0 end end},
  {'budget cutoff',function(e,better,context) if better then context.truncated=true end end},
}
for _,case in ipairs(no_dominance) do
  local old=paired(s,case[2])
  check(old.action.index==1 and not old.pack_diagnostics.planet_dominance,case[1]..' keeps the existing growth preference')
end
local later=copy(s);later.pack_cards[#later.pack_cards+1]=planet('c_pluto','High Card')
local late=Strategy.advise(later,{shop_scoring={compare=function(_,before,after)
  if ((after.hands or {})['High Card'] or {}).level==2 then return nil end
  return evidence(((after.hands or {})['Two Pair'] or {}).level==2 and 0.6 or 0.4)
end}})
check(late.action.index==1 and late.pack_diagnostics.incomplete and not late.pack_diagnostics.planet_dominance,
  'an unsupported later revealed Planet invalidates earlier dominance evidence as a whole')
local inventory=copy(s);inventory.consumeables={planet('c_pluto','High Card'),planet('c_saturn','Straight')}
inventory.consumeables[1].edition={negative=true};inventory.consumable_limit=3
local held_before=Snapshot.fingerprint(inventory.consumeables)
check(paired(inventory).action.index==2 and Snapshot.fingerprint(inventory.consumeables)==held_before and inventory.consumable_limit==3,
  'direct pack use retains all owned Negative inventory and its actual slot count')
for _,key in ipairs({'j_perkeo','j_blueprint','j_brainstorm'}) do
  local protected=copy(inventory)
  protected.jokers={{id='perkeo',key='j_perkeo',name='Perkeo',ability={name='Perkeo'}}}
  if key~='j_perkeo' then protected.jokers[#protected.jokers+1]={id='copy',key=key,name=key,ability={}} end
  check(not paired(protected).pack_diagnostics.planet_dominance,'whole-inventory '..key..' copying tradeoffs retain existing valuation')
end
local observatory=copy(inventory);observatory.used_vouchers={v_observatory=true}
check(not paired(observatory).pack_diagnostics.planet_dominance,'Observatory multipliers and long-term Planet inventory stay outside limited dominance')
for _,key in ipairs({'j_wee','j_hiker','j_burnt','j_yorick','j_square','j_castle','j_supernova','j_dna','j_green_joker','j_unknown'}) do
  local growth=copy(s);growth.jokers={{id='growth',key=key,name=key,ability={}}}
  check(not paired(growth).pack_diagnostics.planet_dominance,key..' unrecorded development cannot be overruled by next-blind progress')
  growth.jokers[1].debuff=true
  check(not paired(growth).pack_diagnostics.planet_dominance,key..' future development stays protected while currently debuffed')
end
local static=copy(s);static.jokers={{id='static',key='j_joker',name='Joker',ability={name='Joker',mult=4,set='Joker'}}}
check(paired(static).action.index==2 and paired(static).pack_diagnostics.planet_dominance,
  'unchanged static Joker scoring retains the generic paired Planet improvement')

-- Complete real scoring on a synthetic public composition: two copies per
-- rank can make Two Pair but cannot make the historically favored Four Kind.
-- This is a mechanics fixture, not a replay of any spent development attempt.
local context=Shop.new(s,Scorer);local real=Strategy.advise(s,{shop_scoring=context})
check(real.action.index==2 and real.pack_diagnostics.planet_dominance and not context.truncated,
  'real complete paired policies ground Planet development in actual deck realizability')
local old_offer,new_offer=real.pack_diagnostics.offers[1],real.pack_diagnostics.offers[2]
check(old_offer.score>new_offer.score,'the real fixture demonstrates a raw history prior overriding supported progress before the repair')
for i=1,4 do
  local a,b=old_offer.scoring_evidence.after_finishing.selected.worlds[i],new_offer.scoring_evidence.after_finishing.selected.worlds[i]
  check(b.progress>a.progress and b.population_loss<=a.population_loss and b.dollars_after>=a.dollars_after,
    'real common world '..i..' has stronger progress without cash or population damage')
end
local dominated_fingerprint=Snapshot.fingerprint(real)
check(dominated_fingerprint==Snapshot.fingerprint(Strategy.advise(s,{shop_scoring=Shop.new(s,Scorer)})),
  'complete real paired Planet choice is deterministic')
local rare=state();rare.hands={['Two Pair']={played=1,level=1}}
for i,c in ipairs(rare.playing_cards) do c.rank=i<=4 and 7 or 9;c.nominal=c.rank end
rare.next_blind.chips=1400;rare.next_blind_chips=1400
local rare_context=Shop.new(rare,Scorer);local rare_choice=Strategy.advise(rare,{shop_scoring=rare_context})
check(rare_choice.action.index==1 and not rare_context.truncated,'real duplicate-rich composition can still select Four of a Kind development')
local tiny=Decision.run(s,modules,nil,{shop_scoring={max_evaluations=1}})
check(tiny.action.index==1 and tiny.pack_diagnostics.tactical_fallback and not tiny.pack_diagnostics.planet_dominance,
  'real incomplete shared scoring falls back to the unchanged whole strategic decision')
check(Snapshot.fingerprint(s)==original,'real forecasts preserve every source fixture field')
math.random,math.randomseed=random,randomseed
print('advisor_planet_commitment: '..checks..' checks passed; real scoring evaluations '..context.evaluations..'/'..rare_context.evaluations)
