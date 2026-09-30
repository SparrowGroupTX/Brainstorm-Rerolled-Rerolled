local P='Brainstorm/Advisor/'
local Preflight=dofile(P..'hand_copy_preflight.lua')
local Decision=dofile(P..'decision.lua')
local Search=dofile(P..'search.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Cache=dofile('Brainstorm/Advisor/score_cache.lua')
local Phase=dofile('Brainstorm/Advisor/phase_copy.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,label)checks=checks+1;assert(v,label)end
local function eq(a,b,label)check(a==b,label..': '..tostring(a)..' ~= '..tostring(b))end
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
local function joker(id,key,name,ability)
  ability=ability or {};ability.name=name;ability.set='Joker'
  return{id=id,key=key,name=name,ability=ability,blueprint_compat=true,face_down=false,pinned=false}
end
local function card(id,rank,suit)
  return{id=id,rank=rank,nominal=math.min(rank,10),suit=suit or 'Spades',enhancement='c_base',
    face_down=false,ability={played_this_ante=false},base={times_played=0}}
end
local function state()
  local s={phase='hand',ante=4,blind={key='bl_big',name='Big Blind',chips=6000},chips=0,
    current_round={discards_left=0,hands_left=4,hands_played=0},discards_left=0,discards_used=4,
    hands_left=4,hands_played=0,hand_size=8,hand_limit=5,dollars=30,modifiers={},probabilities={normal=1},
    consumeable_buffer=0,consumable_limit=2,used_vouchers={v_observatory=true},
    jokers={joker('per','j_perkeo','Perkeo'),
      joker('yor','j_yorick','Yorick',{x_mult=8,yorick_discards=7,extra={discards=23,xmult=1}}),
      joker('copy','j_brainstorm','Brainstorm'),joker('dro','j_droll','Droll Joker',{t_mult=10,type='Flush'}),
      joker('sup','j_supernova','Supernova')},hand={},deck={},playing_cards={},hands={
      ['High Card']={level=1,chips=5,mult=1,played=2,visible=true},
      Flush={level=1,chips=35,mult=4,played=2,visible=true}},consumeables={
      {id='death',key='c_death',edition={negative=true,type='negative'},ability={name='Death',set='Tarot'},
       copy_source={metadata={price=3,retained=false}}},
      {id='planet',key='c_mercury',ability={set='Planet',consumeable={hand_type='Pair'}}}}}
  for i,r in ipairs({2,3,5,7,9,10,11,13})do local c=card('h'..i,r);s.hand[i]=c;s.playing_cards[#s.playing_cards+1]=c end
  s.hand[1].seal='Blue';s.hand[2].enhancement='m_gold';s.hand[2].ability.h_dollars=3
  for i=1,12 do local c=card('d'..i,2+i%10,'Hearts');s.deck[i]=c;s.playing_cards[#s.playing_cards+1]=c end
  return s
end
local rawscore=Scoring.score;local score_calls=0
Scoring.score=function(...)score_calls=score_calls+1;return rawscore(...)end
local modules={scoring=Scoring,score_cache=Cache,search=Search,phase_copy=Phase,hand_copy_preflight=Preflight,
  consumables={suggest=function()return nil,0,{}end}}
local function run(s,opts)
  score_calls=0;local before=Snapshot.fingerprint(s);local result=Decision.run(s,modules,nil,opts)
  eq(Snapshot.fingerprint(s),before,'decision leaves full input unchanged')
  check(score_calls<=result.evaluations,'all actual scores fit the common reported ledger')
  check(result.evaluations<=((opts and opts.search or {}).max_evaluations or 140000),'ordinary ledger cap')
  return result,score_calls
end
local function family(s)
  local out={};Search.combinations(#s.hand,math.min(s.hand_limit or 5,5),function(indices)
    local r=Scoring.score(s,indices);if r.legal then r.indices=copy(indices);out[#out+1]=r end
  end);return out
end
local function compare(s,modify,budget)
  local plan=assert(Preflight.prepare(s,modules));local f=family(s)
  local n=0;local context={budget_left=function()return budget or 436 end,
    after_play=function(st,indices)
      n=n+1;local a,b,c=Scoring.after_play(st,indices)
      if modify then a,b,c=modify(n,a,b,c,st==plan.changed)end
      return a,b,c
    end}
  local r,d=Preflight.compare(plan,Scoring,f,context)
  eq(d.score_calls,n,'each actual resource transition charged once')
  return r,d,n,f,plan
end
math.random=function()error('fixture touched RNG')end
pseudorandom=function()error('fixture touched source RNG')end

do
  local s=state();local r,n=run(s)
  check(r.reorder_only and r.copy_preflight.complete,'new held clear publishes reversible reorder only')
  eq(r.action.kind,'reorder_jokers','only rearrangement is executable')
  check(r.needs_refresh and r.ordering.needs_refresh,'fresh advice required')
  eq(r.copy_preflight.paired_subsets,218,'all 218 held subsets compared')
  eq(r.copy_preflight.score_calls,436,'both full transition families charged')
  eq(n,654,'218 initial scores plus436 transition scores')
  eq(r.evaluations,n,'exact ordinary accounting on complete family')
  check(not r.fast_clear and n<=658,'preflight does not impersonate70-score fast clear')
  eq(r.copy_preflight.copy_events_shifted,1,'one actual Perkeo copy becomes Yorick copying')
  eq(r.copy_preflight.copy_routes_before.copy.key,'j_perkeo','actual original copy route')
  eq(r.copy_preflight.copy_routes_after.copy.key,'j_yorick','actual changed copy route')
  check(r.copy_preflight.held_clear.score>=6000,'supported clear witness')
  check(r.copy_preflight.held_clear.baseline_score<6000,'new clear not old overkill')
  eq(#s.consumeables,2,'all inventory remains owned')
  check(s.consumeables[1].edition.negative,'Negative Perkeo pool card stays present')
  check(s.used_vouchers.v_observatory,'Observatory survives projection')
  local fresh=Phase.reorder(s,r.action.order);check(not Preflight.prepare(fresh,modules),'no preflight bounce after actual order')
  local again,calls=run(fresh)
  check(again.fast_clear and calls<=70,'fresh ordinary advice uses original fast-clear allowance')
  eq(again.action.kind,'play','fresh decision selects its own play')
end

do
  local s=state();local r,n=run(s,{search={max_evaluations=218}})
  check(not r.reorder_only,'no partial family under small budget')
  eq(n,218,'insufficient remaining capacity declines before the pair loop')
  eq(r.copy_preflight_diagnostics.score_calls,0,'declined family adds zero scores')
  check(r.copy_preflight_diagnostics.reason:find('cannot fit'),'explicit complete-budget reason')
  s=state();s.blind.chips=100000000
  r,n=run(s)
  check(not r.reorder_only,'no clear falls back')
  eq(r.copy_preflight_diagnostics.score_calls,436,'complete losing family remains charged')
  check(r.evaluations>=654 and n>=654,'fallback never erases attempted work')
end

do
  local s=state();local r,d,n=compare(s,function(call,a,b,c,changed)
    if call==436 and changed then a.consumeables[1].copy_source.metadata.retained=true end
    return a,b,c
  end)
  check(not r and not d.complete,'unsupported last resource pair prevents prefix success')
  eq(n,436,'late failure retains allspent work')
  eq(d.paired_subsets,217,'only complete earlier pairs are counted')
  check(d.reason:find('resource states differ'),'full historical metadata is protected')
  for _,field in ipairs({'dollars','hands','playing_cards','jokers','consumeables'})do
    local proposal,diag=compare(state(),function(call,a,b,c,changed)
      if changed and a then
        if field=='dollars' then a.dollars=a.dollars-1
        elseif field=='hands' then a.hands[c.hand].level=a.hands[c.hand].level+1
        elseif field=='playing_cards' then a.playing_cards[1].ability.perma_bonus=2
        elseif field=='jokers' then a.jokers[1].ability.yorick_discards=999
        else table.remove(a.consumeables,1)end
      end
      return a,b,c
    end)
    check(not proposal and not diag.complete,'whole resource comparison rejects changed '..field)
  end
  r,d,n=compare(state(),function(call,a,b,c,changed)
    if changed and call==436 then return nil,'synthetic unsupported',nil end
    return a,b,c
  end)
  check(not r and not d.complete and n==436,'last unsupported transition cannot publish')
  r,d=compare(state(),function(call,a,b,c,changed)
    if changed and call==436 then c.score=0 end;return a,b,c
  end)
  check(not r and not d.complete,'a single worse paired score rejects otherwise winning family')
end

do
  local checks_by_name={
    invalid_discards=function(s)s.discards_left=-1 end,
    burnt=function(s)s.jokers[#s.jokers+1]=joker('burn','j_burnt','Burnt Joker')end,
    lucky=function(s)s.hand[1].enhancement='m_lucky'end,
    random_glass=function(s)s.hand[1].enhancement='m_glass'end,
    hook=function(s)s.blind.key='bl_hook';s.blind.name='The Hook'end,
    crimson=function(s)s.blind.key='bl_final_heart';s.blind.name='Crimson Heart'end,
    acorn=function(s)s.blind.key='bl_final_acorn';s.blind.name='Amber Acorn'end,
    unknown_blind=function(s)s.blind.key='bl_custom'end,
    unknown_modifier=function(s)s.modifiers.custom_after_play=true end,
    unknown_deck=function(s)s.deck_key='b_custom'end,
    unknown_joker=function(s)s.jokers[4].key='j_custom'end,
    dagger=function(s)s.jokers[4]=joker('dag','j_ceremonial','Ceremonial Dagger')end,
    hidden=function(s)s.hand[1].face_down=true end,
    shuffling=function(s)s.jokers_shuffling=true end,
    stale_name=function(s)s.jokers[1].ability.name='Unknown'end,
    unknown_consumable=function(s)s.consumeables[1].key='c_custom'end,
    wrong_inventory_set=function(s)s.consumeables[1].ability.set='Planet'end,
    unknown_inventory_edition=function(s)s.consumeables[1].edition={custom=true}end,
    unowned_identity=function(s)s.consumeables[1].id=nil end,
    duplicate_population=function(s)s.playing_cards[#s.playing_cards+1]=s.playing_cards[1]end,
    missing_population=function(s)table.remove(s.playing_cards,1)end,
    divergent_population=function(s)s.playing_cards[1]=copy(s.playing_cards[1]);s.playing_cards[1].rank=14 end,
    unknown_seal=function(s)s.hand[1].seal='Orange'end,
    negative_playing=function(s)s.hand[1].edition={negative=true}end,
    foil_joker=function(s)s.jokers[2].edition={foil=true}end,
    pinned=function(s)for _,j in ipairs(s.jokers)do j.pinned=true end end,
    nonperkeo_copy=function(s)s.jokers[1],s.jokers[4]=s.jokers[4],s.jokers[1]end,
    depleted_copy=function(s)s.jokers[3].debuff=true end,
  }
  for label,change in pairs(checks_by_name)do local s=state();change(s);local before=score_calls
    check(not Preflight.prepare(s,modules),'initial guard declines '..label);eq(score_calls,before,'guard costs no scoring '..label)
  end
  for _,retry in ipairs({{active=true},{matched=true},{pending=true},{unavailable=true}})do
    check(not Preflight.prepare(state(),modules,retry),'marked/active retry cannot bypass its own comparison')
  end
  check(Preflight.prepare(state(),modules,{active=false,valid=true,reloads_used=4}),'clean retry metadata retains prior count without mutation')
  local s=state();s.deck_key='b_red';s.modifiers={scaling=3,no_blind_reward={Small=true},
    enable_eternals_in_shop=true,enable_perishables_in_shop=true,enable_rentals_in_shop=true}
  check(Preflight.prepare(s,modules),'source-shaped normal Gold stake modifiers remain supported')
end

do
  local s=state();s.blind={key='bl_psychic',name='The Psychic',chips=6000}
  local r,n=run(s)
  check(r.reorder_only,'Psychic five-card family can qualify')
  eq(r.copy_preflight.subsets,56,'all56 legal five-card plays included')
  eq(#r.copy_preflight.held_clear.indices,5,'Psychic witness always five cards')
  s=state();s.blind={key='bl_final_bell',name='Cerulean Bell',chips=6000};s.hand[8].ability.forced_selection=true
  r,n=run(s);check(r.reorder_only,'known forced Bell card can qualify')
  local found=false;for _,i in ipairs(r.copy_preflight.held_clear.indices)do if i==8 then found=true end end
  check(found,'forced identity retained in held clear witness')
  eq(r.copy_preflight.subsets,99,'all99 subsets containing forced card included')
end

do
  local s=state();local plan=assert(Preflight.prepare(s,modules));local f=family(s);table.remove(f,#f)
  local touched=false;local r,d=Preflight.compare(plan,Scoring,f,{budget_left=function()return 436 end,
    after_play=function()touched=true;error('incomplete family must not evaluate')end})
  check(not r and not touched,'missing last legal subset declines without extra evaluation')
  f=family(s);f[#f+1]=f[1]
  r,d=Preflight.compare(plan,Scoring,f,{budget_left=function()return 436 end,after_play=function()error('duplicate')end})
  check(not r,'duplicate family rejected')
end

do
  local s=state();s.discards_left=3;s.current_round.discards_left=3
  local r,n=run(s)
  check(r.reorder_only,'remaining discards require the full supported discard family')
  eq(r.copy_preflight.paired_discards,218,'all current discards compared in both physical orders')
  eq(r.copy_preflight.discard_transition_calls,436,'bounded zero-score discard transitions recorded separately')
  eq(n,654,'discard resource verification invokes no scores')
  local changed=Phase.reorder(s,r.action.order)
  local after,e=Scoring.after_discard(changed,{1,2,3,4,5})
  eq(e.discarded_count,5,'five-card Yorick discard remains available after reorder')
  local yorick;for _,j in ipairs(after.jokers)do if j.key=='j_yorick'then yorick=j end end
  eq(yorick.ability.yorick_discards,2,'copying Yorick does not multiply physical discard counter growth')
  local raw_discard=Scoring.after_discard
  local calls=0
  Scoring.after_discard=function(st,indices)
    calls=calls+1;local a,b=raw_discard(st,indices)
    if calls==436 then a.consumeables[1].copy_source.metadata.price=999 end
    return a,b
  end
  local proposal,d=compare(s)
  Scoring.after_discard=raw_discard
  check(not proposal and not d.complete,'a changed last discard resource rejects the whole preflight')
  eq(calls,436,'late discard failure retains full work receipt')
  s.hand[1].seal='Purple';s.consumable_limit=3
  check(not Preflight.prepare(s,modules),'possible Purple generation rejects before paired scoring')
  s.consumable_limit=2
  local allowed=run(s)
  check(allowed.reorder_only,'an exactly full whole inventory creates no imagined Purple card')
  s.jokers[#s.jokers+1]=joker('burn','j_burnt','Burnt Joker');s.discards_used=0
  check(not Preflight.prepare(s,modules),'first Burnt opportunity remains owned by the existing strategy')
end

do
  local s=state();local oldphase=modules.phase_copy;local oldcons=modules.consumables
  modules.phase_copy=setmetatable({apply=function()error('preflight cannot stack post-decision phase allowance')end},{__index=Phase})
  modules.consumables={suggest=function()error('reversible result cannot dispatch irreversible specialist')end}
  local result=run(s);check(result.reorder_only,'preflight result skips later specialists and phase wrapper')
  modules.phase_copy=oldphase;modules.consumables=oldcons
  s=state();s.discards_left=3;s.current_round.discards_left=3;s.blind.chips=100000000
  result=run(s,{search={max_evaluations=1200}})
  check(not result.reorder_only and result.evaluations<=1200,'no-clear fallback retains bounded ordinary discard search')
  eq(result.copy_preflight_diagnostics.score_calls,436,'all candidate score work remains charged before fallback search')
  check(result.copy_preflight_diagnostics.discard_transition_calls==nil,'losing copy family does not spend pointless discard transition work')
  local actual_growth=dofile('Brainstorm/Advisor/growth.lua')
  local strategy=dofile('Brainstorm/Advisor/strategy.lua')
  s=state();s.discards_left=3;s.current_round.discards_left=3;s.blind.chips=500
  s.jokers[2].ability.yorick_discards=3
  local order=Phase.target_order(s,'j_yorick');s=Phase.reorder(s,order)
  local oldgrowth,oldstrategy=modules.growth,modules.strategy;modules.growth=actual_growth;modules.strategy=strategy
  local fresh=run(s)
  modules.growth=oldgrowth;modules.strategy=oldstrategy
  check(fresh.fast_clear,'fresh post-reorder decision has normal known-clear development')
  eq(fresh.action.kind,'discard','fresh growth provider still chooses useful Yorick investment')
  eq(#fresh.action.indices,5,'fresh safe growth still spends a full five-card discard')
  check(not fresh.copy_preflight,'fresh decision never carries the old held witness as permission')
end

do
  local changes={
    root_metatable=function(s)setmetatable(s,{__index=function()error('no metatable access')end})end,
    locked_false_metatable=function(s)s.meta=setmetatable({},{__metatable=false,__index=function()error('locked table callback')end})end,
    cycle=function(s)s.metadata=s end,
    nested_cycle=function(s)s.metadata={};s.metadata.child=s.metadata end,
    function_value=function(s)s.metadata=function()error('do not call')end end,
    thread_value=function(s)s.metadata=coroutine.create(function()end)end,
    nan=function(s)s.metadata=0/0 end,
    infinity=function(s)s.metadata=math.huge end,
    function_key=function(s)s.metadata={[function()end]=1}end,
    oversized_key=function(s)s.metadata={[string.rep('x',4097)]=1}end,
    oversized_string=function(s)s.metadata=string.rep('x',4097)end,
    deep=function(s)s.metadata={};local t=s.metadata;for i=1,14 do t.child={};t=t.child end end,
    nodes=function(s)s.metadata={};for i=1,32768 do s.metadata[i]=0 end end,
    total_string_bytes=function(s)s.metadata={};for i=1,300 do s.metadata[i]=string.rep('x',2000)end end,
    population_limit=function(s)for i=#s.playing_cards+1,129 do s.playing_cards[i]=card('p'..i,2)end end,
    deck_limit=function(s)for i=#s.deck+1,129 do s.deck[i]=card('d'..i,2)end end,
    inventory_limit=function(s)for i=#s.consumeables+1,33 do s.consumeables[i]={id='c'..i,key='c_death',ability={set='Tarot'}}end end,
  }
  for label,change in pairs(changes)do local s=state();change(s);local n=score_calls
    check(not Preflight.prepare(s,modules),'bounded plain input rejects '..label)
    eq(score_calls,n,'malformed input never scores '..label)
  end
  local s=state();s.metadata={text=string.rep('a',4096),finite=123};s.alias=s.metadata
  check(Preflight.prepare(s,modules),'bounded shared acyclic metadata stays permitted')
  local r,d=compare(state(),function(call,a,b,c)
    if a then a.metadata=a end
    return a,b,c
  end)
  check(not r and not d.complete,'unexpected cyclic output cannot make equality recurse forever')
end

print('Hand copy preflight: '..checks..' checks passed; synthetic only, no captured/source execution')
