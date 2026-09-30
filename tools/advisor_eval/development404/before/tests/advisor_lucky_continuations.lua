-- Routine synthetic regression, not a source replay or complete-attempt experiment.
local S=dofile('Brainstorm/Advisor/scoring.lua')
local R=dofile('Brainstorm/Advisor/sampled_outcomes.lua')
local Q=dofile('Brainstorm/Advisor/search.lua')
local D=dofile('Brainstorm/Advisor/draws.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Cache=dofile('Brainstorm/Advisor/score_cache.lua')
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local function eq(a,b,label) check(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function c(id,rank,enh)
  return {id=id,rank=rank,suit='Spades',enhancement=enh or 'c_base',ability={}}
end
local function state()
  local s={phase='hand',ante=2,hand={c('lucky',13,'m_lucky'),c('held',2)},deck={},
    jokers={},consumeables={},consumable_limit=2,hands_left=3,hands_played=1,discards_left=2,
    discards_used=0,hand_size=8,hand_limit=5,chips=0,dollars=10,blind={key='bl_small',chips=10000},
    current_round={},probabilities={normal=1},modifiers={}}
  s.playing_cards={s.hand[1],s.hand[2]};return s
end
local function event(mult,dollars) return {mult=mult,dollars=dollars} end
local function context(events,index) return {lucky_outcomes={[index or 1]=events}} end
do
  local s=state();local before=Snapshot.fingerprint(s)
  local mean=S.score(s,{1});local lower=S.lower_bound(s,{1});local upper=S.upper_bound(s,{1})
  eq(mean.score,75,'ordinary Lucky mean');check(mean.uncertain,'ordinary score remains uncertain')
  eq(lower.score,15,'ordinary supported floor');eq(upper.score,315,'ordinary ceiling')
  for _,mult in ipairs({false,true}) do for _,money in ipairs({false,true}) do
    local next_state,effects,actual=S.after_play(s,{1},context({event(mult,money)}))
    check(next_state,'complete Lucky event resolves')
    eq(actual.score,mult and 315 or 15,'independent Mult outcome')
    eq(next_state.dollars,money and 30 or 10,'independent dollar outcome')
    eq(actual.uncertain,false,'only supplied Lucky randomness is resolved')
    eq(actual.sampled_lucky,true);eq(effects.sampled_lucky,true)
    eq(next_state.hands_left,2);eq(next_state.discards_left,2);eq(#next_state.playing_cards,2)
    eq(#next_state.consumeables,0,'no fabricated consumable reward')
    eq(S.score(s,{1}).score,mean.score,'sampled transition does not poison ordinary scoring')
  end end
  eq(Snapshot.fingerprint(s),before,'all sampled outcomes leave input untouched')
  local cached=Cache.new(S)
  local _,_,sampled=R.after_play(s,{1},cached,42,1)
  check(sampled and sampled.sampled_lucky,'classification cache preserves sampled transition context')
  eq(cached.score(s,{1}).score,75);check(cached.score(s,{1}).uncertain)
end
do
  local s=state();s.hand[1].seal='Red'
  local next_state,_,actual=S.after_play(s,{1},context({event(true,false),event(false,true)}))
  eq(actual.score,525,'Red repetition applies chips twice, only one Mult hit')
  eq(next_state.dollars,30,'second repetition has its own cash outcome')
  local missing,why=S.after_play(s,{1},context({event(true,false)}))
  eq(missing,nil,'partial repetition family fails closed');check(type(why)=='string')
  for _,bad in ipairs({{},{{mult=1,dollars=false}},{{mult=false}},{{mult=false,dollars='false'}}}) do
    eq(S.after_play(state(),{1},context(bad)),nil,'malformed Lucky event is unsupported')
  end
  s=state();s.hand[1].debuff=true
  local _,_,debuffed=S.after_play(s,{1},context({}))
  check(debuffed and not debuffed.uncertain,'debuffed Lucky does not consume an event')
  s=state();s.hand[1].ability.p_dollars=-1
  eq(S.after_play(s,{1},context({event(false,true)})),nil,'negative custom Lucky cash fails closed')
end
do
  local s=state();s.modifiers={chips_dollar_cap=true,minus_hand_size_per_X_dollar=10}
  local next_state,_,actual=S.after_play(s,{1},context({event(true,true)}))
  eq(actual.score,210,'chip cap uses existing cash before Lucky earnings')
  eq(next_state.dollars,30);eq(next_state.hand_size,6,'exact cash changes later hand size')
  s=state();s.blind={key='bl_flint',chips=1600}
  _,_,actual=S.after_play(s,{1},context({event(true,false)}))
  eq(actual.score,273,'Flint halves base before Lucky Mult is added')
  s=state();s.hand={c('left',2),c('middle',3),s.hand[1]};s.playing_cards=s.hand
  s.blind={key='bl_hook',chips=10000}
  local ctx=context({event(true,true)},3);ctx.hook_indices={1,2}
  next_state,_,actual=S.after_play(s,{3},ctx)
  eq(actual.score,315,'Hook remaps Lucky events by the physical selected card')
  eq(actual.scoring_indices[1],3);eq(next_state.dollars,30)
  eq(#next_state.hand,0);eq(#next_state.playing_cards,3,'Hook discards do not destroy population')
  s=state();s.hand[2]=c('glass',13,'m_glass');s.playing_cards=s.hand
  ctx=context({event(true,true)});ctx.glass_outcomes={[2]=true}
  local effects;next_state,effects,actual=S.after_play(s,{1,2},ctx)
  check(actual.sampled_lucky and effects.sampled_glass,'Lucky coexists with explicit Glass destruction')
  eq(#next_state.playing_cards,1);eq(effects.population_delta,-1);eq(next_state.dollars,30)
end
do
  local s=state();s.hand[1].seal='Red'
  local before=Snapshot.fingerprint(s)
  local seen={}
  for seed=1,128 do
    local ctx=R.context(s,{1},seed,2)
    local swapped=Snapshot.copy(s);swapped.hand={s.hand[2],s.hand[1]}
    local other=R.context(swapped,{2},seed,2)
    eq(Snapshot.fingerprint(ctx.lucky_outcomes[1]),Snapshot.fingerprint(other.lucky_outcomes[2]),
      'physical identity shares outcomes across index changes')
    local a,b=ctx.lucky_outcomes[1][1],ctx.lucky_outcomes[1][2]
    seen[tostring(a.mult)..':'..tostring(a.dollars)]=true
    if a.mult~=b.mult or a.dollars~=b.dollars then seen.retrigger=true end
    local _,_,first=R.after_play(s,{1},S,seed,2)
    local _,_,again=R.after_play(s,{1},S,seed,2)
    eq(first.score,again.score);eq(first.expected_dollars,again.expected_dollars)
  end
  check(seen['true:false'] and seen['false:true'] and seen['false:false'],'separate score and cash channels vary')
  check(seen.retrigger,'retrigger events use different keyed draws')
  eq(Snapshot.fingerprint(s),before,'sampling does not mutate input')
  for _,prob in ipairs({0,15}) do
    s.probabilities.normal=prob
    local ctx=R.context(s,{1},1,1)
    for _,e in ipairs(ctx.lucky_outcomes[1]) do eq(e.mult,prob==15);eq(e.dollars,prob==15) end
  end
  s=state();s.hand[1].id=nil
  eq(R.after_play(s,{1},S,42,1),nil,'missing Lucky identity cannot supply a common world')
  s=state();s.hand[2].id=s.hand[1].id
  eq(R.after_play(s,{1},S,42,1),nil,'duplicate held identity cannot share independent events')
  s=state();s.jokers={{key='j_lucky_cat',debuff=true,ability={name='Lucky Cat',x_mult=2}}}
  local _,_,actual=R.after_play(s,{1},S,42,1)
  check(actual and actual.uncertain and not actual.sampled_lucky,'even debuffed Joker ownership stays outside slice')
  eq(S.after_play(s,{1},context({event(true,true)})),nil,'manual supplied family cannot bypass Joker guard')
  s=state();s.hand[2].face_down=true
  _,_,actual=R.after_play(s,{1},S,42,1)
  check(actual and actual.uncertain,'sampling must not erase unrelated concealment uncertainty')
end
do
  -- The same full search comparison with the former mean-only transition
  -- rejects all branches. A complete sampled family can finish without raising
  -- score budgets or using the effect outcomes to choose future play indices.
  local s=state();s.hand_size=2;s.blind.chips=10000
  s.hand={c('h1',14),c('h2',2)}
  s.deck={c('d1',2,'m_lucky'),c('d2',2,'m_lucky'),c('d3',3,'m_lucky'),c('d4',3,'m_lucky')}
  s.playing_cards={};for _,area in ipairs({s.hand,s.deck}) do for _,card in ipairs(area) do s.playing_cards[#s.playing_cards+1]=card end end
  local old={context=R.context,fill=R.fill,roll=R.roll}
  function old.after_play(state,indices,scorer,seed,turn)
    local ctx=R.context(state,indices,seed,turn);ctx.lucky_outcomes=nil
    return scorer.after_play(state,indices,ctx)
  end
  local baseline=Q.run(s,S,{draws=D,sampled_outcomes=old,samples=4,resource_samples=4})
  check(not baseline.resource_comparison and baseline.search_diagnostics.continuation_skipped,
    'mean-only random continuation cannot establish a full comparison')
  local plain_calls,sampled_calls=0,0
  local scorer=setmetatable({score=function(state,indices,...)
    plain_calls=plain_calls+1
    eq(select('#',...),0,'future play selection receives no private outcome')
    return S.score(state,indices)
  end,after_play=function(state,indices,ctx)
    sampled_calls=sampled_calls+1;return S.after_play(state,indices,ctx)
  end},{__index=S})
  local before=Snapshot.fingerprint(s)
  local result=Q.run(s,scorer,{draws=D,sampled_outcomes=R,samples=4,resource_samples=4})
  check(result.resource_comparison,'all remaining-hand branches finish with supported Lucky outcomes')
  eq(result.resource_comparison.samples,4);check(result.resource_comparison.full_remaining_horizon)
  eq(result.resource_comparison.future_discards,false,'future discard gap remains explicit')
  check(result.evaluations<=140000 and plain_calls>0 and sampled_calls>0,'existing ordinary bound')
  local again=Q.run(s,S,{draws=D,sampled_outcomes=R,samples=4,resource_samples=4})
  eq(Snapshot.fingerprint(result.resource_comparison),Snapshot.fingerprint(again.resource_comparison),'complete comparison is deterministic')
  eq(Snapshot.fingerprint(s),before,'search remains detached')
  -- One unsupported competing branch invalidates the entire comparison.
  scorer=setmetatable({after_play=function(state,indices,ctx)
    if state.hands_left==1 then return nil,'fixture unsupported later event' end
    return S.after_play(state,indices,ctx)
  end},{__index=S})
  local incomplete=Q.run(s,scorer,{draws=D,sampled_outcomes=R,samples=4,resource_samples=4})
  check(not incomplete.resource_comparison,'partial random family never promotes an endpoint')
  print('Lucky complete synthetic comparison score calls: '..result.evaluations)
end
print('Lucky continuations: '..checks..' checks passed')
