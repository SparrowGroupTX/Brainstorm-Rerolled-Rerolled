-- Manufactured deterministic comparisons only; no captured state or game/source
-- execution. Yielding changes scheduling, never candidate order or budgets.
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Route=dofile('Brainstorm/Advisor/blind_routing.lua')
local Rewards=dofile('Brainstorm/Advisor/finish_rewards.lua')
local checks=0
local function check(v,m)assert(v,m);checks=checks+1 end
local function eq(a,b,m)check(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function state(phase)
  local s={phase=phase,ante=2,dollars=0,bankrupt_at=0,joker_limit=5,consumable_limit=2,
    jokers={},consumeables={},hand={},deck={},playing_cards={},pack_cards={},
    hand_size=8,hand_limit=5,hands={Pair={level=1,played=6}},
    round_resets={hands=4,discards=3},current_round={},hands_left=0,discards_left=0,
    blind={key='bl_small'},modifiers={},probabilities={normal=1},interest_cap=25}
  for i,r in ipairs({2,4,6,8,10,11,12,14}) do
    s.playing_cards[i]={id='manufactured:'..i,rank=r,suit=({'Hearts','Clubs','Spades','Diamonds'})[(i-1)%4+1],ability={}}
  end
  return s
end
local function parity(s,modules,options,label)
  local before=Snapshot.fingerprint(s)
  local sync=Decision.run(s,modules,nil,options)
  local yields,async=0,nil
  local worker=coroutine.create(function()
    async=Decision.run(s,modules,function()yields=yields+1;coroutine.yield()end,options)
  end)
  local resumes=0
  repeat
    local ok,why=coroutine.resume(worker);check(ok,label..': resume '..tostring(why))
    resumes=resumes+1;check(resumes<=1000,label..': bounded fixture completion')
    if coroutine.status(worker)~='dead' then check(async==nil,label..': no partial completed result') end
  until coroutine.status(worker)=='dead'
  check(yields>0,label..': real scored comparison yields')
  eq(Snapshot.fingerprint(async),Snapshot.fingerprint(sync),label..': full result and diagnostics identical')
  eq(Snapshot.fingerprint(s),before,label..': input remains exact')
  check(async.evaluations>0,label..': comparison actually scores')
  return async,yields
end
do
  local s=state('pack')
  s.pack_cards={{key='j_devious',ability={name='Devious Joker',set='Joker',t_chips=100,type='Straight'},cost=99,sell_cost=2},
    {key='j_joker',ability={name='Joker',set='Joker',mult=4},cost=99,sell_cost=2}}
  local result=parity(s,{strategy=Strategy,scoring=Scoring,shop_scoring=Shop},nil,'pack')
  eq(result.action.kind,'choose','pack retains a complete selection')
  eq(result.action.index,2,'pack keeps the same useful Joker')
  check(result.evaluations<=50000,'pack retains the existing hard shop allowance')
end
do
  local s=state('pack');s.pack_type='PLANET_PACK';s.pack_kind='Celestial';s.pack_choices=1
  s.next_blind={key='bl_small',chips=500};s.blind={disabled=true};s.hands={}
  for i,r in ipairs({2,2,4,4,6,6,8,8})do
    local c=s.playing_cards[i];c.rank=r;c.nominal=r;c.key='c_base';c.ability={set='Default'}
    s.hand[i]=c
  end
  local function planet(key,name,hand)
    return {id=key,key=key,name=name,cost=3,ability={name=name,set='Planet',consumeable={hand_type=hand}}}
  end
  s.pack_cards={planet('c_mercury','Mercury','Pair'),planet('c_pluto','Pluto','High Card')}
  local strategy=dofile('Brainstorm/Advisor/strategy.lua')
  local shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
  local pack=dofile('Brainstorm/Advisor/pack_scoring.lua')
  local consumables=dofile('Brainstorm/Advisor/consumables.lua')
  strategy.consumables=consumables;strategy.pack_scoring=pack
  shop.paired_deck=dofile('Brainstorm/Advisor/paired_deck.lua')
  local modules={strategy=strategy,scoring=Scoring,shop_scoring=shop,pack_scoring=pack,consumables=consumables}
  local result=parity(s,modules,nil,'Celestial Planet pack')
  check(result.action.kind=='choose' and #result.pack_diagnostics.comparisons==2,
    'Celestial choice compares both actual manufactured Planet offers')
  check(not result.pack_diagnostics.tactical_fallback and result.strategy.scoring_evidence.samples==4,
    'Celestial choice retains complete paired scoring evidence')
  check(result.evaluations<=50000,'Celestial choice keeps the existing hard shop allowance')
  local capped=parity(s,modules,{shop_scoring={max_evaluations=900}},'capped Celestial Planet pack')
  check(capped.shop_diagnostics.truncated and capped.pack_diagnostics.tactical_fallback,
    'yielded incomplete Planet coverage retains the complete-decision strategic fallback')
  check(capped.evaluations<=900,'yielding cannot exceed a smaller caller allowance')
end
do
  local s=state('blind');s.blind_on_deck='Big';s.blind_states={Small='Defeated',Big='Select',Boss='Upcoming'}
  s.route_blinds={Big={key='bl_big',chips=500,dollars=4},Boss={key='bl_wall',chips=1000,dollars=5,boss=true}}
  s.route_tags={Big={key='tag_economy',name='Economy Tag',config={max=40}}}
  s.active_tags={};s.round_bonus={};s.dollars=30
  local options={blind_routing={max_evaluations=192,margin=2}}
  local modules={strategy=setmetatable({advise=function()return {action={kind='select_blind',blind='Big'}}end},{__index=Strategy}),
    scoring=Scoring,shop_scoring=Shop,blind_routing=Route,finish_rewards=Rewards}
  local result,yields=parity(s,modules,options,'blind route')
  eq(result.action.kind,'select_blind','insufficient route retains the original action')
  eq(result.evaluations,192,'route uses its original exact allowance')
  eq(yields,3,'route callback reaches the coroutine every 64 scores')
  eq(options.blind_routing.yield_fn,nil,'forwarding leaves caller options unchanged')
  eq(options.blind_routing.max_evaluations,192,'forwarding preserves requested cap')
  local hook_calls=0;local hook=function()hook_calls=hook_calls+1 end
  options.blind_routing.yield_fn=hook
  Decision.run(s,modules,function()error('caller route callback must remain authoritative')end,options)
  eq(hook_calls,3,'explicit caller route callback remains authoritative')
  eq(options.blind_routing.yield_fn,hook,'explicit caller callback is not mutated')
end
do
  eq(Snapshot.phase(nil),nil,'missing game has no decision phase')
  local g={STAGES={RUN=1},STAGE=1,GAME={},STATES={SELECTING_HAND=1,SHOP=2,BLIND_SELECT=3,ROUND_EVAL=4,
    TAROT_PACK=5,PLANET_PACK=6,SPECTRAL_PACK=7,STANDARD_PACK=8,BUFFOON_PACK=9}}
  for value,expected in ipairs({'hand','shop','blind','round','pack','pack','pack','pack','pack'}) do
    g.STATE=value
    local phase,pack_type=Snapshot.phase(g);local captured=Snapshot.capture(g)
    eq(phase,expected,'cheap phase classification '..value)
    eq(phase,captured.phase,'cheap and full phase agree '..value)
    eq(pack_type,captured.pack_type,'cheap and full pack identity agree '..value)
  end
  g.STATE=900;eq(Snapshot.phase(g),'other','unknown state stays outside planning')
  g.STAGE=2;eq(Snapshot.phase(g),nil,'outside-run phase is unavailable')
end
print('advisor_phase_yield: '..checks..' manufactured checks passed')
