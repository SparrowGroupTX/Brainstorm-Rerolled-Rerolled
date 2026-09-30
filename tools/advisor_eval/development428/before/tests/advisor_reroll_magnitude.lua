local R=dofile('Brainstorm/Advisor/paid_reroll.lua')
local C=dofile('Brainstorm/Advisor/catalog_joker.lua');R.catalog=C
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,message) checks=checks+1;assert(v,message) end
local function copy(v) return Snapshot.copy(v) end
local function entry(key,cost)
  return {key=key,name='Joker',cost=cost or 4,rarity=1,source_set='Joker',source_config={mult=4}}
end
local function state()
  return {phase='shop',dollars=13,bankrupt_at=-20,ante=2,reroll_cost=5,joker_limit=5,jokers={},
    shop_jokers={},round_resets={hands=1,discards=6},modifiers={discard_cost=1},
    shop_forecast={slots=2,rental_rate=3,edition_rate=1,used={},rates={joker=1,tarot=0,planet=0,playing=0,spectral=0},
      pools={{entry('j_banner'),entry('j_joker')},{entry('j_abstract')},{entry('j_duo')}}}}
end
local function ready(scores,status)
  local sum=0;local clears=0
  for _,score in ipairs(scores) do sum=sum+score;if score>=600 then clears=clears+1 end end
  return {supported=true,status=status or 'unresolved',target=600,hands=1,discards=6,
    opening_scores=scores,opening_mean=sum/4,clearing_samples=clears,capacity_proxy=650}
end
local before=ready({100,150,200,650})
local function evidence(scores) return {before_readiness=copy(before),after_readiness=ready(scores),uncertain=false} end
local function positive() return evidence({600,650,700,800}) end
local s=state();local fingerprint=Snapshot.fingerprint(s);local calls=0
local result=R.suggest(s,function() return 60 end,{before_readiness=before},
  {compare=function() calls=calls+1;return positive() end})
check(result and result.reroll_forecast.mode=='scoring_shortfall' and calls==4,'complete source-catalog shortlist produces opportunity advice')
check(result.reroll_forecast.purchase_floor==-14 and result.reroll_forecast.survival_reserve==6,
  'observed paid discards reserve all six dollars above the actual purchase debt limit')
check(result.reroll_forecast.failed_search_cost==5 and result.reroll_forecast.expected_cash_spend>5,
  'every search fee and potential purchase expenditure remains in expected cost')
check(Snapshot.fingerprint(s)==fingerprint,'tactical reroll does not mutate its state')
check(not result.reroll_forecast.win_probability and result.reroll_forecast.shortlist_complete,'opportunity forecast never becomes win probability')
check(math.abs(result.reroll_forecast.covered_pool_mass-0.96)<0.000001 and
  result.reroll_forecast.edition_outcomes=='unassessed_zero_credit',
  'base-price affordability applies only to no-edition probability; premium-price outcomes receive zero credit')
local editions=copy(s);editions.shop_forecast.edition_rate=25
check(R.suggest(editions,function() error('guaranteed edition counted at base price') end,{before_readiness=before},
  {compare=positive})==nil,'zero no-edition mass cannot invent an affordable ordinary offer')
local no_debt=copy(s);no_debt.bankrupt_at=0
check(R.suggest(no_debt,function() return 60 end,{before_readiness=before},{compare=positive})==nil,
  'the same low cash cannot spend money reserved for paid discards without a real debt facility')
local generic=copy(s);generic.dollars=50;generic.modifiers={};generic.bankrupt_at=0
check(R.suggest(generic,function() return true end,nil)~=nil,'ordinary legacy generic path remains available to its original callers')
local generic_calls=0
check(R.suggest(generic,function() generic_calls=generic_calls+1;return true end,nil,
  {compare=positive,tactical_only=true})==nil and generic_calls==0,
  'tactical-only integration cannot override unsupported current advice using the weaker generic fallback')
local unsupported=copy(s);unsupported.shop_forecast.pools[1][2]=entry('unknown_mechanics')
local limited=R.suggest(unsupported,function() return 60 end,{before_readiness=before},{compare=positive})
check(limited and limited.reroll_forecast.covered_pool_mass<1 and limited.reroll_forecast.unknown_pool_mass>0,
  'unsupported source effects keep their probability mass but receive no upgrade credit')
local incomplete_calls=0
local incomplete=R.suggest(s,function() return 60 end,{before_readiness=before},{compare=function()
  incomplete_calls=incomplete_calls+1;if incomplete_calls==3 then return nil,'incomplete' end;return positive()
end})
check(incomplete==nil and incomplete_calls==3,'a truncated later comparison rejects earlier favorable results')
local uncertain=R.suggest(s,function() return 60 end,{before_readiness=before},{compare=function()
  local e=positive();e.uncertain=true;return e
end})
check(uncertain==nil,'unknown random score evidence contributes no improvement')
check(R.suggest(s,function() return 60 end,{before_readiness=before},{compare=function() return evidence({100,150,200,650}) end})==nil,
  'a large count of strategically relevant but zero-improvement offers does not justify refresh')
check(R.suggest(s,function() return 60 end,{before_readiness=before},
  {compare=positive,visible_evidence=positive(),visible_cost=1})==nil,'cheap visible scoring wins over a speculative paid search')
local safe=copy(before);safe.status='sampled_safe'
check(R.suggest(s,function() error('safe row assessed speculative purchase') end,{before_readiness=safe},{compare=positive})==nil,
  'proven sampled safety preserves cash before catalog evaluation')
local big=copy(s);big.dollars=100;big.shop_forecast.pools[1]={}
for _,key in ipairs({'j_joker','j_jolly','j_zany','j_mad','j_crazy','j_droll','j_banner','j_sly'}) do
  big.shop_forecast.pools[1][#big.shop_forecast.pools[1]+1]=entry(key)
end
local order={}
local bounded=R.suggest(big,function() return true end,{before_readiness=before},{shortlist_limit=99,compare=function(e)
  order[#order+1]=e.key;return positive()
end})
check(bounded and #order==6,'catalog comparisons never exceed six even with excessive requested limit')
local order2={}
R.suggest(big,function() return true end,{before_readiness=before},{compare=function(e) order2[#order2+1]=e.key;return positive() end})
check(table.concat(order,',')==table.concat(order2,','),'shortlist uses stable deterministic tie breaks')
local c=assert(C.create(entry('j_joker'),5,{hands_played_total=9}))
check(c.ability.mult==4 and c.ability.x_mult==1 and c.sell_cost==2 and c.ability.hands_played_at_create==9,
  'detached base constructor uses original defaults and observed creation counter')
local unknown=entry('j_joker');unknown.source_config=nil
check(C.create(unknown,5)==nil,'a supported key without actual source config cannot invent its values')
unknown=entry('j_misprint')
check(C.create(unknown,5)==nil,'random or unmodeled prospective effects are explicit unsupported')
unknown=entry('j_joker');unknown.source_config.mult=0/0
check(C.create(unknown,5)==nil,'invalid source scoring fields fail closed')
check(C.no_edition_probability(-1)==nil and C.no_edition_probability(nil)==nil and
  math.abs(C.no_edition_probability(0)-0.997)<0.000001,'edition-rate metadata is explicit and retains the source negative branch')
check(math.abs(R.opening_gain(positive())-0.5625)<0.00000001,'target clipping does not reward excessive overkill')
print('advisor_reroll_magnitude: '..checks..' checks passed')
