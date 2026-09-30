-- Manufactured catalog/score fixtures only: no source runtime or captured game.
local R=dofile('Brainstorm/Advisor/paid_reroll.lua')
local C=dofile('Brainstorm/Advisor/catalog_joker.lua')
local S=dofile('Brainstorm/Advisor/snapshot.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Liquidity=dofile('Brainstorm/Advisor/liquidity.lua')
R.catalog=C;R.liquidity=Liquidity;Strategy.paid_reroll=R;Strategy.liquidity=Liquidity
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local function near(a,b) return type(a)=='number' and math.abs(a-b)<1e-9 end
local function copy(v) return S.copy(v) end
math.random=function() error('catalog fixture must not sample RNG') end
local function entry(key)
  return {key=key,name=key=='j_joker' and 'Joker' or key,cost=2,rarity=1,
    source_set='Joker',source_config={mult=4},blueprint_compat=true}
end
local function gold(s)
  s.modifiers.enable_eternals_in_shop=true;s.modifiers.enable_perishables_in_shop=true
  s.modifiers.enable_rentals_in_shop=true;return s
end
local function state()
  return {phase='shop',ante=2,dollars=13,bankrupt_at=-20,hand_size=8,hand_limit=5,joker_limit=2,
    jokers={{key='j_popcorn',cost=4,sell_cost=2,debuff=true,ability={set='Joker',mult=20,perishable=true,perish_tally=0}},
      {key='j_square',cost=4,sell_cost=2,ability={set='Joker',extra={chips=0,chip_mod=4}}}},
    playing_cards={},hands={},modifiers={discard_cost=1},probabilities={normal=1},consumeables={},consumable_limit=2,
    round_resets={hands=1,discards=6},current_round={},next_blind={key='bl_small',chips=600},reroll_cost=5,shop_jokers={},
    shop_forecast={edition_rate=1,slots=2,inflation=0,discount_percent=0,rental_rate=3,
      pools={{entry('j_joker')},{},{}},rates={joker=1,tarot=0,planet=0,playing=0,spectral=0}}}
end
local s=gold(state())
for i,r in ipairs({2,2,4,4,6,6,8,8}) do s.playing_cards[i]={id='p:'..i,rank=r,suit='Spades',nominal=r,ability={}} end
local hash=S.fingerprint(s);local ctx=Shop.new(s,Score)
local result=Strategy.shortfall_reroll(s,{action={kind='leave_shop'}},ctx)
check(result and result.action.kind=='reroll' and result.reroll_forecast.mode=='scoring_shortfall',
  'Gold Stake no-sticker outcomes must reach the production complete score-backed replacement path')
local f=result.reroll_forecast;local selected=f.shortlist[1].replacement
check(f.full_row_replacements and selected and selected.complete and #selected.comparisons==2 and selected.sold_index==1,
  'the full row compares both legal victims before replacing the expired Perishable')
check(selected.sale_proceeds==2 and selected.cash_after==8 and f.expected_cash_spend==5,
  'the paid refresh precedes the conditional sale, and its fee remains charged on every miss')
check(near(f.no_sticker_probability,.28) and near(f.ordinary_outcome_probability,.2688),
  'Gold Stake ordinary mass is the source no-sticker event times the existing no-edition mass')
check(near(f.covered_pool_mass,.7*.2688) and near(f.probability,1-(1-.7*.2688)^2),
  'empty rarity fallback and sticker/edition outcomes remain zero credit in the existing offer approximation')
check(f.sticker_outcomes=='unassessed_zero_credit' and f.shortlist_complete and f.comparison_count==2 and
  f.comparison_limit==12 and not f.win_probability and f.miss_comparisons==1,
  'complete victim sets, paid miss comparison and the original bounded comparison limits remain explicit')
check(ctx.evaluations>0 and ctx.evaluations<=50000 and not ctx.truncated and S.fingerprint(s)==hash,
  'real production scoring respects its unchanged shared cap and leaves the input untouched')

local function ready(scores,status)
  local sum,clears=0,0
  for _,x in ipairs(scores) do sum=sum+x;if x>=600 then clears=clears+1 end end
  return {supported=true,status=status or 'unresolved',target=600,hands=1,discards=6,
    opening_scores=scores,opening_mean=sum/4,clearing_samples=clears,capacity_proxy=650}
end
local before=ready({100,150,200,650})
local function evidence(scores) return {before_readiness=copy(before),after_readiness=ready(scores),uncertain=false} end
local function positive() return evidence({600,650,700,800}) end
local function pure()
  local p=state();p.jokers={};p.joker_limit=5
  p.shop_forecast.pools={{entry('j_banner'),entry('j_joker')},{entry('j_abstract')},{entry('j_duo')}}
  return p
end
local function suggest(p,options,assess)
  options=options or {};options.compare=options.compare or positive;options.tactical_only=true
  options.compare_miss=options.compare_miss or function() return evidence({100,150,200,650}) end
  return R.suggest(p,assess or function() return 60 end,{before_readiness=before},options)
end
for e=0,1 do for p=0,1 do for r=0,1 do
  local x=pure();x.modifiers.enable_eternals_in_shop=e==1;x.modifiers.enable_perishables_in_shop=p==1
  x.modifiers.enable_rentals_in_shop=r==1
  local expected=(1-.3*e-.3*p)*(r==1 and .7 or 1);local calls=0
  local outcome=suggest(x,{compare=function(candidate,price)
    calls=calls+1
    local card=assert(C.create(candidate,price,x))
    check(not card.ability.eternal and not card.ability.perishable and not card.ability.rental and not card.edition,
      'credited catalog cards carry neither actual stickers nor a premium edition')
    check(card.cost==2 and card.ability.perish_tally==nil,
      'hypothetical unstickered cards retain base price and do not invent expiration')
    return positive()
  end})
  check(outcome and calls==4 and near(R.no_sticker_probability(x.modifiers),expected),
    'every source Eternal/Perishable/Rental flag combination has its conservative no-sticker event')
  local forecast=outcome.reroll_forecast
  check(near(forecast.covered_pool_mass,.96*expected) and near(forecast.unknown_pool_mass,1-.96*expected),
    'all other poll and edition outcomes remain unassessed')
  check(near(forecast.probability,1-(1-.96*expected)^2) and forecast.expected_cash_spend>5,
    'per-slot offer approximation and miss-inclusive expected spending remain unchanged')
end end end

local function declined(x,message)
  local calls=0
  check(not suggest(x,{compare=function() calls=calls+1;return positive() end},function() calls=calls+1;return 60 end) and calls==0,message)
end
local forced=gold(pure());forced.modifiers.all_eternal=true
declined(forced,'forced Eternal shops cannot create a qualified unstickered catalog event')
for _,key in ipairs({'all_eternal','enable_eternals_in_shop','enable_perishables_in_shop','enable_rentals_in_shop'}) do
  for _,value in ipairs({0,1,'true',{}}) do local x=gold(pure());x.modifiers[key]=value
    declined(x,'malformed '..key..' is not silently converted into ordinary probability')
  end
end
check(R.no_sticker_probability(nil)==nil and R.no_sticker_probability('unknown')==nil and
  R.no_sticker_probability(setmetatable({},{__index={enable_eternals_in_shop=true}}))==nil,
  'absent, non-table and inherited modifier metadata fail the explicit mass helper')
local editions=gold(pure());editions.shop_forecast.edition_rate=25
declined(editions,'guaranteed editions cannot be forecast at an ordinary price')
local metadata=gold(pure());metadata.shop_forecast.edition_rate=nil
declined(metadata,'missing edition metadata cannot be forecast as ordinary')
local no_credit=gold(pure());no_credit.bankrupt_at=0
declined(no_credit,'Gold Stake support does not spend the retained paid-discard reserve')

local uncertainty=gold(pure())
check(not suggest(uncertainty,{compare=function() local q=positive();q.uncertain=true;return q end}),
  'uncertain/random score outputs give no catalog gain')
check(not suggest(uncertainty,{compare=function() return evidence({100,150,200,650}) end}),
  'an ordinary offer with zero immediate sampled gain cannot justify payment')
check(not suggest(uncertainty,{visible_evidence=positive(),visible_cost=1}),
  'a better complete visible purchase beats speculative Gold Stake catalog spending')
local interrupted=0
check(not suggest(uncertainty,{compare=function() interrupted=interrupted+1
  if interrupted==3 then return nil,'incomplete' end;return positive() end}) and interrupted==3,
  'a later incomplete comparison invalidates the earlier favorable subset')
check(not suggest(uncertainty,{compare_miss=function() return nil,'incomplete' end}),
  'an incomplete paid-refresh miss cannot disappear from the comparison')
check(not suggest(uncertainty,{compare_miss=function() local q=positive();q.uncertain=true;return q end}),
  'unknown cash-sensitive miss scoring blocks the reroll')
local miss=suggest(uncertainty,{compare_miss=function() return evidence({0,0,0,0}) end})
check(miss and miss.reroll_forecast.charged_miss_gain<0 and
  miss.reroll_forecast.expected_shortfall_reduction<miss.reroll_forecast.probability*.5625,
  'cash-sensitive losses after a miss are subtracted rather than hidden by sticker support')
local big=gold(pure());big.dollars=100;big.shop_forecast.pools[1]={}
for _,key in ipairs({'j_joker','j_jolly','j_zany','j_mad','j_crazy','j_droll','j_banner','j_sly'}) do
  big.shop_forecast.pools[1][#big.shop_forecast.pools[1]+1]=entry(key)
end
local ordered={};local bounded=suggest(big,{shortlist_limit=99,compare=function(e) ordered[#ordered+1]=e.key;return positive() end})
check(bounded and #ordered==6 and bounded.reroll_forecast.comparison_limit==6,
  'Gold Stake does not expand the six-offer shortlist')
local ordered2={};suggest(big,{compare=function(e) ordered2[#ordered2+1]=e.key;return positive() end})
check(table.concat(ordered,',')==table.concat(ordered2,','),'catalog admission remains deterministic')

local function controlled()
  local c={comparisons=0}
  function c:compare(left,right)
    self.comparisons=self.comparisons+1
    local function profile(x)
      local value=20;for _,j in ipairs(x.jokers) do if j.key=='j_joker' then value=400 end end
      return ready({value,value,value,value},'sampled_deficit')
    end
    return {before_readiness=profile(left),after_readiness=profile(right),adjustment=35,ratio=2,uncertain=false}
  end
  return c
end
local base={action={kind='leave_shop'}}
local negative=copy(s);negative.jokers[1].edition={negative=true};negative.jokers[2].ability.eternal=true
check(not Strategy.shortfall_reroll(negative,base,controlled()),
  'selling the only legal Negative victim cannot invent its lost supplied slot')
local locked=copy(s);locked.jokers[1].pinned=true;locked.jokers[2].ability.pinned=true
check(not Strategy.shortfall_reroll(locked,base,controlled()),'pinned victims stay protected')
local unknown=copy(s);unknown.jokers[2]={key='j_modded_unknown',cost=4,sell_cost=2,ability={set='Joker'}}
local unknown_ctx=controlled()
check(not Strategy.shortfall_reroll(unknown,base,unknown_ctx) and unknown_ctx.comparisons==1,
  'one unknown legal victim blocks whole-candidate replacement credit')
local interrupted_ctx=controlled();local original=interrupted_ctx.compare
function interrupted_ctx:compare(a,b)
  if self.comparisons==2 then self.truncated=true;return nil end
  return original(self,a,b)
end
check(not Strategy.shortfall_reroll(s,base,interrupted_ctx) and interrupted_ctx.truncated,
  'an unfinished later victim rejects the full Gold Stake candidate')
local unpaid=copy(s);unpaid.dollars=-7;unpaid.jokers[2].ability.rental=true
check(not Strategy.shortfall_reroll(unpaid,base,controlled()),
  'a conditional sale cannot cover owned rental/discard liabilities after a missed refresh')
check(S.fingerprint(s)==hash,'all production and controlled comparisons preserve the manufactured input')
print('advisor_gold_reroll: '..checks..' checks passed; real scoring evaluations '..ctx.evaluations)
