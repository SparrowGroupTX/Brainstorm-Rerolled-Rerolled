-- Synthetic public shop states and real Fool/Planet projections. No source replay.
local Pack=dofile('Brainstorm/Advisor/pack_scoring.lua')
local Sequence=dofile('Brainstorm/Advisor/shop_sequences.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local checks=0;local function check(v,label)assert(v,label);checks=checks+1 end
local copy=Snapshot.copy
Strategy.consumables=Consumables;Strategy.pack_scoring=Pack
local modules={strategy=Strategy,consumables=Consumables,pack_scoring=Pack,shop_scoring=Shop,scoring=Scoring}
local function state()
  local s={phase='shop',ante=2,dollars=9,bankrupt_at=0,jokers={},joker_limit=0,shop_jokers={},shop_vouchers={},shop_booster={},
    consumeables={{id='owned:fool',key='c_fool',name='The Fool',cost=3,base_cost=3,sell_cost=1,
      ability={name='The Fool',set='Tarot',order=1,consumeable={}}}},
    consumable_limit=2,consumeable_buffer=0,hand={},playing_cards={},deck={},hand_size=8,hand_limit=5,hands_played_total=5,
    hands={Straight={level=2,chips=60,mult=7,played=5}},modifiers={},current_round={},round_resets={hands=1,discards=0},
    probabilities={normal=1},last_tarot_planet='c_saturn',interest_cap=25,
    consumeable_usage_total={all=3,tarot=2,planet=1,spectral=0,tarot_planet=3},consumeable_usage={c_saturn={count=1,order=6,set='Planet'}},
    next_blind={key='bl_big',name='Big Blind',chips=12000},next_blind_chips=12000,
    shop_forecast={consumable_pool_schema='source_shop_consumables_v1',discount_percent=0,inflation=0,consumable_used={c_saturn=true},
      tarot_pool={},planet_pool={{key='c_saturn',name='Saturn',cost=3,source_set='Planet',source_order=6,
        source_effect='Hand Upgrade',source_config={hand_type='Straight'}}}}}
  for i,rank in ipairs({2,3,4,5,6,8,10,13}) do
    local card={id='p:'..i,key='c_base',rank=rank,nominal=math.min(rank,10),suit=({'Hearts','Spades','Clubs','Diamonds'})[(i-1)%4+1],ability={}}
    s.playing_cards[i]=card
  end
  return s
end
local function use(s,index,mods)return Sequence.transition(s,{kind='use',area='consumeables',index=index,targets={}},mods or modules)end
local random,randomseed=math.random,math.randomseed
math.random=function()error('No global RNG in owned Fool projection')end
math.randomseed=function()error('No global RNG reseeding')end
do
  local s=state();local hash=Snapshot.fingerprint(s)
  check(Pack.owned_fool_candidate(s,1,modules).hand=='Straight','known played main Planet is admitted without naming a challenge')
  local after,effect=use(s,1)
  check(after and effect.kind=='use_owned_fool' and effect.consumed_id=='owned:fool','exact owned Fool transition is shared with pack creation')
  check(#after.consumeables==1 and after.consumeables[1].key=='c_saturn' and after.consumable_limit==2,'Fool is replaced by an ordinary copy without capacity changes')
  check(effect.inventory_delta==0 and effect.population_delta==0 and not effect.copy_used,'copying is distinct from applying the generated effect')
  check(after.consumeables[1].edition==nil and after.consumeables[1].cost==3 and after.consumeables[1].sell_cost==1,'fresh copy has exact ordinary source price and resale')
  check(after.last_tarot_planet=='c_fool' and after.consumeable_usage.c_fool.count==1 and after.consumeable_usage.c_saturn.count==1,'only Fool is recorded as used')
  check(after.consumeable_usage_total.all==4 and after.consumeable_usage_total.tarot==3 and after.consumeable_usage_total.planet==1,'Fool usage advances the exact totals once')
  check(after.hands.Straight.level==2 and after.dollars==9 and Snapshot.fingerprint(after.playing_cards)==Snapshot.fingerprint(s.playing_cards),'creation leaves cash, population and hand levels intact')
  local used=use(after,1)
  check(used and #used.consumeables==0 and used.hands.Straight.level==3 and used.hands.Straight.chips==90 and used.hands.Straight.mult==10,'separate Planet action performs its exact permanent upgrade')
  check(used.last_tarot_planet=='c_saturn' and used.consumeable_usage_total.all==5,'the second user action owns its own history update')
  check(Snapshot.fingerprint(s)==hash and Snapshot.fingerprint(use(s,1))==Snapshot.fingerprint(after),'projection is deterministic and leaves input unchanged')
end
for _,change in ipairs({
  function(s)s.phase='blind'end,function(s)s.phase='hand'end,function(s)s.consumable_limit=1 end,
  function(s)s.consumable_limit=0/0 end,function(s)s.consumeable_buffer=1 end,
  function(s)s.consumeables[1].edition={negative=true}end,function(s)s.consumeables[1].edition='foil'end,
  function(s)s.consumeables[1].face_down=true end,function(s)s.consumeables[1].debuff=true end,
  function(s)s.consumeables[1].ability.h_size=1 end,function(s)s.consumeables[1].ability.custom=true end,
  function(s)s.consumeables[1].callback=function()end end,function(s)s.consumeables[1].id={}end,
  function(s)s.consumeables[1].id=''end,function(s)s.last_tarot_planet='c_moon'end,function(s)s.last_tarot_planet='c_fool'end,
  function(s)s.hands.Straight.played=0 end,function(s)s.hands.Straight.mult=0/0 end,
  function(s)s.used_vouchers={v_observatory=true}end,function(s)s.jokers={{key='j_perkeo',ability={}}}end,
  function(s)s.jokers={{key='j_joker',ability={}}}end,
  function(s)s.consumeables[2]=copy(s.consumeables[1]);s.consumeables[2].id='second:fool';s.consumable_limit=3 end
})do local s=state();change(s);check(not use(s,1),'out-of-scope or malformed owned Fool abstains')end
for _,change in ipairs({
  function(s)s.shop_forecast=nil end,function(s)s.shop_forecast.planet_pool={}end,
  function(s)s.banned_keys={c_saturn=true}end,function(s)s.shop_forecast.planet_pool[2]=copy(s.shop_forecast.planet_pool[1])end,
  function(s)s.shop_forecast.planet_pool[1].source_config.hand_type='Flush'end,
  function(s)s.shop_forecast.planet_pool[1].source_config.extra=function()end end,
  function(s)s.shop_forecast.planet_pool[1].source_config.mult=2 end,
  function(s)s.shop_forecast.consumable_used='malformed'end,
  function(s)s.consumeable_usage_total.all=nil end
})do local s=state();change(s);check(not use(s,1),'admitted copy with incomplete source metadata fails closed')end
do
  local s=state();s.consumable_limit=3
  table.insert(s.consumeables,1,{id='other',key='c_moon',ability={set='Tarot'}})
  local after,effect=use(s,2)
  check(after and after.consumeables[1].id=='other' and effect.created_index==2,'exact original index shifts without altering other inventory')
  local m={strategy={build_profile=Strategy.build_profile,preservation_cost=function()return 1,'protected',true end}}
  check(not Pack.project_owned_fool(state(),1,m),'whole-inventory preservation rejection is retained')
end
local function fixture(options)
  options=options or {};local s=state();if options.change then options.change(s)end
  local strategy={};for k,v in pairs(Strategy)do strategy[k]=v end
  strategy.shop_sequence_api={};for k,v in pairs(Strategy.shop_sequence_api)do strategy.shop_sequence_api[k]=v end
  strategy.shop_sequence_api.build_value=function(x)return (options.build_gain or 200)*(x.hands.Straight.level-2)end
  strategy.inventory_value=function(x)local n=0;for _,c in ipairs(x.consumeables)do n=n+(c.key=='c_fool' and 100 or 20)end;return n,{direct=n}end
  strategy.liquidity={incremental=function()return options.liquidity_penalty or 0,{},{}end}
  local function ready(x)
    local upgraded=x.hands.Straight.level>2;local mean=0;local worlds={}
    for i=1,4 do
      local progress=upgraded and 0.5 or 0.1;if upgraded and options.crossed and i==4 then progress=0.05 end
      local actions={};for _=1,upgraded and 1 or 4 do actions[#actions+1]={kind='play'}end
      worlds[i]={clear=false,progress=progress,hands_used=#actions,discards_used=0,actions=actions,dollars_after=x.dollars,population_loss=0,finish_reward=0}
      mean=mean+progress/4
    end
    return {supported=true,status='sampled_deficit',target=1000,opening_mean=upgraded and (options.lower_opening and 80 or 200) or 100,
      finishing={complete=true,supported=true,known_mechanics=true,samples=4,selected={worlds=worlds,mean_progress=mean,clearing_samples=0}}}
  end
  local context={comparisons=0}
  function context:readiness(x)return ready(x)end
  function context:compare(a,b)
    self.comparisons=self.comparisons+1;local ar,br=ready(a),ready(b)
    if options.unsupported_copy and #b.consumeables>0 then br.supported=false end
    return {ratio=br.opening_mean/ar.opening_mean,adjustment=0,samples=4,before_readiness=ar,after_readiness=br,
      before_target=1000,after_target=options.target_mismatch and 1200 or 1000,before_finishing=copy(ar.finishing),after_finishing=copy(br.finishing),
      complete_finishing=not options.incomplete,reason='Controlled endpoint evidence with exact owned Fool/Planet transitions.'}
  end
  local m={strategy=strategy,consumables=options.failed_planet and {apply=function()return nil,'Synthetic required Planet failure.'end} or Consumables,pack_scoring=Pack}
  local base={action=options.incumbent_buy and {kind='buy',area='shop_jokers',index=1} or
    options.incumbent and {kind='use',area='consumeables',index=1,targets={}} or {kind='leave_shop'}}
  local hash=Snapshot.fingerprint(s)
  local result,d=Sequence.suggest(s,m,base,context,options.cap and {max_states=2}or nil)
  check(Snapshot.fingerprint(s)==hash,'complete graph preserves its input')
  return result,d,context,base
end
do
  local result,d,ctx=fixture()
  check(result and result.action.kind=='use' and result.action.index==1,'complete copy/use endpoint can recommend the first actual Fool action')
  check(d.complete and d.states==3 and ctx.comparisons==2 and #d.plans==3,'hold, held-copy and permanent-level endpoints all enter the complete graph')
  check(#result.shop_sequence.actions==2 and result.shop_sequence.actions[2].kind=='use','copy and Planet use remain two user actions with fresh advice')
  local copied,used=d.plans[2],d.plans[3]
  check(copied.fool_uses==1 and copied.planet_uses==0 and copied.action_cost==2 and copied.used_inventory_value==0,'Fool receives action cost and no permanent-level conversion credit')
  check(copied.merit<0 and used.fool_uses==1 and used.planet_uses==1 and used.action_cost==4 and used.used_inventory_value==20,'only the consumed Planet receives its existing conversion credit')
  check(result.shop_sequence.cash_after==9 and copied.cash==9 and used.cash==9,'two free uses cannot invent spending or income')
  local again,e=fixture();check(Snapshot.fingerprint(d)==Snapshot.fingerprint(e) and Snapshot.fingerprint(result)==Snapshot.fingerprint(again),'full graph and recommendation repeat deterministically')
end
do
  local result,d,ctx,base=fixture({incumbent=true})
  check(not result and d.complete,'an identical incumbent first action is preserved')
  check(#Sequence.with_continuation(base,d).shop_sequence.actions==2,'best incumbent-first continuation retains the complete copied-Planet use')
  result,d=fixture({build_gain=10});check(not result and d.complete,'holding the original Fool can beat an insufficient upgrade')
  result,d=fixture({lower_opening=true});check(result and d.finishing_override,'287 complete-progress exception remains available')
  for _,options in ipairs({{lower_opening=true,crossed=true},{lower_opening=true,incomplete=true},{lower_opening=true,target_mismatch=true},{liquidity_penalty=200}})do
    result,d=fixture(options);check(not result,'existing cross-world, complete-evidence, target and liquidity guards remain intact')
  end
  for _,options in ipairs({{cap=true},{failed_planet=true},{unsupported_copy=true},
    {change=function(s)s.shop_forecast.planet_pool[1].source_config.extra=function()end end},
    {change=function(s)s.shop_forecast.planet_pool={}end}})do
    result,d=fixture(options);check(not result and not d.complete,'cap or admitted unsupported endpoint aborts the whole family including raw callbacks')
  end
end
do
  local result,d,_,base=fixture({incumbent_buy=true,change=function(s)
    s.shop_jokers={{id='offer:saturn',key='c_saturn',name='Saturn',base_cost=3,cost=3,sell_cost=1,
      ability={name='Saturn',set='Planet',order=6,consumeable={hand_type='Straight'}}}}
  end})
  check(d.complete and d.states>3,'visible buy orders remain in the complete extended graph')
  local incumbent=Sequence.with_continuation(base,d)
  check(incumbent.shop_sequence and incumbent.shop_sequence.actions[1].kind=='buy','best incumbent-buy continuation survives distinct first-action deduplication')
  local paid=false;local delayed=false
  for _,plan in ipairs(d.plans)do if #plan.actions>0 then
    check(plan.fool_uses<=1 and plan.planet_uses<=1 and plan.action_cost>=2*#plan.actions,'each graph path has one original Fool and one separate Planet allowance with every action charged')
    paid=paid or plan.actions[1].kind=='buy' and plan.cash==6
    delayed=delayed or #plan.actions==3 and plan.actions[1].kind=='buy' and plan.actions[2].kind=='use' and plan.fool_uses==1
  end end
  check(paid and delayed,'actual paid buy/use can free the slot before the one original Fool copy, with no second Planet-use lease')
end
do
  local s=state();local context=Shop.new(s,Scoring)
  local _,d=Sequence.suggest(s,modules,{action={kind='leave_shop'}},context)
  check(d.complete and d.states==3 and not context.truncated,'real scorer completes all three synthetic Fool graph endpoints within the existing shop cap')
  check(d.plans[3].opening_mean>context:readiness(s).opening_mean,'exact copied Planet improves the actual sampled opening score')
  print('owned Fool shop real scorer: '..d.states..' states, '..d.comparisons..' comparisons, '..context.evaluations..' score calls')
end
math.random,math.randomseed=random,randomseed
print('advisor_owned_fool_shop: '..checks..' checks passed')
