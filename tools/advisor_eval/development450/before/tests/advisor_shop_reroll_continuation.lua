local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Sequences=dofile('Brainstorm/Advisor/shop_sequences.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
local Reroll=dofile('Brainstorm/Advisor/paid_reroll.lua')
local Catalog=dofile('Brainstorm/Advisor/catalog_joker.lua')
Reroll.catalog=Catalog;Strategy.paid_reroll=Reroll;Strategy.consumables=Consumables
local modules={strategy=Strategy,consumables=Consumables}
local checks=0
local function check(x,message) assert(x,message);checks=checks+1 end
local function joker(key,cost,ability)
  ability.set='Joker'
  return {key=key,cost=cost,base_cost=cost,sell_cost=math.max(1,math.floor(cost/2)),ability=ability}
end
local function state()
  local s={phase='shop',ante=2,dollars=13,bankrupt_at=-20,hand_size=8,hand_limit=5,joker_limit=5,
    jokers={},playing_cards={},hands={Pair={level=1,played=3}},modifiers={discard_cost=1},
    probabilities={normal=1},consumeables={},consumable_limit=2,round_resets={hands=1,discards=6},
    current_round={},next_blind={key='bl_small',chips=600},reroll_cost=5,
    shop_jokers={joker('j_joker',3,{mult=4}),joker('j_banner',3,{extra=30})},
    shop_forecast={edition_rate=1,slots=2,inflation=0,discount_percent=0,pools={{},
      {{key='j_abstract',name='Abstract Joker',cost=2,rarity=2,source_set='Joker',source_config={extra=3}}},{}},
      rates={joker=1,tarot=0,planet=0,playing=0,spectral=0}}}
  for i=1,8 do s.playing_cards[i]={id='p:'..i,rank=i+1,suit='Spades',ability={}} end
  return s
end
local function context()
  -- Controlled paired outcomes isolate the horizon-routing defect. Actual
  -- purchase/use/sale legality, whole-build value and reroll math stay real.
  local ctx={comparisons=0}
  local function score(s)
    local mult,chips=1,10
    for _,j in ipairs(s.jokers) do
      if j.key=='j_joker' then mult=mult+4 end
      if j.key=='j_banner' then chips=chips+90 end
      if j.key=='j_abstract' then chips=chips+390 end
    end
    return mult*chips+50*((s.hands.Pair or {}).level-1)
  end
  function ctx:readiness(s)
    local n=score(s)
    return {supported=true,status='sampled_deficit',target=600,hands=1,discards=6,
      opening_mean=n,opening_scores={n,n,n,n},capacity_proxy=n}
  end
  function ctx:compare(a,b)
    self.comparisons=self.comparisons+1
    return {before_readiness=self:readiness(a),after_readiness=self:readiness(b),before_mean=score(a),after_mean=score(b),
      ratio=score(b)/score(a),adjustment=math.min(35,score(b)/score(a)),reason='Controlled complete paired outcomes.'}
  end
  return ctx
end
local s=state();local original=Snapshot.fingerprint(s);local ctx=context()
local base={action={kind='buy',area='shop_jokers',index=1},title='Buy Joker',lines={},warnings={}}
base.scoring_evidence=ctx:compare(s,assert(Sequences.transition(s,base.action,modules)))
local before=Strategy.shortfall_reroll(s,base,ctx)
check(before and before.action.kind=='reroll','single-buy horizon incorrectly makes the checked refresh look better than the visible pair')
local alternative,diagnostics=Sequences.suggest(s,modules,base,ctx)
check(not alternative and diagnostics.complete,'incumbent first purchase is retained by complete sequence planning')
local enriched=Sequences.with_continuation(base,diagnostics)
check(enriched.shop_sequence.scoring_evidence.after_mean==500 and enriched.shop_sequence.cash_after==7,
  'unchanged incumbent carries final pair score and both actual payments')
check(not Strategy.shortfall_reroll(s,enriched,ctx),'same reroll forecast cannot discard the stronger complete visible continuation')
check(Snapshot.fingerprint(s)==original,'continuation and reroll comparisons leave the real snapshot untouched')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local integrated=Decision.run(s,{strategy=setmetatable({advise=function() return base end},{__index=Strategy}),
  consumables=Consumables,shop_sequences=Sequences,shop_scoring={new=function() return context() end}})
check(integrated.action.kind=='buy' and integrated.action.index==1 and
  integrated.strategy.scoring_evidence.after_mean==500 and integrated.shop_diagnostics.sequences.complete,
  'shared runtime decision routing carries unchanged incumbent continuation through the reroll stage')

local next_state=assert(Sequences.transition(s,base.action,modules));local next_context=context()
local next_base={action={kind='buy',area='shop_jokers',index=1},lines={},warnings={}}
next_base.scoring_evidence=next_context:compare(next_state,assert(Sequences.transition(next_state,next_base.action,modules)))
local _,next_diagnostics=Sequences.suggest(next_state,modules,next_base,next_context)
local next_enriched=Sequences.with_continuation(next_base,next_diagnostics)
check(next_state.shop_jokers[1].key=='j_banner' and #next_enriched.shop_sequence.actions==1 and
  next_enriched.scoring_evidence.before_mean==50,'after execution, advice freshly plans from shifted offers and the observed stronger row')
check(not Strategy.shortfall_reroll(next_state,next_enriched,next_context),'fresh next-step evidence independently keeps the now-visible complement')

local saved_suggest=Reroll.suggest;local captured
Reroll.suggest=function(_,_,_,options) captured=options end
local p=state();p.consumeables={{key='c_mercury',cost=3,sell_cost=1,ability={set='Planet',consumeable={}}}}
p.shop_jokers={joker('j_joker',3,{mult=4})}
local use_base={action={kind='use',area='consumeables',index=1,targets={}}}
local _,use_d=Sequences.suggest(p,modules,use_base,context())
local use_enriched=Sequences.with_continuation(use_base,use_d)
Strategy.shortfall_reroll(p,use_enriched,context())
check(captured and captured.visible_cost==3 and captured.visible_actions[1].kind=='use' and
  captured.visible_evidence.after_mean==100,'free held use competes using only its complete continuation cash and score')
captured=nil
local sale=state();sale.dollars=1;sale.joker_limit=1
sale.jokers={joker('j_joker',4,{mult=0,perishable=true,perish_tally=0})};sale.jokers[1].debuff=true
sale.shop_jokers={joker('j_banner',3,{extra=30})}
local sale_base={action={kind='sell',area='jokers',index=1}}
local _,sale_d=Sequences.suggest(sale,modules,sale_base,context())
local sale_enriched=Sequences.with_continuation(sale_base,sale_d)
Strategy.shortfall_reroll(sale,sale_enriched,context())
check(captured and captured.visible_cost==1 and captured.visible_actions[1].kind=='sell',
  'replacement sale uses its exact proceeds in the full-plan cash comparison')
captured=nil
Strategy.shortfall_reroll(p,use_base,context())
check(not captured,'an unprojected consumable use cannot be replaced by tactical catalog evidence')
local mismatch=Snapshot.copy(use_enriched);mismatch.action.index=2
Strategy.shortfall_reroll(p,mismatch,context())
check(not captured,'continuation for a different first action cannot authorize a use-versus-reroll comparison')
Reroll.suggest=saved_suggest
print('advisor_shop_reroll_continuation: '..checks..' checks passed')
