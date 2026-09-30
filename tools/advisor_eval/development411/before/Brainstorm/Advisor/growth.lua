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
  m_bonus={'Bonus','Enhanced',0,'Bonus Card'},m_steel={'Steel Card','Enhanced',0,'Steel Card'}}
local held_cards={c_base={'Default Base','Default','Base'},m_mult={'Mult','Enhanced','Mult Card'},
  m_bonus={'Bonus','Enhanced','Bonus Card'},m_steel={'Steel Card','Enhanced','Steel Card'},
  m_gold={'Gold Card','Enhanced','Gold Card'},m_wild={'Wild Card','Enhanced','Wild Card'},
  m_stone={'Stone Card','Enhanced','Stone Card'},m_glass={'Glass Card','Enhanced','Glass Card'},
  m_lucky={'Lucky Card','Enhanced','Lucky Card'}}
local function plain(t) return type(t)=='table' and getmetatable(t)==nil end
local function finite(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function zero(v) return v==nil or finite(v) and v==0 end
local function small_integer(v) return finite(v) and v>=0 and v<=1048576 and v%1==0 end
-- Bound recursive detached transitions before considering either old or new
-- investments. The check preserves all fields; it never truncates inventory.
local function bounded_plain(v,path,budget,depth)
  budget=budget or {nodes=0,bytes=0};depth=depth or 0
  budget.nodes=budget.nodes+1
  if budget.nodes>65536 or depth>16 then return false end
  local kind=type(v)
  if kind=='number' then return finite(v) end
  if kind=='string' then budget.bytes=budget.bytes+#v;return #v<=4096 and budget.bytes<=1048576 end
  if kind~='table' then return kind=='nil' or kind=='boolean' end
  if getmetatable(v)~=nil then return false end
  path=path or {};if path[v] then return false end;path[v]=true
  for k,x in pairs(v) do
    if type(k)=='string' then
      budget.bytes=budget.bytes+#k
      if #k>4096 or budget.bytes>1048576 then path[v]=nil;return false end
    elseif not small_integer(k) then path[v]=nil;return false end
    if not bounded_plain(x,path,budget,depth+1) then path[v]=nil;return false end
  end
  path[v]=nil;return true
end
local function dense(v,maximum)
  if type(v)~='table' then return false end
  local n=0;for k in pairs(v) do if not small_integer(k) or k<1 then return false end;n=n+1 end
  return n==#v and n<=maximum
end
local function equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
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
      not zero(a.h_mult) or (key=='m_steel' and a.h_x_mult~=1.5 or key~='m_steel' and not zero(a.h_x_mult)) or
      not zero(a.p_dollars) or not zero(a.h_dollars) or
      not zero(a.t_mult) or not zero(a.t_chips) or not zero(a.h_size) or not zero(a.d_size) then return false end
  end
  return true
end
-- A played canonical Steel card has no scoring-stage multiplier: its 1.5 is
-- read only in the held-card pass. Admitting it above does not admit Steel as
-- a disposable/replacement card in the two-discard proof below.
local function drawn_hazard(s,clear)
  local b=s.blind or {}
  local blocked={bl_hook=true,bl_final_heart=true,bl_final_bell=true,bl_fish=true,bl_mark=true,bl_wheel=true}
  local names={['The Hook']=true,['Crimson Heart']=true,['Cerulean Bell']=true,['The Fish']=true,['The Mark']=true,['The Wheel']=true}
  if not b.disabled and (blocked[b.key] or names[b.name]) then return 'Draw or play changes the finishing conditions.' end
  local scoring_order={Photograph=true,Triboulet=true,['Ancient Joker']=true,['The Idol']=true,Bloodstone=true,['Hanging Chad']=true}
  for _,j in ipairs(s.jokers or {}) do
    if not j.debuff and (name(j)=='Blackboard' or name(j)=='Raised Fist' or name(j)=='Shoot the Moon') then return 'Replacement draws can reduce or reorder the reserved score.' end
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

-- Search optimizes an immediate clear at 100% of the target. Investment needs
-- 105%, so that selected clear is not always the best *already scored* anchor
-- for a discard. This read-only selection never treats an alternative's UI
-- estimate as evidence, spends no scores, or changes the incumbent play.
function M.select_clear(s,selected,alternatives,options)
  local diagnostics={considered=0,qualified=0,changed=false}
  if not s or s.teacher_profile~='perkeo_yorick_win_v1' or
    type(s.hand)~='table' or type(selected)~='table' then return selected,diagnostics end
  local active=false
  for _,j in ipairs(s.jokers or {}) do
    if not j.debuff and name(j)=='Yorick' then active=true;break end
  end
  local exhaust=options and options.exhaust_discards==true
  if not active and not exhaust then return selected,diagnostics end
  local target=math.max(1,num((s.blind or {}).chips)-num(s.chips))*(exhaust and 1 or 1.05)
  local function valid(clear)
    if type(clear)~='table' or clear.legal~=true or clear.uncertain~=false or
      not finite(clear.score) or clear.score<target or
      clear.bound_kind~=nil and not (clear.bound_kind=='supported_random_floor' and clear.reliable_bound==true) or
      clear.conservative==true or not dense(clear.indices,5) or #clear.indices<1 or
      #clear.indices>=#s.hand then return false end
    local seen={}
    for _,i in ipairs(clear.indices) do
      if not small_integer(i) or i<1 or i>#s.hand or seen[i] then return false end
      seen[i]=true
    end
    for _,message in ipairs(clear.warnings or {}) do
      if type(message)~='string' or message:find('Unmodeled',1,true) then return false end
    end
    return true
  end
  if valid(selected) then return selected,diagnostics end
  local function cost(clear,key)
    local value=clear[key]
    return value==nil and 0 or finite(value) and value or nil
  end
  local function no_regression(clear)
    for _,key in ipairs({'population_cost','glass_loss','arm_cost'}) do
      local old,new=cost(selected,key),cost(clear,key)
      if old==nil or new==nil or new>old+0.000001 then return false end
    end
    local old,new=cost(selected,'finish_reward'),cost(clear,'finish_reward')
    return old~=nil and new~=nil and new+0.000001>=old
  end
  local best
  for _,clear in ipairs(alternatives or {}) do
    diagnostics.considered=diagnostics.considered+1
    if valid(clear) and no_regression(clear) and not drawn_hazard(s,clear) then
      diagnostics.qualified=diagnostics.qualified+1
      if not best or #clear.indices<#best.indices or
        (#clear.indices==#best.indices and clear.score>best.score) then best=clear end
    end
  end
  if best then
    diagnostics.changed=best~=selected
    diagnostics.selected_cards=#best.indices
    diagnostics.selected_score=best.score
    return best,diagnostics
  end
  return selected,diagnostics
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
local pair_modifiers={enable_eternals_in_shop='boolean',enable_perishables_in_shop='boolean',
  enable_rentals_in_shop='boolean',no_extra_hand_money='boolean',no_interest='boolean',
  no_blind_reward='table',scaling='number',discard_cost='number',money_per_discard='number',
  money_per_hand='number'}
local pair_decks={}
for _,key in ipairs({'red','blue','yellow','green','black','magic','nebula','ghost','abandoned',
  'checkered','zodiac','painted','anaglyph','plasma','erratic'}) do pair_decks['b_'..key]=true end
local pair_vouchers={}
for _,key in ipairs({'grabber','nacho_tong','wasteful','recyclomancy','paint_brush','palette',
  'antimatter','blank','seed_money','money_tree','clearance_sale','liquidation','overstock_norm',
  'overstock_plus','reroll_surplus','reroll_glut','crystal_ball','omen_globe','telescope','observatory',
  'tarot_merchant','tarot_tycoon','planet_merchant','planet_tycoon','magic_trick','illusion',
  'directors_cut','retcon','hieroglyph','petroglyph','hone','glow_up'}) do pair_vouchers['v_'..key]=true end
local pair_consumables={}
for set,keys in pairs({Tarot={'fool','magician','high_priestess','empress','emperor','heirophant','lovers',
  'chariot','justice','hermit','wheel_of_fortune','strength','hanged_man','death','temperance','devil',
  'tower','star','moon','sun','judgement','world'},Planet={'pluto','mercury','uranus','venus','saturn',
  'jupiter','earth','mars','neptune','planet_x','ceres','eris'},Spectral={'familiar','grim','incantation',
  'talisman','aura','wraith','sigil','ouija','ectoplasm','immolate','ankh','deja_vu','hex','trance',
  'medium','cryptid','soul','black_hole'}}) do
  for _,key in ipairs(keys) do pair_consumables['c_'..key]=set end
end
local function pair_scope(s,clear)
  local r=s.current_round or {};local left=num(s.discards_left,r.discards_left)
  if clear.legal~=true or clear.uncertain~=false or s.phase~='hand' or not small_integer(s.hands_left) or s.hands_left<1 or
    not small_integer(left) or left<2 or not small_integer(s.discards_used) or
    not small_integer(s.hand_size) or #s.hand~=s.hand_size or
    not dense(clear.indices,5) or #clear.indices<1 or not dense(s.hand,12) or
    not dense(s.deck,200) or not dense(s.playing_cards,256) or not dense(s.consumeables,64) or
    not small_integer(s.hand_limit) or s.hand_limit<1 or s.hand_limit>5 or
    not small_integer(s.consumable_limit) or not small_integer(s.consumeable_buffer) or
    not pair_decks[s.deck_key] or s.challenge~=nil then return nil end
  local b=s.blind or {}
  local blinds={bl_small='Small Blind',bl_big='Big Blind'}
  if not blinds[b.key] or b.name~=blinds[b.key] or b.boss or
    b.debuff~=nil and (not plain(b.debuff) or next(b.debuff)) then return nil end
  -- These modifiers either have no discard/draw callback or an exact scalar
  -- cash cost. Unknown callbacks, hand-size tax, concealment and cash-capped
  -- scoring are excluded even if an ordinary one-discard check supports them.
  for k,v in pairs(s.modifiers or {}) do
    local kind=pair_modifiers[k]
    if not kind or type(v)~=kind then return nil end
    if kind=='number' and not small_integer(v) then return nil end
    if kind=='table' then
      for name,flag in pairs(v) do
        if (name~='Small' and name~='Big' and name~='Boss') or type(flag)~='boolean' then return nil end
      end
    end
  end
  if s.used_vouchers~=nil and not plain(s.used_vouchers) then return nil end
  for k,v in pairs(s.used_vouchers or {}) do if not pair_vouchers[k] or type(v)~='boolean' then return nil end end
  if s.interest_cap~=nil and not small_integer(s.interest_cap) or
    s.interest_amount~=nil and not small_integer(s.interest_amount) or
    not additive_order_safe(s,clear) then return nil end
  local reserved,ids={},{}
  for _,i in ipairs(clear.indices) do
    local c=s.hand[i]
    if not c or type(c.id)~='string' or c.id=='' then return nil end
    reserved[c.id]=true
  end
  for _,c in ipairs(s.playing_cards) do
    if not plain(c) or not plain(c.ability) or c.base~=nil and not plain(c.base) then return nil end
    local a=c.ability or {};local key=c.enhancement or 'c_base';local base=c.base or {}
    local rank=c.rank or base.id;local suit=c.suit or base.suit
    local nominal=rank==14 and 11 or type(rank)=='number' and math.min(rank,10)
    if type(c.id)~='string' or c.id=='' or ids[c.id] or c.unknown or c.identity_unknown or
      c.concealed or a.wheel_flipped or a.forced_selection or c.debuff or c.seal~=nil or c.edition~=nil or
      not small_integer(rank) or rank<2 or rank>14 or c.rank~=nil and c.rank~=rank or
      base.id~=nil and base.id~=rank or c.nominal~=nil and c.nominal~=nominal or
      base.nominal~=nil and base.nominal~=nominal or
      (suit~='Spades' and suit~='Hearts' and suit~='Clubs' and suit~='Diamonds') or
      c.suit~=nil and c.suit~=suit or base.suit~=nil and base.suit~=suit or
      not ordinary_ability(a) or not additive_cards[key] or
      not canonical_card(c,key,additive_cards[key],additive_cards[key][4]) or
      a.mult~=additive_cards[key][3] or a.x_mult~=1 or not small_integer(a.bonus) or
      not optional_integers(a,{'perma_bonus'}) or not zero(a.h_mult) or not zero(a.h_dollars) or
      not zero(a.p_dollars) or not zero(a.t_mult) or not zero(a.t_chips) or
      not zero(a.h_size) or not zero(a.d_size) then return nil end
    if reserved[c.id] then
      if key=='m_steel' and a.h_x_mult~=1.5 or key~='m_steel' and not zero(a.h_x_mult) then return nil end
    elseif key=='m_steel' or not zero(a.h_x_mult) then return nil end
    ids[c.id]=c
  end
  local seen={}
  for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do
    if seen[c.id] or not ids[c.id] or not equal(c,ids[c.id]) then return nil end
    seen[c.id]=true
  end end
  for _,c in ipairs(s.hand) do if c.face_down or c.facing=='back' then return nil end end
  local physical_yoricks=0
  for _,j in ipairs(s.jokers) do
    local a=j.ability
    -- Burnt has no pre-discard effect after the first discard. Both public
    -- counters must explicitly agree before treating it as inert in both
    -- planned transitions; additive_order_safe already qualifies its identity
    -- and complete supported ability shape above.
    if j.key=='j_burnt' and (not small_integer(r.discards_used) or
      r.discards_used<1 or r.discards_used~=s.discards_used) then return nil end
    if type(j.id)~='string' or j.id=='' or ids[j.id] or j.unknown or j.face_down or
      j.facing=='back' or j.getting_sliced or j.debuff or a.perma_debuff or
      a.perishable and (not small_integer(a.perish_tally) or a.perish_tally==0) then return nil end
    ids[j.id]=j
    if j.key=='j_yorick' then
      if a.perishable and a.perish_tally<=1 or not plain(a.extra) or not small_integer(a.extra.discards) or a.extra.discards<1 or
        not small_integer(a.extra.xmult) or not small_integer(a.yorick_discards) or
        a.yorick_discards<1 or a.yorick_discards>a.extra.discards or
        a.extra.xmult<1 or a.x_mult+10*a.extra.xmult>1048576 then return nil end
      physical_yoricks=physical_yoricks+1
    end
  end
  if physical_yoricks==0 then return nil end
  for _,c in ipairs(s.consumeables) do
    if not plain(c.ability) or type(c.id)~='string' or c.id=='' or ids[c.id] or c.unknown or c.face_down or c.facing=='back' or
      not pair_consumables[c.key] or (c.ability or {}).set~=pair_consumables[c.key] then return nil end
    ids[c.id]=c
  end
  local spare=#s.hand-#clear.indices
  return {max_count=math.min(5,s.hand_limit,spare),deck_count=#s.deck,left=left}
end
local function next_yorick(a,count)
  local left,x,growth=a.yorick_discards,a.x_mult,0
  for _=1,count do
    if left<=1 then left=a.extra.discards;x=x+a.extra.xmult;growth=growth+a.extra.xmult
    else left=left-1 end
  end
  return left,x,growth
end
local function pair_value(s,state,first_count,scope,profile,first_utility,first_cost,copy_credit)
  if not scope then return nil end
  local best
  for count=1,scope.max_count do
    -- Both ordinary draws refill the same hand. This bound is independent of
    -- which finite-population cards appear and forbids recycling discards.
    if scope.deck_count>=first_count+count then
      local utility,growth,endpoints=0,0,{}
      for i,j in ipairs(state.jokers) do if j.key=='j_yorick' then
        local a=j.ability;local left,x,gain=next_yorick(a,count)
        local early=s.teacher_profile=='perkeo_yorick_win_v1' and num(s.ante,1)<=3 and num(a.x_mult,1)<=4
        utility=utility+(early and 120 or 80)*count/a.extra.discards*a.extra.xmult/math.max(1,a.x_mult)*math.min(1,profile.horizon/6)*(copy_credit[i] or 1)
        growth=growth+gain
        endpoints[#endpoints+1]={id=j.id,discard_count=left,x_mult=x,physical=true}
      end end
      -- The lookahead exists only to cross a threshold that the first action
      -- alone misses. A distant two-step partial-progress weight is unchanged.
      local first_growth=0
      for i,j in ipairs(s.jokers) do if j.key=='j_yorick' then first_growth=first_growth+(state.jokers[i].ability.x_mult-j.ability.x_mult) end end
      if growth>0 and first_growth==0 then
        local m=s.modifiers or {};local loss=num(m.discard_cost)
        local after_dollars=state.dollars-loss
        if after_dollars>=0 then
          local cash=loss+num(m.money_per_discard)
          if not m.no_interest then
            local cap=num(s.interest_cap,25)
            cash=cash+math.max(0,math.floor(math.min(cap,math.max(0,state.dollars))/5)-
              math.floor(math.min(cap,math.max(0,after_dollars))/5))*num(s.interest_amount,1)
          end
          local second_cost=cash*3+weight('growth_action_cost',4)
          utility=utility+15*growth
          local merit=(first_utility+utility)*weight('growth_utility_scale',1)-first_cost-second_cost
          if finite(merit) and merit>0 and (not best or merit>best.merit) then
            best={scope='two_discard_neutral_population_threshold_v1',complete=true,merit=merit,
              first_count=first_count,second_count=count,total_discarded=first_count+count,
              guaranteed_second_capacity=scope.max_count,guaranteed_draws=first_count+count,
              remaining_deck=scope.deck_count-first_count-count,remaining_discards=scope.left-2,
              first_utility=first_utility,second_utility=utility,first_cost=first_cost,second_cost=second_cost,
              future_yoricks=endpoints,future_dollars=after_dollars,second_threshold_growth=growth,
              score_scope='retained physical clear floor; neutral future held cards and monotone physical Yorick growth',
              future_action_dispatched=false,requires_fresh_observation=true}
          end
        end
      end
    end
  end
  return best
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
  local exhaust=options.exhaust_discards==true and s.teacher_profile=='perkeo_yorick_win_v1'
  local evaluations=0
  local cap=math.min(12,math.max(0,math.floor(num(options.max_evaluations,12))))
  local diagnostics={bounded_growth=true,max_evaluations=cap,candidates=0,reasons={},exhaust_discards=exhaust}
  local function stop(reason)
    diagnostics.reasons[#diagnostics.reasons+1]=reason
    if diagnostics.death_fishing then diagnostics.death_fishing.reason=reason;diagnostics.death_fishing.status='not_admitted' end
    return nil,evaluations,diagnostics
  end
  if not plain(s) or not bounded_plain(s) then return stop('The complete input for investment sorting and transitions exceeds its plain finite bounds.') end
  for _,key in ipairs({'hand','deck','jokers','playing_cards','consumeables','hands','modifiers','current_round','blind'}) do
    if s[key]~=nil and not plain(s[key]) then return stop('The investment state has malformed '..key..'.') end
  end
  if not dense(s.hand,12) or not dense(s.deck or {},200) or not dense(s.playing_cards or {},256) or
    not dense(s.consumeables or {},64) or not dense(s.jokers or {},128) then
    return stop('The complete investment arrays exceed their bounds or are not dense.')
  end
  for i,c in ipairs(s.consumeables or {}) do if c.key=='c_death' and not c.debuff then
    diagnostics.death_fishing={schema=1,consumable_index=i,status='not_admitted',reason='public_population_unavailable',
      attempted=false,complete=false,distribution_comparisons=0,positive_comparisons=0,
      scope='public_distribution_bounded_discard_shortlist'};break
  end end
  local scorer,strategy=modules.scoring,modules.strategy
  if not scorer or not strategy or not strategy.build_profile or not known_clear or not known_clear.indices then return stop('No verified finishing plan.') end
  local remaining=math.max(1,num((s.blind or {}).chips)-num(s.chips))
  -- Admission and the exact retained-finish proof use the same safety floor.
  -- A larger entry margin would suppress a complete safe discard comparison.
  local margin=exhaust and 1 or 1.05
  if not reliable(known_clear) or num(known_clear.score)<remaining*margin then return stop('The known clear has insufficient supported score for this discard comparison.') end
  local profile=strategy.build_profile(s)
  if not exhaust and (profile.final or num(profile.horizon)<=0) then return stop('No remaining development horizon.') end
  local round=s.current_round or {}
  local unused_setup=num(s.hands_played,round.hands_played)+num(s.discards_used,round.discards_used)==0
  if #s.hand>12 or #s.hand<2 or #(s.deck or {})>200 or cap<=0 then return stop('The bounded investment check is unavailable.') end
  if num((s.modifiers or {}).flipped_cards)>0 then return stop('Future target visibility is uncertain.') end
  local function score(state,indices)
    if evaluations>=cap then return nil end
    evaluations=evaluations+1
    if exhaust and scorer.lower_bound then return scorer.lower_bound(state,indices) end
    return scorer.score(state,indices)
  end
  -- Fast-clear conservation can retain a five-card proposal even when one
  -- physical card already clears. Spend at most six of this same allowance
  -- finding a smaller supported anchor, reserving work for the discard proof.
  if exhaust and #known_clear.indices>1 then
    local original=known_clear
    local prepared,reward
    if modules.finish_rewards and modules.finish_rewards.prepare and modules.finish_rewards.value then
      prepared=modules.finish_rewards.prepare(s,strategy)
      reward=modules.finish_rewards.value(s,original,prepared)
    end
    local population=modules.search and modules.search.population_profile and modules.search.population_cost
    local population_profile=population and modules.search.population_profile(s)
    local old_population=population and population(s,original,population_profile) or original.population_cost
    for slot=1,math.min(#original.indices,6,math.max(0,cap-1)) do
      -- A subset cannot newly consume a Gold/Blue card held by the original.
      local i=original.indices[slot]
      local candidate=score(s,{i})
      if candidate then candidate.indices={i} end
      local new_population=candidate and population and population(s,candidate,population_profile)
      local new_reward=candidate and prepared and modules.finish_rewards.value(s,candidate,prepared)
      local resources=(old_population==nil or new_population~=nil and finite(old_population) and
          finite(new_population) and new_population<=old_population) and
        (reward==nil and num(original.finish_reward)==0 or reward~=nil and new_reward~=nil and
          finite(reward) and finite(new_reward) and new_reward>=reward)
      if reliable(candidate) and num(candidate.score)>=remaining and
          resources and num(candidate.glass_loss)<=num(original.glass_loss) and
          (not modules.search or not modules.search.arm_cost or
            modules.search.arm_cost(s,candidate.hand)<=modules.search.arm_cost(s,original.hand)) then
        if not drawn_hazard(s,candidate) then
          known_clear=candidate;diagnostics.smaller_anchor=true;diagnostics.anchor_cards=1;break
        end
      end
    end
  end
  local hazard=drawn_hazard(s,known_clear);if hazard then return stop(hazard) end
  local original_glass=0
  for _,exposure in ipairs(known_clear.glass_exposure or {}) do original_glass=original_glass+num(exposure.probability) end
  if not known_clear.glass_exposure then original_glass=num(known_clear.glass_loss) end
  local reserve={};for _,i in ipairs(known_clear.indices) do reserve[i]=true end
  local spare={};for i=1,#s.hand do if not reserve[i] then spare[#spare+1]=i end end
  if #spare==0 then return stop('Every held card belongs to the finishing plan.') end
  local best
  local function accept(action,state,indices,merit,title,lines,metadata)
    -- Blue Joker depends on count alone. Charge every replacement draw before
    -- proving the retained clear. Do not pick or add hypothetical drawn cards.
    local proof=state
    local blue=false
    for _,j in ipairs(state.jokers or {}) do if not j.debuff and name(j)=='Blue Joker' then blue=true end end
    if blue then
      if action.kind~='discard' then return end
      local draws=draw_count(s,state)
      proof=copy(state);proof.deck={}
      -- Values in this unordered population are not scored as known draws.
      for i=1,math.max(0,#(state.deck or {})-draws) do proof.deck[i]=state.deck[i] end
      metadata.blue_joker_draw_cost={draws=draws,remaining_deck=#proof.deck}
    end
    local finish=score(proof,indices)
    if not reliable(finish) or num(finish.score)<math.max(1,num((state.blind or {}).chips)-num(state.chips))*margin then return end
    -- Draws are not required for this score; permitted held effects can only
    -- add to it. Check the actual final hand after every real action/draw.
    if num(finish.glass_loss)>original_glass+0.000001 then return end
    if modules.search and modules.search.arm_cost and modules.search.arm_cost(state,finish.hand)>
      modules.search.arm_cost(s,known_clear.hand) then return end
    finish.indices=list(indices)
    if not best or merit>best.merit or exhaust and merit==best.merit and #action.indices>#best.action.indices then
      best={action=action,title=title,lines=lines,warnings={},play=finish,merit=merit,growth=metadata}
      best.growth.retained_original_indices=list(known_clear.indices)
    end
  end

  local yoricks,burnt={},false
  local death_option
  if s.teacher_profile=='perkeo_yorick_win_v1' and modules.consumables and
      modules.consumables.apply and strategy.development_gain and strategy.preservation_cost and
      #(s.playing_cards or {})>0 and #(s.deck or {})>0 then
    local public,ids=true,{}
    for _,c in ipairs(s.playing_cards) do
      if c.id==nil or ids[c.id] or c.unknown or c.identity_redacted then public=false end
      if c.id~=nil then ids[c.id]=true end
    end
    local seen={}
    for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do
      if c.id==nil or not ids[c.id] or seen[c.id] or c.unknown or c.identity_redacted or
          (c.ability or {}).forced_selection then public=false end
      if c.id~=nil then seen[c.id]=true end
    end end
    for _,c in ipairs(s.hand) do if c.face_down then public=false end end
    if public then for index,owned in ipairs(s.consumeables or {}) do
      if owned.key=='c_death' and not owned.debuff then
        -- Validate the actual owned type/capacity/metadata on a legal pair.
        local projected=modules.consumables.apply(s,index,{1,2})
        if projected then
          local loss,_,last=strategy.preservation_cost(s,projected,index)
          if diagnostics.death_fishing then diagnostics.death_fishing.reason=last and 'inventory_hold' or 'invalid_preservation_cost' end
          if not last and finite(loss) then
            local function gain(recipient,source)
              local after={hand={}};after.hand[recipient]=source
              return strategy.development_gain(s,after,{recipient},profile)-loss-4
            end
            local now=0
            for i in ipairs(s.hand) do for j,c in ipairs(s.hand) do if i~=j and not c.debuff then
              now=math.max(now,gain(i,c))
            end end end
            death_option={index=index,gain=gain,now=now}
            diagnostics.death_fishing.status='considered';diagnostics.death_fishing.attempted=true
            diagnostics.death_fishing.reason='no_better_source';diagnostics.death_fishing.use_now_utility=now
            break
          end
        end
      end
    end end
  end
  -- Exact expected best-source value under an unordered public finite deck.
  -- Integrate its maximum using hypergeometric tail probabilities, so every
  -- possible draw has the same hold/use-now reference. No sampled prefix or
  -- hidden next-card order is consulted. Misses retain their actual utility.
  local function death_draw_value(state,removed)
    if not death_option then return 0 end
    local draws=draw_count(s,state);if draws<1 then return 0 end
    local best=0
    for recipient in ipairs(s.hand) do if not removed[recipient] and not reserve[recipient] then
      local held=0
      for source,c in ipairs(s.hand) do if source~=recipient and not removed[source] and not c.debuff then
        held=math.max(held,death_option.gain(recipient,c))
      end end
      local values={}
      for _,c in ipairs(s.deck) do values[#values+1]=c.debuff and 0 or math.max(0,death_option.gain(recipient,c)) end
      table.sort(values)
      local expected,previous=held,held
      for i,value in ipairs(values) do if value>previous then
        expected=expected+(value-previous)*hit_probability(#values,#values-i+1,draws)
        previous=value
      end end
      best=math.max(best,expected-death_option.now)
    end end
    return best,{schema=1,consumable_index=death_option.index,draws=draws,population=#s.deck,
      use_now_utility=death_option.now,expected_improvement=best,
      complete_public_distribution=true,guaranteed_source=false}
  end
  local yorick_positions={}
  for _,j in ipairs(s.jokers or {}) do if not j.debuff then
    if name(j)=='Yorick' then yoricks[#yoricks+1]=j
    elseif name(j)=='Burnt Joker' and num(s.discards_used,round.discards_used)==0 then burnt=true end
  end end
  if scorer.after_discard and num(s.discards_left,round.discards_left)>0 and (exhaust or #yoricks>0 or burnt or death_option) then
    -- Progress belongs only to physical Yoricks, while the current scoring row
    -- may apply the same multiplier more than once. A bounded same-play rescore
    -- measures that row's marginal effect, including intervening additive Mult.
    -- It changes heuristic utility only, never counters, the reserved finish,
    -- future copy arrangements, or the twelve-call allowance.
    local copy_credit={}
    diagnostics.yorick_copy_credit={scope='current_visible_reserved_play',entries={},evaluations=0}
    local credit_diagnostics=diagnostics.yorick_copy_credit
    local exact_baseline=known_clear.legal==true and known_clear.uncertain==false and
      known_clear.bound_kind==nil and known_clear.conservative~=true and
      finite(known_clear.score) and known_clear.score>0
    for _,message in ipairs(known_clear.warnings or {}) do
      if message:find('Unmodeled',1,true) then exact_baseline=false end
    end
    local row_ok=exact_baseline and additive_order_safe(s,known_clear) and
      s.ordering_safe~=false and not s.jokers_shuffling and not (s.blind or {}).shuffle_pending
    for i,j in ipairs(s.jokers) do
      if j.key=='j_yorick' then yorick_positions[j]=i end
      local a=j.ability or {}
      if j.unknown or j.identity_unknown or j.identity_redacted or j.concealed or j.face_down or
        j.facing=='back' or j.getting_sliced or a.perma_debuff or
        a.perishable and (not small_integer(a.perish_tally) or a.perish_tally<=1) then row_ok=false end
    end
    if not exhaust and row_ok and evaluations+1<cap then
      local counts={}
      local function resolve(i,seen)
        local j=s.jokers[i]
        if not j or j.debuff or seen[i] then return nil end
        seen[i]=true
        if j.key=='j_blueprint' or j.key=='j_brainstorm' then
          local target=j.key=='j_blueprint' and i+1 or 1
          if not s.jokers[target] or s.jokers[target].blueprint_compat~=true then return nil end
          return resolve(target,seen)
        end
        return i
      end
      for i in ipairs(s.jokers) do local target=resolve(i,{})
        if target and s.jokers[target].key=='j_yorick' then counts[target]=(counts[target] or 0)+1 end
      end
      for i,j in ipairs(s.jokers) do
        local a=j.ability or {};local extra=type(a.extra)=='table' and a.extra or {}
        if j.key=='j_yorick' and (counts[i] or 0)>1 and evaluations+1<cap and
          finite(a.x_mult) and a.x_mult>=1 and finite(extra.xmult) and extra.xmult>0 and
          a.x_mult+extra.xmult<=1048576 then
          local upgraded=copy(s);upgraded.jokers=list(s.jokers);upgraded.jokers[i]=copy(j)
          upgraded.jokers[i].ability=copy(a);upgraded.jokers[i].ability.x_mult=a.x_mult+extra.xmult
          local endpoint=score(upgraded,known_clear.indices)
          credit_diagnostics.evaluations=credit_diagnostics.evaluations+1
          local qualified=endpoint and endpoint.legal==true and endpoint.uncertain==false and
            endpoint.bound_kind==nil and endpoint.conservative~=true and finite(endpoint.score)
          for _,message in ipairs(endpoint and endpoint.warnings or {}) do
            if message:find('Unmodeled',1,true) then qualified=false end
          end
          if qualified then
            local relative=(endpoint.score-known_clear.score)/known_clear.score
            local factor=math.max(1,math.min(counts[i],relative/(extra.xmult/a.x_mult)))
            if finite(factor) then
              copy_credit[i]=factor
              credit_diagnostics.entries[#credit_diagnostics.entries+1]={physical_index=i,physical_id=j.id,
                scoring_applications=counts[i],factor=factor,baseline_score=known_clear.score,
                upgraded_score=endpoint.score,physical_increment=extra.xmult,
                score_calls=1,heuristic=true,future_order_assumed=false}
            end
          end
        end
      end
    end
    local pair=pair_scope(s,known_clear)
    diagnostics.two_discard_scope=pair and 'complete neutral finite population' or 'unqualified'
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
      if not state and exhaust and #diagnostics.reasons<2 and type(effects)=='string' then
        diagnostics.reasons[#diagnostics.reasons+1]=effects
      end
      if state then
        local utility=0
        for _,j in ipairs(yoricks) do
          local a=j.ability or {};local extra=type(a.extra)=='table' and a.extra or {}
          local early=s.teacher_profile=='perkeo_yorick_win_v1' and num(s.ante,1)<=3 and num(a.x_mult,1)<=4
          utility=utility+(early and 120 or 80)*#indices/math.max(1,num(extra.discards,23))*num(extra.xmult,1)/math.max(1,num(a.x_mult,1))*math.min(1,profile.horizon/6)*(copy_credit[yorick_positions[j]] or 1)
        end
        utility=utility+15*num(effects.yorick_growth)
        if effects.burnt_hand and modules.search and modules.search.hand_growth_value then
          local category=effects.burnt_hand
          if growth_values[category]==nil then growth_values[category]=modules.search.hand_growth_value(s,category,profile) end
          utility=utility+10*growth_values[category]*num(effects.burnt_levels)*math.min(1,profile.horizon/3)
        end
        local cost=cash_cost(s,state,false,indices)
        local removed={};for _,i in ipairs(indices) do removed[i]=true end
        local source_value,source_receipt=death_draw_value(state,removed)
        if source_receipt and diagnostics.death_fishing then
          local d=diagnostics.death_fishing
          d.distribution_comparisons=d.distribution_comparisons+1
          d.best_expected_improvement=math.max(d.best_expected_improvement or 0,source_value)
          if source_value>0 then d.positive_comparisons=d.positive_comparisons+1;d.reason='cost_or_retained_clear' end
        end
        utility=utility+source_value
        local merit=utility*weight('growth_utility_scale',1)-cost
        local threshold=pair_value(s,state,#indices,pair,profile,utility,cost,copy_credit)
        if threshold and threshold.merit>merit then merit=threshold.merit else threshold=nil end
        local cash_safe=not exhaust or num(state.dollars)>=num(s.dollars)
        if exhaust and not cash_safe then diagnostics.reasons[#diagnostics.reasons+1]='Discarding spends current cash.' end
        if cash_safe and (exhaust or merit>0) then candidates[#candidates+1]={state=state,effects=effects,indices=indices,merit=merit,threshold=threshold,
          death_source=source_value>0 and source_receipt or nil} end
      end
    end
    table.sort(candidates,function(a,b)
      if a.merit==b.merit then
        if exhaust and #a.indices~=#b.indices then return #a.indices>#b.indices end
        return table.concat(a.indices,',')<table.concat(b.indices,',')
      end
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
      local purpose=c.death_source and 'find a stronger Death source' or c.effects.burnt_hand and ('level '..c.effects.burnt_hand) or #yoricks>0 and 'grow Yorick' or 'use remaining discards'
      accept({kind='discard',area='hand',indices=list(c.indices)},c.state,indices,c.merit,
        c.threshold and ('Discard '..#c.indices..' toward a guaranteed Yorick threshold') or 'Discard '..#c.indices..' to '..purpose,
        {c.threshold and ('The same physical clear survives two discards of '..#c.indices..' then '..c.threshold.second_count..
            ' cards for every remaining draw; both action and cash costs are charged.') or
            'The retained cards still clear without a favorable draw; this discard develops later blinds.',
          c.threshold and 'Only this discard is recommended. Refresh after the actual draw before spending the next discard.' or
          #yoricks>0 and 'Refresh after each draw. Use more full Yorick discards while the clear and resource tradeoff remain safe.' or
            'Burnt upgrades the actual first-discard hand; its value depends on the deck, levels and scoring support.'},
        {kind='discard',effects=c.effects,utility=c.merit,remaining_discards=c.state.discards_left,exhaust_discards=exhaust,
          repeatable_yorick=#yoricks>0,first_burnt_discard=burnt,two_discard_threshold=c.threshold,death_source=c.death_source})
    end
  end

  if not exhaust and unused_setup and scorer.after_play and strategy.development_gain and strategy.preservation_cost and
    (s.teacher_profile~='perkeo_yorick_win_v1' or death_option) and
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
  if exhaust and not best and #diagnostics.reasons==0 then
    diagnostics.reasons[1]=evaluations>=cap and 'The bounded discard proof allowance is exhausted.' or
      'No shortlisted legal discard preserved the supported clearing score and held resources.'
  end
  if exhaust and best then
    best.lines={'Spend a remaining discard while the retained cards still have a supported clearing score.',
      'Refresh after the actual draw. Continue using discards while that proof remains valid.'}
  end
  local fishing=diagnostics.death_fishing
  if fishing and fishing.attempted then
    fishing.evaluations=evaluations;fishing.complete=evaluations<cap
    fishing.selected=best and best.action.kind=='discard' and best.growth and best.growth.death_source~=nil or false
    fishing.status=fishing.selected and 'selected' or evaluations>=cap and 'bounded_work_exhausted' or 'declined'
    fishing.reason=fishing.selected and 'stronger_public_source_expectation' or evaluations>=cap and 'incomplete_work' or fishing.reason
    if num(s.discards_left,round.discards_left)<=0 then fishing.reason='no_discards' end
  end
  return best,evaluations,diagnostics
end
return M
