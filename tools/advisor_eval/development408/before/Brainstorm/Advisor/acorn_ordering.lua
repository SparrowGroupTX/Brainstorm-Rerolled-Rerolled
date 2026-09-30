-- Complete, finite immediate play/order comparison over a public slot belief.
-- Inventory and discards remain untouched. This is immediate-play evidence,
-- not a full blind continuation or a reason to claim a terminal win.
local M={}
local function finite(x) return type(x)=='number' and x==x and math.abs(x)<math.huge end
local function list(x) local r={};for i,v in ipairs(x or {}) do r[i]=v end;return r end
-- Snapshot editions retain vanilla numeric metadata. Admit equivalent public
-- representations, never arbitrary numeric/custom effects or mixed editions.
local function public_edition(value)
  if value==nil then return true,nil end
  local e=type(value)=='string' and {[value]=true} or value
  if type(e)~='table' or getmetatable(e) then return false end
  local kinds={foil=true,holo=true,polychrome=true,negative=true}
  local selected=e.type
  if selected~=nil and not kinds[selected] then return false end
  for key in pairs(kinds) do
    if e[key]~=nil and type(e[key])~='boolean' then return false end
    if e[key] then if selected and selected~=key then return false end;selected=key end
  end
  if selected and e[selected]==false then return false end
  local numeric={chips={foil=50},mult={holo=10},x_mult={polychrome=1.5}}
  for key,v in pairs(e) do
    if numeric[key] then
      if not finite(v) or not selected or numeric[key][selected]~=v then return false end
    elseif key~='type' and not kinds[key] then return false end
  end
  return true,selected and {[selected]=true,type=selected} or {}
end
function M.suggest(s,b,scorer,belief,options)
  options=options or {};local diag={evaluations=0,complete=false,worlds=b and b.worlds and #b.worlds or 0,
    projected_state_allocations=0,
    terminal_evidence=false,source_counterfactual=false,order_complete=false,resource_override=false,
    joint_resource_comparison=false,consumables_unchanged=true,discards_unchanged=true,
    scope='All public legal subsets over every consistent inventory world in the current slot order; optional complete common-world reorder family. Immediate-play metric only, no future discard/use or blind-win forecast.'}
  local function no(reason) diag.reason=reason;return nil,diag.evaluations,diag end
  if not belief or not belief.validate(b) or b.state_valid~=true then return no('Current public inventory abilities are not qualified.') end
  if s.phase~='hand' or not finite(s.hands_left) or s.hands_left<1 or s.hands_left%1~=0 or
    not finite(s.discards_left) or s.discards_left<0 or s.discards_left%1~=0 or
    #(s.hand or {})<1 or #s.hand>12 or s.jokers_shuffling or s.ordering_safe==false then
    return no('The belief comparison requires a settled visible hand and known remaining resources.') end
  if not scorer or not scorer.score or not finite(s.chips) or not finite((s.blind or {}).chips) then return no('Exact scoring and target resources are required.') end
  local target=s.blind.chips-s.chips;if target<=0 then return no('The round is already cleared.') end
  -- Glass breaks after the immediate score, not between its retriggers. The
  -- pure scorer retains exposure without predicting a surviving population.
  local known_enhancements={c_base=true,m_bonus=true,m_mult=true,m_steel=true,m_stone=true,m_wild=true,m_lucky=true,m_glass=true,m_gold=true}
  local random_floor=false;local editions={}
  for i,c in ipairs(s.hand) do
    if c.face_down or c.unknown or c.concealed or c.facing=='back' or not known_enhancements[c.enhancement or 'c_base'] or
      c.seal and not ({Red=true,Blue=true,Purple=true,Gold=true})[c.seal] then
      return no('Concealed or unknown playing-card effects remain outside this immediate comparison.') end
    if c.enhancement=='m_lucky' then random_floor=true end
    if c.enhancement=='m_glass' then diag.glass_after_scoring=true end
    if c.enhancement=='m_gold' or c.seal=='Blue' or c.seal=='Purple' then diag.unplanned_rewards=true end
    local admitted,e=public_edition(c.edition)
    if not admitted then return no('Unknown playing-card edition effect.') end
    editions[i]=e
  end
  if random_floor and type(scorer.lower_bound)~='function' then
    return no('Lucky cards require a supported conservative score floor in every public Joker world.') end
  diag.supported_random_floor=random_floor
  -- Ignore the raw live Joker array even if a caller supplied concealed payloads.
  local root={};for k,v in pairs(s) do if k~='jokers' and k~='public_joker_belief' then root[k]=belief.copy(v) end end
  for i,c in ipairs(root.hand) do c.edition=editions[i] end
  local selected,subsets={},{};local maximum=math.min(5,s.hand_limit or 5)
  local function walk(start)
    if #selected>0 then
      local ok=true;for i,c in ipairs(s.hand) do if (c.ability or {}).forced_selection then
        local found=false;for _,index in ipairs(selected) do if i==index then found=true end end;ok=ok and found
      end end
      if ok then subsets[#subsets+1]=list(selected) end
    end
    if #selected>=maximum then return end
    for i=start,#s.hand do selected[#selected+1]=i;walk(i+1);selected[#selected]=nil end
  end
  walk(1)
  local orders=belief.permutations(#b.inventory,720)
  local requested=options.max_evaluations or 140000
  local requested_order=options.max_order_evaluations or 30000
  if not finite(requested) or not finite(requested_order) then return no('Finite score allowances are required.') end
  local budget=math.min(140000,math.max(0,math.floor(requested)))
  local legal_subset_count=#subsets
  -- Restrict actions, never public worlds. Build a deterministic visible-card
  -- shortlist before scoring, balanced across play sizes. Each selected action
  -- still receives every world, and no incomplete prefix can be recommended.
  if #subsets*#b.worlds>budget and #b.worlds>=120 and #b.worlds<=720 then
    local count=math.min(64,math.floor(budget/#b.worlds))
    if count>=16 then
      local groups={};for i=1,5 do groups[i]={} end
      local function quality(indices)
        local ranks,suits={},{};local value=0
        for _,i in ipairs(indices) do local c=s.hand[i]
          local rank=c.rank or (c.base or {}).id or 0
          ranks[rank]=(ranks[rank] or 0)+1
          local suit=c.suit or '';suits[suit]=(suits[suit] or 0)+1
        end
        for _,n in pairs(ranks) do value=value+n*n*4 end
        for _,n in pairs(suits) do value=value+n*n end
        return value
      end
      for _,indices in ipairs(subsets) do groups[#indices][#groups[#indices]+1]={indices=indices,value=quality(indices)} end
      for _,group in ipairs(groups) do table.sort(group,function(a,c)
        if a.value~=c.value then return a.value>c.value end
        return table.concat(a.indices,',')<table.concat(c.indices,',')
      end) end
      subsets={};local rank=1
      while #subsets<count do
        local added=false
        for size=5,1,-1 do local entry=groups[size][rank]
          if entry and #subsets<count then subsets[#subsets+1]=entry.indices;added=true end
        end
        if not added then break end;rank=rank+1
      end
      diag.action_family='bounded_visible_subset_shortlist'
      diag.all_legal_subsets=false
      diag.scope='Complete public worlds for a deterministic visible-card shortlist; not exhaustive actions or future resource planning.'
    end
  end
  diag.legal_subsets=legal_subset_count
  if diag.all_legal_subsets==nil then diag.all_legal_subsets=true end
  local needed=#subsets*#b.worlds
  local order_needed=(#orders-1)*needed
  local order_budget=math.min(30000,math.max(0,math.floor(requested_order)),math.max(0,budget-needed))
  diag.orders=#orders;diag.subsets=#subsets;diag.required_evaluations=needed;diag.max_evaluations=budget
  diag.required_order_evaluations=order_needed;diag.max_order_evaluations=order_budget
  if needed==0 or needed>budget then return no('The entire current-order common-world/play family does not fit the ordinary allowance.') end
  local compare_orders=order_needed<=order_budget
  local profiles={}
  local function compare_order(oi,order)
    profiles[oi]={}
    -- The production scorer is pure. Build each public world once per order,
    -- then reuse it across the identical legal-subset family. Cloning the full
    -- population and collection context once per score would add no evidence.
    local states={}
    for wi,world in ipairs(b.worlds) do
      local state=belief.copy(root);state.jokers={}
      for position,oldslot in ipairs(order) do
        local ordinal=world[oldslot];local j=belief.copy(b.inventory[ordinal]);j.id='public-belief:'..ordinal;j.face_down=false
        state.jokers[position]=j
      end
      states[wi]=state;diag.projected_state_allocations=diag.projected_state_allocations+1
    end
    for pi,indices in ipairs(subsets) do
      local profile={order=list(order),indices=list(indices),scores={},minimum=math.huge,mean=0,
        clipped_mean=0,clear_count=0,legal=true}
      for wi=1,#b.worlds do
        -- One charged pass per world/subset. Lucky triggers are bounded, not
        -- sampled or replaced with their mean, including copied Joker effects.
        local result=(random_floor and scorer.lower_bound or scorer.score)(states[wi],indices)
        diag.evaluations=diag.evaluations+1
        if not result or result.uncertain or type(result.warnings)=='table' and #result.warnings>0 or
          result.legal~=false and (not finite(result.score) or random_floor and result.reliable_bound~=true) then
          return nil,'An admitted world lacks a supported score or reliable floor; no partial comparison is published.' end
        if result.legal==false then profile.legal=false;profile.minimum=-math.huge;profile.scores[wi]=false
        else
          profile.scores[wi]=result.score;profile.minimum=math.min(profile.minimum,result.score)
          profile.mean=profile.mean+result.score/#b.worlds
          profile.clipped_mean=profile.clipped_mean+math.min(target,result.score)/#b.worlds
          if result.score>=target then profile.clear_count=profile.clear_count+1 end
        end
        if options.yield_fn and diag.evaluations%32==0 then options.yield_fn(diag.evaluations) end
      end
      profiles[oi][pi]=profile
    end
    return true
  end
  local ok,reason=compare_order(1,orders[1]);if not ok then return no(reason) end
  diag.complete=true;diag.profiles=profiles
  local best
  local function better(a,old)
    if not a.legal then return false end
    if not old then return true end
    local clear,oldclear=a.minimum>=target,old.minimum>=target
    if clear~=oldclear then return clear end
    if clear then return #a.indices<#old.indices end -- Do not optimize excess score.
    if s.hands_left==1 then
      if a.clear_count~=old.clear_count then return a.clear_count>old.clear_count end
      if a.clipped_mean~=old.clipped_mean then return a.clipped_mean>old.clipped_mean end
    end
    if a.minimum~=old.minimum then return a.minimum>old.minimum end
    if a.mean~=old.mean then return a.mean>old.mean end
    return #a.indices<#old.indices
  end
  for _,profile in ipairs(profiles[1]) do if better(profile,best) then best=profile end end
  if not best then return no('No fixed legal play is supported in every consistent world.') end
  if s.hands_left==1 then
    diag.final_hand_clear_fraction=best.clear_count/#b.worlds
    diag.final_hand_clipped_mean=best.clipped_mean
  end
  local function current(extra)
    local clear=best.minimum>=target
    if not clear and options.public_incumbent and options.public_incumbent.supported==true and
      options.public_incumbent.action and options.public_incumbent.action.kind~='play' then
      return no('An existing supported public resource action is not overridden by this immediate-play-only comparison.')
    end
    diag.reason=extra or 'Complete current-order comparison supplies a fixed public play.'
    return {kind='play',action={kind='play',area='hand',indices=list(best.indices)},
      play={indices=list(best.indices),score=best.minimum},minimum_score=best.minimum,mean_score=best.mean,
      belief_epoch=b.epoch,belief_revision=b.revision,immediate_clear_all_worlds=clear,
      public_information_fallback=not clear,joint_resource_comparison=false,
      lines={clear and 'This fixed play reaches the modeled target in every consistent public Joker order.' or
        (s.hands_left==1 and 'On the last hand, this fixed play reaches the target on a supported score floor in '..best.clear_count..' of '..#b.worlds..' retained public Joker orders; this is not a calibrated win probability.' or
        (diag.all_legal_subsets and 'This fixed play has the strongest conservative immediate score across the consistent public Joker orders.' or
          'This fixed play has the strongest conservative immediate score in the bounded shortlist, checked against every public Joker world.')),
        diag.unplanned_rewards and 'Immediate score only; held Gold and seal rewards are not planned against discards or future hands.' or
        diag.glass_after_scoring and 'Glass may break after scoring; its survival and the next hand are not predicted.' or
        'Observe visible Joker activations and refresh the belief after the action; future draws, discards and consumable uses are not forecast here.'}},diag.evaluations,diag
  end
  if best.minimum>=target then return current('A current-order all-world clear avoids an unnecessary reorder comparison.') end
  if not compare_orders then return current('The complete reorder family exceeds its allowance; the complete current-order play remains available.') end
  for oi=2,#orders do
    local qualified,gap=compare_order(oi,orders[oi])
    if not qualified then
      diag.order_gap=gap;return current('An alternate order is unsupported; retain the independently complete current-order comparison.')
    end
  end
  diag.order_complete=true
  for oi=2,#orders do for _,profile in ipairs(profiles[oi]) do if profile.legal and profile.minimum>=target then
    return {kind='reorder_jokers',action={kind='reorder_jokers',order=profile.order},projected_play={indices=profile.indices,score=profile.minimum},
      minimum_score=profile.minimum,belief_epoch=b.epoch,belief_revision=b.revision,
      lines={'Move the current visible slots into this order, then refresh advice.',
        'The same proposed hand reaches the modeled target in every remaining public identity world.'}},diag.evaluations,diag
  end end end
  return current('No reordered immediate clear exists in the completed family; retain the conservative current-order play.')
end
return M
