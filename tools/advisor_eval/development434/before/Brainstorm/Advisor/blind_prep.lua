-- Executable preparation for irreversible blind-entry effects. Dagger's
-- protection policy runs first; copy setup uses the source-checked start model.
local M={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function name(c) return (c.ability or {}).name or c.name or c.key end
local function dagger(c) return c.key=='j_ceremonial' or name(c)=='Ceremonial Dagger' end
local function pinned(c) return c.pinned or (c.ability or {}).pinned end
-- Sacrifice eligibility is narrower than purchase utility. Only explicitly
-- understood minor static effects or resale fodder may become a NEW victim.
-- Unsupported effects, permanent engines and large existing scoring effects
-- retain priority even when Dagger could gain a large amount from their price.
local static_fodder={j_joker=true,j_jolly=true,j_zany=true,j_mad=true,j_crazy=true,j_droll=true,
  j_half=true,j_sly=true,j_wily=true,j_clever=true,j_devious=true,j_crafty=true,
  j_scary_face=true,j_smiley=true,j_popcorn=true,j_ice_cream=true,j_gros_michel=true}
local function expendable(s,c,strategy)
  local a=c.ability or {}
  if c.rarity==4 or c.key=='j_blueprint' or c.key=='j_brainstorm' then return false end
  if (a.x_mult or 1)>1 or (a.caino_xmult or 1)>1 or (a.mult or 0)>=16 or
    (a.t_mult or 0)>=16 or (a.t_chips or 0)>50 or (a.h_size or 0)~=0 or (a.d_size or 0)~=0 then return false end
  if c.key=='j_egg' then return true end
  if not static_fodder[c.key] then return false end
  if type(a.extra)=='table' and ((a.extra.chips or 0)>50 or (a.extra.xmult or 1)>1 or (a.extra.x_mult or 1)>1) then return false end
  if strategy and strategy.owned_joker_value then
    local _,_,known=strategy.owned_joker_value(s,c)
    if not known then return false end
  end
  return true
end
local function valid(s,order)
  if #order~=#(s.jokers or {}) then return false end
  local seen={}
  for i,j in ipairs(order) do
    if not s.jokers[j] or seen[j] or (pinned(s.jokers[j]) and i~=j) then return false end
    seen[j]=true
  end
  return true
end
function M.project(s,order)
  if not valid(s,order) then return nil,'Invalid or pinned Joker order.' end
  local state=copy(s);state.jokers={}
  for i,index in ipairs(order) do state.jokers[i]=copy(s.jokers[index]) end
  local removed,gains={},{}
  for i,j in ipairs(state.jokers) do
    local victim=state.jokers[i+1]
    if dagger(j) and not j.debuff and not removed[i] and victim and not removed[i+1] and not (victim.ability or {}).eternal then
      removed[i+1]=true
      local gain=2*(victim.sell_cost or 0)
      j.ability=j.ability or {};j.ability.mult=(j.ability.mult or 0)+gain
      gains[#gains+1]={dagger=order[i],victim=order[i+1],mult=gain}
    end
  end
  local survivors={}
  for i,j in ipairs(state.jokers) do
    if removed[i] then
      if (j.edition or {}).negative then state.joker_limit=(state.joker_limit or 5)-1 end
    else survivors[#survivors+1]=j end
  end
  state.jokers=survivors
  local stencils=0
  for _,j in ipairs(survivors) do if j.key=='j_stencil' or name(j)=='Joker Stencil' then stencils=stencils+1 end end
  for i,j in ipairs(survivors) do
    if j.key=='j_stencil' or name(j)=='Joker Stencil' then j.ability.x_mult=(state.joker_limit or 5)-#survivors+stencils end
    if j.key=='j_swashbuckler' or name(j)=='Swashbuckler' then
      local value=0;for k,c in ipairs(survivors) do if k~=i then value=value+(c.sell_cost or 0) end end
      j.ability.mult=value
    end
  end
  return state,{sacrifices=gains,scope='dagger_only'}
end
local function utility(s,strategy)
  local total=0
  for _,j in ipairs(s.jokers) do
    if dagger(j) then total=total+40*math.log(1+math.max(0,(j.ability or {}).mult or 0))
    elseif strategy and strategy.owned_joker_value then
      local value,_,known=strategy.owned_joker_value(s,j)
      local a=j.ability or {}
      local ongoing=math.max(1,a.x_mult or 1,a.caino_xmult or 1)
      local floor=60*math.log(ongoing)
      if j.rarity==4 or j.key=='j_blueprint' or j.key=='j_brainstorm' then floor=math.max(floor,120) end
      if not known then floor=math.max(floor,80) end
      total=total+math.max(0,value,floor)
    else
      local a=j.ability or {}
      total=total+(j.rarity==4 and 100 or j.key=='j_egg' and 15 or 40)+
        math.max(0,a.mult or 0)+20*math.max(0,(a.x_mult or 1)-1)
    end
  end
  if strategy and strategy.inventory_value then
    local _,info=strategy.inventory_value(s)
    total=total+0.3*(info.future or 0)
  end
  return total
end
function M.suggest(s,strategy)
  local diagnostics={orders=0,max_orders=64,scope='dagger_only',heuristic=true}
  if s.phase~='blind' or #(s.jokers or {})<2 or #s.jokers>20 then return nil,diagnostics end
  local active=false
  for _,j in ipairs(s.jokers) do
    if j.face_down or j.getting_sliced then return nil,diagnostics end
    if dagger(j) and not j.debuff then active=true end
  end
  if not active then return nil,diagnostics end
  local identity,free={},{}
  for i,j in ipairs(s.jokers) do identity[i]=i;if not pinned(j) then free[#free+1]=i end end
  local baseline,effects=M.project(s,identity)
  if #effects.sacrifices==0 then return nil,diagnostics end
  local original_victims={}
  for _,e in ipairs(effects.sacrifices) do original_victims[e.victim]=true end
  local function protected_count(result)
    local count=0
    for _,e in ipairs(result.sacrifices) do if not expendable(s,s.jokers[e.victim],strategy) then count=count+1 end end
    return count
  end
  local best,best_effects,best_value=identity,effects,utility(baseline,strategy)
  local initial=best_value
  local best_protected=protected_count(effects);local initial_protected=best_protected
  diagnostics.protected_before=initial_protected;diagnostics.unsafe_orders=0
  local seen={}
  local function inspect(order)
    if diagnostics.orders>=64 or not valid(s,order) then return end
    local key=table.concat(order,',');if seen[key] then return end;seen[key]=true
    diagnostics.orders=diagnostics.orders+1
    local after,result=M.project(s,order)
    for _,e in ipairs(result.sacrifices) do
      if not original_victims[e.victim] and not expendable(s,s.jokers[e.victim],strategy) then
        diagnostics.unsafe_orders=diagnostics.unsafe_orders+1;return
      end
    end
    local protected=protected_count(result)
    local value=utility(after,strategy)
    if protected<best_protected or protected==best_protected and value>best_value+0.000001 then
      best,best_effects,best_value,best_protected=order,result,value,protected
    end
  end
  inspect(identity)
  -- Move free Daggers to the end, or supply a pinned Dagger with safe fodder
  -- or an eternal neighbour. Existing pins are never moved.
  for _,effect in ipairs(effects.sacrifices) do
    for _,index in ipairs(free) do
      local order=copy(identity)
      if not pinned(s.jokers[effect.victim]) then
        order[effect.victim],order[index]=order[index],order[effect.victim];inspect(order)
      end
    end
  end
  for _,position in ipairs(free) do if dagger(s.jokers[position]) then
    local order=copy(identity);local values={}
    for _,i in ipairs(free) do if i~=position then values[#values+1]=i end end
    values[#values+1]=position;for k,i in ipairs(free) do order[i]=values[k] end;inspect(order)
  end end
  diagnostics.protected_after=best_protected
  if best==identity or best_protected==initial_protected and best_value<=initial+2 then return nil,diagnostics end
  local lines={'Arrange the row before selecting the blind; Dagger destroys its non-eternal right neighbour.'}
  if #best_effects.sacrifices==0 then lines[#lines+1]='This order prevents the Dagger sacrifice.'
  else
    for _,e in ipairs(best_effects.sacrifices) do
      lines[#lines+1]='Dagger #'..e.dagger..' consumes #'..e.victim..' '..tostring(name(s.jokers[e.victim]))..' for +'..e.mult..' Mult.'
    end
    if best_protected<initial_protected then
      lines[#lines+1]='This protects an existing engine or unsupported effect by supplying understood expendable fodder.'
    else lines[#lines+1]='The projected surviving row has more estimated future value than the current sacrifice.' end
  end
  lines[#lines+1]='Click Execute to reorder, then review fresh advice before starting the blind.'
  return {title='Prepare the Dagger sacrifice',lines=lines,warnings={},
    action={kind='reorder_jokers',area='jokers',order=best},preparation=best_effects},diagnostics
end
local dagger_suggest=M.suggest
local aliases={Blueprint='j_blueprint',Brainstorm='j_brainstorm',Burglar='j_burglar',
  ['Marble Joker']='j_marble',Hologram='j_hologram',Acrobat='j_acrobat',Dusk='j_dusk',Erosion='j_erosion'}
local function key(j) return j.key or aliases[name(j)] end
local function active(j)
  local a=j.ability or {}
  return not j.debuff and not a.perma_debuff and not (a.perishable and (a.perish_tally or 5)<=0)
end
local function copy_joker(j) return key(j)=='j_blueprint' or key(j)=='j_brainstorm' end
local function startup_joker(j) return key(j)=='j_burglar' or key(j)=='j_marble' end
local function scoring_edition(j)
  local e=j.edition or {};return type(e)=='table' and (e.foil or e.holo or e.polychrome)
end
local function copy_target(row,index,seen)
  local j=row[index];if not j or not active(j) then return nil end
  seen=seen or {};if seen[index] then return nil end;seen[index]=true
  if key(j)=='j_blueprint' then return copy_target(row,index+1,seen) end
  if key(j)=='j_brainstorm' then return copy_target(row,1,seen) end
  return j
end
local function row_signature(row)
  local out={}
  for i,j in ipairs(row) do
    -- Native scoring order and scoring editions stay in exactly the same
    -- relative order. Merely moving a passive startup effect is allowed.
    local target=copy_joker(j) and copy_target(row,i)
    if (not copy_joker(j) and not startup_joker(j)) or scoring_edition(j) or target and not startup_joker(target) then
      out[#out+1]=tostring(j.id)
    end
  end
  return table.concat(out,',')
end
local function dagger_signature(diagnostics)
  local out={}
  for _,e in ipairs(diagnostics.events or {}) do if e.kind=='dagger' then
    out[#out+1]=tostring(e.actor)..'>'..tostring(e.victim)..':'..tostring(e.mult)
  end end
  return table.concat(out,',')
end
local function setup_copy(s,strategy)
  local diagnostics={scope='startup_copy',orders=0,max_orders=64,complete=false,heuristic=true}
  local function stop(reason) diagnostics.reason=reason;return nil,diagnostics end
  if s.phase~='blind' or #(s.jokers or {})<2 or #s.jokers>8 then return stop('Copy setup requires a visible row of two to eight Jokers.') end
  if not M.blind_start then return stop('The source-checked blind-start model is unavailable.') end
  local has_copy,has_start=false,false
  for _,j in ipairs(s.jokers) do
    if j.face_down or j.facing=='back' or j.getting_sliced then return stop('The current row is not fully observable and settled.') end
    if active(j) then has_copy=has_copy or copy_joker(j);has_start=has_start or startup_joker(j) end
  end
  if not has_copy or not has_start then return stop('No supported start-of-blind copy opportunity.') end
  local model=copy(s);model.current_round=model.current_round or {};model.playing_cards=model.playing_cards or {}
  if s.next_blind then model.blind=copy(s.next_blind) end
  local blind=model.blind or {}
  if ({bl_final_acorn=true,bl_final_leaf=true,bl_final_heart=true})[blind.key] or
    ({['Amber Acorn']=true,['Verdant Leaf']=true,['Crimson Heart']=true})[blind.name] then
    return stop('Upcoming Joker shuffling or debuff changes need an ordered blind-entry model.')
  end
  local identity,free={},{}
  for i,j in ipairs(model.jokers) do
    -- These identifiers track source callback actors only inside this detached
    -- projection; returned orders always use the real row's current positions.
    j.id='preparation:'..i;identity[i]=i;if not pinned(j) then free[#free+1]=i end
  end
  local baseline,base_effects=M.blind_start.project(model)
  if not baseline then return stop(base_effects) end
  local function scoring_targets(row)
    local targets={}
    for i,j in ipairs(row) do if active(j) and copy_joker(j) then
      local target=copy_target(row,i)
      if target and not startup_joker(target) then targets[j.id]=target.id end
    end end
    return targets
  end
  local function preserves_targets(row,targets)
    for i,j in ipairs(row) do if targets[j.id] then
      local target=copy_target(row,i);if not target or target.id~=targets[j.id] then return false end
    end end
    return true
  end
  local targets=scoring_targets(model.jokers)
  local retained_targets=scoring_targets(baseline.jokers)
  local native_order=row_signature(baseline.jokers);local sacrifices=dagger_signature(base_effects)
  local last_hand=false;local erosion=false
  for _,j in ipairs(baseline.jokers) do if active(j) then
    last_hand=last_hand or key(j)=='j_acrobat' or key(j)=='j_dusk'
    erosion=erosion or key(j)=='j_erosion'
  end end
  local base_holograms={}
  for _,j in ipairs(baseline.jokers) do if active(j) and key(j)=='j_hologram' then base_holograms[j.id]=(j.ability or {}).x_mult end end
  local function terminal_growth(after)
    local modifiers=s.modifiers or {}
    if #(s.consumeables or {})>0 or s.deck_key=='b_plasma' or modifiers.balance or
      modifiers.chips_dollar_cap or modifiers.minus_hand_size_per_X_dollar then return nil end
    -- Multiplying every Hologram ratio is unsound when flat Mult is added
    -- between them. Only one final native multiplier receives ratio credit;
    -- all earlier growth is merely nonnegative, and every later callback must
    -- be a known no-op startup effect or another copy of Hologram.
    local terminal
    for i,j in ipairs(after.jokers) do if active(j) and key(j)=='j_hologram' then terminal=i end end
    if not terminal then return nil end
    for i,j in ipairs(after.jokers) do if active(j) then
      if startup_joker(j) or copy_joker(j) or key(j)=='j_hologram' then
        -- These callback roles are checked by the start model itself.
      elseif strategy and strategy.owned_joker_value then
        local _,_,known=strategy.owned_joker_value(after,j);if not known then return nil end
      else return nil end
      if i>terminal then
        if scoring_edition(j) then return nil end
        local target=copy_joker(j) and copy_target(after.jokers,i)
        if not startup_joker(j) and not (copy_joker(j) and
          (not target or startup_joker(target) or key(target)=='j_hologram')) then return nil end
      end
    end end
    local hologram=after.jokers[terminal];local before=base_holograms[hologram.id]
    local value=(hologram.ability or {}).x_mult
    if (hologram.ability or {}).type and hologram.ability.type~='' then return nil end
    if type(before)~='number' or before<1 or type(value)~='number' or value<=before then return nil end
    return value/before
  end
  local base_hands=baseline.hands_left or 0;local base_size=#baseline.playing_cards
  local best,best_effect,best_hands,best_ratio=nil,nil,base_hands,1
  local seen={};local failure
  local function inspect(order)
    if not valid(s,order) then return end
    local signature=table.concat(order,',');if seen[signature] then return end;seen[signature]=true
    diagnostics.orders=diagnostics.orders+1
    if diagnostics.orders>64 then failure='The complete insertion family exceeds the preparation bound.';return end
    local candidate=copy(model);candidate.jokers={}
    for i,index in ipairs(order) do candidate.jokers[i]=copy(model.jokers[index]) end
    for i,j in ipairs(candidate.jokers) do if active(j) and copy_joker(j) then
      local target=copy_target(candidate.jokers,i)
      if target and startup_joker(target) and target.blueprint_compat==false then return end
    end end
    if not preserves_targets(candidate.jokers,targets) then return end
    -- Do not oscillate between a new copy layout and Dagger protection on the
    -- next refresh. Every accepted layout is already stable for that policy.
    if dagger_suggest(candidate,strategy) then return end
    local after,effects=M.blind_start.project(candidate)
    if not after then failure=effects;return end
    if row_signature(after.jokers)~=native_order or dagger_signature(effects)~=sacrifices or
      not preserves_targets(after.jokers,retained_targets) then return end
    local hands=after.hands_left or 0;local added=#after.playing_cards-base_size
    if hands<base_hands or added<0 then return end
    for _,j in ipairs(after.jokers) do if base_holograms[j.id] then
      local before=base_holograms[j.id];local value=(j.ability or {}).x_mult
      if type(before)~='number' or before<=0 or type(value)~='number' or value<before then return end
    end end
    local ratio=1
    if added>0 then
      local growth=terminal_growth(after)
      if erosion or not growth or growth<=1 or base_size<1 then return end
      local draw=math.min(base_size,math.max(1,baseline.hand_size or 8))
      local retained=1;for i=0,draw-1 do retained=retained*(base_size-i)/(base_size+added-i) end
      -- Ignore ALL hands containing a new Stone, giving them zero credit.
      -- A final native Hologram's growth must outweigh that dilution by 1%.
      -- This is a continuous-score heuristic: final integer rounding and the
      -- full blind are not compared here. No rank/suit luck or post-entry
      -- copy rearrangement is assumed, and this cannot certify readiness.
      ratio=retained*growth
      if ratio<=1.01 then return end
    end
    if hands>base_hands and last_hand then return end
    if hands==base_hands and added==0 then return end
    if hands>best_hands or hands==best_hands and ratio>best_ratio+0.000001 then
      best,best_effect,best_hands,best_ratio=order,effects,hands,ratio
    end
  end
  inspect(identity)
  -- Complete one-insertion family over unpinned positions: at most 57 rows
  -- for an eight-Joker row. A later click can add another strictly improving
  -- copy; no intermediate downgrade or unpublished multi-step setup is used.
  for from=1,#free do for to=1,#free do if from~=to then
    local values=copy(free);local moving=table.remove(values,from);table.insert(values,to,moving)
    local order=copy(identity);for i,position in ipairs(free) do order[position]=values[i] end;inspect(order)
  end end end
  if failure then return stop(failure) end
  diagnostics.complete=true;diagnostics.projected_hand_counter_before=base_hands
  diagnostics.projected_hand_counter_after=best_hands;diagnostics.additional_hands=best_hands-base_hands
  diagnostics.continuous_opening_ratio=best_ratio
  if not best then return nil,diagnostics end
  local lines={}
  if best_hands>base_hands then lines[#lines+1]='Copy the supported blind-start effect for '..(best_hands-base_hands)..' additional hands; Burglar already removes the discards.' end
  local extra=#best_effect.generated-#base_effects.generated
  if extra>0 then
    lines[#lines+1]='Add '..extra..' Stone card(s) for observed Hologram growth; the estimate discounts the larger deck and gives new-card draws no scoring credit.'
    lines[#lines+1]='This growth estimate is not a guaranteed score gain or a supported clear.'
  end
  lines[#lines+1]='Existing scoring copy targets and native scoring order are preserved.'
  lines[#lines+1]='Click Execute to reorder, then review fresh advice before selecting the blind.'
  best_effect.scope='startup_copy';best_effect.setup_actions=1;best_effect.post_entry_restore_required=false
  return {title='Prepare start-of-blind copies',lines=lines,warnings={},
    action={kind='reorder_jokers',area='jokers',order=best},preparation=best_effect},diagnostics
end
-- An owned played-hand Planet has an exact permanent effect even when a random
-- boss prevents a supported scoring forecast. Do not strand this known upgrade
-- behind an unavailable tactical comparison or turn a text tip into dead stock.
local function planet_preparation(s,strategy)
  local diagnostics={scope='exact_main_hand_planet',evaluations=0,complete=false}
  local function stop(reason) diagnostics.reason=reason;return nil,diagnostics end
  if s.phase~='shop' and s.phase~='blind' then return stop('Planet preparation applies before shop or blind actions.') end
  if #(s.jokers or {})>0 or (s.used_vouchers or {}).v_observatory or (s.vouchers or {}).v_observatory then
    return stop('Preserve Joker and Observatory inventory planning.')
  end
  if not strategy or not strategy.build_profile or not strategy.preservation_cost or
      not strategy.consumables or not strategy.consumables.apply then return stop('Exact Planet preparation dependencies are unavailable.') end
  local inventory=s.consumeables or {}
  if #inventory<1 or #inventory>20 or (s.consumeable_buffer or 0)~=0 then return stop('No settled bounded inventory is available.') end
  local profile=strategy.build_profile(s)
  local main_hand=profile and profile.hand
  local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
  local function played(old)
    return old and finite(old.played) and old.played>0 and finite(old.level) and old.level>=1 and
      finite(old.chips) and old.chips>=0 and finite(old.mult) and old.mult>=1
  end
  if s.phase=='shop' and not played(main_hand and (s.hands or {})[main_hand]) then
    return stop('A played main hand with finite public levels is required.')
  end
  local matches={c_pluto='High Card',c_mercury='Pair',c_uranus='Two Pair',c_venus='Three of a Kind',
    c_saturn='Straight',c_jupiter='Flush',c_earth='Full House',c_mars='Four of a Kind',
    c_neptune='Straight Flush',c_planet_x='Five of a Kind',c_ceres='Flush House',c_eris='Flush Five'}
  local names={c_pluto='Pluto',c_mercury='Mercury',c_uranus='Uranus',c_venus='Venus',c_saturn='Saturn',
    c_jupiter='Jupiter',c_earth='Earth',c_mars='Mars',c_neptune='Neptune',c_planet_x='Planet X',c_ceres='Ceres',c_eris='Eris'}
  -- Keep the established main hand first even if its Planet is later in the
  -- inventory. Only after committing to leave the shop may a secondary hand's
  -- known played history justify this exact upgrade without a scoring forecast.
  for pass=1,s.phase=='blind' and 2 or 1 do
  for index,owned in ipairs(inventory) do
    local hand=matches[owned.key]
    local old=hand and (s.hands or {})[hand]
    local selected_pass=(pass==1 and hand==main_hand) or (pass==2 and hand~=main_hand)
    local a=owned.ability or {};local config=a.consumeable or {};local e=owned.edition
    local plain_config=type(config)=='table'
    if plain_config then for key in pairs(config) do if key~='hand_type' and key~='softlock' then plain_config=false end end end
    if hand and selected_pass and played(old) and a.set=='Planet' and a.name==names[owned.key] and plain_config and not owned.debuff and not owned.face_down and
        not owned.unknown and owned.facing~='back' and not e and config.hand_type==hand then
      local fool_conflict=false
      for _,other in ipairs(inventory) do
        if other.key=='c_fool' and s.last_tarot_planet~=owned.key then fool_conflict=true end
      end
      if not fool_conflict then
        local after,reason=strategy.consumables.apply(s,index,{})
        local changed=after and (after.hands or {})[hand]
        if after and changed and finite(changed.level) and changed.level==old.level+1 and
            finite(changed.chips) and finite(changed.mult) and changed.chips>=old.chips and changed.mult>=old.mult and
            (changed.chips>old.chips or changed.mult>old.mult) and after.dollars==s.dollars and
            after.hand_size==s.hand_size and after.joker_limit==s.joker_limit and
            after.consumable_limit==s.consumable_limit and #(after.consumeables or {})==#inventory-1 and
            #(after.playing_cards or {})==#(s.playing_cards or {}) then
          local loss,retention,last=strategy.preservation_cost(s,after,index)
          if finite(loss) and loss==0 and not last then
            diagnostics.complete=true;diagnostics.index=index;diagnostics.key=owned.key;diagnostics.hand=hand
            diagnostics.main_hand=hand==main_hand;diagnostics.profile_hand=main_hand
            diagnostics.scope=hand==main_hand and 'exact_main_hand_planet' or 'exact_played_hand_planet'
            diagnostics.played=old.played
            diagnostics.level_before=old.level;diagnostics.level_after=changed.level
            diagnostics.chips_before=old.chips;diagnostics.chips_after=changed.chips
            diagnostics.mult_before=old.mult;diagnostics.mult_after=changed.mult
            diagnostics.inventory_before=#inventory;diagnostics.inventory_after=#after.consumeables
            diagnostics.score_forecast_required=false;diagnostics.readiness_claim=false
            return {title='Use '..tostring(owned.name or a.name or owned.key)..' to level '..hand,
              lines={'Apply the exact permanent level before spending or selecting the next blind; this also frees its held slot.',
                'The public level increases from '..old.level..' to '..changed.level..'. Refresh advice after use; this is not a blind-clear forecast.'},
              warnings={},action={kind='use',area='consumeables',index=index,targets={}},
              preparation=diagnostics},diagnostics
          else diagnostics.reason=retention or 'Existing inventory retains a protected future value.' end
        elseif reason then diagnostics.reason=reason end
      else diagnostics.reason='Keep the current previous-consumable identity for the owned Fool.' end
    end
  end
  end
  return nil,diagnostics
end
M.planet_preparation=planet_preparation
function M.suggest(s,strategy)
  local planet,planet_diagnostics=planet_preparation(s,strategy)
  if planet then return planet,planet_diagnostics end
  local suggestion,diagnostics=dagger_suggest(s,strategy)
  if suggestion then return suggestion,diagnostics end
  local setup,copy_diagnostics=setup_copy(s,strategy)
  if setup then return setup,copy_diagnostics end
  diagnostics.copy_setup=copy_diagnostics
  diagnostics.planet_preparation=planet_diagnostics
  return nil,diagnostics
end
return M
