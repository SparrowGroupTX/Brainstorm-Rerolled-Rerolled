-- Routine synthetic regressions; no source execution or captured-state replay.
local Finish=dofile('Brainstorm/Advisor/blind_finishing.lua')
local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
for _,name in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards'}) do
  Finish[name]=dofile('Brainstorm/Advisor/'..name..'.lua')
end
Finish.strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Outcomes=Finish.sampled_outcomes
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
Shop.blind_finishing=Finish;Shop.strategy=Finish.strategy
Shop.blind_start=dofile('Brainstorm/Advisor/blind_start.lua')
Shop.paired_deck=dofile('Brainstorm/Advisor/paired_deck.lua')
Shop.blind_prep=dofile('Brainstorm/Advisor/blind_prep.lua')
local checks=0
local function check(value,label) checks=checks+1;assert(value,label) end
local function eq(a,b,label) check(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(id,rank,enhancement)
  return {id=id,rank=rank,suit='Spades',enhancement=enhancement or 'c_base',ability={}}
end
local function state()
  local s={phase='hand',ante=2,hand={card('opening',14),card('held',2)},
    deck={card('lucky-a',13,'m_lucky'),card('lucky-b',12,'m_lucky'),card('lucky-c',11,'m_lucky')},
    jokers={},consumeables={},consumable_limit=2,hand_size=2,hand_limit=1,
    hands_left=3,discards_left=1,hands_played=0,discards_used=0,dollars=10,bankrupt_at=0,chips=0,
    hands={},current_round={},modifiers={},probabilities={normal=1},blind={key='bl_small',chips=10000}}
  s.playing_cards={};for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do s.playing_cards[#s.playing_cards+1]=c end end
  return s
end
local function worlds(s,scorer)
  local result={}
  for i=1,4 do
    local w=Snapshot.copy(s);local p=(scorer or Scorer).score(w,{1});p.indices={1}
    result[i]={state=w,opening_play=p}
  end
  return result
end
local function run(w,scorer,limit)
  local calls=0
  local result=Finish.forecast(w,scorer or Scorer,function()
    if calls>=(limit or 50000) then return false end
    calls=calls+1;return true
  end)
  return result,calls
end
local old_random,old_randomseed=math.random,math.randomseed
math.random=function() error('Blind Lucky comparison touched game RNG') end
math.randomseed=function() error('Blind Lucky comparison reseeded game RNG') end

do
  local s=state();local w=worlds(s);local fingerprint=Snapshot.fingerprint(w)
  local baseline={context=Outcomes.context,fill=Outcomes.fill,roll=Outcomes.roll}
  function baseline.after_play(state,indices,scorer,seed,turn)
    local ctx=Outcomes.context(state,indices,seed,turn);ctx.lucky_outcomes=nil
    return scorer.after_play(state,indices,ctx)
  end
  Finish.sampled_outcomes=baseline
  local prior=run(w)
  check(not prior.complete and prior.reason:find('play transition',1,true),'mean-only Lucky transition still rejects the family')
  Finish.sampled_outcomes=Outcomes
  local plain_calls,transition_calls=0,0
  local instrumented=setmetatable({score=function(state,indices,...)
    plain_calls=plain_calls+1
    eq(select('#',...),0,'future selection receives no private outcome')
    return Scorer.score(state,indices)
  end,after_play=function(state,indices,context)
    transition_calls=transition_calls+1
    return Scorer.after_play(state,indices,context)
  end},{__index=Scorer})
  local after,calls=run(w,instrumented)
  check(after.complete and after.supported and #after.policies==2,'future Lucky completes both policies in all common worlds')
  check(plain_calls>0 and transition_calls>0 and calls==plain_calls+transition_calls,'every score and final transition charges the shared allowance')
  local lucky_plays,final_lucky=0,0
  for _,policy in ipairs(after.policies) do
    eq(#policy.worlds,4,'every fixed policy completes every world')
    for _,outcome in ipairs(policy.worlds) do
      local score,hands,discards,cash=0,0,0,s.dollars
      for _,action in ipairs(outcome.actions) do
        eq(action.dollars_before,cash,'cash continuity before every action');cash=action.dollars_after
        if action.kind=='play' then
          hands=hands+1;score=score+action.score
          eq(action.cumulative_score,score,'cumulative score uses actual sampled results')
          if action.sampled_lucky then
            lucky_plays=lucky_plays+1
            eq(action.score_kind,'private_sampled_lucky','private sample label retained')
            eq(action.score_guaranteed,false,'sample is never a guarantee')
            check(action.score==15 or action.score==315,'Lucky uses hit or miss score, never the ordinary 75-chip mean')
          end
        else discards=discards+1 end
      end
      if outcome.actions[#outcome.actions].sampled_lucky then final_lucky=final_lucky+1 end
      eq(outcome.score,score);eq(outcome.hands_used,hands);eq(outcome.discards_used,discards)
      eq(outcome.dollars_after,cash);eq(outcome.dollars_delta,cash-s.dollars)
    end
  end
  check(lucky_plays>0 and final_lucky==8,'each final play resolves Lucky rather than appending a mean score')
  eq(Snapshot.fingerprint(w),fingerprint,'world inputs unchanged')
  local again,repeated_calls=run(w)
  eq(Snapshot.fingerprint(after),Snapshot.fingerprint(again),'private worlds are repeatable')
  eq(calls,repeated_calls,'deterministic operation count')
  local exhausted,bounded=run(w,nil,5)
  check(not exhausted.complete and exhausted.reason:find('allowance',1,true),'incomplete family fails closed')
  eq(bounded,5,'no budget increase or partial certificate')
end

do
  local s=state();s.hand={card('lucky',13,'m_lucky'),card('plain',14)};s.hands_left=1;s.deck={}
  s.playing_cards=Snapshot.copy(s.hand);s.discards_left=0;s.blind.chips=16
  local uncertain=Scorer.score(s,{1});uncertain.indices={1}
  local certain=Scorer.score(s,{2});certain.indices={2}
  check(Finish.choice_supported(s,uncertain),'ordinary no-Joker Lucky opening can be selected')
  check(Finish.better_play(s,certain,uncertain),'supported exact clear remains preferred to a larger Lucky mean')
  check(not Finish.better_play(s,uncertain,certain),'Lucky mean cannot replace an exact clear')
  local r=run(worlds(s))
  check(r.complete,'explicit Lucky opening transition completes')
  for _,policy in ipairs(r.policies) do for _,outcome in ipairs(policy.worlds) do
    eq(outcome.hands_used,1)
    local action=outcome.actions[1]
    eq(action.card_ids[1],'lucky','opening commitment is preserved before private roll')
    check(action.score==15 or action.score==315,'even single final play uses conditional sample')
    eq(outcome.clear,action.score>=16,'clear result does not use Lucky mean')
  end end
end

do
  local s=state();s.hand[1]=card('opening',13,'m_lucky');s.playing_cards[1]=s.hand[1]
  local p=Scorer.score(s,{1})
  check(Finish.choice_supported(s,p),'positive explicit Lucky-only support')
  local silent=Snapshot.copy(p);silent.warnings={}
  check(not Finish.choice_supported(s,silent),'suppressed uncertainty cannot establish the family')
  local unknown=Snapshot.copy(p);unknown.warnings[#unknown.warnings+1]='A different uncertain effect.'
  check(not Finish.choice_supported(s,unknown),'any unrelated warning fails closed')
  local no_scoring=Snapshot.copy(p);no_scoring.scoring_indices={2}
  check(not Finish.choice_supported(s,no_scoring),'Lucky warning requires an active scored Lucky')
  for _,edit in ipairs({
    function(s) s.jokers={{key='j_lucky_cat',debuff=true,ability={}}} end,
    function(s) s.hand[1].id=nil end,
    function(s) s.deck[1].id=s.hand[1].id end,
    function(s) s.hand[1].ability.mult=-1 end,
    function(s) s.hand[1].ability.p_dollars='20' end,
    function(s) s.probabilities.normal='1' end,
    function(s) s.probabilities.normal=0/0 end,
    function(s) s.hand[1].debuff=true end,
  }) do
    local bad=Snapshot.copy(s);edit(bad)
    check(not Finish.choice_supported(bad,p),'malformed or unsupported Lucky scope remains rejected')
  end
  local concealed=Snapshot.copy(s);concealed.hand[2].face_down=true
  check(not Finish.choice_supported(concealed,Scorer.score(concealed,{1})),'concealment warning is not erased')
  local hook=Snapshot.copy(s);hook.blind.key='bl_hook'
  check(not Finish.choice_supported(hook,Scorer.score(hook,{1})),'Hook uncertainty is not added to this family')
  local custom=Snapshot.copy(s);custom.hand[2].enhancement='m_unknown'
  local unsupported=run(worlds(custom))
  check(not unsupported.complete,'unknown effects invalidate all policies')
  local old=Finish.sampled_outcomes
  Finish.sampled_outcomes=setmetatable({after_play=function(state,indices,scorer,seed,turn)
    local after,effect,result=old.after_play(state,indices,scorer,seed,turn)
    if result then result.uncertain=true end
    return after,effect,result
  end},{__index=old})
  unsupported=run(worlds(s))
  check(not unsupported.complete,'actual transition must still resolve all uncertainty')
  Finish.sampled_outcomes=old
end

do
  local s={phase='shop',ante=2,dollars=10,bankrupt_at=0,joker_limit=5,consumable_limit=2,
    jokers={},consumeables={},hands={},modifiers={},probabilities={normal=1},hand_size=2,hand_limit=1,
    round_resets={hands=3,discards=1},current_round={},playing_cards={},
    next_blind={key='bl_small',chips=1000},next_blind_chips=1000,
    shop_jokers={},shop_booster={},shop_vouchers={},reroll_cost=5}
  for i=1,12 do s.playing_cards[i]=card('shop:'..i,13,'m_lucky') end
  local before=Snapshot.fingerprint(s)
  local helper=Finish.choice_supported
  Finish.choice_supported=nil
  local old=Shop.new(s,Scorer):readiness(s)
  check(old.status=='unsupported' and old.reason:find('Random scoring',1,true),'former shop gate rejects Lucky opening family')
  Finish.choice_supported=helper
  local ctx=Shop.new(s,Scorer)
  local r=ctx:readiness(s)
  check(r.supported and r.finishing.complete,'actual shop gate admits known Lucky opening and every continuation')
  eq(r.finishing_basis,'complete_paired_observed_policies')
  check(r.resource_plan and not r.resource_plan.finishing_guarantee,'resource evidence remains explicitly nonguaranteed')
  local observed_hits,observed_misses=false,false
  for _,policy in ipairs(r.finishing.policies) do for _,w in ipairs(policy.worlds) do for _,a in ipairs(w.actions) do
    if a.kind=='play' then
      check(a.sampled_lucky and a.score_guaranteed==false,'shop path retains actual sampled-score labels')
      if a.score==315 then observed_hits=true elseif a.score==15 then observed_misses=true end
    end
  end end end
  check(observed_hits and observed_misses,'fixed sample worlds exercise both Lucky scores')
  local count=ctx.evaluations
  eq(Snapshot.fingerprint(ctx:readiness(s)),Snapshot.fingerprint(r),'Lucky readiness cache remains deterministic')
  eq(ctx.evaluations,count,'exact endpoint repeat adds no scoring')
  local comparison=ctx:compare(s,s)
  check(comparison.complete_finishing and comparison.uncertain,'paired shop evidence completes without relabeling random opening means exact')
  eq(comparison.adjustment,0,'identical endpoint never receives improvement credit')
  eq(Snapshot.fingerprint(s),before,'shop projections preserve inventory and source endpoint')
  local silent=setmetatable({score=function(state,indices)
    local p=Scorer.score(state,indices);p.warnings={};return p
  end},{__index=Scorer})
  eq(Shop.new(s,silent):readiness(s).status,'unsupported','suppressed ordinary warnings cannot bypass shop guard')
  local unrelated=setmetatable({score=function(state,indices)
    local p=Scorer.score(state,indices)
    if indices[1]==2 then p.warnings[#p.warnings+1]='Uncertain future effect.' end
    return p
  end},{__index=Scorer})
  eq(Shop.new(s,unrelated):readiness(s).status,'unsupported','nonselected unsupported candidate prevents complete shop admission')
  local owned=Snapshot.copy(s);owned.jokers={{key='j_joker',id='j',ability={name='Joker',mult=4},sell_cost=1}}
  eq(Shop.new(owned,Scorer):readiness(owned).status,'unsupported','owned Joker Lucky interactions remain outside shop scope')
  local marble=Snapshot.copy(s)
  for _,c in ipairs(marble.playing_cards) do c.enhancement='c_base' end
  marble.jokers={{key='j_marble',id='marble',ability={name='Marble Joker',eternal=true},sell_cost=1}}
  local m=Shop.new(marble,Scorer):readiness(marble)
  check(m.status=='unsupported' and m.reason:find('blind-start',1,true),'independent stochastic startup cannot use Lucky gate')
  local truncated=Shop.new(s,Scorer,nil,{max_evaluations=30})
  check(not truncated:compare(s,s) and truncated.truncated and truncated.evaluations<=30,'shop incomplete comparison stays under unchanged shared allowance')
end

math.random,math.randomseed=old_random,old_randomseed
print('advisor_blind_lucky: '..checks..' checks passed')
