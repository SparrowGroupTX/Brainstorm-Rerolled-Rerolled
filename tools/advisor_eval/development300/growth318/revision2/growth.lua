-- Bounded investments beside an already verified clearing hand. Discard
-- growth is reconsidered after each draw; a Death cycle remains once per blind.
-- Exact transitions prove the retained finish without assuming a favorable
-- replacement draw. Development utility is heuristic, never a win probability.
local M={}
local function weight(key,default) return M.policy_weights and M.policy_weights.get(key) or default end
local function num(v,d) return type(v)=='number' and v or (d or 0) end
local function copy(t) local r={};for k,v in pairs(t or {}) do r[k]=v end;return r end
local function list(t) local r={};for i,v in ipairs(t or {}) do r[i]=v end;return r end
local aliases={j_yorick='Yorick',j_burnt='Burnt Joker',j_blackboard='Blackboard',j_raised_fist='Raised Fist',j_blue_joker='Blue Joker',
  j_shoot_the_moon='Shoot the Moon',j_photograph='Photograph',j_triboulet='Triboulet',j_ancient='Ancient Joker',j_idol='The Idol',j_bloodstone='Bloodstone',j_hanging_chad='Hanging Chad'}
local function name(j) return (j.ability or {}).name or j.name or aliases[j.key] or j.key end
local function reliable(play) return play and play.legal~=false and play.uncertain~=true end
-- A narrow exception to the sorting hazard below. Ordinary card +Mult adds
-- before these Joker-stage effects, so reordering the same reserved cards does
-- not change their sum. This does not qualify other card/Joker effects or draws.
local additive_jokers={j_yorick='Yorick',j_perkeo='Perkeo',j_brainstorm='Brainstorm',
  j_blueprint='Blueprint',j_supernova='Supernova',j_droll='Droll Joker',j_burnt='Burnt Joker'}
local joker_effects={j_yorick='',j_perkeo='',j_brainstorm='Copycat',j_blueprint='Copycat',
  j_supernova='Hand played mult',j_droll='Type Mult',j_burnt=''}
local additive_cards={c_base={'Default Base','Default',0,'Base'},m_mult={'Mult','Enhanced',4,'Mult Card'},
  m_bonus={'Bonus','Enhanced',0,'Bonus Card'}}
local held_cards={c_base={'Default Base','Default','Base'},m_mult={'Mult','Enhanced','Mult Card'},
  m_bonus={'Bonus','Enhanced','Bonus Card'},m_steel={'Steel Card','Enhanced','Steel Card'},
  m_gold={'Gold Card','Enhanced','Gold Card'},m_wild={'Wild Card','Enhanced','Wild Card'},
  m_stone={'Stone Card','Enhanced','Stone Card'},m_glass={'Glass Card','Enhanced','Glass Card'},
  m_lucky={'Lucky Card','Enhanced','Lucky Card'}}
local function plain(t) return type(t)=='table' and getmetatable(t)==nil end
local function finite(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function zero(v) return v==nil or finite(v) and v==0 end
local function small_integer(v) return finite(v) and v>=0 and v<=1048576 and v%1==0 end
local function optional_integers(t,fields)
  for _,key in ipairs(fields) do if t[key]~=nil and not small_integer(t[key]) then return false end end
  return true
end
local hand_names={['High Card']=true,Pair=true,['Two Pair']=true,['Three of a Kind']=true,
  Straight=true,Flush=true,['Full House']=true,['Four of a Kind']=true,['Straight Flush']=true,
  ['Five of a Kind']=true,['Flush House']=true,['Flush Five']=true}
local hand_numbers={'chips','mult','s_chips','s_mult','l_chips','l_mult','level','played','played_this_round','order'}
local function exact_additive_inputs(s,clear)
  if not finite(clear.score) or clear.score<0 or not plain(s.hands or {}) or
    not optional_integers(s,{'first_used_hand_level'}) or
    s.hand_size~=nil and (not small_integer(s.hand_size) or s.hand_size>12) or
    not finite(s.dollars) or math.abs(s.dollars)>1048576 or s.dollars%1~=0 then return false end
  for key,h in pairs(s.hands or {}) do
    if not hand_names[key] or not plain(h) or not optional_integers(h,hand_numbers) then return false end
  end
  local known={}
  for _,i in ipairs(clear.indices) do
    if not small_integer(i) or i<1 or i>#s.hand or known[i] then return false end
    known[i]=true
    local c=s.hand[i];local a=c and c.ability;local base=c and c.base or {}
    if not plain(c) or not plain(a) or not plain(base) then return false end
    local rank=c.rank or base.id
    if not small_integer(rank) or rank<2 or rank>14 or c.rank~=nil and c.rank~=rank or
      base.id~=nil and base.id~=rank then return false end
    local nominal=rank==14 and 11 or math.min(rank,10)
    if c.nominal~=nil and c.nominal~=nominal or base.nominal~=nil and base.nominal~=nominal or
      not small_integer(a.bonus) or not optional_integers(a,{'perma_bonus'}) then return false end
  end
  if #clear.indices>5 then return false end
  -- Initial hand fields and level bonuses are <=2^20. An admitted eight-Joker
  -- Burnt row can add at most eight levels before scoring: reconstructing its
  -- hand value and adding a first-hand level bonus keeps chips/Mult <2^42.
  -- Arm subtraction is exact in that range; Flint's n/2+1/2 is an exact half
  -- before floor. Five canonical cards each add <=11+2*2^20 chips and <=4 Mult,
  -- so every reordered card sum is still <2^43 (well below binary64's2^53).
  -- A cash cap is an exact integer min over nonnegative terms. The separately
  -- qualified held effects only repeat the SAME positive factor1.5 (Steel/Red);
  -- sorting them cannot change the sequence of nonidentity operations. Joker
  -- and consumable order stays fixed. Additional drawn Steel is monotone.
  return true
end
local ability_fields={name='string',set='string',effect='string',type='string',blueprint_compat='string',
  bonus='number',d_size='number',extra_value='number',h_dollars='number',h_mult='number',h_size='number',
  h_x_mult='number',hands_played_at_create='number',mult='number',order='number',p_dollars='number',
  perma_bonus='number',t_chips='number',t_mult='number',x_mult='number',yorick_discards='number',
  eternal='boolean',rental='boolean',perishable='boolean',perish_tally='number',perma_debuff='boolean',
  discarded='boolean',played_this_ante='boolean'}
local function ordinary_ability(a,joker_key)
  if not plain(a) then return false end
  for key,value in pairs(a) do
    if key=='extra' and joker_key=='j_yorick' then
      if not plain(value) or not small_integer(value.discards) or value.discards<1 or
        not small_integer(value.xmult) then return false end
      for k in pairs(value) do if k~='discards' and k~='xmult' then return false end end
    elseif key=='extra' and joker_key=='j_supernova' then
      if value~=1 then return false end
    elseif key=='extra' and (joker_key=='j_burnt' or joker_key=='m_glass') then
      if value~=4 then return false end
    else
      local kind=ability_fields[key]
      if not kind or type(value)~=kind or kind=='number' and not finite(value) then return false end
    end
  end
  return true
end
local function canonical_card(c,key,shape,effect)
  local a=c.ability
  return (c.key==nil or c.key==key) and (c.name==nil or c.name==shape[1]) and
    a.name==shape[1] and a.set==shape[2] and (a.effect==nil or a.effect==effect)
end
local function ordinary_held_inputs(s)
  local seals={Red=true,Blue=true,Gold=true,Purple=true}
  for _,area in ipairs({s.hand,s.deck or {}}) do
    for _,c in ipairs(area) do
      local key=c.enhancement or 'c_base';local shape=held_cards[key];local a=c.ability
      if not plain(c) or not ordinary_ability(a,key) or not shape or c.edition~=nil or
        not canonical_card(c,key,shape,shape[3]) or c.seal~=nil and not seals[c.seal] or
        not zero(a.h_mult) or not zero(a.h_size) or not zero(a.d_size) then return false end
      if key=='m_steel' then
        if a.h_x_mult~=1.5 then return false end
      elseif not zero(a.h_x_mult) then return false end
      if key=='m_gold' then
        if a.h_dollars~=3 then return false end
      elseif not zero(a.h_dollars) then return false end
    end
  end
  -- Keep the complete inventory. Unknown edition fields and nonmonotone
  -- arithmetic are excluded; ordinary Negative/Observatory remains valid.
  local edition_fields={type='string',foil='boolean',holo='boolean',polychrome='boolean',negative='boolean',
    chips='number',mult='number',x_mult='number',card_limit='number'}
  for _,c in ipairs(s.consumeables or {}) do
    if not plain(c) then return false end
    local e=c.edition
    if e~=nil then
      if not plain(e) then return false end
      for key,v in pairs(e) do
        if type(v)~=edition_fields[key] then return false end
      end
      for _,key in ipairs({'chips','mult','x_mult'}) do
        if e[key]~=nil and (not finite(e[key]) or e[key]<(key=='x_mult' and 1 or 0)) then return false end
      end
    end
  end
  return true
end
local function additive_order_safe(s,clear)
  if not plain(s.jokers) or #s.jokers>8 or not exact_additive_inputs(s,clear) or
    not ordinary_held_inputs(s) then return false end
  for _,j in ipairs(s.jokers or {}) do
    local a=j.ability
    if not plain(j) or not ordinary_ability(a,j.key) or j.edition~=nil or not additive_jokers[j.key] or
      a.name~=additive_jokers[j.key] or a.set~='Joker' or
      a.effect~=nil and a.effect~=joker_effects[j.key] then return false end
    if not j.debuff then
      if not zero(a.mult) or not zero(a.bonus) or not zero(a.t_chips) or
        not zero(a.h_mult) or not zero(a.h_x_mult) or not zero(a.p_dollars) or not zero(a.h_dollars) or
        not zero(a.h_size) or not zero(a.d_size) then return false end
      if j.key=='j_droll' then
        if a.type~='Flush' or a.t_mult~=10 then return false end
      elseif not zero(a.t_mult) then return false end
      if j.key=='j_yorick' then
        if not small_integer(a.x_mult) or a.x_mult<1 then return false end
      elseif a.x_mult~=1 then return false end
    end
  end
  for _,i in ipairs(clear.indices) do
    local c=s.hand[i];local a=c and c.ability
    local key=c.enhancement or 'c_base';local shape=c and additive_cards[key]
    if not plain(c) or not ordinary_ability(a) or not shape or c.edition~=nil or c.seal~=nil or
      not canonical_card(c,key,shape,shape[4]) or a.mult~=shape[3] or a.x_mult~=1 or
      not zero(a.h_mult) or not zero(a.h_x_mult) or not zero(a.p_dollars) or not zero(a.h_dollars) or
      not zero(a.t_mult) or not zero(a.t_chips) or not zero(a.h_size) or not zero(a.d_size) then return false end
  end
  return true
end
local function drawn_hazard(s,clear)
  local b=s.blind or {}
  local blocked={bl_hook=true,bl_final_heart=true,bl_final_bell=true,bl_fish=true,bl_mark=true,bl_wheel=true}
  local names={['The Hook']=true,['Crimson Heart']=true,['Cerulean Bell']=true,['The Fish']=true,['The Mark']=true,['The Wheel']=true}
  if not b.disabled and (blocked[b.key] or names[b.name]) then return 'Draw or play changes the finishing conditions.' end
  local scoring_order={Photograph=true,Triboulet=true,['Ancient Joker']=true,['The Idol']=true,Bloodstone=true,['Hanging Chad']=true}
  for _,j in ipairs(s.jokers or {}) do
    if not j.debuff and (name(j)=='Blackboard' or name(j)=='Raised Fist' or name(j)=='Blue Joker' or name(j)=='Shoot the Moon') then return 'Replacement draws can reduce or reorder the reserved score.' end
    if not j.debuff and #clear.indices>1 and scoring_order[name(j)] then return 'Automatic hand sorting can change scoring-trigger order.' end
  end
  local additive_safe
  for _,i in ipairs(clear.indices) do
    local c=s.hand[i]
    if #clear.indices>1 then
      if c.enhancement=='m_glass' or c.enhancement=='m_lucky' or (c.edition or {}).polychrome or
        num((c.edition or {}).x_mult)>1 or num((c.ability or {}).x_mult)>1 then
        return 'Automatic hand sorting can change scoring-card order.'
      end
      if c.enhancement=='m_mult' or num((c.ability or {}).mult)~=0 then
        if additive_safe==nil then additive_safe=additive_order_safe(s,clear) end
        if not additive_safe then return 'Automatic hand sorting can change scoring-card order.' end
      end
    end
  end
  for _,c in ipairs(s.hand) do if num((c.ability or {}).h_mult)~=0 then return 'Automatic hand sorting can change held-card arithmetic.' end end
  local enhancements={c_base=true,m_bonus=true,m_mult=true,m_wild=true,m_stone=true,m_steel=true,m_gold=true,m_glass=true,m_lucky=true}
  for _,c in ipairs(s.deck or {}) do
    local a=c.ability or {}
    -- Deck cards normally face back; their current area orientation does not
    -- predict draw visibility. Bosses/modifiers above govern that visibility.
    if not enhancements[c.enhancement or 'c_base'] or num(a.h_mult)~=0 or
      (num(a.h_x_mult)>0 and num(a.h_x_mult)<1) then return 'Replacement held effects are not guaranteed monotone.' end
  end
end
local function remap(clear,removed,size)
  local map,next_index={},0
  for i=1,size do if not removed[i] then next_index=next_index+1;map[i]=next_index end end
  local result={};for _,i in ipairs(clear) do if not map[i] then return nil end;result[#result+1]=map[i] end
  return result
end
local function cash_cost(s,after,played,indices)
  local m=s.modifiers or {}
  local loss=math.max(0,num(s.dollars)-num(after.dollars))
  local id=type(s.challenge)=='table' and (s.challenge.id or s.challenge.key) or s.challenge
  if played and not m.no_extra_hand_money and id~='c_omelette_1' and id~='c_mad_world_1' then loss=loss+1 end
  if not played then loss=loss+math.max(0,num(m.money_per_discard)) end
  if not m.no_interest and id~='c_omelette_1' then
    local cap=num(s.interest_cap,25)
    loss=loss+math.max(0,math.floor(math.min(cap,math.max(0,num(s.dollars)))/5)-
      math.floor(math.min(cap,math.max(0,num(after.dollars)))/5))*num(s.interest_amount,1)
  end
  local resources=0
  for _,i in ipairs(indices) do
    local c=s.hand[i]
    if not c.debuff then
      if c.enhancement=='m_gold' then resources=resources+9 end
      if c.seal=='Blue' then resources=resources+10 end
    end
  end
  return loss*3+resources+weight('growth_action_cost',4) -- added action/time, deliberately uncalibrated
end
local function draw_count(s,after)
  local b=s.blind or {}
  local serpent=not b.disabled and (b.key=='bl_serpent' or b.name=='The Serpent')
  return math.min(#(after.deck or {}),serpent and 3 or math.max(0,num(after.hand_size,#s.hand)-#after.hand))
end
local function hit_probability(total,targets,draws)
  if total<=0 or targets<=0 or draws<=0 then return 0 end
  local miss=1
  for i=0,math.min(draws,total)-1 do miss=miss*math.max(0,total-targets-i)/(total-i) end
  return 1-miss
end
M.hit_probability=hit_probability

function M.suggest(s,modules,known_clear,options)
  options=options or {}
  local evaluations=0
  local cap=math.min(12,math.max(0,math.floor(num(options.max_evaluations,12))))
  local diagnostics={bounded_growth=true,max_evaluations=cap,candidates=0,reasons={}}
  local function stop(reason) diagnostics.reasons[#diagnostics.reasons+1]=reason;return nil,evaluations,diagnostics end
  local scorer,strategy=modules.scoring,modules.strategy
  if not scorer or not strategy or not strategy.build_profile or not known_clear or not known_clear.indices then return stop('No verified finishing plan.') end
  local remaining=math.max(1,num((s.blind or {}).chips)-num(s.chips))
  if not reliable(known_clear) or num(known_clear.score)<remaining*1.10 then return stop('The known clear has insufficient safety margin for investment.') end
  local profile=strategy.build_profile(s)
  if profile.final or num(profile.horizon)<=0 then return stop('No remaining development horizon.') end
  local round=s.current_round or {}
  local unused_setup=num(s.hands_played,round.hands_played)+num(s.discards_used,round.discards_used)==0
  if #s.hand>12 or #s.hand<2 or #(s.deck or {})>200 or cap<=0 then return stop('The bounded investment check is unavailable.') end
  if num((s.modifiers or {}).flipped_cards)>0 then return stop('Future target visibility is uncertain.') end
  local hazard=drawn_hazard(s,known_clear);if hazard then return stop(hazard) end
  local original_glass=0
  for _,exposure in ipairs(known_clear.glass_exposure or {}) do original_glass=original_glass+num(exposure.probability) end
  if not known_clear.glass_exposure then original_glass=num(known_clear.glass_loss) end
  local reserve={};for _,i in ipairs(known_clear.indices) do reserve[i]=true end
  local spare={};for i=1,#s.hand do if not reserve[i] then spare[#spare+1]=i end end
  if #spare==0 then return stop('Every held card belongs to the finishing plan.') end
  local function score(state,indices)
    if evaluations>=cap then return nil end
    evaluations=evaluations+1;return scorer.score(state,indices)
  end
  local best
  local function accept(action,state,indices,merit,title,lines,metadata)
    local finish=score(state,indices)
    if not reliable(finish) or num(finish.score)<math.max(1,num((state.blind or {}).chips)-num(state.chips))*1.05 then return end
    -- Draws are not required for this score; permitted held effects can only
    -- add to it. Check the actual final hand after every real action/draw.
    if num(finish.glass_loss)>original_glass+0.000001 then return end
    if modules.search and modules.search.arm_cost and modules.search.arm_cost(state,finish.hand)>
      modules.search.arm_cost(s,known_clear.hand) then return end
    finish.indices=list(indices)
    if not best or merit>best.merit then
      best={action=action,title=title,lines=lines,warnings={},play=finish,merit=merit,growth=metadata}
      best.growth.retained_original_indices=list(known_clear.indices)
    end
  end

  local yoricks,burnt={},false
  for _,j in ipairs(s.jokers or {}) do if not j.debuff then
    if name(j)=='Yorick' then yoricks[#yoricks+1]=j
    elseif name(j)=='Burnt Joker' and num(s.discards_used,round.discards_used)==0 then burnt=true end
  end end
  if scorer.after_discard and num(s.discards_left,round.discards_left)>0 and (#yoricks>0 or burnt) then
    local raw,seen={},{}
    local max_cards=math.min(5,num(s.hand_limit,5))
    local function add(indices)
      if #indices<1 or #indices>max_cards then return end
      table.sort(indices);local key=table.concat(indices,',')
      if not seen[key] then seen[key]=true;raw[#raw+1]=indices end
    end
    -- Prefer a full Yorick discard when it costs no useful held resources.
    -- Also admit smaller batches: Blue/Gold retention or a paid discard can
    -- make spending every possible card worse than finishing now.
    local expendable=list(spare)
    local function resource(i)
      local c=s.hand[i]
      if c.debuff then return 0 end
      return (c.enhancement=='m_gold' and 9 or 0)+(c.seal=='Blue' and 10 or 0)
    end
    table.sort(expendable,function(a,b) local x,y=resource(a),resource(b);return x==y and a<b or x<y end)
    for size=1,math.min(max_cards,#expendable) do
      local all={};for i=1,size do all[i]=expendable[i] end;add(all)
    end
    local ranks,suits={},{}
    for _,i in ipairs(spare) do
      local c=s.hand[i];local r=num(c.rank,num((c.base or {}).id))
      ranks[r]=ranks[r] or {};ranks[r][#ranks[r]+1]=i
      local su=c.suit or (c.base or {}).suit or '?';suits[su]=suits[su] or {};suits[su][#suits[su]+1]=i
    end
    for r=2,14 do
      local group=ranks[r] or {}
      for size=1,math.min(max_cards,#group) do local t={};for i=1,size do t[i]=group[i] end;add(t) end
      -- A Burnt rank hand can coexist with a full Yorick batch. Its actual
      -- category is obtained from after_discard, never assumed from the core.
      if #yoricks>0 and burnt and #group>=2 and #group<max_cards then
        local padded,have=list(group),{}
        for _,i in ipairs(group) do have[i]=true end
        for _,i in ipairs(expendable) do if #padded<max_cards and not have[i] then padded[#padded+1]=i end end
        add(padded)
      end
      if #group>=3 and max_cards>=5 then
        for other=2,14 do if other~=r and #(ranks[other] or {})>=2 then
          add({group[1],group[2],group[3],ranks[other][1],ranks[other][2]});break
        end end
      end
    end
    for _,su in ipairs({'Spades','Hearts','Clubs','Diamonds'}) do
      local group=suits[su] or {};if #group>=5 then add({group[1],group[2],group[3],group[4],group[5]}) end
    end
    local candidates,growth_values={},{}
    for _,indices in ipairs(raw) do
      local state,effects=scorer.after_discard(s,indices)
      if state then
        local utility=0
        for _,j in ipairs(yoricks) do
          local a=j.ability or {};local extra=type(a.extra)=='table' and a.extra or {}
          utility=utility+80*#indices/math.max(1,num(extra.discards,23))*num(extra.xmult,1)/math.max(1,num(a.x_mult,1))*math.min(1,profile.horizon/6)
        end
        utility=utility+15*num(effects.yorick_growth)
        if effects.burnt_hand and modules.search and modules.search.hand_growth_value then
          local category=effects.burnt_hand
          if growth_values[category]==nil then growth_values[category]=modules.search.hand_growth_value(s,category,profile) end
          utility=utility+10*growth_values[category]*num(effects.burnt_levels)*math.min(1,profile.horizon/3)
        end
        local merit=utility*weight('growth_utility_scale',1)-cash_cost(s,state,false,indices)
        if merit>0 then candidates[#candidates+1]={state=state,effects=effects,indices=indices,merit=merit} end
      end
    end
    table.sort(candidates,function(a,b)
      if a.merit==b.merit then return table.concat(a.indices,',')<table.concat(b.indices,',') end
      return a.merit>b.merit
    end)
    -- Reserve the six existing scoring slots across category/count choices;
    -- duplicate rank variants must not crowd out every alternative Burnt hand.
    local shortlist,groups,selected={},{},{}
    for _,c in ipairs(candidates) do
      local key=(c.effects.burnt_hand or 'Yorick')..':'..#c.indices
      if not groups[key] then groups[key]=true;selected[c]=true;shortlist[#shortlist+1]=c end
      if #shortlist==6 then break end
    end
    -- Use remaining slots for physical variants. Equal category/count does
    -- not mean equal retained score (for example discarding held Steel).
    for _,c in ipairs(candidates) do
      if #shortlist==6 then break end
      if not selected[c] then shortlist[#shortlist+1]=c;selected[c]=true end
    end
    for i=1,#shortlist do
      if evaluations>=cap then break end
      local c=shortlist[i];local removed={};for _,index in ipairs(c.indices) do removed[index]=true end
      local indices=remap(known_clear.indices,removed,#s.hand)
      diagnostics.candidates=diagnostics.candidates+1
      local purpose=c.effects.burnt_hand and ('level '..c.effects.burnt_hand) or 'grow Yorick'
      accept({kind='discard',area='hand',indices=list(c.indices)},c.state,indices,c.merit,
        'Discard '..#c.indices..' to '..purpose,
        {'The retained cards still clear without a favorable draw; this discard develops later blinds.',
          #yoricks>0 and 'Refresh after each draw. Use more full Yorick discards while the clear and resource tradeoff remain safe.' or
            'Burnt upgrades the actual first-discard hand; its value depends on the deck, levels and scoring support.'},
        {kind='discard',effects=c.effects,utility=c.merit,remaining_discards=c.state.discards_left,
          repeatable_yorick=#yoricks>0,first_burnt_discard=burnt})
    end
  end

  if unused_setup and scorer.after_play and strategy.development_gain and strategy.preservation_cost and
    num(s.hands_left,round.hands_left)>=2 and #(s.deck or {})>0 and not (s.modifiers or {}).debuff_played_cards then
    local death_index
    for i,c in ipairs(s.consumeables or {}) do if c.key=='c_death' and not c.debuff then death_index=i;break end end
    if death_index and #spare>=2 then
      local after_inventory=copy(s);after_inventory.consumeables={}
      for i,c in ipairs(s.consumeables) do if i~=death_index then after_inventory.consumeables[#after_inventory.consumeables+1]=c end end
      local preservation,_,last=strategy.preservation_cost(s,after_inventory,death_index)
      if not last then
        local function copy_gain(recipient,source)
          local after=copy(s);after.hand=list(s.hand);after.hand[recipient]=copy(source)
          return strategy.development_gain(s,after,{recipient},profile)
        end
        local recipient,best_expected,targets,total_gain=nil,0,0,0
        for _,index in ipairs(spare) do
          local count,total=0,0
          for _,c in ipairs(s.deck) do
            local gain=copy_gain(index,c)-preservation-4
            if gain>8 and not c.debuff then count=count+1;total=total+gain end
          end
          if total>best_expected then recipient=index;best_expected=total;targets=count;total_gain=total end
        end
        local source_present=false
        if recipient then
          for i,c in ipairs(s.hand) do if i~=recipient and copy_gain(recipient,c)-preservation-4>8 then source_present=true end end
        end
        if recipient and not source_present then
          local cycle={};for _,i in ipairs(spare) do if i~=recipient and #cycle<math.min(5,num(s.hand_limit,5)) then cycle[#cycle+1]=i end end
          local cycle_candidates={cycle}
          if #cycle>1 then cycle_candidates[#cycle_candidates+1]={cycle[1]} end
          for _,indices in ipairs(cycle_candidates) do
            if #indices>0 and evaluations+3<=cap then
              local setup=score(s,indices)
              if reliable(setup) and num(setup.score)<remaining and num(setup.glass_loss)==0 then
                evaluations=evaluations+1 -- after_play performs exactly one score()
                local state=scorer.after_play(s,indices)
                if state and num(state.hands_left)>=1 then
                  local d=draw_count(s,state)
                  local chance=hit_probability(#s.deck,targets,d)
                  local merit=chance*total_gain/math.max(1,targets)*weight('growth_utility_scale',1)-cash_cost(s,state,true,indices)
                  if d>0 and merit>0 then
                    local removed={};for _,i in ipairs(indices) do removed[i]=true end
                    local finish_indices=remap(known_clear.indices,removed,#s.hand)
                    diagnostics.candidates=diagnostics.candidates+1
                    accept({kind='play',area='hand',indices=list(indices)},state,finish_indices,merit,
                      'Cycle cards to find a useful Death source',
                      {'Keep the existing clearing cards and a Death recipient; spend one spare play looking for a better copying source.',
                        'The retained cards still finish if the search misses. Refresh after the draw before using Death.'},
                      {kind='death_cycle',draws=d,target_probability=chance,eligible_targets=targets,
                        recipient_original_index=recipient,consumable_index=death_index,utility=merit})
                  end
                end
              end
            end
          end
        elseif source_present then diagnostics.reasons[#diagnostics.reasons+1]='A useful Death source is already held; use or arrange it before cycling.' end
      else diagnostics.reasons[#diagnostics.reasons+1]='Preserve the last useful Death source for Perkeo.' end
    end
  end
  diagnostics.evaluations=evaluations
  return best,evaluations,diagnostics
end
return M
