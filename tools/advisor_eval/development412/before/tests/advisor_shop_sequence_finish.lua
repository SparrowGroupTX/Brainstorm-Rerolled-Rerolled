-- Controlled complete-policy evidence around real paid Planet transitions.
local Sequence=dofile('Brainstorm/Advisor/shop_sequences.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0;local function check(v,label)assert(v,label);checks=checks+1 end
local function copy(v)if type(v)~='table' then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
local function state(options)
  local s={phase='shop',ante=2,dollars=10,bankrupt_at=0,joker_limit=0,consumable_limit=1,jokers={},consumeables={},
    shop_jokers={{key='c_mars',cost=3,base_cost=3,sell_cost=1,ability={set='Planet',consumeable={}}}},
    shop_vouchers={},shop_booster={},shop_forecast={discount_percent=0,inflation=0},hand_size=8,hand_limit=5,
    hand={},deck={},playing_cards={},hands={['Four of a Kind']={level=1,played=3,chips=60,mult=7},Flush={level=1,played=1,chips=35,mult=4}},
    round_resets={hands=4,discards=3},current_round={},modifiers={},probabilities={normal=1},interest_cap=25,
    next_blind={key='bl_small',name='Small Blind',chips=1000},blind={key='bl_small',name='Small Blind',chips=300}}
  for i=1,12 do s.playing_cards[i]={id='p:'..i,rank=i+2,suit='Hearts',ability={}} end
  if options.incumbent then s.shop_jokers[2]={key='c_jupiter',cost=3,base_cost=3,sell_cost=1,ability={set='Planet',consumeable={}}} end
  if options.protected then s.used_vouchers={v_observatory=true} end
  return s
end
local function fixture(options)
  options=options or {};local s=state(options)
  local strategy={};for k,v in pairs(Strategy)do strategy[k]=v end
  strategy.shop_sequence_api={};for k,v in pairs(Strategy.shop_sequence_api)do strategy.shop_sequence_api[k]=v end
  strategy.shop_sequence_api.build_value=function(x)return 100*(x.hands['Four of a Kind'].level-1)+50*(x.hands.Flush.level-1)end
  strategy.inventory_value=function()return 0,{direct=0}end
  strategy.liquidity={incremental=function()return options.liquidity_penalty or 0,{},{}end}
  local function ready(x)
    local mars=x.hands['Four of a Kind'].level>1;local jupiter=x.hands.Flush.level>1
    local progress=mars and 1 or jupiter and 0.8 or 0.4
    local worlds,mean,clears={},0,0
    for i=1,4 do
      local p=progress
      if not mars and not jupiter and options.root_clear and i==1 then p=1 end
      if mars and options.crossed and i==4 then p=0.3 end
      if jupiter and options.incumbent_superior then p=1 end
      local hands=mars and 1 or jupiter and 2 or 4
      local actions={};for _=1,hands do actions[#actions+1]={kind='play'}end
      local survivors={};for _,card in ipairs(x.playing_cards)do survivors[card.id]=true end
      if mars and options.lost_survivor then survivors['p:1']=nil end
      local blue=options.root_blue and not mars and 1 or 0
      worlds[i]={clear=p==1,progress=p,hands_used=hands,discards_used=0,actions=actions,
        dollars_after=x.dollars-(mars and options.extra_cash_loss and 1 or 0),population_loss=0,finish_reward=p==1 and 20 or 0,
        resources=p==1 and {blue_planets=blue,planet_hand='Four of a Kind',planet_utility=blue*10,survivors=survivors} or nil}
      mean=mean+p/4;clears=clears+(p==1 and 1 or 0)
    end
    return {supported=true,status=clears==4 and 'sampled_safe' or clears==0 and 'sampled_deficit' or 'unresolved',target=1000,
      opening_mean=mars and 80 or jupiter and 130 or 100,
      finishing={complete=true,supported=true,known_mechanics=true,samples=4,
        selected={worlds=worlds,mean_progress=mean,clearing_samples=clears}}}
  end
  local context={comparisons=0}
  function context:readiness(x)return ready(x)end
  function context:compare(a,b)
    self.comparisons=self.comparisons+1
    local ar,br=ready(a),ready(b)
    local e={ratio=br.opening_mean/ar.opening_mean,adjustment=30,samples=4,
      before_readiness=ar,after_readiness=br,before_target=1000,after_target=options.target_mismatch and 1100 or 1000,
      before_finishing=copy(ar.finishing),after_finishing=copy(br.finishing),complete_finishing=not options.incomplete,
      reason='Controlled whole-blind evidence; no source or captured replay.'}
    if options.baseline_mismatch then e.before_finishing.selected.worlds[1].dollars_after=9 end
    if options.unmodeled then e.after_finishing.known_mechanics=false end
    if options.invalid_actions then e.after_finishing.selected.worlds[1].actions={} end
    if options.missing_world then e.after_finishing.selected.worlds[2]=nil end
    if options.invalid_action_type then e.after_finishing.selected.worlds[1].actions[1]=42 end
    if options.unsupported_endpoint and #b.consumeables>0 then br.supported=false end
    if options.incomplete_other_endpoint and #b.consumeables>0 then e.complete_finishing=false end
    return e
  end
  local base=options.incumbent and {action={kind='buy',area='shop_jokers',index=2}} or {action={kind='leave_shop'}}
  local hash=Snapshot.fingerprint(s)
  local result,diagnostics=Sequence.suggest(s,{strategy=strategy,consumables=Consumables},base,context,
    options.partial and {max_states=1} or nil)
  check(Snapshot.fingerprint(s)==hash,'paid comparison never changes input')
  return result,diagnostics,context
end
local result,diagnostics,context=fixture()
check(result and result.action.kind=='buy' and result.action.index==1,'lower-opening buy/use sequence can improve complete fixed-world progress')
check(diagnostics.complete and context.comparisons>0 and diagnostics.finishing_override.complete,'whole graph and both endpoints completed before exception')
check(#result.shop_sequence.actions==2 and result.shop_sequence.actions[2].kind=='use','result emits only first action of the actual buy/use sequence')
check(diagnostics.finishing_override.additional_paid_cash==3 and result.shop_sequence.cash_after==7,
  'actual three-dollar payment remains explicit; no free purchase or invented interest')
check(diagnostics.finishing_override.before_mean_progress==0.4 and diagnostics.finishing_override.after_mean_progress==1,
  'complete progress, not the lower eighty-chip opening, supplies this narrow override')
result,diagnostics=fixture({incumbent=true})
check(result and result.action.index==1 and diagnostics.finishing_override.before_mean_progress==0.8,
  'candidate also dominates the best complete continuation of the incumbent first action')
for _,options in ipairs({{crossed=true},{incomplete=true},{target_mismatch=true},{baseline_mismatch=true},{unmodeled=true},
  {invalid_actions=true},{missing_world=true},{invalid_action_type=true},{incomplete_other_endpoint=true},{extra_cash_loss=true},
  {root_clear=true,root_blue=true},{root_clear=true,lost_survivor=true},
  {incumbent=true,incumbent_superior=true},{liquidity_penalty=200},{protected=true}}) do
  local alternative=fixture(options)
  check(not alternative,'unsupported, crossed, protected, unpaid or non-dominating exception is declined')
end
result,diagnostics=fixture({unsupported_endpoint=true})
check(not result and not diagnostics.complete,'one unsupported admitted endpoint aborts the whole comparison')
result,diagnostics=fixture({partial=true})
check(not result and not diagnostics.complete,'state cap never publishes a partial plan')
print('advisor_shop_sequence_finish: '..checks..' checks passed')
