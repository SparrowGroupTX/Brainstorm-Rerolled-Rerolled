local Reroll=dofile('Brainstorm/Advisor/paid_reroll.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(ok,message) checks=checks+1; assert(ok,message) end
local function copy(v) return Snapshot.copy(v) end
local function near(a,b) return math.abs(a-b)<0.000000001 end
local function entry(key,cost,rarity)
  return {key=key,name=key,cost=cost or 4,rarity=rarity or 1,ability={set='Joker'}}
end
local function state()
  return {phase='shop',ante=3,dollars=50,reroll_cost=5,interest_cap=25,next_blind_chips=400,
    jokers={},joker_limit=5,consumeables={},hand={},deck={},playing_cards={},hands={},
    shop_jokers={},shop_booster={},shop_vouchers={},pack_cards={},modifiers={},
    round_resets={hands=4,discards=3},current_round={},
    shop_forecast={slots=2,inflation=0,discount_percent=0,rental_rate=3,used={},
      rates={joker=20,tarot=4,planet=4,playing=0,spectral=0},pools={
        {entry('j_common_good',4,1),entry('j_common_bad',4,1)},
        {entry('j_uncommon_good',4,2),entry('j_uncommon_bad',4,2)},
        {entry('j_rare_good',4,3),entry('j_rare_bad',4,3)}}}}
end
local function useful(e) return e.key:find('_good',1,true)~=nil end
local random,seed=math.random,math.randomseed
math.random=function() error('paid reroll advanced game RNG') end
math.randomseed=function() error('paid reroll reseeded game RNG') end
local s=state(); local before=Snapshot.fingerprint(s)
local e=Reroll.suggest(s,useful)
local per_slot=(20/28)*0.5
check(e and e.action.kind=='reroll' and near(e.reroll_forecast.probability,1-(1-per_slot)^2),
  'one paid reroll uses actual Joker rate, rarity weights and eligible pool counts')
check(e.reroll_forecast.cost==5 and e.reroll_forecast.purchase_floor==25 and e.reroll_forecast.reserve==33,
  'a nonurgent refresh reserves a purchase budget and the current maximum-interest floor')
check(table.concat(e.lines,' '):find('not a win chance',1,true) and
  table.concat(e.lines,' '):find('approximate independent offers',1,true),
  'the find chance explicitly identifies its approximation and never claims a win probability')
check(Snapshot.fingerprint(s)==before and Snapshot.fingerprint(e)==Snapshot.fingerprint(Reroll.suggest(s,useful)),
  'one-refresh advice is deterministic and does not mutate the snapshot or game RNG')
local overstock=copy(s); overstock.shop_forecast.slots=4
local more=Reroll.suggest(overstock,useful)
check(more and near(more.reroll_forecast.probability,1-(1-per_slot)^4) and more.reroll_forecast.probability>e.reroll_forecast.probability,
  'Overstock shop slots increase only the actual one-refresh opportunity count')
local costly=copy(s); costly.reroll_cost=8
check(Reroll.suggest(costly,useful)==nil,'rising reroll cost eventually exceeds the same finding opportunity value')
costly.reroll_cost=9
check(Reroll.suggest(costly,function() return true end)==nil,'the optional paid refresh has a hard cost ceiling')
local discounted=copy(s); discounted.reroll_cost=nil; discounted.current_round.reroll_cost=1
local cheap=Reroll.suggest(discounted,useful)
check(cheap and cheap.reroll_forecast.cost==1,'the observed discounted current reroll price is respected')
discounted.current_round.reroll_cost=0
check(Reroll.suggest(discounted,useful)==nil,'free rerolls remain the separate free-action path')

local excluded=copy(s)
for _,rarity in ipairs(excluded.shop_forecast.pools) do excluded.shop_forecast.used[rarity[1].key]=true end
check(Reroll.suggest(excluded,useful)==nil,'used excluded targets contribute no finding chance')
for _,rarity in ipairs(excluded.shop_forecast.pools) do excluded.shop_jokers[#excluded.shop_jokers+1]=copy(rarity[1]) end
check(near(Reroll.suggest(excluded,useful).reroll_forecast.probability,e.reroll_forecast.probability),
  'current offers return to the available pool after the one refresh')
excluded.shop_jokers={}; excluded.jokers={entry('j_ring_master')}
check(Reroll.suggest(excluded,useful)~=nil,'an active Showman lifts duplicate exclusions')
excluded.jokers[1].ability={perishable=true,perish_tally=0}
check(Reroll.suggest(excluded,useful)==nil,'an expired Showman cannot enable excluded duplicates')
local no_jokers=copy(s); no_jokers.shop_forecast.rates.joker=0
check(Reroll.suggest(no_jokers,useful)==nil,'a shop with zero Joker rate never promises a Joker opportunity')
local no_useful=Reroll.suggest(s,function() return false end)
check(no_useful==nil,'a complete pool containing no strategic upgrade does not justify paid rerolling')
local impossible=copy(s); impossible.shop_forecast.pools[3]=nil
local calls=0
check(Reroll.suggest(impossible,function() calls=calls+1; return true end)==nil and calls==0,
  'incomplete rarity metadata is rejected before candidate assessments')
local bad_rates=copy(s); bad_rates.shop_forecast.rates.joker=0/0
check(Reroll.suggest(bad_rates,useful)==nil,'invalid probability metadata never produces a NaN forecast')
local tagged=copy(s); tagged.shop_forecast.special_shop_rules=true
check(Reroll.suggest(tagged,useful)==nil,'special forced-offer rules decline the ordinary shop probability model')
local jokerless=copy(s); jokerless.challenge={id='c_jokerless_1'}
check(Reroll.suggest(jokerless,useful)==nil,'Jokerless challenge identifiers suppress Joker-refresh advice')
local tiny=copy(s); tiny.shop_forecast.rates={joker=1,tarot=99,planet=0,playing=0,spectral=0}; tiny.reroll_cost=1
check(Reroll.suggest(tiny,useful)==nil,'a negligible upgrade chance is not worth even a discounted paid refresh')

local healthy=Reroll.suggest(s,useful,{before_mean=200})
check(healthy==nil,'a comfortably sufficient estimated scoring row preserves its cash')
local restricted=copy(s);restricted.dollars=20
local restricted_e=Reroll.suggest(restricted,useful,{before_mean=200,
  before_readiness={supported=true,status='sampled_deficit',target=400,hands=1,capacity_proxy=200}})
check(restricted_e and restricted_e.reroll_forecast.urgent and restricted_e.reroll_forecast.pressure_capacity==200,
  'actual one-hand blind pressure overrides generic four-hand shop capacity')
check(Reroll.suggest(s,useful,{before_mean=20,
  before_readiness={supported=true,status='sampled_safe',target=40,capacity_proxy=80}})==nil,
  'supported actual-blind safety preserves cash even when old target metadata differs')
local unresolved=Reroll.suggest(s,useful,{before_mean=200,
  before_readiness={supported=true,status='unresolved',target=400,capacity_proxy=800}})
check(unresolved and not unresolved.reroll_forecast.urgent,
  'a repeated-opening capacity proxy does not manufacture safety or emergency spending')
local bonus=copy(s); bonus.shop_forecast.round_bonus={next_hands=2}
check(Reroll.suggest(bonus,useful,{before_mean=110})==nil,
  'known next-round bonus hands contribute to the conservative pressure check')
local urgent=copy(s); urgent.dollars=20
local urgent_e=Reroll.suggest(urgent,useful,{before_mean=50})
check(urgent_e and urgent_e.reroll_forecast.urgent and urgent_e.reroll_forecast.interest_floor==0,
  'known scoring pressure may spend below the interest floor while keeping actual upgrade money')
urgent.dollars=12
check(Reroll.suggest(urgent,useful,{before_mean=50})==nil,'urgent advice still cannot consume its purchase reserve or borrow money')
local omelette=copy(s); omelette.challenge={id='c_omelette_1'}; omelette.dollars=20
omelette.jokers={entry('j_egg')}; omelette.jokers[1].sell_cost=100
local egg_e=Reroll.suggest(omelette,useful)
check(egg_e and egg_e.reroll_forecast.interest_floor==0,'Omelette does not reserve nonexistent interest income')
omelette.dollars=12
check(Reroll.suggest(omelette,useful)==nil,'an Egg with large resale value is not treated as already-spendable cash')
local rent=copy(s); rent.modifiers.no_interest=true; rent.dollars=19
rent.jokers={entry('j_egg'),entry('j_golden')}; rent.jokers[1].ability.rental=true; rent.jokers[2].ability.rental=true
local rent_e=Reroll.suggest(rent,useful)
check(rent_e and rent_e.reroll_forecast.survival_reserve==6 and rent_e.reroll_forecast.purchase_floor==6,
  'near-term rental payments are kept after the prospective purchase')
rent.dollars=18
check(Reroll.suggest(rent,useful)==nil,'the last rental-reserve dollar is not spent on a speculative refresh')
local needle=copy(s); needle.challenge='c_golden_needle_1'; needle.modifiers={discard_cost=1,no_interest=true}
needle.round_resets={hands=1,discards=6}; needle.dollars=23
local needle_e=Reroll.suggest(needle,useful)
check(needle_e and needle_e.reroll_forecast.survival_reserve>=10,
  'Golden Needle reserves its paid-discard survival money before rerolling')
needle.dollars=22
check(Reroll.suggest(needle,useful)==nil,'Golden Needle cannot spend its paid-discard reserve')

local luxury=copy(s); luxury.dollars=40
for _,rarity in ipairs(luxury.shop_forecast.pools) do rarity[1].cost=12 end
check(Reroll.suggest(luxury,useful)==nil,
  'an expensive prospective purchase cannot secretly consume the supposedly protected interest floor')
luxury.shop_forecast.discount_percent=25
local observed_price
local sale=Reroll.suggest(luxury,function(candidate,price)
  if useful(candidate) then observed_price=price; return true end
end)
check(sale and observed_price==9,'future ordinary prices use the observed shop discount')
luxury.shop_forecast.inflation=4
check(Reroll.suggest(luxury,useful)==nil,'inflation can make formerly affordable upgrade outcomes unavailable')

local full=copy(s); full.joker_limit=2; full.jokers={entry('j_joker'),entry('j_ramen')}
for _,j in ipairs(full.jokers) do j.ability.eternal=true end
local full_calls=0
check(Reroll.suggest(full,function() full_calls=full_calls+1; return true end)==nil and full_calls==0,
  'a full Eternal row is rejected before any 150-card pool scan')
full.jokers[2].ability.eternal=nil; full.jokers[2].edition={negative=true}
check(Reroll.suggest(full,function() return true end)==nil,
  'selling a Negative Joker would remove its slot, so it cannot make ordinary upgrade space')
full.jokers[2]=entry('j_invisible'); full.jokers[2].ability={extra=2,invis_rounds=2}
check(Reroll.suggest(full,function() return true end)==nil,
  'a charged Invisible Joker replaces itself and cannot promise a free ordinary slot')
full.jokers[2]=entry('j_egg')
check(Reroll.suggest(full,function() return true end)~=nil,'a full row with a usable non-Negative sacrifice may consider a known upgrade')
full.modifiers.all_eternal=true
check(Reroll.suggest(full,function() return true end)==nil,'the all-Eternal challenge rule protects every full slot')

-- Exercise the real strategy callback, not just a synthetic assessment.
Strategy.paid_reroll=Reroll
Strategy.synergies=dofile('Brainstorm/Advisor/synergies.lua')
local integrated=state()
integrated.shop_forecast.pools={
  {entry('j_popcorn',5,1),entry('j_credit_card',1,1)},
  {entry('j_stuntman',7,2),entry('j_credit_card',1,2)},
  {entry('j_cavendish',4,3),entry('j_credit_card',1,3)}}
local advice=Strategy.advise(integrated)
check(advice.action.kind=='reroll' and advice.reroll_forecast and advice.title:find('Reroll',1,true),
  'the real strategy publishes coherent paid-reroll title, action and probability metadata')
integrated.joker_limit=1; integrated.jokers={entry('j_joker')}; integrated.jokers[1].ability.eternal=true
check(Strategy.advise(integrated).action.kind=='leave_shop','strategy leaves a full Eternal row instead of advertising impossible upgrades')
local mature=copy(integrated); mature.ante=8; mature.next_blind_chips=500000
mature.jokers={entry('j_green_joker')}; mature.jokers[1].ability={set='Joker',name='Green Joker',mult=100,extra={hand_add=1}}
mature.shop_forecast.pools={{entry('j_credit_card',1,1)},{entry('j_stuntman',7,2)},{entry('j_cavendish',4,3)}}
check(Strategy.advise(mature).action.kind=='leave_shop',
  'a mature +100 Green Joker is not a speculative sacrifice merely because its age-based base rating is low')
local filler=copy(mature); filler.jokers={entry('j_egg')}; filler.reroll_cost=4
check(Strategy.advise(filler).action.kind=='reroll','a weak Egg filler can still justify searching for a substantial immediate upgrade')
local old_forecast=Strategy.synergies.forecast
local nested=0
Strategy.synergies.forecast=function(snapshot,candidate)
  if snapshot.shop_forecast then nested=nested+1 end
  return old_forecast(snapshot,candidate)
end
Strategy.advise(filler)
check(nested==0,'pool-candidate assessments retain owned synergies without nested future-shop probability scans')
Strategy.synergies.forecast=old_forecast
local egg_core=copy(mature); egg_core.joker_limit=2
egg_core.jokers={entry('j_egg'),entry('j_swashbuckler')}
egg_core.jokers[1].sell_cost=60; egg_core.jokers[2].ability={set='Joker',name='Swashbuckler',mult=60}
check(Strategy.advise(egg_core).action.kind=='leave_shop',
  'an Egg feeding a retained Swashbuckler is protected from hypothetical filler replacement odds')
local temporal=state(); temporal.hand_size=8; temporal.hand_limit=1
temporal.shop_forecast=copy(integrated.shop_forecast); temporal.jokers={entry('j_card_sharp')}
temporal.jokers[1].name='Card Sharp'; temporal.jokers[1].ability={name='Card Sharp',extra={Xmult=3}}
for i=1,8 do temporal.playing_cards[i]={id='card:'..i,rank=i+1,suit='Spades',ability={}} end
local shop=Shop.new(temporal,Scorer)
local readiness=shop:compare(temporal,temporal)
local temporal_e=Reroll.suggest(temporal,function() return true end,readiness)
check(readiness and readiness.temporal and temporal_e and temporal_e.reroll_forecast.pressure_capacity>0,
  'conditional temporal shop evidence can supply pressure without becoming a win probability')
check(temporal_e.reroll_forecast.probability<=1 and not temporal_e.reroll_forecast.win_probability,
  'the only reported probability remains the pool-based affordable-upgrade opportunity')
math.random,math.randomseed=random,seed
print('advisor_paid_reroll: '..checks..' checks passed')
