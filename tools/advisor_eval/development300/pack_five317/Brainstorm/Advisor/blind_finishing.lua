-- Complete, bounded next-blind policies on the shop's existing paired worlds.
-- The known composition is public; future deck order is used only by drawing.
-- Four deterministic worlds are decision evidence, never a win-rate estimate.
local M={}
local ranking=setmetatable({},{__mode='k'})
local function num(v,d) return type(v)=='number' and v or (d or 0) end
local function finite(v) return type(v)=='number' and v==v and v>=0 and v<math.huge end
local function copy(v,seen)
  if type(v)~='table' then return v end
  seen=seen or {};if seen[v] then return seen[v] end
  local out={};seen[v]=out;for k,x in pairs(v) do out[k]=copy(x,seen) end;return out
end
local function valid(state)
  local generation=state.certificate_generation
  local maximum=8
  if type(generation)=='table' and generation.schema==1 and generation.kind=='certificate_four_composition_worlds_v1' and
      generation.extra_held==1 and generation.hand_capacity==state.hand_size and generation.population_after==#(state.playing_cards or {}) then
    local found=0
    for _,card in ipairs(state.playing_cards or {}) do if card.id==generation.generated_id and
        card.advisor_generated=='certificate_composition_sample' then found=found+1 end end
    if found==1 then maximum=9 end
  end
  if #state.hand<1 or #state.hand>maximum or #state.deck>120 or num(state.hand_size)>8 then return false end
  for _,c in ipairs(state.hand) do if c.face_down or not c.rank or not c.suit then return false end end
  return true
end
local function supported(p)
  if not p or p.legal==false or not finite(p.score) or p.uncertain then return false end
  for _,w in ipairs(p.warnings or {}) do
    if w:find('Unmodeled',1,true) or w:find('unknown card',1,true) or
      w:find('not included',1,true) or w:find('not modeled',1,true) then return false end
  end
  return true
end
-- A choice uses its ordinary public-state mean, never the outcome of the play
-- being considered. Only this explicit random family can then be resolved by
-- sampled_outcomes.after_play. An empty/suppressed warning list is not evidence
-- that Lucky is the only source of uncertainty.
function M.choice_supported(state,p)
  if not p or p.legal==false then return false end
  if supported(p) then return true end
  if not finite(p.score) or not p.uncertain or next(state.jokers or {}) or #(p.warnings or {})==0 then return false end
  for _,warning in ipairs(p.warnings) do
    if warning~='Lucky cards and other random effects use averages; a clearing estimate is not a guarantee.' then return false end
  end
  if not finite(num((state.probabilities or {}).normal,1)) or
    (state.probabilities or {}).normal~=nil and type(state.probabilities.normal)~='number' then return false end
  local ids={}
  for _,area in ipairs({state.hand or {},state.deck or {}}) do for _,card in ipairs(area) do
    local id=card.id
    if not (type(id)=='string' and id~='' or type(id)=='number' and id==id and math.abs(id)<math.huge) then return false end
    if ids[tostring(id)] then return false end;ids[tostring(id)]=true
  end end
  local lucky=false
  for _,index in ipairs(p.scoring_indices or {}) do
    local card=state.hand[index]
    if not card then return false end
    local ability=card.ability or {}
    local enhancement=card.enhancement or (card.key and card.key:sub(1,2)=='m_' and card.key) or
      (ability.effect=='Lucky Card' and 'm_lucky')
    if enhancement=='m_lucky' and not card.debuff then
      if not finite(num(ability.mult,20)) or ability.mult~=nil and type(ability.mult)~='number' or
        not finite(num(ability.p_dollars,20)) or ability.p_dollars~=nil and type(ability.p_dollars)~='number' then return false end
      lucky=true
    end
  end
  return lucky
end
-- Shared with exhaustive opening scoring so the first play needs no rescore.
-- Once a play clears, preserving population and held rewards beats overkill.
function M.better_play(state,p,best)
  if not p or p.legal==false then return false end
  local target=math.max(1,num((state.blind or {}).chips)-num(state.chips))
  local clear=supported(p) and p.score>=target
  local old_clear=supported(best) and best.score>=target
  if not best or clear and not old_clear then return true end
  if clear and old_clear and M.search then
    local prepared=ranking[state]
    if not prepared then prepared={population=M.search.population_profile(state)};ranking[state]=prepared end
    local population=prepared.population
    local cost=M.search.population_cost(state,p,population)
    local old_cost=M.search.population_cost(state,best,population)
    if cost~=old_cost then return cost<old_cost end
    local arm=M.search.arm_cost and M.search.arm_cost(state,p.hand) or 0
    local old_arm=M.search.arm_cost and M.search.arm_cost(state,best.hand) or 0
    if arm~=old_arm then return arm<old_arm end
    if M.finish_rewards then
      prepared.rewards=prepared.rewards or M.finish_rewards.prepare(state,M.strategy)
      local rewards=prepared.rewards
      return M.finish_rewards.value(state,p,rewards)>M.finish_rewards.value(state,best,rewards)
    end
    return false
  end
  return not clear and not old_clear and p.score>best.score
end

-- Supported end-of-blind resource components, not a complete future-run value.
-- Keep these separate: more cash must not compensate for losing a Blue Planet,
-- a physical survivor, a developed hand, or a successful common-world finish.
local function known_number(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local planet_keys={['High Card']='c_pluto',Pair='c_mercury',['Two Pair']='c_uranus',
  ['Three of a Kind']='c_venus',Straight='c_saturn',Flush='c_jupiter',['Full House']='c_earth',
  ['Four of a Kind']='c_mars',['Straight Flush']='c_neptune',['Five of a Kind']='c_planet_x',
  ['Flush House']='c_ceres',['Flush Five']='c_eris'}
local function raw_finish_details(before,after,prepared,details)
  if type(details)~='table' then return nil end
  local receipt=copy(details)
  receipt.schema=1;receipt.kind='held_finish_components_v1'
  receipt.planet_key=planet_keys[details.planet_hand]
  receipt.slots_before_blue=prepared.slots
  receipt.slots_after_blue=prepared.slots-num(details.blue_planets)
  receipt.inventory_before=copy(before.consumeables or {})
  receipt.inventory_after_play=copy(after.consumeables or {})
  receipt.consumable_limit=before.consumable_limit
  receipt.consumeable_buffer=before.consumeable_buffer
  receipt.cash_after_play=after.dollars
  -- This preserves raw held/Blue components, not an invented complete cashout.
  -- The existing no-Joker resources receipt remains the only full cash proof.
  receipt.cashout_joker_income_modeled=next(before.jokers or {})==nil
  receipt.scope='Raw supported held Gold, Blue identities/counts and inventory room; complete Joker cashout income is not projected.'
  return receipt
end
local function finish_resources(before,after,details)
  local mods=before.modifiers or {};local blind=before.blind or {}
  if next(before.jokers or {}) or (before.used_vouchers or {}).v_observatory or
    (before.vouchers or {}).v_observatory or mods.debuff_played_cards or
    num(mods.minus_hand_size_per_X_dollar)>0 or not blind.disabled and
    (blind.key=='bl_arm' or blind.name=='The Arm') or not details or details.final_blind or
    not details.held_supported or not details.blue_supported then return nil end
  for _,field in ipairs({'held_dollars','hand_dollars','discard_dollars','blue_planets','planet_utility'}) do
    if not known_number(details[field]) or details[field]<0 then return nil end
  end
  if not known_number(after.dollars) then return nil end
  local amount,cap=num(before.interest_amount,1),num(before.interest_cap,25)
  if not known_number(amount) or amount<0 or not known_number(cap) or cap<0 then return nil end
  -- after.dollars already contains every scored payout, including the final
  -- play. Gold arrives before interest; unused hands/discards arrive after it.
  -- The common blind award is deliberately omitted on both sides.
  local held_cash=after.dollars+details.held_dollars
  local interest=not mods.no_interest and held_cash>=5 and amount*math.min(math.floor(held_cash/5),cap/5) or 0
  local cash=held_cash+interest+details.hand_dollars+details.discard_dollars
  if not known_number(cash) then return nil end
  local survivors={}
  for _,card in ipairs(after.playing_cards or {}) do
    if card.id==nil or survivors[tostring(card.id)] then return nil end
    survivors[tostring(card.id)]=true
  end
  if next(survivors)==nil then return nil end
  local levels,played,leaders,max_played={},{},{},-1
  for hand,h in pairs(after.hands or {}) do
    if type(h)~='table' or not known_number(h.played) or h.played<0 then return nil end
    levels[hand]={level=h.level,chips=h.chips,mult=h.mult}
    if h.played>0 then played[hand]=true end
    if h.visible~=false then
      if h.played>max_played then max_played=h.played;leaders={} end
      if h.played==max_played then leaders[#leaders+1]=hand end
    end
  end
  if next(levels)==nil then return nil end
  table.sort(leaders)
  return {cash_components=cash,held_dollars=details.held_dollars,interest=interest,
    hand_dollars=details.hand_dollars,discard_dollars=details.discard_dollars,
    blue_planets=details.blue_planets,planet_hand=details.planet_hand,planet_utility=details.planet_utility,
    survivors=survivors,levels=levels,played=played,leaders=table.concat(leaders,'|'),
    scope='No-Joker supported cash, same-hand Blue rewards and conserved population; common blind payout omitted'}
end

local function resource_dominates(candidate,incumbent)
  if #candidate.worlds~=4 or #incumbent.worlds~=4 then return false end
  local strict=false
  for i=1,4 do
    local a,b=candidate.worlds[i],incumbent.worlds[i]
    local av,bv=a.resources,b.resources
    -- Economics never buys a failed world or reduced progress, including when
    -- another world would compensate in a four-sample mean.
    if not a.clear or not b.clear or a.progress<b.progress or not av or not bv or
      a.population_loss>b.population_loss or #a.actions>#b.actions or
      av.cash_components<bv.cash_components or av.blue_planets<bv.blue_planets or
      av.planet_utility<bv.planet_utility or bv.blue_planets>0 and av.planet_hand~=bv.planet_hand or
      av.leaders~=bv.leaders then return false end
    for id in pairs(bv.survivors) do if not av.survivors[id] then return false end end
    for hand in pairs(bv.played) do if not av.played[hand] then return false end end
    for hand,level in pairs(bv.levels) do
      local other=av.levels[hand]
      if not other or other.level~=level.level or other.chips~=level.chips or other.mult~=level.mult then return false end
    end
    for hand in pairs(av.levels) do if not bv.levels[hand] then return false end end
    strict=strict or #a.actions<#b.actions or av.cash_components>bv.cash_components or
      av.blue_planets>bv.blue_planets or av.planet_utility>bv.planet_utility or a.population_loss<b.population_loss
  end
  return strict
end

-- Apply a fully specified physical permutation; this is one actual projected
-- action, not permission to invent a different scoring row for each play.
local function setup(world)
  local state=copy(world.state);local action=world.setup_action
  if action==nil then return state,nil end
  local row=state.jokers or {};local order=type(action)=='table' and action.order
  if type(action)~='table' or action.kind~='reorder_jokers' or action.area~='jokers' or
      type(order)~='table' or #order~=#row or #row<2 or #row>12 or state.jokers_shuffling or
      state.ordering_safe==false or (state.blind or {}).shuffle_pending or
      not (state.blind or {}).disabled and (state.blind or {}).key=='bl_final_acorn' then
    return nil,'The projected Joker setup is not a legal settled reorder.'
  end
  local next_row,seen,changed,ids={},{},false,{}
  for i,index in ipairs(order) do
    local j=row[index]
    if type(index)~='number' or index%1~=0 or not j or seen[index] or j.face_down or j.facing=='back' or
        (j.pinned or (j.ability or {}).pinned) and i~=index then
      return nil,'The projected Joker setup changes a pinned/hidden card or physical membership.'
    end
    seen[index]=true;next_row[i]=j;changed=changed or i~=index
    ids[i]=j.id or j.key
  end
  if not changed then return nil,'A no-op setup must not be counted as an action.' end
  state.jokers=next_row
  return state,{kind='reorder_jokers',area='jokers',order=copy(order),joker_ids=ids,projected=true}
end

function M.forecast(worlds,scorer,charge,options)
  options=options or {}
  local diagnostic={complete=false,supported=false,samples=4,policies={},candidate_limit=32,
    policy_scope='Four common composition worlds; fixed play-only or one targeted observed discard policy; up to four hands, eight cards, and 32 future-play candidates.',
    cost_model='actual_actions',known_mechanics=false,finishing_guarantee=false}
  if options.certificate_samples then
    diagnostic.policy_scope='Four common deck/front/seal composition worlds; play-only or one targeted observed discard retaining Purple cards; up to four hands, one certified extra initial card, and32 future-play candidates. Other generation outcomes and Tarot branches are omitted.'
  end
  local function no(reason) diagnostic.reason=reason;return diagnostic end
  if options.five_card_discard~=nil and type(options.five_card_discard)~='boolean' then
    return no('The optional fixed five-card discard policy must be explicitly declared.')
  end
  local policy_names={'play_only','one_targeted_discard'}
  if options.five_card_discard then
    diagnostic.policy_family='fixed_play_only_or_one_targeted_or_one_five_card_observed_discard_v1'
    policy_names[3]='one_five_card_targeted_discard'
    diagnostic.policy_scope=diagnostic.policy_scope..' Also compares one fixed observed discard of exactly five eligible cards; inability to form a legal five-card discard leaves the policy on its play path.'
  end
  if #worlds~=4 or not M.search or not M.search.obvious_candidates or not M.draws or not M.sampled_outcomes or
    not M.multi_discard or not scorer.after_play or not scorer.after_discard then
    return no('Whole-blind transition or observed-candidate dependencies are unavailable.')
  end
  local prepared={}
  for index,world in ipairs(worlds) do
    local s,action=setup(world)
    if not s then return no(action) end
    prepared[index]={state=s,opening_play=world.opening_play,setup_action=action}
    if not valid(s) or num(s.hands_left)<1 or num(s.hands_left)>4 or not finite((s.blind or {}).chips) or s.blind.chips<=0 then
      return no('Whole-blind comparison requires visible hands up to eight cards and one to four playable hands with a known target.')
    end
    if (s.modifiers or {}).flipped_cards or not (s.blind or {}).disabled and
      ({bl_house=true,bl_wheel=true,bl_mark=true,bl_fish=true})[(s.blind or {}).key] then
      return no('Concealed opening or later observations require a separate belief policy.')
    end
    for _,j in ipairs(s.jokers or {}) do if not j.debuff and
      (j.key=='j_business' or j.key=='j_reserved_parking') then
      return no('Conditional random income cannot be used as exact spendable future cash.')
    end end
    local seen={};for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do
      if c.id==nil or seen[c.id] then return no('Distinct physical identities are required in every paired world.') end;seen[c.id]=true
    end end
    if not M.choice_supported(s,world.opening_play) then return no('An opening score has unsupported uncertainty or effects.') end
  end
  local aborted
  local function best_play(state)
    if not valid(state) then aborted='A later observation is concealed or exceeds the admitted hand/deck size.';return nil end
    local candidates=M.search.obvious_candidates(state,math.min(5,num(state.hand_limit,5)))
    if #candidates==0 or #candidates>32 then aborted='The complete observed play family is unavailable.';return nil end
    local best
    for _,indices in ipairs(candidates) do
      if not charge() then aborted='The shared shop allowance cannot complete every admitted world and policy.';return nil end
      local p=scorer.score(state,indices)
      if p and p.legal~=false then
        if not M.choice_supported(state,p) then aborted='A considered future score has unsupported uncertainty or effects.';return nil end
        p.indices=copy(indices)
        if M.better_play(state,p,best) then best=p end
      end
    end
    if not best then aborted='No supported legal play in the complete observed family.' end
    return best
  end
  local function fill(state,seed,turn)
    local s,reason=M.sampled_outcomes.fill(state,state.deck,scorer,M.draws,seed,turn,0)
    if not s then aborted='A replacement draw is unsupported: '..tostring(reason);return nil end
    if not valid(s) then aborted='A replacement observation is concealed or exceeds eight cards.';return nil end
    return s
  end
  local function run(world,index,policy)
    local state=copy(world.state);local first=true;local discarded=false
    local seed=({977,1999,3253,4751})[index];local hands,discards,loss,rewards=0,0,0,0
    local actions={};local initial_cash=state.dollars;local resources,finish_details
    local setup_actions=world.setup_action and 1 or 0
    if world.setup_action then actions[1]=copy(world.setup_action) end
    while num(state.hands_left)>0 and #state.hand>0 and num(state.chips)<state.blind.chips do
      local play=first and copy(world.opening_play) or best_play(state);first=false
      if not play then return nil end
      if policy~='play_only' and not discarded and play.score<state.blind.chips-num(state.chips) and
        num(state.discards_left)>0 and #state.deck>0 then
        -- Candidate selection uses only this observed hand. Never select a
        -- different discard based on the resulting hidden cards or world win.
        local candidate=M.multi_discard.discard_candidates(state,nil,1,{keep_purple=options.keep_purple==true,
          exact_count=policy=='one_five_card_targeted_discard' and 5 or nil})[1]
        local cost=math.max(0,num((state.modifiers or {}).discard_cost))
        if candidate and num(state.dollars)-cost>=math.min(0,num(state.bankrupt_at)) then
          local after,reason=scorer.after_discard(state,candidate.indices)
          if not after then aborted='An admitted discard transition is unsupported: '..tostring(reason);return nil end
          actions[#actions+1]={kind='discard',indices=copy(candidate.indices),dollars_before=state.dollars,dollars_after=after.dollars}
          discards=discards+1;discarded=true
          state=fill(after,seed,hands*2+1);if not state then return nil end
          play=best_play(state);if not play then return nil end
        end
      end
      if not charge() then aborted='The shared shop allowance cannot complete every admitted transition.';return nil end
      local after,reason,actual=M.sampled_outcomes.after_play(state,play.indices,scorer,seed,hands+1)
      if not after or not supported(actual) then aborted='A play transition has unsupported scoring, growth or population effects: '..tostring(reason);return nil end
      actual.indices=copy(play.indices)
      loss=loss+M.search.population_cost(state,actual,M.search.population_profile(state))
      hands=hands+1
      local selected_ids={};for _,i in ipairs(play.indices) do selected_ids[#selected_ids+1]=state.hand[i].id end
      actions[#actions+1]={kind='play',indices=copy(play.indices),hand=actual.hand,score=actual.score,
        card_ids=selected_ids,
        sampled_lucky=actual.sampled_lucky,score_kind=actual.score_kind,score_guaranteed=actual.score_guaranteed,
        cumulative_score=after.chips,dollars_before=state.dollars,dollars_after=after.dollars,
        remaining_population=#(after.playing_cards or {}),remaining_draw=#after.deck}
      if after.chips>=after.blind.chips and M.finish_rewards then
        local details
        local prepared_rewards=M.finish_rewards.prepare(state,M.strategy)
        rewards,details=M.finish_rewards.value(state,actual,prepared_rewards)
        finish_details=raw_finish_details(state,after,prepared_rewards,details)
        resources=finish_resources(state,after,details)
      end
      state=after
      if state.chips<state.blind.chips and state.hands_left>0 and #state.hand+#state.deck>0 then
        state=fill(state,seed,hands*2+2);if not state then return nil end
      end
    end
    local target=state.blind.chips;local score=num(state.chips)
    return {clear=score>=target,score=score,shortfall=math.max(0,target-score),progress=math.min(1,score/target),
      hands_used=hands,discards_used=discards,dollars_delta=num(state.dollars)-num(initial_cash),
      dollars_after=state.dollars,population_loss=loss,finish_reward=rewards,finish_details=finish_details,resources=resources,actions=actions,
      setup_actions=setup_actions,action_count=#actions,
      endpoint_resources=M.pack_survival and M.pack_survival.capture(state) or nil}
  end
  local best
  for _,policy in ipairs(policy_names) do
    local record={name=policy,worlds={},clearing_samples=0,mean_score=0,mean_shortfall=0,mean_progress=0,
      mean_hands_used=0,mean_discards_used=0,mean_setup_actions=0,mean_action_count=0,max_discards_used=0,population_loss=0,finish_reward=0}
    diagnostic.policies[#diagnostic.policies+1]=record
    for index,world in ipairs(prepared) do
      local outcome=run(world,index,policy)
      if not outcome then return no(aborted) end
      record.worlds[index]=outcome
      record.clearing_samples=record.clearing_samples+(outcome.clear and 1 or 0)
      for _,field in ipairs({'score','shortfall','progress','hands_used','discards_used','setup_actions','action_count'}) do record['mean_'..field]=record['mean_'..field]+outcome[field]/4 end
      record.max_discards_used=math.max(record.max_discards_used,outcome.discards_used)
      record.population_loss=record.population_loss+outcome.population_loss/4
      record.finish_reward=record.finish_reward+outcome.finish_reward/4
    end
    -- Commit one policy across all four worlds. Do not take the winning branch
    -- separately in each world and manufacture knowledge of the hidden deck.
    local tied=best and record.clearing_samples==best.clearing_samples and record.mean_progress==best.mean_progress
    local resource_gain=tied and resource_dominates(record,best)
    if resource_gain then
      best=record;diagnostic.selection_basis='per_world_resource_dominance'
    elseif not best or record.clearing_samples>best.clearing_samples or record.clearing_samples==best.clearing_samples and
      (record.mean_progress>best.mean_progress or record.mean_progress==best.mean_progress and
        (record.mean_discards_used<best.mean_discards_used or record.mean_discards_used==best.mean_discards_used and
          record.population_loss<best.population_loss)) then
      best=record;diagnostic.selection_basis='existing_survival_progress_resource_order'
    end
  end
  diagnostic.complete=true;diagnostic.supported=true;diagnostic.known_mechanics=true
  diagnostic.keep_purple=options.keep_purple==true
  diagnostic.generation_composition_samples=options.certificate_samples==true
  diagnostic.selected=best;diagnostic.all_worlds_clear=best.clearing_samples==4
  diagnostic.max_discards_used=best.max_discards_used
  diagnostic.reason='Completed '..(options.five_card_discard and 'all three' or 'both')..' observed policies in all four paired worlds, carrying conditional sampled scores, growth, population and resource costs; omitted policies and unseen draws remain uncertain.'
  return diagnostic
end
return M
