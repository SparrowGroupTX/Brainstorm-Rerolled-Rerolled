-- Manufactured public states only. No source executable, saved game or RNG.
local Route=dofile('Brainstorm/Advisor/blind_routing.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Rewards=dofile('Brainstorm/Advisor/finish_rewards.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Bell=dofile('Brainstorm/Advisor/bell_opening.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local function eq(a,b,label) check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local copy=Snapshot.copy
local function joker(key,name,id,ability)
  ability=ability or {};ability.name=name;ability.set='Joker'
  return {key=key,name=name,id=id,ability=ability,sell_cost=3,cost=6}
end
local function state(label)
  label=label or 'Big'
  local s={phase='blind',ante=8,win_ante=8,blind_on_deck=label,
    blind_states={Small='Defeated',Big='Select',Boss='Upcoming'},
    route_blinds={Small={key='bl_small',name='Small Blind',chips=300,dollars=3},
      Big={key='bl_big',name='Big Blind',chips=500,dollars=4},
      Boss={key='bl_final_bell',name='Cerulean Bell',chips=1000,dollars=5,boss=true}},
    route_tags={Big={key='tag_double',name='Double Tag',config={type='tag_add'}},
      Small={key='tag_investment',name='Investment Tag',config={type='eval',dollars=25}}},
    dollars=30,hand_size=8,hand_limit=5,round_resets={hands=4,discards=3},round_bonus={},modifiers={},
    hand={},deck={},playing_cards={},
    jokers={joker('j_joker','Joker','j1',{mult=100}),joker('j_caino','Caino','j2',{caino_xmult=20,extra=1})},
    consumeables={},consumable_limit=2,active_tags={},hands={},probabilities={normal=1},skips=2,
    completionist_goal={schema=1,goal='gold_stickers',metadata_status='complete',catalog_status='complete',held_status='complete',
      eligibility={eligible=true},counts={total=150,complete=149,missing=1,unknown=0},
      held_target_keys={'j_caino'},held_target_count=1,
      by_key={j_joker={status='complete'},j_caino={status='missing'}}}}
  for i=1,32 do s.playing_cards[i]={id='p'..i,rank=2+i%13,suit='Spades',enhancement='c_base',ability={}} end
  if label=='Small' then s.blind_states.Small='Select';s.blind_states.Big='Upcoming' end
  return s
end
local function modules(scorer)
  return {scoring=scorer or Score,shop_scoring=Shop,strategy=Strategy,finish_rewards=Rewards,bell_opening=Bell,blind_routing=Route}
end
math.random=function() error('Manufactured Bell routing must not read RNG') end
pseudorandom=math.random

do
  local s=state();local before=Snapshot.fingerprint(s);local calls,worlds=0,{}
  local counted={after_play=Score.after_play,score=function(current,indices)
    calls=calls+1
    if current.blind.key=='bl_final_bell' then
      local ids={};for _,c in ipairs(current.hand) do ids[#ids+1]=c.id end
      worlds[table.concat(ids,',')]=copy(current)
    end
    return Score.score(current,indices)
  end}
  local advice,d=Route.suggest(s,modules(counted))
  check(advice,'mature fixed current row may skip into Bell: '..tostring(d.reason))
  eq(advice.action.kind,'skip_blind','only actual skip action returned');eq(advice.action.blind,'Big','correct blind')
  eq(#d.bell_worlds,4,'all four Boss composition openings completed')
  eq(d.gold_cargo,1,'held distinct missing cargo reconciled')
  eq(calls,d.evaluations,'every Bell score remains in the shared routing ledger')
  check(calls<=5000,'routing hard cap unchanged')
  check(d.minimum_capacity>=2,'existing twofold safety margin retained')
  check(d.foregone_income>0 and d.shop_cost>0,'cash and forgone shop still charged')
  eq(Snapshot.fingerprint(s),before,'no input state/cash/inventory mutation')
  local world_count=0
  for _,receipt in ipairs(d.bell_worlds) do
    local matched
    for _,current in pairs(worlds) do
      local candidate=assert(Bell.new(current))
      if table.concat(candidate.hand_ids,',')==table.concat(receipt.hand_ids,',') then matched=current end
    end
    check(matched,'receipt corresponds to one actual scored common-world hand')
    world_count=world_count+1
    eq(receipt.scored_subsets,218,'every nonempty legal-size subset scored even after a clear')
    eq(#receipt.branches,8,'every possible physical forced card represented')
    for forced,branch in ipairs(receipt.branches) do
      local observed=copy(matched);observed.hand[forced].ability.forced_selection=true
      local maximum=-1
      Search.combinations(#observed.hand,observed.hand_limit,function(indices)
        local p=Score.score(observed,indices)
        if p.legal then maximum=math.max(maximum,p.score) end
      end)
      eq(branch.score,maximum,'branch agrees with exhaustive actual-forced-flag oracle')
      local actual=Score.score(observed,branch.indices)
      check(actual.legal and actual.score==branch.score,'branch selected action is legal with its actual forced flag')
      check(branch.score>=2*observed.blind.chips,'no forced branch hides behind a mean')
    end
  end
  eq(world_count,4,'oracle covers all four reported worlds')
  local relaxed,relaxed_diag=Route.suggest(s,modules(),{margin=1.5})
  check(relaxed and relaxed_diag.minimum_capacity>=2,'Bell never lowers its existing default twofold margin')
  for _,world in ipairs(relaxed_diag.bell_worlds) do check(world.minimum>=2000,'every forced-card floor retains twofold margin under a relaxed caller option') end
  local marginal=copy(s);marginal.route_blinds.Boss.chips=d.minimum_capacity*1000/1.75
  local unsafe,unsafe_diag=Route.suggest(marginal,modules(),{margin=1.5})
  check(not unsafe,'a1.75x Bell capacity cannot qualify with a1.5x caller margin')
  check(unsafe_diag.reason:find('forced Bell card',1,true),'the failed twofold Bell floor remains explicit')
  local m=modules();m.strategy=setmetatable({advise=function() return {action={kind='select_blind'}} end},{__index=Strategy})
  local decision=Decision.run(s,m)
  eq(decision.action.kind,'skip_blind','whole Decision exposes supported executable Bell skip')
  eq(decision.evaluations,d.evaluations,'Decision includes routing evaluations')
  m.strategy=setmetatable({advise=function() return {action={kind='sell',area='jokers',index=1}} end},{__index=Strategy})
  eq(Decision.run(s,m).action.kind,'sell','mandatory preparation retains priority')
end

do
  local s=state('Small');local advice,d=Route.suggest(s,modules())
  check(advice,'Small skip checks Big then Bell: '..tostring(d.reason))
  check(d.checked_blinds.Big and d.checked_blinds.Boss,'both actual remaining blinds checked')
  eq(#d.bell_worlds,4,'all four post-Big Bell worlds represented')
  eq(d.outcome_branches,4,'each exact Big transition retained')
  check(d.evaluations<=5000,'two-blind Bell route bounded')
  s.probabilities.normal=1
  for _,c in ipairs(s.playing_cards) do c.enhancement='m_glass';c.ability.extra=4 end
  advice,d=Route.suggest(s,modules())
  check(advice,'supported single Glass scoring-card outcome branches reach Bell: '..tostring(d.reason))
  eq(d.outcome_branches,8,'both Big survivor/break outcomes checked in each world')
  eq(#d.bell_worlds,8,'every intermediate Glass outcome gets complete Bell coverage')
  check(d.evaluations<=5000,'eight Bell branches remain within original cap')
end

do
  -- Every draw has at least three Kings. Without the forced card, a strong
  -- three-card hand appears sufficient; one off-rank forced identity defeats
  -- that claim under the visible three-card play limit.
  local s=state();s.hand_limit=3;s.playing_cards={};s.jokers={}
  s.completionist_goal=nil;s.hands={['Three of a Kind']={chips=1000,mult=100,level=10,played=1}}
  for i=1,12 do s.playing_cards[i]={id='f'..i,rank=i<=7 and 13 or 2+i,suit=({'Spades','Hearts','Clubs','Diamonds'})[i%4+1],enhancement='c_base',ability={}} end
  s.route_blinds.Big.chips=1;s.route_blinds.Boss.chips=1000
  local advice,d=Route.suggest(s,modules())
  check(not advice,'off-rank forced card prevents a cherry-picked strong-hand skip')
  check(d.reason:find('forced Bell card',1,true),'failure identifies the weak forced-card branch')
  check(d.evaluations>0 and d.evaluations<=5000,'rejected complete branch scored within limit')
end

do
  local s=state();local baseline=assert(Route.suggest(s,modules()))
  local mutations={
    {'missing Bell dependency',function(x,m) m.bell_opening=nil end},
    {'not winning ante',function(x) x.ante=7 end},
    {'unknown win ante',function(x) x.win_ante=nil end},
    {'Gold metadata unknown',function(x) x.completionist_goal.metadata_status='unavailable' end},
    {'ineligible Gold run',function(x) x.completionist_goal.eligibility.eligible=false end},
    {'unknown held status',function(x) x.completionist_goal.by_key.j_caino.status='unknown' end},
    {'no held missing cargo',function(x) x.completionist_goal.by_key.j_caino.status='complete';x.completionist_goal.held_target_count=0;x.completionist_goal.held_target_keys={} end},
    {'stale cargo key',function(x) x.completionist_goal.held_target_keys={'j_joker'} end},
    {'sparse cargo list',function(x) x.completionist_goal.held_target_keys={[2]='j_caino'} end},
    {'stale cargo count',function(x) x.completionist_goal.held_target_count=2 end},
    {'malformed count table',function(x) x.completionist_goal.counts=1 end},
    {'incomplete total count',function(x) x.completionist_goal.counts.missing=2 end},
    {'unmodeled random Heart',function(x) x.route_blinds.Boss={key='bl_final_heart',name='Crimson Heart',chips=1000,boss=true} end},
    {'unknown skip tag',function(x) x.route_tags.Big={key='tag_negative',name='Negative Tag'} end},
    {'pending unknown tag',function(x) x.active_tags={{key='tag_boss'}} end},
    {'copy startup generator',function(x) x.jokers[3]=joker('j_certificate','Certificate','j3') end},
    {'perishable engine expires',function(x) x.jokers[2].ability.perishable=true;x.jokers[2].ability.perish_tally=1 end},
    {'population duplicate',function(x) x.playing_cards[2].id=x.playing_cards[1].id end},
    {'physical Joker id unavailable',function(x) x.jokers[1].id=nil end},
    {'unknown Joker identity',function(x) x.jokers[2].key='j_unknown' end},
    {'weak final boss capacity',function(x) x.route_blinds.Boss.chips=1e12 end},
    {'cash changes hand size',function(x) x.modifiers.minus_hand_size_per_X_dollar=5 end},
  }
  for _,entry in ipairs(mutations) do
    local x,m=copy(s),modules();entry[2](x,m)
    local before=Snapshot.fingerprint(x);local out,d=Route.suggest(x,m)
    check(not out,entry[1]..' declines unsupported skip')
    check(type(d.reason)=='string' and d.reason~='',entry[1]..' gives explicit reason')
    eq(Snapshot.fingerprint(x),before,entry[1]..' preserves input')
  end
  local incomplete=modules({after_play=Score.after_play,score=function(current,indices)
    local p=Score.score(current,indices)
    if current.blind.key=='bl_final_bell' and #indices==5 then p.uncertain=true end
    return p
  end})
  check(not Route.suggest(s,incomplete),'uncertain later subset cannot hide behind earlier supported clears')
  s.completionist_goal=nil
  check(Route.suggest(s,modules()),'ordinary objective needs no Gold profile metadata')
end

do
  local s=state();local full,d=Route.suggest(s,modules());check(full,'budget baseline exists')
  local total=d.evaluations
  for _,limit in ipairs({0,1,217,total-1}) do
    local calls=0;local counted={after_play=Score.after_play,score=function(current,indices) calls=calls+1;return Score.score(current,indices) end}
    local out,diag=Route.suggest(s,modules(counted),{max_evaluations=limit})
    check(not out,'partial Bell family never produces a skip at cap '..limit)
    eq(calls,diag.evaluations,'all attempted work counted at cap '..limit)
    check(calls<=limit,'no overrun at cap '..limit)
  end
  local exact,at=Route.suggest(s,modules(),{max_evaluations=total})
  check(exact,'exact complete-family cap succeeds');eq(at.evaluations,total,'exact cap fully used')
end

do
  local s=state();s.jokers[3]=joker('j_perkeo','Perkeo','j3')
  s.completionist_goal.by_key.j_perkeo={status='complete'}
  s.consumeables={{id='c1',key='c_mercury',ability={set='Planet',consumeable={hand_type='Pair'}}},
    {id='c2',key='c_mercury',edition={negative=true},ability={set='Planet',consumeable={hand_type='Pair'}}}}
  local before=Snapshot.fingerprint(s)
  local _,d=Route.suggest(s,modules())
  check(d.growth_cost and d.growth_cost>0,'whole Perkeo inventory foregone copying remains priced')
  eq(Snapshot.fingerprint(s),before,'ordinary and Negative consumables remain unchanged')
  s.jokers[1].ability.rental=true
  local _,rental=Route.suggest(s,modules())
  eq(rental.foregone_income,d.foregone_income-3,'rental saving remains counted exactly once')
  s.jokers[3]=joker('j_egg','Egg','j3',{extra=300})
  s.completionist_goal.by_key.j_egg={status='complete'}
  local out,cost=Route.suggest(s,modules())
  check(not out and cost.net_seconds<8,'material growth opportunity may still outweigh a Bell skip')
end
do
  local s=state();s.jokers[3]=joker('j_brainstorm','Brainstorm','j3')
  s.completionist_goal.by_key.j_brainstorm={status='complete'}
  local advice,d=Route.suggest(s,modules());check(advice,'supported current copy row can qualify')
  local order
  for _,world in ipairs(d.bell_worlds) do
    if not order then order=world.order_identity end
    eq(world.order_identity,order,'all composition worlds use the same physical Joker order')
  end
  local before=Snapshot.fingerprint(s)
  eq(s.jokers[1].id,'j1','front scoring target kept');eq(s.jokers[3].id,'j3','copy Joker kept at original index')
  Route.suggest(s,modules())
  eq(Snapshot.fingerprint(s),before,'routing never changes or invents a future Joker order')
end
print('Bell routing: '..checks..' manufactured checks passed; complete forced-card openings, no source run or win probability')
