local Finish=dofile('Brainstorm/Advisor/two_hand_finish.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Draws=dofile('Brainstorm/Advisor/draws.lua')
local Outcomes=dofile('Brainstorm/Advisor/sampled_outcomes.lua')
local Multi=dofile('Brainstorm/Advisor/multi_discard.lua')
local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Rewards=dofile('Brainstorm/Advisor/finish_rewards.lua')
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local function eq(a,b,label) check(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function shallow(t) local out={};for k,v in pairs(t) do out[k]=v end;return out end
local function card(id,rank)
  return {id=id,rank=rank,suit='Spades',enhancement='c_base',ability={}}
end
local function item(key)
  local set=key=='c_black_hole' and 'Spectral' or 'Planet'
  return {key=key,ability={name=key,set=set,consumeable={}}}
end
local function state()
  local s={phase='hand',ante=2,win_ante=8,hand={card('h1',13),card('h2',7),card('h3',4),card('h4',2)},
    deck={card('d1',14),card('d2',14)},playing_cards={},jokers={},consumeables={item('c_mercury')},
    consumable_limit=2,joker_limit=5,hands_left=2,hands_played=0,discards_left=1,discards_used=0,
    hand_size=4,hand_limit=5,dollars=20,chips=0,blind={key='bl_small',chips=100},current_round={},modifiers={},
    hands={Pair={level=1,played=12,chips=10,mult=2,l_chips=15,l_mult=1}},probabilities={normal=1}}
  for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do s.playing_cards[#s.playing_cards+1]=c end end
  return s
end
local function result(s)
  local play=Scoring.score(s,{1});play.indices={1}
  return {kind='discard',play=play,discard={indices={4}},resource_comparison={samples=4,
    horizon=s.hands_left,full_remaining_horizon=true,future_discards=false,prior={probability=0}}}
end
local modules={scoring=Scoring,search=Search,draws=Draws,sampled_outcomes=Outcomes,
  multi_discard=Multi,consumables=Consumables,strategy=Strategy,finish_rewards=Rewards}
do
  local s=state();local before=Snapshot.fingerprint(s)
  local upgraded=Consumables.apply(s,1,{})
  eq(Scoring.score(s,{1}).score,Scoring.score(upgraded,{1}).score,'Mercury has no immediate high-card gain')
  local suggestion,n,d=Finish.suggest(s,modules,result(s))
  check(suggestion and suggestion.action.kind=='use','upgrade pays off in the later observed Pair')
  eq(suggestion.action.area,'consumeables');eq(suggestion.action.index,1);eq(#suggestion.action.targets,0)
  eq(suggestion.action.indices,nil,'use does not pretend to select playing cards');eq(suggestion.action.queue,nil)
  eq(suggestion.indices,nil,'no hypothetical first play is queued')
  eq(d.first_actions,3);eq(d.complete,true);eq(d.completed_outer,4)
  eq(suggestion.no_use_probability,0);eq(suggestion.probability,1,'later upgrade improves all compared worlds')
  eq(d.consumable_offers[1].status,'selected');check(d.consumable_offers[1].required_uplift>=.15,'one extra use action has a cost')
  check(n<=12000);eq(Snapshot.fingerprint(s),before,'exact use planning is detached')
  local again,_,again_d=Finish.suggest(s,modules,result(s))
  eq(Snapshot.fingerprint(suggestion),Snapshot.fingerprint(again),'repeated first use deterministic')
  eq(Snapshot.fingerprint(d),Snapshot.fingerprint(again_d),'repeated evidence deterministic')
  print('owned final-plan actual score calls: '..n)
end
do
  local s=state();s.hands_left=3;s.blind.chips=120
  s.deck[3]=card('d3',14);s.playing_cards[#s.playing_cards+1]=s.deck[3]
  local suggestion,n,d=Finish.suggest(s,modules,result(s))
  check(suggestion and suggestion.action.kind=='use' and suggestion.horizon==3,'owned upgrade extends through the observed middle hand: '..tostring(d.reason)..' '..Snapshot.fingerprint(d.candidates))
  check(d.complete and d.estimated_probability>d.baseline_probability and n<=12000,'three-hand owned comparison completes within shared allowance')
  s=state();s.hands_left=3;s.blind.chips=100000000;s.hand_size=6
  s.hand[5]=card('h5',3);s.hand[6]=card('h6',5)
  for i=3,28 do s.deck[i]=card('d'..i,2+i%13) end
  s.playing_cards={};for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do s.playing_cards[#s.playing_cards+1]=c end end
  s.consumeables={item('c_mercury'),item('c_black_hole')}
  local _,count,full=Finish.suggest(s,modules,result(s))
  check(full.complete and full.first_actions==4 and count<=12000,'six-card three-hand comparison includes both owned alternatives')
  print('owned six-card three-hand score calls: '..count)
end
do
  -- Both use branches receive exactly the same outer/inner draws; no candidate
  -- weight or item-specific seed changes the sample population.
  local s=state();s.blind.chips=10000;s.consumeables={item('c_mercury'),item('c_black_hole')}
  local logs={mercury={},black_hole={}}
  local conditional={roll=Outcomes.roll,after_play=Outcomes.after_play}
  function conditional.fill(state,order,scorer,draws,seed,turn,bell)
    local after,reason=Outcomes.fill(state,order,scorer,draws,seed,turn,bell)
    if #state.consumeables==1 and after then
      local label=state.consumeables[1].key=='c_black_hole' and 'mercury' or 'black_hole'
      local ids={};for _,c in ipairs(after.hand) do ids[#ids+1]=c.id end
      logs[label][#logs[label]+1]=seed..':'..turn..':'..table.concat(ids,',')
    end
    return after,reason
  end
  local scoped=shallow(modules);scoped.sampled_outcomes=conditional
  local _,n,d=Finish.suggest(s,scoped,result(s))
  check(d.complete and d.first_actions==4,'two actual owned alternatives fully compared')
  check(#logs.mercury>4 and #logs.black_hole==#logs.mercury,'conditional inner samples were exercised')
  eq(table.concat(logs.mercury,'|'),table.concat(logs.black_hole,'|'),'common conditional worlds')
  eq(d.consumable_offers[1].status,'declined','no clear uplift cannot spend an upgrade')
  eq(d.consumable_offers[2].status,'declined');check(n<=12000)
end
do
  local s=state();s.jokers={{key='j_perkeo',ability={name='Perkeo'},blueprint_compat=true}}
  local _,_,d=Finish.suggest(s,modules,result(s))
  eq(d.first_actions,2,'protected last source never reaches sampled rescue comparison')
  eq(d.consumable_offers[1].protected_last_source,true);eq(d.consumable_offers[1].status,'declined')
  s.consumeables[1].edition={negative=true};s.consumable_limit=3
  _,_,d=Finish.suggest(s,modules,result(s));eq(d.first_actions,2,'Negative last source remains protected')
  eq(d.consumable_offers[1].capacity_after,2,'exact Negative use would remove its granted slot')
  s.consumeables[2]=item('c_mercury')
  local observed=0;local scoped=shallow(modules)
  scoped.strategy=setmetatable({preservation_cost=function(before,after,index)
    observed=observed+1
    eq(#before.consumeables,2);eq(#after.consumeables,1,'the entire inventory enters preservation')
    eq(after.consumeables[1].key,'c_mercury','duplicate source remains')
    return Strategy.preservation_cost(before,after,index)
  end},{__index=Strategy})
  _,_,d=Finish.suggest(s,scoped,result(s));eq(observed,2);eq(d.first_actions,4)
  eq(d.consumable_offers[1].protected_last_source,false);eq(d.consumable_offers[2].protected_last_source,false)
  eq(d.consumable_offers[1].capacity_after,2);eq(d.consumable_offers[2].capacity_after,3)
  -- Observatory loss is valued on the complete post-use inventory; neither
  -- an empty slot nor a retained duplicate grants an omitted multiplier.
  s=state();s.hands.Pair={level=20,played=20,chips=295,mult=21,l_chips=15,l_mult=1}
  s.used_vouchers={v_observatory=true};s.blind.chips=100000
  local after=Consumables.apply(s,1,{});local cost=Strategy.preservation_cost(s,after,1)
  _,_,d=Finish.suggest(s,modules,result(s));eq(d.consumable_offers[1].inventory_cost,cost)
  check(cost>0,'matching Observatory Planet has a real retention cost')
end
do
  local s=state();local scoped=shallow(modules)
  scoped.strategy=setmetatable({preservation_cost=function()return 100,'valuable inventory',false end},{__index=Strategy})
  local suggestion,_,d=Finish.suggest(s,scoped,result(s))
  check(not suggestion or suggestion.action.kind~='use','sampled gain cannot ignore large inventory cost')
  check(d.consumable_offers[1].required_uplift>1,'explicit inventory conversion is not capped away')
  s.consumeables={item('c_mercury'),item('c_pluto'),item('c_black_hole')}
  local uses=0;scoped=shallow(modules);scoped.consumables={apply=function()uses=uses+1;error('large family must decline before cloning')end}
  _,_,d=Finish.suggest(s,scoped,result(s));eq(uses,0);eq(d.first_actions,2);eq(d.consumable_scope_declined,true)
  eq(#d.consumable_offers,3,'every item is recorded even when the family is too large')
  s=state();s.consumeables[1].ability.consumeable.hand_type='Flush';s.consumeables[2]=item('c_black_hole')
  local none,n;none,n,d=Finish.suggest(s,modules,result(s))
  eq(none,nil);eq(n,0);eq(d.complete,false,'unsupported use invalidates whole alternative comparison')
  eq(#d.consumable_offers,2,'later offered items remain reviewable after an unsupported item')
  s=state();none,n,d=Finish.suggest(s,modules,result(s),nil,{max_evaluations=30})
  eq(none,nil);eq(n,30);eq(d.complete,false,'no partial use comparison can override')
  s=state();s.hand_size=7;_,_,d=Finish.suggest(s,modules,result(s));eq(d.first_actions,2,'large hands keep existing no-use scope')
  for _,field in ipairs({'consumable','ordering','growth'}) do
    s=state();local incumbent=result(s);incumbent[field]={}
    none,n=Finish.suggest(s,modules,incumbent);eq(none,nil);eq(n,0,'existing tactical action still wins')
  end
end
do
  -- after_play returns a score without indices. The actual middle clear must
  -- attach its chosen indices before valuing Gold/Blue cards left in hand.
  local s=state();s.consumeables={};s.hands_left=3;s.hand_size=4
  s.hand[2].enhancement='m_gold';s.hand[2].seal='Blue'
  for i=3,10 do s.deck[i]=card('d'..i,2) end
  s.playing_cards={};for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do s.playing_cards[#s.playing_cards+1]=c end end
  local fake={}
  function fake.score(state,indices)
    local first=false;for _,i in ipairs(indices) do if i==1 then first=true end end
    return {score=first and (state.hands_left==2 and 80 or 20) or 1,
      legal=true,hand='High Card',scoring_indices=indices}
  end
  function fake.after_play(state,indices)
    local after=Snapshot.copy(state);local score=fake.score(state,indices);score.from_transition=true
    after.hand={};local selected={};for _,i in ipairs(indices) do selected[i]=true end
    for i,c in ipairs(state.hand) do if not selected[i] then after.hand[#after.hand+1]=Snapshot.copy(c) end end
    after.chips=state.chips+score.score;after.hands_left=state.hands_left-1;after.hands_played=state.hands_played+1
    return after,{},score
  end
  fake.after_discard=Scoring.after_discard
  local valued=0;local reward={prepare=Rewards.prepare,value=function(state,play,prepared)
    local value,details=Rewards.value(state,play,prepared)
    if state.hands_left==2 and play.from_transition then
      valued=valued+1;check(play.indices and play.indices[1]==1,'actual middle selection is attached')
      eq(details.held_dollars,0,'played Gold is not a held reward');eq(details.blue_planets,0,'played Blue seal generates no held Planet')
    end
    return value,details
  end}
  local scoped=shallow(modules);scoped.scoring=fake;scoped.finish_rewards=reward
  local incumbent=result(s);incumbent.play.score=20;incumbent.discard.indices={4}
  local _,n,d=Finish.suggest(s,scoped,incumbent)
  check(d.complete and valued==8,'both first actions receive four correct middle-clear reward valuations')
  check(n<=12000)
end
print('owned finishing: '..checks..' checks passed')
