-- Manufactured public inputs only. No captured state, source replay, RNG, or live game.
local base='Brainstorm/Advisor/'
local B=dofile(base..'acorn_belief.lua')
local O=dofile(base..'acorn_ordering.lua')
local D=dofile(base..'decision.lua')
local S=dofile(base..'scoring.lua')
local fingerprint=dofile(base..'snapshot.lua').fingerprint
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function eq(actual,expected,message)
  check(actual==expected,(message or 'check')..': '..tostring(actual)..' ~= '..tostring(expected))
end
local function forbidden() error('Unqualified fallback or random sampling was called.') end
local function joker(key,name,ability)
  ability=ability or {};ability.name=name
  return {key=key,ability=ability,blueprint_compat=true,sell_cost=2}
end
local function belief()
  return assert(B.start({joker('j_joker','Joker',{mult=4}),
    joker('j_cavendish','Cavendish',{extra={Xmult=3}})},'manufactured-lucky-340',
    {public_before_shuffle=true}))
end
local function card(rank,lucky)
  return {id='manufactured-playing:'..rank,rank=rank,nominal=math.min(rank,10),suit='Spades',
    enhancement=lucky and 'm_lucky' or 'c_base',
    ability=lucky and {mult=20,p_dollars=20} or {}}
end
local function snapshot()
  local s={phase='hand',hand={card(11,true),card(2),card(5)},hands={},deck={},playing_cards={},
    hands_left=4,discards_left=3,hand_limit=5,hand_size=8,chips=0,dollars=31,
    blind={key='bl_final_acorn',name='Amber Acorn',chips=1000000000},
    modifiers={},probabilities={normal=1},used_vouchers={v_observatory=true},
    consumeables={{key='c_pluto',ability={name='Pluto',set='Planet',consumeable={hand_type='High Card'}},
      edition={negative=true}},
      {key='c_mercury',ability={name='Mercury',set='Planet',consumeable={hand_type='Pair'}}}}}
  for i,c in ipairs(s.hand) do s.playing_cards[i]=B.copy(c) end
  local poison=setmetatable({face_down=true},{__index=function(_,key)
    error('Concealed Joker field was read: '..tostring(key))
  end})
  s.jokers={poison,poison};s.public_joker_belief=belief()
  return s
end
local function modules(scorer)
  return {acorn_belief=B,acorn_ordering=O,scoring=scorer,
    search={run=forbidden},concealed_belief={run=forbidden},score_cache={new=forbidden},
    phase_copy={apply=forbidden},retry_policy={apply=forbidden},strategy={advise=forbidden},
    consumables={suggest=forbidden},ordering={suggest=forbidden}}
end
local function limits(n)
  return {max_evaluations=n,max_order_evaluations=0}
end
local function project(s,b,world)
  local state={}
  for key,value in pairs(s) do if key~='jokers' and key~='public_joker_belief' then state[key]=B.copy(value) end end
  state.jokers={}
  for slot,ordinal in ipairs(world) do
    local j=B.copy(b.inventory[ordinal]);j.id='public-belief:'..ordinal;j.face_down=false
    state.jokers[slot]=j
  end
  return state
end

local old_random,old_randomseed,old_pseudorandom=math.random,math.randomseed,_G.pseudorandom
math.random,math.randomseed,_G.pseudorandom=forbidden,forbidden,forbidden
local ok,err=pcall(function()
  do
    local s=snapshot();local original=fingerprint(s);local calls,seen=0,{}
    local scorer={score=forbidden,lower_bound=function(state,indices)
      calls=calls+1
      eq(state.dollars,31,'Every world retains public cash')
      eq(state.discards_left,3,'Every world retains all available discards')
      eq(state.hands_left,4,'Every world retains all available hands')
      eq(fingerprint(state.consumeables),fingerprint(s.consumeables),'Every world retains the complete consumable inventory')
      check(state.used_vouchers.v_observatory,'Held Observatory scoring is preserved')
      local order={}
      for i,j in ipairs(state.jokers) do
        check(j~=s.jokers[i] and j.id:sub(1,14)=='public-belief:','Only synthetic public Jokers enter scoring')
        order[i]=j.key
      end
      local key=table.concat(order,',')..'|'..table.concat(indices,',')
      check(not seen[key],'Each admitted current-order world/subset pair is scored once')
      seen[key]=true
      local before=fingerprint(state);local result=S.lower_bound(state,indices)
      eq(fingerprint(state),before,'The public floor scorer is pure')
      return result
    end}
    local action,reported,diag=O.suggest(s,s.public_joker_belief,scorer,B,limits(14))
    check(action and action.kind=='play','A Lucky hand supports a complete current-order public action')
    eq(reported,14,'All seven nonempty subsets in both worlds are charged')
    eq(calls,14,'Reported calls equal actual lower-bound calls')
    eq(diag.subsets,7,'No candidate containing or retaining Lucky is dropped')
    check(diag.complete and not diag.order_complete,'Only the independently complete current-order family is certified')
    check(diag.supported_random_floor,'The comparison records its supported random-floor scope')
    local distinct=0;for _ in pairs(seen) do distinct=distinct+1 end
    eq(distinct,14,'Full common-world family is covered')
    eq(fingerprint(s),original,'Public planning preserves the complete supplied snapshot')
    calls=0;seen={}
    local result=D.run(s,modules(scorer),nil,{acorn_belief=limits(14)})
    check(result.action and result.action.kind=='play','Decision dispatch admits the manufactured Lucky hand')
    eq(result.evaluations,14,'Decision accounts for every actual lower-bound call')
    eq(calls,14,'Decision never spends an uncharged mean-scoring pass')
    check(result.play.uncertain and result.conservative and not result.deterministic_exact,
      'A random and identity-world floor is never represented as an exact realized score')
    check(result.public_joker_belief.supported_random_floor,'The public decision proof retains the random-floor qualification')
    eq(result.bound_kind,'public_joker_world_floor','Public reorder execution protocol remains compatible')
    check(table.concat(result.strategy.lines,' '):find('Lucky effects use supported score floors',1,true),
      'User-facing advice distinguishes the floor from average or successful triggers')
    eq(fingerprint(s),original,'Decision dispatch preserves inventory, cash and remaining resources')
  end
  do
    -- A random mean would claim a clear; the actual supported floor cannot.
    local s=snapshot();s.hand={card(14,true)};s.hand[1].nominal=11
    s.playing_cards={B.copy(s.hand[1])};s.consumeables={};s.used_vouchers={};s.blind.chips=200
    local b=s.public_joker_belief;local floor_min,mean_min=math.huge,math.huge
    for _,world in ipairs(b.worlds) do
      local public=project(s,b,world)
      floor_min=math.min(floor_min,S.lower_bound(public,{1}).score)
      mean_min=math.min(mean_min,S.score(public,{1}).score)
    end
    eq(floor_min,112,'Manufactured world floor includes no optional Lucky trigger')
    eq(mean_min,304,'Manufactured expected score would give a false all-world clear')
    local calls=0
    local result=D.run(s,modules({score=forbidden,lower_bound=function(state,indices)
      calls=calls+1;return S.lower_bound(state,indices)
    end}),nil,{acorn_belief=limits(2)})
    check(result.action and result.action.kind=='play','The complete non-clearing public action remains available')
    eq(result.play.score,floor_min,'Displayed recommendation uses the floor, never the expected score')
    eq(calls,2,'Both consistent public worlds contribute to the floor')
    check(not result.play.immediate_clear_all_worlds,'Mean-only threshold crossing does not certify a clear')
    check(result.public_information_fallback,'Non-clearing action retains its limited information scope')
  end
  do
    local s=snapshot();local calls=0
    local result=D.run(s,modules({score=forbidden,lower_bound=function(state,indices)
      calls=calls+1
      if #indices==1 and indices[1]==1 and state.jokers[1].key=='j_joker' then
        return {legal=false,score=0,reliable_bound=false}
      end
      return {legal=true,score=1000000001,reliable_bound=true}
    end}),nil,{acorn_belief=limits(14)})
    check(result.action and result.action.kind=='play','An explicitly illegal world is handled as legality, not a missing score')
    check(not (#result.action.indices==1 and result.action.indices[1]==1),
      'A play legal in only one identity world cannot become the fixed action')
    eq(calls,14,'Common-world legality does not drop the remaining candidate family')
    eq(result.evaluations,14,'Every legal and illegal result is counted')
  end
  do
    local s=snapshot();local b=s.public_joker_belief
    local action,n,diag=O.suggest(s,b,{score=forbidden},B,limits(14))
    eq(action,nil,'A missing floor API declines instead of using mean or raw exact fallback')
    eq(n,0,'Missing floor API spends no scoring calls')
    check(not diag.complete,'Missing floor support cannot yield a complete certificate')
    local absent=D.run(s,modules({score=forbidden}),nil,{acorn_belief=limits(14)})
    eq(absent.action,nil,'Decision also refuses a missing floor API')
    eq(absent.evaluations,0,'Decision spends no hidden or mean scores when the floor API is missing')
    for _,mode in ipairs({'missing','false','uncertain','warning','nonfinite'}) do
      local calls=0
      local bad={score=forbidden,lower_bound=function()
        calls=calls+1;local result={score=9999999999,legal=true,reliable_bound=true}
        if mode=='missing' then result.reliable_bound=nil
        elseif mode=='false' then result.reliable_bound=false
        elseif mode=='uncertain' then result.uncertain=true
        elseif mode=='warning' then result.warnings={'Unsupported manufactured mechanic'}
        else result.score=math.huge end
        return result
      end}
      local result=D.run(s,modules(bad),nil,{acorn_belief=limits(14)})
      eq(result.action,nil,'A '..mode..' floor cannot publish partial or false clearing evidence')
      eq(result.evaluations,calls,'Rejected '..mode..' floor still has exact accounting')
      check(calls>0 and calls<=14,'Rejected '..mode..' floor respects the ordinary allowance')
    end
  end
  do
    local s=snapshot();local b=s.public_joker_belief
    local no_calls={score=forbidden,lower_bound=forbidden}
    local action,n=O.suggest(s,b,no_calls,B,limits(13))
    eq(action,nil,'An allowance smaller than the whole family is refused')
    eq(n,0,'No partial common-world family starts')
    s.hand[2].enhancement='m_unqualified'
    eq(O.suggest(s,b,no_calls,B,limits(14)),nil,'Unknown playing-card mechanics remain unavailable')
    s.hand[2].enhancement='m_glass'
    eq(O.suggest(s,b,no_calls,B,limits(14)),nil,'Glass and population scope is not expanded by the Lucky repair')
    s.hand[2].enhancement='m_gold'
    eq(O.suggest(s,b,no_calls,B,limits(14)),nil,'Held Gold reward scope remains unchanged')
    s.hand[2].enhancement='c_base';s.hand[2].seal='Blue'
    eq(O.suggest(s,b,no_calls,B,limits(14)),nil,'Blue generation is not silently omitted by the Lucky repair')
    s.hand[2].seal='Purple'
    eq(O.suggest(s,b,no_calls,B,limits(14)),nil,'Purple generation scope remains unchanged')
    s.hand[2].seal=nil;s.hand[2].face_down=true
    eq(O.suggest(s,b,no_calls,B,limits(14)),nil,'Concealed playing cards still decline')
    s.hand[2].face_down=false;s.hand[1].enhancement='c_base'
    local score_calls=0
    local ordinary={score=function(state,indices)score_calls=score_calls+1;return S.score(state,indices)end,
      lower_bound=forbidden}
    local plain,plain_calls=O.suggest(s,b,ordinary,B,limits(14))
    check(plain and plain.kind=='play','Ordinary deterministic hands keep their existing exact-scoring path')
    eq(plain_calls,14,'The plain complete family keeps its existing score accounting')
    eq(score_calls,14,'Plain worlds do not acquire unnecessary floor passes')
  end
  do
    local s=snapshot();s.hand={card(14,true)};s.hand[1].nominal=11
    s.playing_cards={B.copy(s.hand[1])};s.consumeables={};s.used_vouchers={};s.blind.chips=200
    local before=s.public_joker_belief
    s.public_joker_belief=assert(B.observe(before,{epoch=before.epoch,slot=1,
      type='rendered_status',phase='play',qualified_render=true,channel='x_mult',amount=3}))
    eq(#s.public_joker_belief.worlds,1,'Manufactured visible activation narrows the row without reading backs')
    local calls=0
    local scorer={score=forbidden,lower_bound=function(state,indices)
      calls=calls+1;return S.lower_bound(state,indices)
    end}
    local original=fingerprint(s)
    local result=D.run(s,modules(scorer),nil,{acorn_belief={max_evaluations=2,max_order_evaluations=1}})
    check(result.action and result.action.kind=='reorder_jokers','A complete Lucky floor comparison can certify a shared clearing reorder')
    eq(table.concat(result.action.order,','),'2,1','The observed Cavendish slot moves after additive Mult')
    eq(result.acorn_diagnostics.profiles[1][1].minimum,112,'Current-order Lucky floor does not clear the target')
    eq(result.play.score,240,'Reordered Lucky floor clears with no assumed trigger')
    eq(result.evaluations,2,'Both current and alternate order floors are charged')
    eq(calls,2,'Reorder uses exactly two production lower-bound passes')
    check(result.action.public_belief.complete and result.action.public_belief.complete_order_comparison
      and result.action.public_belief.all_world_clear,'Reorder retains complete all-world execution proof')
    check(result.public_joker_belief.supported_random_floor,'Reorder advice discloses its random-floor qualification')
    eq(fingerprint(s),original,'Reorder planning cannot mutate the actual public snapshot')
    s.public_joker_belief=assert(B.reorder(s.public_joker_belief,result.action.order,s.public_joker_belief.epoch))
    calls=0
    local played=D.run(s,modules(scorer),nil,{acorn_belief={max_evaluations=2,max_order_evaluations=1}})
    check(played.action and played.action.kind=='play','After a verified public reorder, fresh advice plays the clearing hand')
    eq(played.play.score,240,'Fresh play retains the certified conservative floor')
    check(played.play.immediate_clear_all_worlds,'Fresh current-order play clears in every remaining world')
    eq(calls,1,'An existing all-world clear avoids unnecessary alternate order scoring')
    eq(played.evaluations,1,'Re-advice counts only its actual one-world pass')
  end
  do
    -- Independent manufactured composition: eight ranks and five distinct public
    -- Joker payloads. It is not a copied run, logged snapshot, or seed replay.
    local s=snapshot();s.hand={};s.playing_cards={};s.blind.chips=1000000000000
    for rank=2,9 do
      local c=card(rank,rank==7);s.hand[#s.hand+1]=c;s.playing_cards[#s.playing_cards+1]=B.copy(c)
    end
    for slot=3,5 do s.jokers[slot]=s.jokers[1] end
    s.public_joker_belief=assert(B.start({joker('j_joker','Joker',{mult=4}),
      joker('j_cavendish','Cavendish',{extra={Xmult=3}}),joker('j_scary_face','Scary Face',{extra=30}),
      joker('j_egg','Egg',{}),joker('j_yorick','Yorick',{x_mult=2,yorick_discards=10,extra={discards=23,xmult=1}})},
      'manufactured-full-family-340',{public_before_shuffle=true}))
    local original=fingerprint(s);local calls,worlds=0,{}
    local scorer={score=forbidden,lower_bound=function(state,indices)
      calls=calls+1
      local world=worlds[state]
      if not world then world={before=fingerprint(state),count=0,subsets={}};worlds[state]=world end
      local key=table.concat(indices,',')
      check(not world.subsets[key],'No candidate/world cell is substituted for another full-family cell')
      world.subsets[key]=true;world.count=world.count+1
      return S.lower_bound(state,indices)
    end}
    local result=D.run(s,modules(scorer))
    check(result.action and result.action.kind=='play','The full eight-card Lucky family supplies a public play')
    eq(calls,26160,'All 218 subsets across all 120 consistent identity worlds are scored')
    eq(result.evaluations,26160,'Decision exactly charges the full manufactured family')
    local diag=result.acorn_diagnostics
    eq(diag.subsets,218,'Eight-card one-through-five-card subset family is complete')
    eq(diag.worlds,120,'Every permutation of five distinct public payloads remains possible')
    eq(diag.required_evaluations,26160,'Preflight accounts for the entire current-order comparison')
    eq(diag.max_evaluations,140000,'The ordinary allowance is unchanged')
    eq(diag.max_order_evaluations,30000,'The reorder allowance is unchanged')
    eq(diag.required_order_evaluations,3113040,'The complete alternate-order family exceeds the unchanged allowance')
    check(diag.complete and not diag.order_complete,'Only the complete current-order evidence is published')
    check(not result.play.immediate_clear_all_worlds,'The high manufactured target yields no false clear')
    check(result.public_information_fallback,'The limited immediate-play scope remains explicit')
    local count=0
    for state,world in pairs(worlds) do
      count=count+1
      eq(world.count,218,'Every independently projected world receives the same complete subset family')
      eq(fingerprint(state),world.before,'All reused projected worlds remain pure after their complete comparisons')
    end
    eq(count,120,'All 120 public worlds were projected independently')
    eq(fingerprint(s),original,'The complete eight-card comparison preserves public input, inventory and resources')
  end
  do
    local s=snapshot()
    s.public_joker_belief={schema=1,supported=false,complete=false,reason='Manufactured missing witnessed origin'}
    local result=D.run(s,modules({score=forbidden,lower_bound=forbidden}))
    eq(result.kind,'unsupported','An unavailable public belief remains unavailable')
    eq(result.action,nil,'An unavailable public belief cannot dispatch an action')
    eq(result.evaluations,0,'An unavailable public belief never reaches scoring')
    eq(result.public_joker_belief.reason,'Manufactured missing witnessed origin',
      'Decision preserves the concrete public-observer reason')
    eq(result.strategy.lines[1],'Manufactured missing witnessed origin',
      'User-facing explanation preserves the concrete reason')
  end
end)
math.random,math.randomseed,_G.pseudorandom=old_random,old_randomseed,old_pseudorandom
if not ok then error(err,0) end
print('advisor_acorn_lucky_340: '..checks..' checks passed')
