local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local R=dofile('Brainstorm/Advisor/paid_reroll.lua')
local Catalog=dofile('Brainstorm/Advisor/catalog_joker.lua')
local Liquidity=dofile('Brainstorm/Advisor/liquidity.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
R.catalog=Catalog;R.liquidity=Liquidity;Strategy.paid_reroll=R;Strategy.liquidity=Liquidity
local checks=0
local function check(x,message) assert(x,message);checks=checks+1 end
local function copy(x) return Snapshot.copy(x) end
local function joker(key,ability)
  ability=ability or {};ability.set='Joker'
  return {key=key,cost=4,sell_cost=2,ability=ability}
end
local function entry(key,config)
  return {key=key,name=key=='j_joker' and 'Joker' or key,cost=2,rarity=1,source_set='Joker',source_config=config or {mult=4},blueprint_compat=true}
end
local function state()
  local s={phase='shop',ante=2,dollars=13,bankrupt_at=-20,hand_size=8,hand_limit=5,joker_limit=2,
    jokers={joker('j_popcorn',{mult=20,perishable=true,perish_tally=0}),joker('j_square',{extra={chips=0,chip_mod=4}})},
    playing_cards={},hands={},modifiers={discard_cost=1},probabilities={normal=1},consumeables={},consumable_limit=2,
    round_resets={hands=1,discards=6},current_round={},next_blind={key='bl_small',chips=600},reroll_cost=5,shop_jokers={},
    shop_forecast={edition_rate=1,slots=2,inflation=0,discount_percent=0,rental_rate=3,
      pools={{entry('j_joker')},{},{}},rates={joker=1,tarot=0,planet=0,playing=0,spectral=0}}}
  s.jokers[1].debuff=true
  for i,r in ipairs({2,2,4,4,6,6,8,8}) do s.playing_cards[i]={id='p:'..i,rank=r,suit='Spades',nominal=r,ability={}} end
  return s
end
local base={action={kind='leave_shop'}}
local s=state();local hash=Snapshot.fingerprint(s);local ctx=Shop.new(s,Scorer)
local result=Strategy.shortfall_reroll(s,base,ctx)
check(result and result.action.kind=='reroll' and result.reroll_forecast.full_row_replacements,
  'a supported full row may search for a sale-funded retained-build improvement')
local chosen=result.reroll_forecast.shortlist[1].replacement
check(chosen and chosen.complete and #chosen.comparisons==2 and chosen.sold_index==1,
  'every legal victim is compared before choosing the expired filler replacement')
check(chosen.sale_proceeds==2 and chosen.cash_after==8 and result.reroll_forecast.expected_cash_spend==5,
  'refresh is paid before selling, and actual proceeds fund the replacement purchase without concealing failed-search cost')
check(Snapshot.fingerprint(s)==hash and not ctx.truncated,'replacement forecasts preserve the actual row and shared scoring budget')
check(result.reroll_forecast.unknown_pool_mass>0 and result.reroll_forecast.no_edition_probability==0.96,
  'unassessed rarity/edition outcomes retain zero credit')

local function controlled()
  local c={comparisons=0}
  function c:compare(before,after)
    self.comparisons=self.comparisons+1
    local function profile(state)
      local score=20
      for _,j in ipairs(state.jokers) do if j.key=='j_joker' then score=400 end end
      return {supported=true,status='sampled_deficit',target=600,hands=1,discards=6,
        opening_scores={score,score,score,score},opening_mean=score,capacity_proxy=score}
    end
    return {before_readiness=profile(before),after_readiness=profile(after),adjustment=35,ratio=2}
  end
  return c
end
local negative=state();negative.jokers[1].edition={negative=true};negative.jokers[2].ability.eternal=true
local nctx=controlled()
check(not Strategy.shortfall_reroll(negative,base,nctx) and nctx.comparisons==1,
  'selling the only expendable Negative removes its supplied slot, so no ordinary purchase is promised')
local locked=state();locked.jokers[1].pinned=true;locked.jokers[2].ability.pinned=true
check(not Strategy.shortfall_reroll(locked,base,controlled()),'both representations of a protected pinned victim are respected')
local credit=state();credit.dollars=1;credit.joker_limit=1;credit.jokers={joker('j_credit_card',{extra=20})}
check(not Strategy.shortfall_reroll(credit,base,controlled()),
  'sale cannot fund a replacement using the Credit Card allowance removed by that same sale')
local low=state();low.dollars=-18
check(not Strategy.shortfall_reroll(low,base,controlled()),'future sale proceeds cannot make the first refresh legal')
local miss=state();miss.dollars=-7;miss.jokers[2].ability.rental=true
local miss_ctx=controlled()
check(not Strategy.shortfall_reroll(miss,base,miss_ctx) and miss_ctx.comparisons==1,
  'a speculative post-hit rental sale cannot cover the paid-discard and rental reserve left short after a missed refresh')
local boundary=state();boundary.dollars=-9
local boundary_result=Strategy.shortfall_reroll(boundary,base,controlled())
check(boundary_result and boundary_result.reroll_forecast.purchase_floor==-14,
  'preserving the exact miss reserve still permits a later sale-funded purchase without an unnecessary extra purchase dollar')
for _,card in ipairs({joker('j_invisible',{invis_rounds=2,extra=2}),joker('j_modded_unknown'),
  joker('j_luchador'),joker('j_diet_cola'),joker('j_astronomer'),joker('j_chaos')}) do
  local unmodeled=state();unmodeled.jokers[2]=card;local uc=controlled()
  check(not Strategy.shortfall_reroll(unmodeled,base,uc) and uc.comparisons==1,
    card.key..' cannot be silently excluded while a favorable known victim earns candidate probability credit')
end
local incomplete=controlled();local original_compare=incomplete.compare
function incomplete:compare(a,b)
  if self.comparisons==2 then self.truncated=true;return nil end
  return original_compare(self,a,b)
end
check(not Strategy.shortfall_reroll(s,base,incomplete) and incomplete.truncated,
  'an incomplete later victim discards earlier favorable replacement evidence')
local unknown=controlled();local unknown_compare=unknown.compare
function unknown:compare(a,b)
  if self.comparisons==2 then self.comparisons=self.comparisons+1;return nil end
  return unknown_compare(self,a,b)
end
check(not Strategy.shortfall_reroll(s,base,unknown) and not unknown.truncated,
  'one unsupported paired victim gives the whole candidate zero improvement credit')

local perkeo=state();perkeo.joker_limit=1;perkeo.jokers={joker('j_perkeo')}
perkeo.consumeables={{key='c_strength',edition={negative=true},ability={set='Tarot'}},
  {key='c_death',edition={negative=true},ability={set='Tarot'}}};perkeo.consumable_limit=4
check(not Strategy.shortfall_reroll(perkeo,base,controlled()),
  'raw immediate opening gain cannot discard the whole-inventory Perkeo engine without retained-build merit')
local mature=state();mature.joker_limit=1;mature.jokers={joker('j_hologram',{x_mult=4,extra=.25})}
check(not Strategy.shortfall_reroll(mature,base,controlled()),
  'already mature growth must survive the same whole-build replacement comparison')

local bounded=state();bounded.shop_forecast.pools[1]={}
for _,key in ipairs({'j_joker','j_abstract','j_banner','j_duo','j_half','j_sly'}) do
  bounded.shop_forecast.pools[1][#bounded.shop_forecast.pools[1]+1]=entry(key)
end
local root=controlled():compare(bounded,bounded);local upgrade=copy(root)
upgrade.after_readiness.opening_scores={600,600,600,600};upgrade.after_readiness.opening_mean=600
local calls=0
local limited=R.suggest(bounded,function() return 60 end,root,{replacement_comparison_limit=100,
  replacement_plans=function() return {{},{},{},{},{}} end,
  compare=function(_,_,plans) calls=calls+#plans;return upgrade end})
check(limited and #limited.reroll_forecast.shortlist==2 and limited.reroll_forecast.comparison_count==10 and
  limited.reroll_forecast.comparison_limit==12 and calls==10,
  'admission keeps whole five-victim sets within twelve comparisons and gives omitted catalog outcomes zero credit')
print('advisor_catalog_replacements: '..checks..' checks passed; real scoring evaluations '..ctx.evaluations)
