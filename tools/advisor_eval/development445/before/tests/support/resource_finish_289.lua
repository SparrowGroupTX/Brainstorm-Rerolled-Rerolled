-- Bounded full-blind resource policies. A policy is fixed across every common
-- world; only its actions after a draw may depend on that public observation.
local M={}
local min,max,floor=math.min,math.max,math.floor
local categories={'High Card','Pair','Two Pair','Three of a Kind','Straight','Flush','Full House',
  'Four of a Kind','Straight Flush','Five of a Kind','Flush House','Flush Five'}
local function num(v,d) return type(v)=='number' and v or (d or 0) end
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function list(t) local out={};for i,v in ipairs(t or {}) do out[i]=v end;return out end
local function copy(t,seen)
  if type(t)~='table' then return t end
  seen=seen or {};if seen[t] then return seen[t] end
  local out={};seen[t]=out;for k,v in pairs(t) do out[k]=copy(v,seen) end;return out
end
-- Exact, per-comparison observation identity. Include every field (including
-- cash, inventory, blind history and deck order); length-prefix strings and
-- round-trip numbers so different public states cannot alias a cached choice.
-- Unsupported/cyclic values simply disable reuse, never establish support.
local function observation_key(value,active)
  local kind=type(value)
  if kind=='nil' then return 'z' end
  if kind=='boolean' then return value and 'b1' or 'b0' end
  if kind=='number' then
    if not finite(value) then return nil end
    return 'n'..string.format('%.17g',value)..';'
  end
  if kind=='string' then return 's'..#value..':'..value end
  if kind~='table' then return nil end
  active=active or {};if active[value] then return nil end;active[value]=true
  local items={}
  for key,item in pairs(value) do
    local k,v=observation_key(key,active),observation_key(item,active)
    if not k or not v then active[value]=nil;return nil end
    items[#items+1]=k..v
  end
  table.sort(items);active[value]=nil
  return 't'..#items..':'..table.concat(items)..'e'
end
local function enhancement(c)
  local a=c.ability or {}
  return c.enhancement or (c.key and c.key:sub(1,2)=='m_' and c.key) or
    (a.effect=='Lucky Card' and 'm_lucky') or (a.effect=='Glass Card' and 'm_glass') or 'c_base'
end
local function visible(s)
  if #(s.hand or {})<1 or #s.hand>10 or num(s.hand_size,#s.hand)>10 or #(s.deck or {})>120 then return false end
  for _,c in ipairs(s.hand) do if c.face_down or c.unknown or c.concealed then return false end end
  return true
end
local function resources_valid(s)
  for _,value in ipairs({num(s.hands_left,(s.current_round or {}).hands_left),num(s.discards_left,(s.current_round or {}).discards_left)}) do
    if not finite(value) or value<0 or value%1~=0 then return false end
  end
  for _,field in ipairs({'hands_left','discards_left','hands_played','discards_used','hand_size','hand_limit'}) do
    if s[field]~=nil and (not finite(s[field]) or s[field]<0 or s[field]%1~=0) then return false end
  end
  if not finite(s.dollars) or not finite(s.chips) or s.chips<0 or not finite((s.blind or {}).chips) or s.blind.chips<=0 then return false end
  if s.bankrupt_at~=nil and not finite(s.bankrupt_at) then return false end
  local cost=(s.modifiers or {}).discard_cost
  return cost==nil or finite(cost) and cost>=0
end
local function affordable_discard(s)
  return s.dollars-num((s.modifiers or {}).discard_cost)>=min(0,num(s.bankrupt_at))
end
function M.admits(s,modules)
  local hands=num(s.hands_left,(s.current_round or {}).hands_left)
  if hands<2 or hands>5 or hands%1~=0 or num(s.discards_left)<=0 or #(s.deck or {})==0 or not visible(s) or
    next(s.jokers or {}) or (s.used_vouchers or {}).v_observatory or (s.vouchers or {}).v_observatory then return false end
  local uses=modules and modules.consumables and modules.consumables.resource_policy
  if uses and uses.admits and uses.admits(s) then return true end
  if hands>=4 or hands==3 and max(#s.hand,num(s.hand_size))>6 or hands==2 and max(#s.hand,num(s.hand_size))>8 then return true end
  for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do if enhancement(c)=='m_lucky' then return true end end end
  return false
end
local function reliable(p,target)
  return p and p.legal~=false and not p.uncertain and finite(p.score) and p.score>=target
end
local function legal_category(s,indices,category,contains)
  local used={};for _,i in ipairs(indices) do used[i]=true end
  for i,c in ipairs(s.hand) do if (c.ability or {}).forced_selection and not used[i] then return false end end
  local b=s.blind or {};if b.disabled then return true end
  local bd=b.debuff or {};local n=#indices
  if (b.key=='bl_psychic' or b.name=='The Psychic') and n~=5 or bd.h_size_ge and n<bd.h_size_ge or
    bd.h_size_le and n>bd.h_size_le or bd.hand and contains[bd.hand] then return false end
  if (b.key=='bl_eye' or b.name=='The Eye') and (b.hands or {})[category] then return false end
  if (b.key=='bl_mouth' or b.name=='The Mouth') and b.only_hand and b.only_hand~=category then return false end
  return true
end
-- Cover every observed legal category with two structural representatives.
-- This shortlist never uses sampled score outcomes or the remaining deck order.
-- Its proxies are not exact scoring and do not establish the best variant.
function M.structural_candidates(s,scorer,charge)
  local groups={};local selected={};local limit=min(5,num(s.hand_limit,5),#s.hand)
  local function consider()
    if charge and not charge() then return false end
    local category,scoring,contains=scorer.classify(s,selected)
    if not legal_category(s,selected,category,contains or {}) then return true end
    local used,scored={},{ };for _,i in ipairs(selected) do used[i]=true end;for _,i in ipairs(scoring or {}) do scored[i]=true end
    local chips,multiplier,retained,exposure,additive=0,1,0,0,0
    for i,c in ipairs(s.hand) do
      local a=c.ability or {};local e=enhancement(c)
      if scored[i] and not c.debuff then
        local repetitions=c.seal=='Red' and 2 or 1
        chips=chips+repetitions*(num(c.nominal,min(num(c.rank),10))+num(a.perma_bonus)+num(a.bonus,e=='m_bonus' and 30 or e=='m_stone' and 50 or 0))
        -- A structural hint, not a second scorer: represent ordinary additive
        -- enhancements/repetition when otherwise identical rank variants tie.
        additive=additive+repetitions*(e=='m_mult' and max(0,num(a.mult,4)) or e=='m_lucky' and max(0,num(a.mult,20))*.2 or 0)
        if e=='m_glass' then multiplier=multiplier*2;exposure=exposure+1 end
        if type(c.edition)=='table' and c.edition.polychrome then multiplier=multiplier*1.5 end
      end
      if not used[i] then
        if not c.debuff and e=='m_steel' then multiplier=multiplier*1.5;retained=retained+4 end
        if c.seal=='Blue' then retained=retained+3 end
        if e=='m_gold' then retained=retained+2 end
      end
    end
    local candidate={indices=list(selected),category=category,key=table.concat(selected,','),
      power=(chips+num(((s.hands or {})[category] or {}).chips,5))*multiplier*
        (num(((s.hands or {})[category] or {}).mult,1)+additive),
      conservation=retained-10*exposure,exposure=exposure}
    local group=groups[category] or {};groups[category]=group
    local function prefer(a,b,field,other)
      return not b or a[field]>b[field] or a[field]==b[field] and (a[other]>b[other] or a[other]==b[other] and a.key<b.key)
    end
    if prefer(candidate,group.power,'power','conservation') then group.power=candidate end
    if prefer(candidate,group.conservation,'conservation','power') then group.conservation=candidate end
    return true
  end
  local function walk(start)
    if #selected>0 and not consider() then return false end
    if #selected>=limit then return true end
    for i=start,#s.hand do selected[#selected+1]=i;local ok=walk(i+1);selected[#selected]=nil;if not ok then return false end end
    return true
  end
  if not walk(1) then return nil end
  local out,seen={},{}
  for _,category in ipairs(categories) do
    local group=groups[category]
    if group then for _,field in ipairs({'power','conservation'}) do
      local candidate=group[field]
      if candidate and not seen[candidate.key] then out[#out+1]=candidate;seen[candidate.key]=true end
    end end
  end
  return out
end
local function ordered(deck,seed)
  local out=list(deck);table.sort(out,function(a,b) return tostring(a.id)<tostring(b.id) end)
  for i=#out,2,-1 do seed=(seed*1664525+1013904223)%4294967296;local j=seed%i+1;out[i],out[j]=out[j],out[i] end
  return out
end
function M.suggest(s,modules,result,yield_fn,options)
  modules=modules or {};result=result or {};options=options or {}
  local hands=num(s.hands_left,(s.current_round or {}).hands_left)
  local diag={evaluations=0,max_evaluations=min(12000,max(0,floor(num(options.max_evaluations,12000)))),
    classifications=0,max_classifications=min(150000,max(0,floor(num(options.max_classifications,150000)))),
    samples=4,first_action_limit=3,policy_limit=5,play_candidate_limit=24,horizon=hands,complete=false,heuristic=true,
    future_discards=num(s.discards_left),full_remaining_horizon=true,consumable_use=false,
    observation_cache_hits=0,observation_cache_entries=0,observation_cache_limit=128,
    policy_exhausted_worlds=0,source_counterfactual=false,terminal_evidence=false,
    scope='Three fixed first actions and five fixed continuation policies across four common worlds; remaining hands until clear, hand exhaustion, or explicitly labeled policy exhaustion with no admitted legal action. Original never/one-early/one-final discard policies plus repeated observed early/final discards until a reliable clear or no eligible affordable discard remains. Two structural representatives per hand category; no owned-consumable use or globally exhaustive discard-schedule guarantee.'}
  local function no(reason) diag.reason=reason;return nil,diag.evaluations,diag end
  if not M.admits(s,modules) then return no('This extension covers bounded visible no-Joker resource scopes only.') end
  if not resources_valid(s) then return no('Finite cash, credit, scoring and integer hand/discard resources are required.') end
  local target=num((s.blind or {}).chips)-num(s.chips)
  if not finite(target) or target<=0 then return no('A finite positive remaining blind target is required.') end
  if reliable(result.play,target) or result.fast_clear then return no('A reliable current finish takes priority.') end
  for _,field in ipairs({'ordering','hand_ordering','boss_rescue','mixed_rescue','growth'}) do
    if result[field] then return no('An existing tactical or investment action takes priority.') end
  end
  local uses=modules.consumables and modules.consumables.resource_policy
  local use_context,use_reason
  if uses and uses.admits and uses.admits(s) then
    use_context,use_reason=uses.prepare(s,modules,result)
    if not use_context then return no(use_reason or 'The admitted owned-use family could not be prepared.') end
  end
  if result.consumable then
    if not use_context or not use_context.first then return no(use_reason or 'An existing tactical or investment action takes priority.') end
    if reliable(result.consumable.play,target) then return no('A reliable current consumable finish takes priority.') end
  end
  if use_context then
    diag.consumable_use=true;diag.maximum_uses=use_context.maximum_uses;diag.first_action_limit=4;diag.use_policy_limit=2
    diag.population_loss_scope='Scored-play population exposure; intentional consumable removal is counted separately in each use and population_removed.'
    diag.scope='At most four fixed first actions, five fixed discard schedules and hold/observed-use rules across four common worlds. Exact current owned use is compared when present; later targets use only the visible hand and canonical public composition. At most two ordinary owned uses; actual inventory, population, cash, plays and discards are carried until clear, hand exhaustion or explicit policy exhaustion. Fixed target/development heuristics, not an exhaustive game policy or win-rate estimate.'
  end
  if not result.play or not result.play.indices or not result.discard or not result.discard.indices then return no('Both incumbent play and discard actions are required.') end
  local scorer,search,outcomes,draws,multi=modules.scoring,modules.search,modules.sampled_outcomes,modules.draws,modules.multi_discard
  local support=modules.blind_finishing and modules.blind_finishing.choice_supported
  if not scorer or not scorer.classify or not scorer.score or not scorer.after_play or not scorer.after_discard or
    not search or not search.population_profile or not search.population_cost or not search.resource_override_supported or not outcomes or not outcomes.fill or not outcomes.roll or
    not outcomes.after_play or not draws or not multi or not multi.discard_candidates or not support then
    return no('Public-choice support, exact transitions, category, draw and resource dependencies are required.')
  end
  local seen,population={},{}
  for _,c in ipairs(s.playing_cards or {}) do
    if c.id==nil or population[tostring(c.id)] then return no('Unique full playing-card population identities are required.') end
    population[tostring(c.id)]=true
  end
  local known_enhancements={c_base=true,m_stone=true,m_wild=true,m_bonus=true,m_mult=true,m_glass=true,m_steel=true,m_gold=true,m_lucky=true}
  for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do
    local id=c.id
    if not (type(id)=='string' and id~='' or finite(id)) or seen[tostring(id)] or not population[tostring(id)] then
      return no('Every held and drawable card requires a distinct identity in the full population.')
    end
    if c.unknown or c.concealed or not finite(c.rank) or c.rank<2 or c.rank>14 or c.rank%1~=0 or
      not ({Spades=true,Hearts=true,Clubs=true,Diamonds=true})[c.suit] then return no('Known ordinary public rank and suit composition is required.') end
    if not known_enhancements[enhancement(c)] then return no('Unknown public card enhancements cannot establish a resource policy comparison.') end
    seen[tostring(id)]=true
  end end
  local aborted
  local function charge()
    if diag.evaluations>=diag.max_evaluations then aborted='The 12,000-score specialist allowance cannot complete every admitted policy and world.';return false end
    diag.evaluations=diag.evaluations+1;if yield_fn and diag.evaluations%64==0 then yield_fn() end;return true
  end
  local function classify_charge()
    if diag.classifications>=diag.max_classifications then aborted='The 150,000-classification allowance cannot complete every admitted observation.';return false end
    diag.classifications=diag.classifications+1;if yield_fn and diag.classifications%64==0 then yield_fn() end;return true
  end
  local root=copy(s);root.suppress_warnings=false
  local firsts={{kind='play',indices=list(result.play.indices),key='play:'..table.concat(result.play.indices,',')},
    {kind='discard',indices=list(result.discard.indices),key='discard:'..table.concat(result.discard.indices,',')}}
  if not charge() then return no(aborted) end
  local initial=scorer.score(root,firsts[1].indices)
  if not support(root,initial) then return no('The incumbent first play has unsupported scoring uncertainty.') end
  local same_key='play:'..table.concat(result.discard.indices,',')
  if same_key~=firsts[1].key then
    if not charge() then return no(aborted) end
    local same=scorer.score(root,result.discard.indices)
    if same and same.legal~=false then
      if not support(root,same) then return no('The same-cards play has unsupported scoring uncertainty.') end
      firsts[#firsts+1]={kind='play',indices=list(result.discard.indices),key=same_key,same_cards=true}
    else diag.same_cards_declined=same and same.reason or 'The identical selection is not a legal play.' end
  end
  local observations={}
  local function best_play(state)
    if not visible(state) then aborted='A future observation is concealed or exceeds ten cards.';return nil end
    state.suppress_warnings=false
    local key=observation_key(state)
    local saved=key and observations[key]
    if saved then diag.observation_cache_hits=diag.observation_cache_hits+1;return copy(saved.play),saved.no_legal_play end
    local function remember(play,no_legal_play)
      if key and diag.observation_cache_entries<diag.observation_cache_limit then
        observations[key]={play=copy(play),no_legal_play=no_legal_play}
        diag.observation_cache_entries=diag.observation_cache_entries+1
      end
      return play,no_legal_play
    end
    local candidates=M.structural_candidates(state,scorer,classify_charge);if not candidates then return nil end
    if #candidates==0 then return remember(nil,true) end
    local population_profile=search.population_profile(state);local remaining=max(1,num(state.blind.chips)-num(state.chips))
    local best,rewards
    for _,candidate in ipairs(candidates) do
      if not charge() then return nil end
      local p=scorer.score(state,candidate.indices)
      if p and p.legal~=false then
        if not support(state,p) then aborted='A considered future play has unsupported uncertainty or scoring effects.';return nil end
        p.indices=list(candidate.indices);p.population_cost=search.population_cost(state,p,population_profile)
        p.arm_cost=search.arm_cost and search.arm_cost(state,p.hand) or 0;p.finish_reward=0
        local clear,old_clear=reliable(p,remaining),reliable(best,remaining)
        if clear and modules.finish_rewards then
          rewards=rewards or modules.finish_rewards.prepare(state,modules.strategy)
          p.finish_reward=modules.finish_rewards.value(state,p,rewards)
        end
        if not best or clear and not old_clear or clear and old_clear and
          (p.population_cost<best.population_cost or p.population_cost==best.population_cost and
            (p.arm_cost<best.arm_cost or p.arm_cost==best.arm_cost and p.finish_reward>best.finish_reward)) or
          not clear and not old_clear and (p.score>best.score or p.score==best.score and p.population_cost<best.population_cost) then best=p end
      end
    end
    if not best then aborted='No supported legal play exists in the complete declared structural family.' end
    if best then return remember(best) end
  end
  if use_context then
    local first=use_context.first
    if first then
      local checked,why=use_context.project(root,first.index,first.targets)
      if not checked then return no('The exact incumbent use is unsupported: '..tostring(why)) end
    else
      local proposed,why=use_context.propose(root,best_play)
      if proposed==nil then return no(aborted or why) end
      if proposed then first={kind='use',index=proposed.index,targets=list(proposed.targets),
        action={kind='use',area='consumeables',index=proposed.index,targets=list(proposed.targets)},
        key='use:'..proposed.index..':'..table.concat(proposed.targets,',')} end
    end
    if first then firsts[#firsts+1]=first end
  end
  diag.first_actions=#firsts
  local function run(first,policy,use_policy,seed)
    local state=copy(root);state.deck=ordered(state.deck,seed)
    local draw_turn,plays,discards,exposure,arm,reward,later,used,removed=0,0,0,0,0,0,false,0,0
    local actions={};local selected=first.kind=='play' and first.indices or nil;local policy_exhausted
    local function fill()
      draw_turn=draw_turn+1
      local bell=floor(outcomes.roll(seed,draw_turn,'resource-bell',0)*1000000)
      local next_state,why=outcomes.fill(state,state.deck,scorer,draws,seed,draw_turn,bell)
      if not next_state or not visible(next_state) or not resources_valid(next_state) then aborted='An observed replacement draw is unsupported: '..tostring(why or 'concealed, oversized or invalid resource state');return false end
      state=next_state;state.suppress_warnings=false;return true
    end
    local function discard(indices)
      if not affordable_discard(state) then aborted='The incumbent discard cannot preserve the declared borrowing limit.';return false end
      local after,why=scorer.after_discard(state,indices)
      if not after or not resources_valid(after) then aborted='An admitted discard transition is unsupported: '..tostring(why or 'invalid resource state');return false end
      if num(after.discards_left)~=num(state.discards_left)-1 then aborted='A discard did not consume exactly one remaining discard.';return false end
      actions[#actions+1]={kind='discard',indices=list(indices),hands_left=state.hands_left,
        dollars_before=state.dollars,dollars_after=after.dollars}
      state=after;discards=discards+1;return fill()
    end
    local function use(index,targets)
      if not use_context or used>=use_context.maximum_uses then aborted='A policy exceeded its original owned-use limit.';return false end
      local after,details=use_context.project(state,index,targets)
      if not after or not visible(after) or not resources_valid(after) then
        aborted='An admitted owned-use transition is unsupported: '..tostring(details);return false
      end
      if after.hands_left~=state.hands_left or after.discards_left~=state.discards_left or after.chips~=state.chips then
        aborted='An ordinary owned use unexpectedly changed hand, discard or chip resources.';return false
      end
      used=used+1;removed=removed+max(0,#(state.playing_cards or {})-#(after.playing_cards or {}))
      details.use_number=used;actions[#actions+1]=details;state=after;return true
    end
    local function observed_uses()
      if use_policy~='observed' or selected or #actions==0 then return true end
      while used<use_context.maximum_uses and #(state.consumeables or {})>0 do
        local proposed,why=use_context.propose(state,best_play)
        if proposed==nil then aborted=aborted or why;return false end
        if not proposed then break end
        if not use(proposed.index,proposed.targets) then return false end
      end
      return true
    end
    if first.kind=='discard' and not discard(first.indices) then return nil end
    if first.kind=='use' and not use(first.index,first.targets) then return nil end
    while num(state.hands_left)>0 and #state.hand>0 and num(state.chips)<num(state.blind.chips) do
      local play,no_legal_play
      if not observed_uses() then return nil end
      if not selected then play,no_legal_play=best_play(state);if not play and not no_legal_play then return nil end end
      -- The initial action is fixed. This rule sees only a later public hand;
      -- its discard indices are fixed before the replacement cards are drawn.
      local repeated=policy=='repeat_early' or policy=='repeat_final'
      local function eligible()
        local observed=repeated and selected==nil and #actions>0 or not repeated and plays>0
        return observed and (repeated or not later) and num(state.discards_left)>0 and #state.deck>0 and affordable_discard(state) and
          (policy=='early' or policy=='repeat_early' or (policy=='final' or policy=='repeat_final') and num(state.hands_left)==1)
      end
      while eligible() and not reliable(play,max(1,num(state.blind.chips)-num(state.chips))) do
        local candidate=multi.discard_candidates(state,nil,1)[1]
        if candidate then
          later=true;if not discard(candidate.indices) then return nil end
          if not observed_uses() then return nil end
          play,no_legal_play=best_play(state);if not play and not no_legal_play then return nil end
        else break end
      end
      if not selected and not play then
        -- Exhaustive classification found no legal category. This declared
        -- policy has no further action; do not invent a scored repeat or call
        -- it an observed game-over. Unknown/truncated scoring still aborts.
        policy_exhausted='no_legal_play';break
      end
      local indices=selected or play.indices;selected=nil
      if not charge() then return nil end
      local after,why,actual=outcomes.after_play(state,indices,scorer,seed,plays+1)
      if not after or not resources_valid(after) or not actual or actual.uncertain or actual.legal==false or not finite(actual.score) or actual.score<0 then
        aborted='An actual sampled play transition is unsupported: '..tostring(why);return nil
      end
      if num(after.hands_left)~=num(state.hands_left)-1 then aborted='A play did not consume exactly one remaining hand.';return nil end
      actual.indices=list(indices);plays=plays+1
      exposure=exposure+search.population_cost(state,actual,search.population_profile(state))
      arm=arm+(search.arm_cost and search.arm_cost(state,actual.hand) or 0)
      local ids={};for _,i in ipairs(indices) do ids[#ids+1]=state.hand[i].id end
      actions[#actions+1]={kind='play',indices=list(indices),card_ids=ids,hand=actual.hand,score=actual.score,
        cumulative_score=after.chips,dollars_before=state.dollars,dollars_after=after.dollars,
        population_after=#(after.playing_cards or {}),sampled_lucky=actual.sampled_lucky or false,
        score_kind=actual.score_kind,score_guaranteed=actual.score_guaranteed}
      if num(after.chips)>=num(after.blind.chips) and modules.finish_rewards then
        local details;reward,details=modules.finish_rewards.value(state,actual,modules.finish_rewards.prepare(state,modules.strategy))
        actions[#actions].finish_rewards=details
      end
      state=after
      if num(state.chips)<num(state.blind.chips) and num(state.hands_left)>0 and #state.hand+#state.deck>0 then
        if not fill() then return nil end
      end
    end
    local gain=max(0,num(state.chips)-num(root.chips))
    return {win=num(state.chips)>=num(state.blind.chips) and 1 or 0,utility=min(1,gain/target),score=gain,
      hands=plays,discards=discards,uses=used,actions=actions,dollars_after=num(state.dollars),
      dollars_delta=num(state.dollars)-num(root.dollars),population_loss=exposure,
      intentional_population_removed=removed,
      population_removed=#(root.playing_cards or {})-#(state.playing_cards or {}),arm_cost=arm,finish_reward=reward,
      hands_left=num(state.hands_left),discards_left=num(state.discards_left),policy_exhausted=policy_exhausted,
      inventory_before_finish_rewards=copy(state.consumeables),consumable_limit_after=state.consumable_limit}
  end
  local plans={}
  for _,first in ipairs(firsts) do for _,policy in ipairs({'never','early','final','repeat_early','repeat_final'}) do
    for _,use_policy in ipairs(use_context and {'hold','observed'} or {'hold'}) do
    plans[#plans+1]={kind=first.kind,indices=list(first.indices),key=first.key,policy=policy,same_cards=first.same_cards,
      action=copy(first.action),use_policy=use_policy,first=first,worlds={},probability=0,utility=0,hands=0,discards=0,uses=0,dollars_delta=0,population_loss=0,intentional_population_removed=0,arm_cost=0,finish_reward=0,
      policy_exhausted_worlds=0}
  end end end
  for outer,seed in ipairs({2718281,3141593,1618033,1414213}) do
    local observations={}
    for i,plan in ipairs(plans) do observations[i]=run(plan.first,plan.policy,plan.use_policy,seed);if not observations[i] then return no(aborted) end end
    for i,plan in ipairs(plans) do
      local v=observations[i];plan.worlds[outer]=v;plan.probability=plan.probability+v.win/4
      if v.policy_exhausted then
        plan.policy_exhausted_worlds=plan.policy_exhausted_worlds+1;diag.policy_exhausted_worlds=diag.policy_exhausted_worlds+1
      end
      for _,field in ipairs({'utility','hands','discards','uses','dollars_delta','population_loss','intentional_population_removed','arm_cost','finish_reward'}) do plan[field]=plan[field]+num(v[field])/4 end
    end
    diag.completed_outer=outer
  end
  local function better(a,b)
    if not b then return true end
    for _,field in ipairs({'probability','utility'}) do if a[field]~=b[field] then return a[field]>b[field] end end
    for _,field in ipairs({'population_loss','arm_cost'}) do if a[field]~=b[field] then return a[field]<b[field] end end
    if a.finish_reward~=b.finish_reward then return a.finish_reward>b.finish_reward end
    if a.hands+a.discards+a.uses~=b.hands+b.discards+b.uses then return a.hands+a.discards+a.uses<b.hands+b.discards+b.uses end
    return a.dollars_delta>b.dollars_delta
  end
  local incumbent_key=use_context and use_context.first and use_context.first.key or
    (result.kind=='discard' and firsts[2].key or firsts[1].key)
  local baseline,best
  for _,plan in ipairs(plans) do
    if plan.key==incumbent_key and better(plan,baseline) then baseline=plan end
    if better(plan,best) then best=plan end
    plan.first=nil
  end
  diag.complete=true;diag.candidates=plans;diag.baseline=baseline;diag.best=best
  diag.baseline_probability=baseline.probability;diag.estimated_probability=best.probability
  diag.uplift=best.probability-baseline.probability
  if best.key==incumbent_key then return no('The incumbent first action remains best across the complete declared resource policies.') end
  -- These five fixed schedules still do not exhaust arbitrary discard timing
  -- or choices. Preserve the existing274 crossed-world guard for that scope.
  local allowed,why=search.resource_override_supported(root,baseline,best)
  if allowed and (result.consumable or best.kind=='use') then
    for i=1,4 do
      local before,after=baseline.worlds[i],best.worlds[i]
      if after.win<before.win or after.utility<before.utility then
        allowed=false;why='Crossed common worlds cannot establish this owned-use first-action override.';break
      end
    end
  end
  if not allowed then
    diag.aggregate_best=best;diag.override_rejected=why;diag.best=baseline
    diag.estimated_probability=baseline.probability;diag.uplift=0
    return no(why)
  end
  local extra_actions=max(0,best.hands+best.discards+best.uses-baseline.hands-baseline.discards-baseline.uses)
  local extra_paid=max(0,best.discards-baseline.discards)*max(0,num((root.modifiers or {}).discard_cost))
  diag.required_uplift=max(.125,num(options.minimum_uplift,.125))+min(.25,.025*(extra_actions+extra_paid))
  if diag.uplift<diag.required_uplift then return no('The paired clearing gain does not cover the extra action and discard costs.') end
  local action=best.action or {kind=best.kind,area='hand',indices=list(best.indices)}
  return {action=copy(action),indices=best.kind~='use' and list(best.indices) or nil,horizon=hands,
    replaces_consumable=result.consumable and true or nil,use_policy=best.use_policy,
    probability=best.probability,baseline_probability=baseline.probability,policy=best.policy,heuristic=true,scope=diag.scope,
    reason=string.format('Coordinate the remaining hands, observed discards and admitted owned uses: %d of four common samples clear versus %d for the incumbent. Take only this first action, then refresh; these samples are not a win-rate estimate.',
      best.probability*4,baseline.probability*4)},diag.evaluations,diag
end
return M
