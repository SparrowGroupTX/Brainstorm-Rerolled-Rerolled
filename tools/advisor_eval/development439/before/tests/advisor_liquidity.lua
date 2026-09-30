local L=dofile('Brainstorm/Advisor/liquidity.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Sequences=dofile('Brainstorm/Advisor/shop_sequences.lua')
local Conditional=dofile('Brainstorm/Advisor/conditional_value.lua')
local Reroll=dofile('Brainstorm/Advisor/paid_reroll.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
L.snapshot=Snapshot
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
Strategy.liquidity=L;Conditional.liquidity=L;Reroll.liquidity=L
Strategy.conditional_value=Conditional;Strategy.consumables=Consumables
Reroll.catalog=dofile('Brainstorm/Advisor/catalog_joker.lua')
local checks=0
local function check(x,message) assert(x,message);checks=checks+1 end
local function copy(x) return Snapshot.copy(x) end
local function joker(key,cost,ability)
  ability=ability or {};ability.set='Joker'
  return {key=key,cost=cost or 0,base_cost=cost or 0,sell_cost=2,ability=ability}
end
local function state()
  local s={phase='shop',ante=2,dollars=10,bankrupt_at=-20,hand_size=8,hand_limit=5,joker_limit=5,
    rental_rate=4,jokers={},consumeables={},consumable_limit=2,playing_cards={},hands={},
    round_resets={hands=1,discards=6},modifiers={discard_cost=2},current_round={},
    next_blind={key='bl_small',chips=600},probabilities={normal=1},reroll_cost=5,
    shop_jokers={},shop_forecast={edition_rate=1,rental_rate=3,slots=2,discount_percent=0,inflation=0,
      rates={joker=1,tarot=0,planet=0,playing=0,spectral=0},used={},pools={
      {{key='j_joker',name='Joker',source_set='Joker',source_config={mult=4},rarity=1,cost=2}},{},{}}}}
  for i=1,8 do s.playing_cards[i]={id='p:'..i,rank=i+1,suit='Spades',ability={}} end
  return s
end
local ready={supported=true,status='sampled_deficit',target=600,hands=1,discards=6}
local s=state();s.jokers={joker('j_joker',1,{rental=true}),joker('j_golden',1,{rental=true,perishable=true,perish_tally=0})}
s.jokers[1].debuff=true
local fingerprint=Snapshot.fingerprint(s);local b=L.estimate(s,ready)
check(b.rental_cost==8 and b.discard_cost==2 and b.reserve==20 and b.purchase_floor==0,
  'actual retained rentals, including debuffed/expired cards, and all six paid discards share one debt-relative reserve')
check(b.remaining_allowance==10 and b.rental_timing=='after_play_before_interest' and not b.finishing_guarantee,
  'budget reports current spending allowance and delayed charge timing without promising survival')
check(Snapshot.fingerprint(s)==fingerprint,'resource estimation leaves the state untouched')
local safe=copy(ready);safe.status='sampled_safe'
check(L.estimate(s,safe).discards_reserved==6,'four safe opening samples cannot invent a smaller complete finishing cost')
local none=copy(ready);none.discards=0
check(L.estimate(s,none).reserve==8,'supported Water/Burglar zero-discard resources reserve only actual rentals')
local unknown=L.estimate(s,{supported=false,discards=0})
check(unknown.reserve==20 and unknown.resource_basis=='unresolved_reset_resources',
  'unsupported next-blind resources cannot turn the reset discard reserve into zero')
local bonus=copy(s);bonus.round_bonus={discards=2}
check(L.estimate(bonus,{}).discards_reserved==8,'unknown resources include captured pending discard bonuses')
local plan={complete=true,supported=true,known_mechanics=true,all_worlds_clear=true,cost_model='actual_actions',
  observation_key=L.observation_key(s),target=600,samples=4,discards_available=6,max_discards_used=2}
local exact=L.estimate(s,ready,{resource_plan=plan,observation_key=L.observation_key(s)})
check(exact.reserve==12 and exact.scope=='complete_sampled_finish_resources' and not exact.finishing_guarantee,
  'optional complete resource evidence reserves the most expensive sampled actual route while retaining sampling uncertainty')
check(L.estimate(s,ready,{resource_plan=plan,observation_key='changed-observation'}).reserve==20,
  'a resource plan for another observation cannot lower the reserve')
plan.complete=false
check(L.estimate(s,ready,{resource_plan=plan,observation_key=L.observation_key(s)}).reserve==20,
  'an incomplete finishing comparison cannot lower the reserve')
plan.complete=true
local planned=copy(ready);planned.resource_plan=copy(plan)
check(L.estimate(s,planned).reserve==12,'complete producer evidence is consumed by the common liquidity path')
local with_cache=copy(s);with_cache._readiness=planned;with_cache._shop_scoring={callback=function()end}
check(L.observation_key(with_cache)==plan.observation_key and L.estimate(with_cache).reserve==12,
  'derived context and readiness do not change the actual observation binding')
for _,mutate in ipairs({function(x)x.dollars=x.dollars-1 end,
  function(x)x.jokers[1].ability.rental=false end,function(x)x.playing_cards[1].rank=14 end,
  function(x)x.next_blind.chips=601 end,function(x)x.modifiers.discard_cost=3 end,
  function(x)x.consumeables={{key='c_mercury'}} end}) do
  local changed=copy(s);mutate(changed)
  check(L.estimate(changed,planned).discards_reserved==6,'changed resource/build/target cannot reuse the old finishing reserve')
end
local broken=copy(s);broken.callback=function()end
check(L.observation_key(broken)==nil and L.estimate(broken,planned).discards_reserved==6,
  'non-data observations fail closed for reserve reuse')
s.dollars=-5;local after=copy(s);after.dollars=-6
local penalty,left,right=L.incremental(s,after,ready,ready)
check(left.shortfall==5 and right.shortfall==6 and penalty==5,'existing shortages are not repeatedly penalized; only new shortage is charged')
after.jokers={}
check(L.incremental(s,after,ready,ready)==0,'removing rental obligations may fund spending without a new liquidity penalty')

s=state();s.dollars=1;s.bankrupt_at=0;s.modifiers={};s.rental_rate=3
local free=joker('j_joker',0,{mult=4});local rented=joker('j_joker',0,{mult=4,rental=true})
local ordinary_penalty=Strategy.shop_sequence_api.purchase_penalty(s,0,free)
local rental_penalty=Strategy.shop_sequence_api.purchase_penalty(s,0,rented)
check(ordinary_penalty==0 and rental_penalty==10,'a free purchase is not free of its newly added rental obligation')
local credit=joker('j_credit_card',1,{extra=20})
local borrowed=Strategy.shop_sequence_api.after_joker_purchase(s,credit)
check(borrowed.dollars==0 and borrowed.bankrupt_at==-20,'single-purchase preview applies Credit Card allowance before budgeting')
s.shop_jokers={credit}
local sequence_credit=assert(Sequences.transition(s,{kind='buy',area='shop_jokers',index=1},{strategy=Strategy}))
check(sequence_credit.bankrupt_at==-20,'full sequence applies the same debt change once')
local moon=joker('j_to_the_moon',1,{extra=1});local moon_after=Strategy.shop_sequence_api.after_joker_purchase(s,moon)
check(moon_after.interest_amount==2,'shared purchase preview applies the actual Moon interest change')

s=state();s.dollars=20;s.bankrupt_at=0;s.rental_rate=3;s.modifiers.discard_cost=1
moon=joker('j_to_the_moon',4,{extra=1,rental=true})
local assessed=Conditional.assess(s,moon,{base_value=50,readiness=ready})
check(assessed.liquidity.cash_after_payment==16 and assessed.liquidity.reserve==9 and
  assessed.liquidity.remaining_allowance==7,'conditional income uses post-payment cash including the incoming rental and all reserved discards')
check(assessed.cash_before_blind==0 and assessed.cash_end_round==1 and assessed.interest_cash_basis=='after_conservative_reserved_costs',
  'Moon interest uses the same conservative after-cost basis and does not finance its own purchase')
local golden=joker('j_golden',4,{extra=4})
s.modifiers.discard_cost=0;s.dollars=40
local ahead=Conditional.assess(s,golden,{base_value=55,readiness=safe})
check(ahead.rating>=55 and ahead.payback_rounds==1 and ahead.liquidity.shortfall==0,
  'worthwhile safely-ahead income investment retains its value')

s=state();s.rental_rate=3;s.modifiers.discard_cost=1;s.dollars=13
s.jokers={joker('j_golden',1,{extra=4,rental=true})}
local rr={supported=true,status='sampled_deficit',target=600,hands=1,discards=6,
  opening_scores={100,100,100,100},opening_mean=100,capacity_proxy=100}
local function paired()
  local upgraded=copy(rr);upgraded.opening_scores={600,600,600,600};upgraded.opening_mean=600
  return {before_readiness=rr,after_readiness=upgraded}
end
local tactical=Reroll.suggest(s,function() return 50 end,{before_readiness=rr},{compare=paired})
local generic=Reroll.suggest(s,function() return true end,{before_readiness=rr})
check(tactical and generic and tactical.reroll_forecast.purchase_floor==-11 and generic.reroll_forecast.purchase_floor==-11,
  'generic and tactical rerolls use the same nine-dollar resource reserve above the actual twenty-dollar debt allowance')
check(generic.reroll_forecast.survival_reserve==9 and generic.reroll_forecast.liquidity.conservative,
  'generic reroll no longer substitutes a two-discard or challenge-name reserve')

s=state();s.dollars=2;s.bankrupt_at=0;s.modifiers.discard_cost=1;s.rental_rate=3
s.next_blind.chips=6000
s.shop_jokers={joker('j_joker',0,{mult=4,rental=true}),joker('j_banner',1,{extra=30})}
local ctx=Shop.new(s,Scorer)
local _,diag=Sequences.suggest(s,{strategy=Strategy,consumables=Consumables,shop_scoring=Shop},
  {action={kind='leave_shop'}},ctx)
check(diag.complete,'shared reserve fits the existing small-shop complete comparison budget')
local pair_count=0
for _,p in ipairs(diag.plans) do if #p.actions==2 then
  pair_count=pair_count+1
  check(p.liquidity and p.liquidity.reserve==9 and p.liquidity_penalty==20,
    'sequence assesses the final rental and spending shortfall once, independent of purchase order')
end end
check(pair_count==2,'both first-purchase alternatives retain endpoint resource accounting')
print('advisor_liquidity: '..checks..' checks passed')
