local R=dofile('Brainstorm/Advisor/paid_reroll.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local L=dofile('Brainstorm/Advisor/liquidity.lua')
R.catalog=dofile('Brainstorm/Advisor/catalog_joker.lua');R.liquidity=L
Strategy.paid_reroll=R;Strategy.liquidity=L
local checks=0
local function check(x,message) assert(x,message);checks=checks+1 end
local function copy(x) return Snapshot.copy(x) end
local function evidence(score)
  return {before_readiness={supported=true,status='sampled_deficit',target=600,hands=1,discards=0,
    opening_scores={300,300,300,300},opening_mean=300,capacity_proxy=300},
    after_readiness={supported=true,status='sampled_deficit',target=600,hands=1,discards=0,
    opening_scores={score,score,score,score},opening_mean=score,capacity_proxy=score}}
end
local duo={key='j_duo',name='The Duo',cost=8,rarity=3,source_set='Joker',source_effect='X1.5 Mult',
  source_config={Xmult=2,type='Pair'},blueprint_compat=true}
local s={phase='shop',ante=2,dollars=50,bankrupt_at=-20,reroll_cost=5,joker_limit=5,jokers={},
  shop_jokers={},modifiers={},round_resets={hands=1,discards=0},
  shop_forecast={edition_rate=1,slots=2,inflation=0,discount_percent=0,rental_rate=3,
    pools={{},{},{duo}},rates={joker=1,tarot=0,planet=0,playing=0,spectral=0}}}
local initial=evidence(300)
local legacy=R.suggest(s,function() return 60 end,initial,{compare=function() return evidence(600) end})
check(legacy and legacy.reroll_forecast.expected_shortfall_reduction>0.02,
  'a rare strong hit clears the old positive-only target-gain threshold')
local calls=0
local decline=R.suggest(s,function() return 60 end,initial,{compare=function() return evidence(600) end,
  compare_miss=function() calls=calls+1;return evidence(50) end})
check(not decline and calls==1,'cash-sensitive scoring loss on likely misses outweighs the rare hit after one lazy complete comparison')
local constant=R.suggest(s,function() return 60 end,initial,{compare=function() return evidence(600) end,
  compare_miss=function() return evidence(300) end})
check(constant and constant.reroll_forecast.miss_gain==0 and constant.reroll_forecast.miss_comparisons==1 and
  constant.reroll_forecast.expected_shortfall_reduction==legacy.reroll_forecast.expected_shortfall_reduction,
  'cash-insensitive scoring retains the prior expected gain while recording its complete miss comparison')
local positive=R.suggest(s,function() return 60 end,initial,{compare=function() return evidence(600) end,
  compare_miss=function() return evidence(500) end})
check(positive and positive.reroll_forecast.miss_gain>0 and positive.reroll_forecast.charged_miss_gain==0 and
  positive.reroll_forecast.expected_shortfall_reduction==legacy.reroll_forecast.expected_shortfall_reduction,
  'positive miss development is explicit and receives no speculative gain credit')
check(not R.suggest(s,function() return 60 end,initial,{compare=function() return evidence(300) end,
  compare_miss=function() error('miss evaluated without any supported useful catalog mass') end}),
  'miss scoring is skipped when no catalog upgrade can justify a search')
check(not R.suggest(s,function() return 60 end,initial,{compare=function() return evidence(600) end,
  compare_miss=function() return nil,'incomplete' end}),
  'an incomplete miss comparison invalidates the favorable hit forecast')
check(not R.suggest(s,function() return 60 end,initial,{compare=function() return evidence(600) end,
  compare_miss=function() local e=evidence(300);e.uncertain=true;return e end}),
  'unsupported miss mechanics cannot silently receive zero loss')

local runtime=copy(s);runtime.dollars=13;runtime.joker_limit=2;runtime.hand_size=8;runtime.hand_limit=5
runtime.shop_forecast.discount_percent=25
runtime.jokers={{key='j_popcorn',cost=4,sell_cost=2,debuff=true,
  ability={set='Joker',mult=20,perishable=true,perish_tally=0}},
  {key='j_bull',cost=6,sell_cost=3,ability={set='Joker',extra=2}}}
runtime.playing_cards={};runtime.hands={};runtime.consumeables={};runtime.consumable_limit=2
runtime.modifiers={discard_cost=1};runtime.probabilities={normal=1};runtime.round_resets.discards=6
runtime.current_round={};runtime.next_blind={key='bl_small',chips=600}
for i,r in ipairs({2,2,4,4,6,6,8,8}) do runtime.playing_cards[i]={id='p:'..i,rank=r,suit='Spades',nominal=r,ability={}} end
local base={action={kind='leave_shop'}};local before=Snapshot.fingerprint(runtime)
local original_suggest=R.suggest
R.suggest=function(state,assess,readiness,options)
  options.compare_miss=nil
  return original_suggest(state,assess,readiness,options)
end
local old_context=Shop.new(runtime,Scorer)
local old=Strategy.shortfall_reroll(runtime,base,old_context)
R.suggest=original_suggest
local context=Shop.new(runtime,Scorer)
local now=Strategy.shortfall_reroll(runtime,base,context)
check(old and not now and context.reroll_miss_diagnostics and context.reroll_miss_diagnostics.gain<0,
  'real Bull scoring rejects the rare-hit refresh once actual cash loss on a missed shop is included')
check(context.reroll_miss_diagnostics.cash_after==8 and context.reroll_miss_diagnostics.status=='complete' and
  not context.truncated and Snapshot.fingerprint(runtime)==before,
  'runtime miss uses exact post-refresh cash, retains the row, completes within the shared budget and preserves the snapshot')
print('advisor_reroll_miss: '..checks..' checks passed; real scoring evaluations '..context.evaluations)
