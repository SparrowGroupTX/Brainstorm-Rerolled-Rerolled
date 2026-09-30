local R=dofile('Brainstorm/Advisor/paid_reroll.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(x,message) checks=checks+1;assert(x,message) end
local function near(a,b) return math.abs(a-b)<1e-9 end
local function copy(x) return Snapshot.copy(x) end
local function entry(key,hand)
  return {key=key,name=key,cost=3,source_set='Planet',source_effect='Hand Upgrade',source_config={hand_type=hand}}
end
local function evidence(after)
  return {before_readiness={supported=true,status='sampled_deficit',target=100,hands=1,discards=0,
      opening_scores={20,20,20,20},opening_mean=20},
    after_readiness={supported=true,status='sampled_deficit',target=100,hands=1,discards=0,
      opening_scores={after,after,after,after},opening_mean=after}}
end
local function state()
  return {phase='shop',ante=3,dollars=30,reroll_cost=2,bankrupt_at=0,joker_limit=0,jokers={},
    consumeables={},consumable_limit=2,shop_jokers={},modifiers={},hands={},hand={},deck={},playing_cards={},
    round_resets={hands=1,discards=0},current_round={},
    shop_forecast={consumable_pool_schema='source_shop_consumables_v1',consumable_used={},
      planet_pool={entry('c_mercury','Pair'),entry('c_jupiter','Flush')},tarot_pool={},
      pools={{},{},{}},slots=2,inflation=0,discount_percent=0,rental_rate=3,
      rates={joker=0,tarot=4,planet=4,playing=0,spectral=0}}}
end
local function options()
  return {compare=function(e) return evidence(e.key=='c_mercury' and 100 or 20) end,
    compare_miss=function() return evidence(20) end}
end
local function advise(s,o) return R.planet_suggest(s,function() return 1 end,evidence(20),o or options()) end
local random,seed=math.random,math.randomseed
math.random=function() error('Planet refresh advanced RNG') end
math.randomseed=function() error('Planet refresh reseeded RNG') end
local s=state();local fingerprint=Snapshot.fingerprint(s);local advice=advise(s)
check(advice and advice.action.kind=='reroll' and advice.reroll_forecast.mode=='planet_shortfall',
  'a generic zero Joker rate and zero Joker capacity allow source-supported Planet refresh')
check(near(advice.reroll_forecast.opportunity_mass,0.25) and near(advice.reroll_forecast.covered_pool_mass,0.5) and
  near(advice.reroll_forecast.unknown_pool_mass,0.5),'actual first-slot Planet type and eligible pool shares keep Tarot mass unknown')
check(near(advice.reroll_forecast.expected_cash_spend,2.75) and near(advice.reroll_forecast.expected_shortfall_reduction,0.2),
  'refresh is paid on every outcome while only supported useful first-slot purchases receive cost and gain')
check(not advice.reroll_forecast.probability and not advice.reroll_forecast.win_probability and
  table.concat(advice.lines,' '):find('not a win chance',1,true),'catalog opportunity never claims exact odds or a win rate')
check(Snapshot.fingerprint(s)==fingerprint and Snapshot.fingerprint(advice)==Snapshot.fingerprint(advise(s)),
  'Planet refresh is deterministic and leaves all detached input data unchanged')
local more=copy(s);more.shop_forecast.slots=8
check(near(advise(more).reroll_forecast.opportunity_mass,0.25),'later sequential shop slots do not gain independent duplicate credit')
local legacy=copy(s);legacy.shop_forecast.rates.joker=20
check(not advise(legacy),'nonzero Joker rates retain the existing Joker refresh path')
local stale=copy(s);stale.shop_forecast.consumable_pool_schema=nil
check(not advise(stale),'old snapshots without consumable pool provenance decline new advice')
local invalid=copy(s);invalid.shop_forecast.rates.tarot=0/0
check(not advise(invalid),'invalid rates never turn into numeric opportunity estimates')
local tagged=copy(s);tagged.shop_forecast.special_shop_rules=true
check(not advise(tagged),'forced tags and tutorial shops decline ordinary source pool assumptions')
local inflation=copy(s);inflation.modifiers.inflation=true
check(not advise(inflation),'purchase-triggered global repricing remains explicit unsupported')
local exhausted=copy(s);exhausted.reroll_cost=9
check(not advise(exhausted),'existing eight-dollar paid search cost ceiling is preserved')
exhausted.reroll_cost=0;check(not advise(exhausted),'free refresh remains the existing separate action')
local held=copy(s);held.shop_forecast.consumable_used.c_mercury=true
check(not advise(held),'excluded held targets contribute no opportunity mass')
held.shop_jokers={R.planet_card(held.shop_forecast.planet_pool[1],3)}
check(advise(held),'current shop offers reenter the prospective first-slot pool')
held.consumeables=copy(held.shop_jokers)
check(not advise(held),'retained inventory reasserts duplicate exclusion after an old offer is removed')
held.shop_jokers={};held.jokers={{key='j_ring_master',ability={}}}
check(advise(held),'active Showman permits source duplicate Planet offers')
held.jokers[1].debuff=true;check(not advise(held),'debuffed Showman does not remove source duplicate exclusions')
local full=copy(s);full.consumeables={{key='c_strength',edition='negative'},{key='c_death'}}
check(not advise(full),'actual full capacity counts Negative cards without inventing a sale or use')
full.consumable_limit=3;check(advise(full),'observed capacity already includes the Negative slot contribution')
local price=copy(s);price.shop_forecast.inflation=2;price.shop_forecast.discount_percent=25
local price_options=options();local prices={}
price_options.compare=function(e,c) prices[#prices+1]=c;return evidence(100) end
check(advise(price,price_options) and prices[1]==4,'source rounded discount and current inflation determine prospective Planet prices')
price.jokers={{key='j_astronomer',ability={}}};prices={}
check(advise(price,price_options) and prices[1]==0,'active Astronomer sets source Planet prices to zero')
price.jokers[1].debuff=true;prices={}
check(advise(price,price_options) and prices[1]==4,'debuffed Astronomer cannot promise free Planets')
local broke=copy(s);broke.dollars=4
check(not advise(broke),'the refresh and prospective purchase must both be affordable')
local reserve=copy(s);reserve.dollars=8;reserve.modifiers.discard_cost=2
local ready=evidence(20);ready.before_readiness.discards=2
check(not R.planet_suggest(reserve,function() return 1 end,ready,options()),'paid discard reserves survive even successful Planet searches')
local debt=copy(s);debt.dollars=0;debt.bankrupt_at=-10
check(advise(debt),'actual debt allowance can fund a supported purchase without imagined sale proceeds')
local miss=options();miss.compare_miss=function() return evidence(0) end
check(near(advise(s,miss).reroll_forecast.expected_shortfall_reduction,0.05),'all uncredited first-slot outcomes still charge their cash-sensitive miss loss')
miss.compare_miss=function() return evidence(100) end
check(near(advise(s,miss).reroll_forecast.expected_shortfall_reduction,0.2),'positive miss growth is recorded without gaining forecast credit')
miss.compare_miss=function() return nil,'incomplete' end
check(not advise(s,miss),'incomplete miss comparison invalidates all useful hit evidence')
local partial=options();local calls=0
partial.compare=function() calls=calls+1;if calls==2 then return nil,'incomplete' end;return evidence(100) end
check(not advise(s,partial) and calls==2,'late comparison cutoff cannot select an earlier favorable partial shortlist')
local visible=options();visible.visible_evidence=evidence(100);visible.visible_cost=3
check(not advise(s,visible),'a better complete visible purchase prevents speculative paid refresh')
local unsupported=copy(s);unsupported.shop_forecast.planet_pool[1].source_config.unmodeled=true
check(not advise(unsupported),'modified source Planet mechanics earn zero useful mass')
local empty=copy(s);empty.shop_forecast.planet_pool={}
check(not advise(empty),'exceptional empty-pool Pluto fallback is unassessed rather than fabricated')
local safe=evidence(20);safe.before_readiness.status='sampled_safe'
check(not R.planet_suggest(s,function() return 1 end,safe,options()),'supported safe openings preserve cash')

-- Exercise real strategy transitions with a deterministic paired-score stub.
-- These checks inspect cash, levels and complete whole-inventory endpoints;
-- actual scoring is covered below under its existing shared evaluation cap.
R.catalog=dofile('Brainstorm/Advisor/catalog_joker.lua');Strategy.paid_reroll=R
Strategy.consumables=dofile('Brainstorm/Advisor/consumables.lua')
local base={action={kind='leave_shop'}}
local context={states={},compare=function(self,before,after)
  self.states[#self.states+1]=copy(after)
  return evidence(((after.hands or {}).Pair or {}).level==2 and 100 or 20)
end}
local integrated=Strategy.shortfall_reroll(s,base,context)
check(integrated and integrated.reroll_forecast.shortlist[1].planet_plan,
  'runtime strategy routes actual zero-rate shops to bounded Planet endpoint comparisons')
local found_use,found_hold,found_miss=false,false,false
for _,after in ipairs(context.states) do
  if ((after.hands or {}).Pair or {}).level==2 then found_use=after.dollars==25 and #after.consumeables==0 end
  if #after.consumeables==1 then found_hold=found_hold or after.dollars==25 end
  if after.dollars==28 and #after.consumeables==0 then found_miss=true end
end
check(found_use and found_hold and found_miss,'runtime endpoints charge refresh and purchase, compare holding and exact Planet use, and pay cash-only miss')
check(Snapshot.fingerprint(s)==fingerprint,'runtime hold/use and usage counters cannot mutate the original shop')
local truncated={compare=function(self) self.truncated=true;return evidence(100) end}
check(not Strategy.shortfall_reroll(s,base,truncated),'shared scoring cutoff cannot produce new Planet refresh advice')
local perkeo=copy(s);perkeo.jokers={{key='j_perkeo',name='Perkeo',ability={name='Perkeo'}}}
local protected={uses=0,compare=function(self,before,after)
  if ((after.hands or {}).Pair or {}).level==2 then self.uses=self.uses+1 end
  return evidence(((after.hands or {}).Pair or {}).level==2 and 100 or 20)
end}
check(not Strategy.shortfall_reroll(perkeo,base,protected) and protected.uses==0,
  'prospective last useful Planet type is kept for the full Perkeo copying inventory')
local dilution=copy(perkeo);dilution.consumeables={{key='c_mercury',name='Mercury',edition='negative',ability={set='Planet'}}}
dilution.shop_forecast.planet_pool={entry('c_jupiter','Flush')};dilution.hands.Pair={played=8}
local diluted={compare=function(self,before,after) return evidence(#after.consumeables>1 and 100 or 20) end}
check(not Strategy.shortfall_reroll(dilution,base,diluted),'an attractive held-score stub cannot override weakened whole Perkeo inventory value')

local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua');local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
local real=state();real.hand_size=8;real.hand_limit=5;real.probabilities={normal=1}
real.next_blind={key='bl_small',chips=600};real.shop_forecast.planet_pool={entry('c_jupiter','Flush')}
for i,r in ipairs({2,2,4,4,6,6,8,8}) do real.playing_cards[i]={id='p:'..i,rank=r,suit='Spades',nominal=r,ability={}} end
local paired=Shop.new(real,Scorer);local real_advice=Strategy.shortfall_reroll(real,base,paired)
check(real_advice and real_advice.reroll_forecast.mode=='planet_shortfall' and not paired.truncated,
  'real scorer completes a generic no-Joker Planet upgrade within the shared shop budget')
local small=Shop.new(real,Scorer,nil,{max_evaluations=1})
check(not Strategy.shortfall_reroll(real,base,small) and small.truncated,'real insufficient scoring budget preserves the original visible advice')
math.random,math.randomseed=random,seed
print('advisor_planet_reroll: '..checks..' checks passed; real scoring evaluations '..paired.evaluations)
