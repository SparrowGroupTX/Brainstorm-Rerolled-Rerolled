local Synergies=dofile('Brainstorm/Advisor/synergies.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(x,message) checks=checks+1; assert(x,message) end
local function equal(a,b,message) check(a==b,message..': '..tostring(a)..' ~= '..tostring(b)) end
local function near(a,b,message) check(math.abs(a-b)<1e-9,message) end
local function card(key,cost,extra)
  local out={key=key,cost=cost or 0,ability={}}
  for k,v in pairs(extra or {}) do out[k]=v end
  return out
end
local function state(extra)
  local s={phase='shop',dollars=40,ante=2,joker_limit=5,consumeables={},jokers={card('j_abstract')},
    playing_cards={{rank=2,suit='Hearts'},{rank=13,suit='Spades'},{rank=13,suit='Hearts'},
      {rank=13,suit='Diamonds'},{rank=13,suit='Clubs'},{rank=14,suit='Spades'}},
    hand={},deck={},shop_jokers={},pack_cards={},hands_left=2,interest_cap=25,interest_amount=1,
    blind={key='bl_small'},modifiers={},used_vouchers={},
    current_round={reroll_cost=5,reroll_cost_increase=0,free_rerolls=0,ancient_card={suit='Hearts'}},
    round_resets={hands=4,reroll_cost=5},
    shop_forecast={slots=2,discount_percent=0,inflation=0,rental_rate=3,
      rates={joker=20,tarot=4,planet=4,playing=0,spectral=0},used={},
      blind_rewards={Small=3,Big=4,Boss=5},pools={
        {card('j_hanging_chad',4,{rarity=1}),card('j_photograph',5,{rarity=1}),card('j_common_other',4,{rarity=1})},
        {card('j_hack',6,{rarity=2}),card('j_mime',5,{rarity=2}),card('j_hologram',7,{rarity=2})},
        {card('j_wee',8,{rarity=3}),card('j_baron',8,{rarity=3}),card('j_dna',8,{rarity=3})}}}}
  for k,v in pairs(extra or {}) do s[k]=v end
  return s
end
local function text(result) return table.concat(result.lines,' ') end
local old_random=math.random
math.random=function() error('synergy forecast must not use RNG') end

local s=state()
local candidate=card('j_wee',8)
local before=Snapshot.fingerprint(s)
local result=Synergies.forecast(s,candidate)
equal(Snapshot.fingerprint(s),before,'forecast leaves all snapshot tables unchanged')
equal(Snapshot.fingerprint(result),Snapshot.fingerprint(Synergies.forecast(s,candidate)),'forecast is deterministic')
equal(result.mode,'speculative','missing partners are explicitly speculative')
equal(#result.potential,2,'Wee recognizes both common Chad and uncommon Hack')
local expected_slot=(20/28)*(0.7/3+0.25/3)
near(result.per_slot,expected_slot,'partner chance uses actual Joker shop rate and eligible rarity pool sizes')
near(result.probability,1-(1-expected_slot)^result.horizon.slots,'horizon chance follows independent missed-slot product')
check(result.bonus>0 and result.bonus<=22,'future synergy gets a bounded discounted purchase bonus')
check(text(result):find('not a run-win probability',1,true),'shop odds cannot be confused with full-run success')
check(text(result):find('current rerolls + next 3 shops',1,true),'useful acquisition horizon is explicit')

local missing=state(); missing.shop_forecast=nil
result=Synergies.forecast(missing,candidate)
equal(result.probability,nil,'missing pool metadata never invents a probability')
equal(result.bonus,0,'missing pool metadata gives no speculative purchase bonus')
local tagged=state(); tagged.shop_forecast.special_shop_rules=true
equal(Synergies.forecast(tagged,candidate).probability,nil,'special shop tags suppress ordinary-slot probability claims')
local nojokers=state(); nojokers.shop_forecast.rates.joker=0
equal(Synergies.forecast(nojokers,candidate).probability,0,'zero shop Joker rate means no partner opportunity')

local nohand=state({playing_cards={{rank=13,suit='Spades'}}})
equal(Synergies.forecast(nohand,candidate).bonus,0,'Wee synergy requires 2s in the current deck')
local nosupport=state({jokers={card('j_egg',0,{sell_cost=20})}})
equal(Synergies.forecast(nosupport,candidate).bonus,0,'Egg assets alone do not justify speculative scoring')
local full=state({jokers={card('j_abstract'),card('j_blue_joker'),card('j_joker'),card('j_half')}})
equal(Synergies.forecast(full,candidate).bonus,0,'do not sacrifice full immediate scoring row for a future partner')

result=Synergies.forecast(state({jokers={card('j_hanging_chad')}}),card('j_photograph',5))
equal(result.mode,'owned','owned partner is an actual synergy')
equal(result.probability,nil,'owned synergy has no random acquisition probability')
check(result.bonus>=40 and text(result):find('face card first',1,true),'Photograph + Chad uses first-scoring-face positioning')
result=Synergies.forecast(state({jokers={card('j_mime')}}),card('j_baron',8))
equal(result.mode,'owned','Baron recognizes owned Mime')
check(text(result):find('Hold Kings unplayed',1,true),'Baron/Mime preserves held Kings')
result=Synergies.forecast(state({jokers={card('j_hologram')}}),card('j_dna',8))
equal(result.mode,'owned','DNA recognizes Hologram')
check(text(result):find('single-card first play',1,true),'DNA combo explains its hand cost')
result=Synergies.forecast(state({jokers={card('j_hanging_chad')}}),card('j_ancient',8))
equal(result.mode,'owned','Ancient recognizes owned Chad')
check(text(result):find('current suit first',1,true),'Ancient combo includes suit and ordering condition')

local visible=state({shop_jokers={card('j_wee',8),card('j_hanging_chad',4)}})
result=Synergies.forecast(visible,visible.shop_jokers[1])
equal(result.mode,'available','visible affordable partner is distinguished from a random future find')
equal(result.available.index,2,'visible synergy identifies its exact offer')
equal(result.probability,nil,'visible partners do not inflate randomized chance calculations')

local excluded=state(); excluded.shop_forecast.used.j_hanging_chad=true
local blocked=Synergies.forecast(excluded,candidate)
equal(#blocked.potential,1,'already-used excluded partner is absent from future pool')
excluded.shop_jokers={card('j_hanging_chad',100)}
local released=Synergies.forecast(excluded,candidate)
equal(#released.potential,2,'visible shop exclusions are released on the forecast refresh')
excluded.shop_jokers={}
excluded.jokers[#excluded.jokers+1]=card('j_ring_master')
equal(#Synergies.forecast(excluded,candidate).potential,2,'Showman allows an otherwise used partner')
excluded.jokers[2].debuff=true
equal(#Synergies.forecast(excluded,candidate).potential,1,'debuffed Showman does not lift used exclusions')

local small=state()
local larger=state(); larger.shop_forecast.slots=4; larger.used_vouchers={v_overstock_norm=true,v_overstock_plus=true}
local ordinary=Synergies.forecast(small,candidate)
local overstock=Synergies.forecast(larger,candidate)
equal(overstock.horizon.slots,ordinary.horizon.slots*2,'actual Overstock shop capacity increases opportunities')
check(overstock.probability>ordinary.probability,'more affordable slots improve acquisition odds')
local discounted=state(); discounted.round_resets.reroll_cost=1; discounted.current_round.reroll_cost=1
discounted.used_vouchers={v_reroll_surplus=true,v_reroll_glut=true}
check(Synergies.forecast(discounted,candidate).horizon.rerolls>ordinary.horizon.rerolls,'actual voucher-reduced reroll prices increase affordable searches')
local dear=state(); dear.current_round.reroll_cost=12; dear.current_round.reroll_cost_increase=7
check(Synergies.forecast(dear,candidate).horizon.stages[1].rerolls<ordinary.horizon.stages[1].rerolls,'current paid reroll history reduces current opportunities')
local free=state(); free.current_round.free_rerolls=2; free.current_round.reroll_cost=0
local free_horizon=Synergies.forecast(free,candidate).horizon
check(free_horizon.stages[1].rerolls>=ordinary.horizon.stages[1].rerolls+2,'remaining free rerolls are available before paid refreshes')
local reset=state(); reset.jokers[#reset.jokers+1]=card('j_chaos'); reset.current_round.free_rerolls=0
check(Synergies.forecast(reset,candidate).horizon.stages[2].rerolls>=ordinary.horizon.stages[2].rerolls,'Chaos resets future free rerolls, not already-consumed current freebies')

local egg=state({challenge='c_omelette_1',dollars=20,jokers={card('j_abstract'),card('j_egg',0,{sell_cost=60,ability={extra=3}})}})
local eh=Synergies.forecast(egg,candidate).horizon
equal(eh.projected_income,0,'Omelette forecast includes no blind/unused-hand/interest cash')
equal(eh.resale_growth,9,'Egg gains $3 resale per modeled completed round')
check(eh.reroll_spend<=eh.starting_cash,'an unsold $60 Egg does not fund any reroll')
egg.jokers[1].ability.rental=true
local rent=Synergies.forecast(egg,candidate).horizon
equal(rent.rental_drain,9,'rental drains use the actual $3 rate across three rounds')
equal(rent.projected_income,-9,'Omelette rental drain cannot be hidden by imaginary income')
local late=state({ante=8,blind={key='bl_big'}})
equal(Synergies.forecast(late,candidate).horizon.future_shops,0,'no partner forecast extends beyond the ante-8 finish')

local cheaper=state(); cheaper.shop_forecast.discount_percent=50
local ch=Synergies.forecast(cheaper,candidate)
check(ch.horizon.reserve<ordinary.horizon.reserve,'known shop discount reduces partner purchase reserve')
local inflated=state(); inflated.shop_forecast.inflation=4
check(Synergies.forecast(inflated,candidate).horizon.reserve>ordinary.horizon.reserve,'current inflation raises the future partner price reserve')
math.random=old_random
print('advisor_synergies: '..checks..' checks passed')
