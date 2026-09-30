local M=dofile('Brainstorm/Advisor/shop_sequences.lua')
local S=dofile('Brainstorm/Advisor/strategy.lua')
local C=dofile('Brainstorm/Advisor/consumables.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
S.consumables=C
local checks=0
local function check(v,msg) assert(v,msg);checks=checks+1 end
local serial=0
local function joker(key,cost,a)
  serial=serial+1
  a=a or {};a.set='Joker'
  return {id="invented:j"..serial,key=key,cost=cost or 0,base_cost=cost or 0,sell_cost=math.max(1,math.floor((cost or 0)/2)),ability=a}
end
local function planet(key,cost) serial=serial+1;return {id='invented:c'..serial,key=key,cost=cost or 3,base_cost=cost or 3,sell_cost=1,ability={set='Planet',consumeable={}}} end
local function state()
  local s={phase='shop',ante=2,dollars=20,bankrupt_at=0,joker_limit=5,consumable_limit=2,jokers={},consumeables={},
    shop_jokers={},shop_vouchers={},shop_booster={},shop_forecast={discount_percent=0,inflation=0},
    hand_size=8,hand_limit=5,hand={},playing_cards={},deck={},hands={Pair={level=1,played=3}},
    round_resets={hands=1,discards=3},current_round={},modifiers={},probabilities={normal=1},interest_cap=25,
    next_blind={key='bl_small',name='Small Blind',chips=2000},blind={key='bl_small',name='Small Blind',chips=300}}
  for i=1,8 do s.playing_cards[i]={id='p:'..i,rank=i+1,suit='Hearts',ability={}} end
  return s
end
local modules={strategy=S,consumables=C,shop_scoring=Shop,scoring=Scorer}
local function buy(s,i) return M.transition(s,{kind='buy',area='shop_jokers',index=i},modules) end
local function sell(s,i) return M.transition(s,{kind='sell',area='jokers',index=i},modules) end
local function use(s,i) return M.transition(s,{kind='use',area='consumeables',index=i,targets={}},modules) end
check(S.shop_sequence_api~=nil,'strategy exports the shared pure short-plan helpers')
do
  local s=state();s.dollars=5;s.shop_jokers={joker('j_credit_card',1,{extra=20}),joker('j_popcorn',8,{mult=20})}
  local hash=Snapshot.fingerprint(s)
  local first=buy(s,1);check(first.dollars==4 and first.bankrupt_at==-20,'Credit Card immediately expands the next purchase allowance')
  check(#first.shop_jokers==1 and first.shop_jokers[1].key=='j_popcorn','purchase removes the actual offer and shifts follow-up indices')
  local second=buy(first,1);check(second and second.dollars==-4,'second visible buy uses only the now-legal debt allowance')
  local sold=sell(second,1);check(sold.bankrupt_at==0,'Credit Card sale removes its allowance before any later purchase')
  sold.shop_jokers={joker('j_joker',1,{mult=4})}
  check(not buy(sold,1),'sale cannot promise purchases using removed Credit Card debt')
  check(Snapshot.fingerprint(s)==hash,'all transitions preserve the original snapshot')
end
do
  local s=state();s.shop_jokers={joker('j_stuntman',2,{extra={chip_mod=250,h_size=2}}),joker('j_to_the_moon',2,{extra=1})}
  local a=buy(s,1);check(a.hand_size==6,'sequence applies the shared Stuntman draw-size cost')
  local b=buy(a,1);check(b.interest_amount==2,'Moon changes actual future interest before subsequent valuation')
  check(sell(b,2).interest_amount==1,'Moon sale reverses its interest change')
  s=state();s.modifiers.minus_hand_size_per_X_dollar=5;s.shop_jokers={joker('j_joker',5,{mult=4})}
  check(buy(s,1).hand_size==9,'spending restores the correct cash-tax hand-size step')
end
do
  local s=state();s.modifiers.inflation=true;s.dollars=7
  s.shop_jokers={joker('j_joker',3,{mult=4}),joker('j_popcorn',4,{mult=20})}
  local a=buy(s,1);check(a.dollars==4 and a.shop_jokers[1].cost==5,'inflation charges current cost then reprices the remaining offer')
  check(a.jokers[1].sell_cost==2,'global inflation repricing also updates retained Joker resale')
  check(not buy(a,1),'a pair affordable at old prices is rejected after the actual inflation step')
  s.dollars=20;s.shop_forecast.discount_percent=25
  s.shop_jokers[1].cost=2;s.shop_jokers[2].cost=3
  a=buy(s,1);check(a.shop_jokers[1].cost==4,'discounted inflation uses source floor rounding from base price')
  s.shop_jokers[2].base_cost=nil
  check(not buy(s,1),'ambiguous discounted repricing fails closed without base cost')
end
do
  local s=state();s.joker_limit=1;s.jokers={joker('j_joker',2,{mult=4})};s.jokers[1].edition={negative=true}
  s.joker_limit=2;s.jokers[2]=joker('j_popcorn',2,{mult=20});s.shop_jokers={joker('j_banner',2,{extra=30})}
  local a=sell(s,1);check(#a.jokers==1 and a.joker_limit==1,'selling Negative removes its supplied slot')
  check(not buy(a,1),'Negative sale cannot create an ordinary replacement slot')
  s.jokers[1].ability.eternal=true;check(not sell(s,1),'Eternal sale rejected')
  s.jokers[1].ability.eternal=nil;s.jokers[1].pinned=true;check(not sell(s,1),'pinned sale protected')
  s.jokers[1].pinned=nil;s.jokers[1].ability.pinned=true;check(not sell(s,1),'ability-carried pinned sale protected')
  s.jokers[1]=joker('j_invisible',4,{invis_rounds=2,extra=2});check(not sell(s,1),'charged Invisible random replacement is explicit unsupported')
  s.jokers[1]=joker('j_joker',4,{mult=4});s.modifiers.all_eternal=true;check(not sell(s,1),'mechanical row lock rejects sale')
end
do
  local s=state();s.jokers={joker('j_campfire',4,{x_mult=1.25,extra=.25}),joker('j_joker',2,{mult=4})}
  local a=sell(s,2);check(a.jokers[1].ability.x_mult==1.5,'one sale grows retained Campfire exactly once')
  s=state();s.consumeables={planet('c_mercury',3)}
  local a=use(s,1);check(a.hands.Pair.level==2 and #a.consumeables==0,'held Planet use advances its exact hand level and consumes inventory')
  s.jokers={joker('j_constellation',4,{x_mult=1,extra=.1})}
  a=use(s,1);check(a.jokers[1].ability.x_mult==1.1,'Planet sequence applies Constellation growth')
  s.used_vouchers={v_observatory=true};check(not use(s,1),'matching Observatory inventory is protected')
  s.used_vouchers={};s.jokers={joker('j_perkeo',20,{})};check(not use(s,1),'last worthwhile Perkeo Planet source is protected')
  s.jokers={};s.consumeables[1].edition={negative=true};s.consumable_limit=3
  a=use(s,1);check(a.consumable_limit==2,'using a Negative Planet removes its own supplied slot')
end
do
  local s=state();s.shop_jokers={joker('j_astronomer',8,{}),planet('c_mercury',3)}
  local a=buy(s,1);check(a.shop_jokers[1].cost==0,'Astronomer acquisition makes the actual offered Planet free')
  local b=sell(a,1);check(b.shop_jokers[1].cost==3,'Astronomer removal restores the actual base price')
  s.shop_jokers={joker('j_joker',2,{mult=4})};s.modifiers.no_shop_jokers=true
  check(not buy(s,1),'mechanical no-shop-Joker rule is respected without naming a challenge')
end
local function fake_context()
  local context={comparisons=0}
  local function score(s)
    local mult,chips=1,10
    for _,j in ipairs(s.jokers or {}) do
      if j.key=='j_joker' then mult=mult+4 end
      if j.key=='j_banner' then chips=chips+90 end
      if j.key=='j_popcorn' then mult=mult+2 end
    end
    return mult*chips+50*((s.hands.Pair or {}).level-1)
  end
  function context:readiness(s)
    local n=score(s)
    return {supported=true,status=n>=600 and 'sampled_safe' or 'sampled_deficit',target=600,
      opening_mean=n,opening_min=n,opening_max=n,opening_scores={n,n,n,n},hands=1,reason='Controlled paired fixture.'}
  end
  function context:compare(a,b)
    self.comparisons=self.comparisons+1
    return {ratio=score(b)/score(a),adjustment=math.min(35,score(b)/score(a)),before_mean=score(a),after_mean=score(b),
      before_readiness=self:readiness(a),after_readiness=self:readiness(b),reason='Controlled complete score comparison.'}
  end
  return context
end
do
  local s=state();s.shop_jokers={joker('j_joker',3,{mult=4}),joker('j_banner',3,{extra=30})}
  local ctx=fake_context();local hash=Snapshot.fingerprint(s)
  local advice,d=M.suggest(s,modules,{action={kind='leave_shop'}},ctx)
  check(d.complete and d.comparisons>2,'all admitted one- and two-buy endpoints are compared')
  check(advice and #advice.shop_sequence.actions==2 and advice.action.kind=='buy','a useful affordable pair can beat saving and publishes just its first buy')
  check(advice.shop_sequence.actions[2].index==1,'second buy targets the shifted visible shop index')
  local incumbent,incumbent_d=M.suggest(s,modules,{action={kind='buy',area='shop_jokers',index=2}},fake_context())
  local continued=false
  for _,plan in ipairs(incumbent_d.plans) do
    if #plan.actions==2 and plan.actions[1].index==2 then continued=true end
  end
  check(not incumbent and incumbent_d.complete and continued,'existing first action receives its full best continuation before an alternate can override it')
  local original_base={action={kind='buy',area='shop_jokers',index=2},title='Keep the same first action',
    scoring_evidence={after_mean=100},warnings={},lines={}}
  local enriched=M.with_continuation(original_base,incumbent_d)
  check(enriched.action.index==2 and enriched.title==original_base.title and #enriched.shop_sequence.actions==2,
    'an unchanged incumbent carries its complete best continuation without changing its published action')
  check(enriched.scoring_evidence.after_mean==500 and enriched.shop_sequence.cash_after==14,
    'reroll receives full-pair scoring and both purchase costs instead of the single-buy horizon')
  check(original_base.shop_sequence==nil and original_base.scoring_evidence.after_mean==100,
    'attaching continuation evidence does not mutate the caller recommendation')
  check(incumbent_d.best_by_first_action['buy:shop_jokers:1'].scoring_evidence.after_mean==500 and
    incumbent_d.best_by_first_action['buy:shop_jokers:2'].scoring_evidence.after_mean==500,
    'each legal first purchase retains its own strongest completed continuation')
  check(M.with_continuation(original_base,{complete=false,best_by_first_action=incumbent_d.best_by_first_action})==original_base,
    'an incomplete comparison cannot leak favorable continuation evidence into reroll advice')
  check(Snapshot.fingerprint(s)==hash,'complete sequence search does not change original state')
  local repeat_advice,repeat_d=M.suggest(s,modules,{action={kind='leave_shop'}},fake_context())
  check(Snapshot.fingerprint(advice)==Snapshot.fingerprint(repeat_advice) and Snapshot.fingerprint(d)==Snapshot.fingerprint(repeat_d),'sequence decisions and diagnostics are deterministic')
  local none,cut=M.suggest(s,modules,{action={kind='leave_shop'}},fake_context(),{max_states=2})
  check(not none and not cut.complete and cut.comparisons==0,'graph admission limit returns no partial scored winner')
  local fail=fake_context();function fail:compare() return nil end
  none,cut=M.suggest(s,modules,{action={kind='leave_shop'}},fail)
  check(not none and not cut.complete,'one failed paired comparison discards the whole sequence choice')
  local safe=fake_context();function safe:readiness() return {supported=true,status='sampled_safe'} end
  none,cut=M.suggest(s,modules,{action={kind='leave_shop'}},safe)
  check(not none and safe.comparisons==0,'safe investment states incur no sequence comparisons or override')
  none,cut=M.suggest(s,modules,{action={kind='open',area='shop_booster',index=1}},fake_context())
  check(not none and cut.comparisons==0,'unknown pack outcome is not silently excluded from the incumbent comparison')
end
do
  local s=state();s.consumeables={planet('c_mercury',3)};s.shop_jokers={joker('j_joker',3,{mult=4})}
  local advice,d=M.suggest(s,modules,{action={kind='leave_shop'}},fake_context())
  local found_use=false
  for _,a in ipairs(advice and advice.shop_sequence.actions or {}) do if a.kind=='use' then found_use=true end end
  check(d.complete and advice and found_use,'actual held Planet plus visible Joker can form the chosen short plan')
  check(advice.shop_sequence.readiness.opening_mean==100,'Planet level and Joker scoring are included together in the final profile')
  local held_first=M.with_continuation({action={kind='use',area='consumeables',index=1}},d)
  check(held_first.shop_sequence and held_first.shop_sequence.actions[1].kind=='use' and
    held_first.shop_sequence.cash_after==17,'free held-Planet first step carries only the later actual purchase spend')
end
do
  local s=state();s.joker_limit=1;s.dollars=1
  s.jokers={joker('j_joker',4,{mult=0,perishable=true,perish_tally=0})};s.jokers[1].debuff=true
  s.shop_jokers={joker('j_banner',3,{extra=30})}
  local advice,d=M.suggest(s,modules,{action={kind='leave_shop'}},fake_context())
  check(d.complete and not advice and d.reason:find('not prequalified',1,true),
    'Opening-only sale-funded plan is declined before irreversible sale; full paired positive is in408')
  local sale_first=M.with_continuation({action={kind='sell',area='jokers',index=1}},d,s,modules)
  check(not sale_first.shop_sequence,'Unqualified incumbent sale is not enriched into a promised continuation')
end
do
  local s=state();s.shop_jokers={joker('j_joker',3,{mult=4}),joker('j_banner',3,{extra=30})}
  local ctx=Shop.new(s,Scorer)
  local _,d=M.suggest(s,modules,{action={kind='leave_shop'}},ctx)
  check(d.complete and not ctx.truncated,'small visible pair finishes with the real scoring context and its shared budget')
  check(d.plans[1].merit==0 and #d.plans[1].actions==0,'save is present as the explicit no-spend baseline')
  print('shop sequence real scorer: '..d.states..' states, '..d.comparisons..' complete comparisons, '..ctx.evaluations..' score evaluations')
end
print('advisor_shop_sequences: '..checks..' checks passed')
