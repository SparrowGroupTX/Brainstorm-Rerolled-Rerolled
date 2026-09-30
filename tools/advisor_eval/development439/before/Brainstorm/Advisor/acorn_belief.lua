-- Detached public Joker-slot beliefs. No live object, hidden row or stable-ID lookup.
local M={}
local function finite(x) return type(x)=='number' and x==x and math.abs(x)<math.huge end
local function integer(x) return finite(x) and x>=0 and x%1==0 end
local forbidden={id=true,ID=true,sort_id=true,unique_val=true,position=true,slot=true,T=true,VT=true,
  facing=true,face_down=true,card=true,object=true,reference=true,config=true,children=true}
local function copy(x,strip,seen)
  if type(x)~='table' then if type(x)=='function' or type(x)=='userdata' or type(x)=='thread' then return nil end;return x end
  seen=seen or {};if seen[x] then error('Cyclic public belief input') end;seen[x]=true
  local out={};for k,v in pairs(x) do if not strip or not forbidden[k] then out[k]=copy(v,strip,seen) end end
  seen[x]=nil;return out
end
local function encode(x)
  local t=type(x)
  if t=='number' then if not finite(x) then error('Nonfinite public belief input') end;return 'n'..string.format('%.17g',x)..';' end
  if t=='string' then return 's'..#x..':'..x end
  if t=='nil' then return 'z' end
  if t=='boolean' then return x and 'b1' or 'b0' end
  if t~='table' then error('Unsupported public belief value') end
  local entries={};for k,v in pairs(x) do entries[#entries+1]=encode(k)..encode(v) end
  table.sort(entries);return 't'..#entries..':'..table.concat(entries)..'e'
end
local function permutation(a,n)
  if type(a)~='table' or #a~=n then return false end
  local seen={};for _,x in ipairs(a) do if not integer(x) or x<1 or x>n or seen[x] then return false end;seen[x]=true end
  return true
end
local function permutations(n,maximum)
  local size=1;for i=2,n do size=size*i end
  if size>maximum then return nil end
  local out,used,row={},{},{}
  local function walk(i)
    if i>n then out[#out+1]=copy(row);return end
    for k=1,n do if not used[k] then used[k]=true;row[i]=k;walk(i+1);used[k]=nil end end
  end
  walk(1);return out
end
function M.start(inventory,epoch,options)
  options=options or {}
  if options.public_before_shuffle~=true or epoch==nil or type(inventory)~='table' or #inventory<1 or #inventory>6 then
    return nil,'A complete public pre-shuffle inventory of one through six Jokers is required.'
  end
  for _,j in ipairs(inventory) do if type(j)~='table' or j.face_down or j.facing=='back' or j.unknown or j.concealed then
    return nil,'Concealed payloads cannot initialize public identity memory.' end end
  local clean=copy(inventory,true)
  for _,j in ipairs(clean) do if type(j.key)~='string' or type(j.ability)~='table' or j.unknown or j.concealed or j.pinned or j.ability.pinned then
    return nil,'Every pre-shuffle Joker must be public, described and unpinned.' end end
  local maximum=options.max_worlds or 720
  if not integer(maximum) or maximum<1 then return nil,'A finite positive whole world cap is required.' end
  table.sort(clean,function(a,b)return encode(a)<encode(b) end)
  local worlds=permutations(#clean,math.min(720,maximum))
  if not worlds then return nil,'The entire permutation family exceeds the belief limit.' end
  -- Equal public payloads are exchangeable; no physical identity survives this quotient.
  local unique,seen={},{}
  for _,world in ipairs(worlds) do
    local row={};for i,index in ipairs(world) do row[i]=clean[index] end
    local key=encode(row);if not seen[key] then seen[key]=true;unique[#unique+1]=world end
  end
  return {schema=1,epoch=epoch,inventory=clean,worlds=unique,complete=true,supported=true,
    observations={},state_valid=true,qualification='public_pre_shuffle_inventory',revision=0}
end
function M.validate(b)
  if type(b)~='table' or b.schema~=1 or b.complete~=true or b.supported~=true or
    type(b.inventory)~='table' or #b.inventory<1 or #b.inventory>6 or type(b.worlds)~='table' or
    #b.worlds<1 or #b.worlds>720 then return false end
  local seen={};for _,w in ipairs(b.worlds) do
    if not permutation(w,#b.inventory) then return false end
    local key=table.concat(w,',');if seen[key] then return false end;seen[key]=true
  end
  return true
end
local mult_keys={j_joker=true,j_jolly=true,j_zany=true,j_mad=true,j_crazy=true,j_droll=true}
local chips_keys={j_sly=true,j_wily=true,j_clever=true,j_devious=true,j_crafty=true}
local x_keys={j_duo=true,j_trio=true,j_family=true,j_order=true,j_tribe=true}
local suit_keys={j_greedy_joker=true,j_lusty_joker=true,j_wrathful_joker=true,j_gluttenous_joker=true}
local silent_keys={j_perkeo=true,j_burnt=true,j_egg=true}
local expected_names={j_joker='Joker',j_jolly='Jolly Joker',j_zany='Zany Joker',j_mad='Mad Joker',
  j_crazy='Crazy Joker',j_droll='Droll Joker',j_sly='Sly Joker',j_wily='Wily Joker',j_clever='Clever Joker',
  j_devious='Devious Joker',j_crafty='Crafty Joker',j_duo='The Duo',j_trio='The Trio',j_family='The Family',
  j_order='The Order',j_tribe='The Tribe',j_greedy_joker='Greedy Joker',j_lusty_joker='Lusty Joker',
  j_wrathful_joker='Wrathful Joker',j_gluttenous_joker='Gluttonous Joker',j_cavendish='Cavendish',
  j_yorick='Yorick',j_perkeo='Perkeo',j_burnt='Burnt Joker',j_egg='Egg',j_blueprint='Blueprint',j_brainstorm='Brainstorm',
  j_fortune_teller='Fortune Teller',j_swashbuckler='Swashbuckler',j_scary_face='Scary Face'}
local function own_signatures(j,state_valid)
  if j.debuff then return {} end
  local a=j.ability or {};local key=j.key;local out={}
  if expected_names[key]==nil or a.name~=expected_names[key] then return nil end
  local function add(channel,amount) if finite(amount) and amount>0 then out[#out+1]={channel=channel,amount=amount} end end
  if mult_keys[key] then add('mult',key=='j_joker' and a.mult or a.t_mult)
  elseif chips_keys[key] then add('chips',a.t_chips)
  elseif x_keys[key] then add('x_mult',a.x_mult)
  elseif suit_keys[key] then add('mult',type(a.extra)=='table' and a.extra.s_mult)
  elseif key=='j_cavendish' then add('x_mult',type(a.extra)=='table' and a.extra.Xmult)
  elseif key=='j_yorick' and state_valid then add('x_mult',a.x_mult)
  elseif key=='j_fortune_teller' or key=='j_swashbuckler' then
    -- Their displayed additive amount depends on public history/inventory.
    -- It is never guessed from the parsed popup; channel membership suffices.
    out[#out+1]={channel='mult',wildcard=true}
  elseif key=='j_scary_face' then add('chips',type(a.extra)=='number' and a.extra)
  elseif silent_keys[key] or key=='j_blueprint' or key=='j_brainstorm' then
  else return nil end -- Unqualified effects are wildcards, never contrary evidence.
  if not silent_keys[key] and key~='j_blueprint' and key~='j_brainstorm' and #out==0 then return nil end
  -- Modified generic main effects can still print on an otherwise silent Joker.
  add('mult',a.mult);add('mult',a.t_mult);add('chips',a.t_chips)
  if finite(a.x_mult) and a.x_mult>1 then add('x_mult',a.x_mult) end
  return out
end
-- These base-game abilities do not change on play/discard. Their score may
-- depend on the current hand/round, which the next public snapshot supplies,
-- but their rendered effects cannot safely identify a concealed slot.
local stable_ability_fields={bonus=true,d_size=true,effect=true,extra=true,extra_value=true,
  h_dollars=true,h_mult=true,h_size=true,h_x_mult=true,hands_played_at_create=true,
  mult=true,name=true,order=true,p_dollars=true,perma_bonus=true,rental=true,
  eternal=true,perishable=true,perish_tally=true,set=true,t_chips=true,t_mult=true,
  type=true,x_mult=true}
local checked_opaque_keys={j_green_joker=true,j_misprint=true,j_blackboard=true,
  j_smiley=true,j_supernova=true,j_campfire=true,j_hit_the_road=true}
local function stable_opaque_ability(j)
  local a=j.ability or {}
  for field,value in pairs(a) do
    if not stable_ability_fields[field] or type(value)=='table' and field~='extra' then return false end
  end
  if a.set~=nil and a.set~='Joker' or a.type~=nil and a.type~='' then return false end
  if checked_opaque_keys[j.key] then
    -- These remain opaque to popup filtering. In particular Green's rendered
    -- before-play increment precedes the completed-action inventory update.
    local defaults={bonus=0,d_size=0,h_dollars=0,h_mult=0,h_size=0,h_x_mult=0,
      p_dollars=0,perma_bonus=0,t_chips=0,t_mult=0,x_mult=1}
    local growing_x=j.key=='j_campfire' or j.key=='j_hit_the_road'
    for k,v in pairs(defaults) do if not (growing_x and k=='x_mult') and a[k]~=nil and a[k]~=v then return false end end
    if j.key~='j_green_joker' and a.mult~=nil and a.mult~=0 then return false end
    if growing_x then
      local road=j.key=='j_hit_the_road';local step=road and 0.5 or 0.25
      return a.name==(road and 'Hit the Road' or 'Campfire') and
        a.effect==(road and 'Jack Discard Effect' or nil) and a.extra==step and
        finite(a.x_mult) and a.x_mult>=1 and (a.x_mult-1)%step==0 and
        (a.hands_played_at_create==nil or integer(a.hands_played_at_create) and a.hands_played_at_create>=0)
    end
    if j.key=='j_blackboard' then return a.name=='Blackboard' and a.effect==nil and a.extra==3 end
    -- Neither ability changes during a play/discard. Smiley counts scoring
    -- faces; Supernova reads the hand's played count from each fresh public
    -- snapshot. Keep both opaque to popup identity filtering, including copies.
    if j.key=='j_smiley' then return a.name=='Smiley Face' and a.effect==nil and a.extra==5 end
    if j.key=='j_supernova' then return a.name=='Supernova' and a.effect=='Hand played mult' and a.extra==1 end
    local e=a.extra
    if type(e)~='table' or getmetatable(e) then return false end
    if j.key=='j_green_joker' then
      if a.name~='Green Joker' or a.effect~=nil or not integer(a.mult) or a.mult<0 or
        e.hand_add~=1 or e.discard_sub~=1 then return false end
      for k in pairs(e) do if k~='hand_add' and k~='discard_sub' then return false end end
      return true
    end
    if a.name~='Misprint' or a.effect~='Random Mult' or e.min~=0 or e.max~=23 then return false end
    for k in pairs(e) do if k~='min' and k~='max' then return false end end
    return true
  elseif j.key=='j_raised_fist' then
    return a.name=='Raised Fist' and a.effect=='Socialized Mult' and a.extra==nil
  elseif j.key=='j_banner' then
    return a.name=='Banner' and a.effect=='Discard Chips' and a.extra==30
  elseif j.key=='j_odd_todd' then
    return a.name=='Odd Todd' and a.effect=='Odd Card Buff' and a.extra==31
  elseif j.key=='j_card_sharp' then
    local extra=a.extra
    return a.name=='Card Sharp' and a.effect==nil and type(extra)=='table' and extra.Xmult==3 and
      next(extra,'Xmult')==nil and next(extra)== 'Xmult'
  elseif j.key=='j_arrowhead' then
    -- Spade scoring is handled by the scorer and may display on a playing
    -- card. It does not change this captured Joker ability on play/discard.
    return a.name=='Arrowhead' and a.effect=='' and a.extra==50
  elseif j.key=='j_red_card' then
    -- Red Card gains Mult on a booster skip, never on play/discard. Such an
    -- unmodelled action invalidates the concealed belief separately.
    return a.name=='Red Card' and a.effect==nil and a.extra==3 and
      finite(a.mult) and a.mult>=0
  elseif j.key=='j_mystic_summit' then
    local extra=a.extra
    -- Discards left is read from the fresh public round, not retained here.
    if a.name~='Mystic Summit' or a.effect~='No Discard Mult' or
      type(extra)~='table' or extra.mult~=15 or extra.d_remaining~=0 then return false end
    local count=0
    for key in pairs(extra) do
      if key~='mult' and key~='d_remaining' then return false end
      count=count+1
    end
    return count==2
  elseif j.key=='j_popcorn' then
    -- Its Mult changes only at round end, when this belief expires.
    return a.name=='Popcorn' and a.effect==nil and a.extra==4 and
      finite(a.mult) and a.mult>0 and a.mult<=20 and a.mult%4==0
  elseif j.key=='j_blue_joker' then
    -- Remaining deck size comes from each new public snapshot.
    return a.name=='Blue Joker' and a.effect==nil and a.extra==2
  elseif j.key=='j_bull' then
    -- Bull's coefficient is fixed. Its dollars come from each new public
    -- snapshot, including cash earned on the preceding completed play.
    return a.name=='Bull' and a.effect==nil and a.extra==2
  elseif j.key=='j_scholar' then
    -- Scholar has a fixed per-Ace effect and no play/discard ability counter.
    local extra=a.extra
    if a.name~='Scholar' or a.effect~='Ace Buff' or type(extra)~='table' or
      extra.chips~=20 or extra.mult~=4 then return false end
    local count=0
    for key in pairs(extra) do
      if key~='chips' and key~='mult' then return false end
      count=count+1
    end
    return count==2
  elseif j.key=='j_golden' then
    -- Payout happens after the round, never during a play or discard.
    return a.name=='Golden Joker' and a.effect=='Bonus dollars' and a.extra==4
  end
  return false
end
-- Validate the newly supported forms before the FIRST score too, not only
-- after a public action. Other inventory support remains with the scorer.
function M.public_edition(value)
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
function M.qualified_values(b)
  if not M.validate(b) or not b.state_valid then return false end
  local floor=false
  for _,j in ipairs(b.inventory) do
    if not M.public_edition(j.edition) then return false end
    if checked_opaque_keys[j.key] then
      if not stable_opaque_ability(j) then return false end
      floor=floor or j.key=='j_misprint' and not j.debuff
    end
  end
  return true,floor
end
local function signatures(b,world,slot)
  local j=b.inventory[world[slot]];local out={}
  local function edition(card)
    local admitted,e=M.public_edition(card.edition)
    if not admitted then return false end
    if e==nil then return true end
    if e.foil then out[#out+1]={channel='chips',amount=50} end
    if e.holo then out[#out+1]={channel='mult',amount=10} end
    if e.polychrome then out[#out+1]={channel='x_mult',amount=1.5} end
    return true
  end
  if not edition(j) then return nil end
  local used={}
  local function resolve(position)
    if used[position] then return {} end;used[position]=true
    local card=b.inventory[world[position]];if not card or card.debuff then return {} end
    if (card.ability or {}).name~=expected_names[card.key] then return nil end
    local to=card.key=='j_blueprint' and position+1 or card.key=='j_brainstorm' and 1
    if to then
      local target=b.inventory[world[to]]
      if not target or target.blueprint_compat==false then return {} end
      if target.blueprint_compat~=true then return nil end
      return resolve(to)
    end
    return own_signatures(card,b.state_valid==true)
  end
  local effects=resolve(slot);if not effects then return nil end
  for _,effect in ipairs(effects) do out[#out+1]=effect end
  return out
end
function M.observe(b,event,options)
  options=options or {}
  if not M.validate(b) then return nil,'The public belief is unavailable.' end
  local next_b=copy(b);local info={before=#b.worlds,after=#b.worlds,filtered=false}
  if type(event)~='table' or event.epoch~=b.epoch or event.qualified_render~=true or
    event.type~='rendered_status' or event.phase~='play' or not ({x_mult=true,mult=true,chips=true})[event.channel] or
    not finite(event.amount) or not integer(event.slot) or event.slot<1 or event.slot>#b.inventory then
    info.reason='Unqualified or stale visible event leaves every world possible.';return next_b,info
  end
  local worlds={}
  for _,world in ipairs(b.worlds) do
    local effects=signatures(b,world,event.slot);local compatible=effects==nil
    for _,effect in ipairs(effects or {}) do
      if effect.channel==event.channel then
        if effect.wildcard then compatible=true
        elseif options.render then
          local ok,rendered=pcall(options.render,effect.channel,effect.amount)
          if not ok or type(rendered)~='string' or type(event.text)~='string' then compatible=true
          elseif rendered==event.text then compatible=true end
        elseif effect.amount==event.amount then compatible=true end
      end
    end
    if compatible then worlds[#worlds+1]=copy(world) end
  end
  local log={slot=event.slot,channel=event.channel,amount=event.amount,text=event.text,color=copy(event.color),phase='play'}
  next_b.observations[#next_b.observations+1]=log;next_b.revision=next_b.revision+1
  if #worlds==0 then
    next_b.supported=false;next_b.complete=false;info.reason='Visible evidence contradicts the qualified model; no identity is guessed.'
    info.after=0;return next_b,info
  end
  next_b.worlds=worlds;info.after=#worlds;info.filtered=#worlds<#b.worlds
  info.reason=info.filtered and 'Only incompatible supported worlds were removed.' or 'The visible event remains ambiguous.'
  return next_b,info
end
function M.reorder(b,order,epoch)
  if not M.validate(b) or epoch~=b.epoch or not permutation(order,#b.inventory) then return nil,'A verified public slot permutation in the same epoch is required.' end
  local out=copy(b);out.worlds={}
  for k,w in ipairs(b.worlds) do out.worlds[k]={};for i,slot in ipairs(order) do out.worlds[k][i]=w[slot] end end
  out.revision=out.revision+1;return out
end
function M.invalidate_values(b,reason)
  if not M.validate(b) then return nil end
  local out=copy(b);out.state_valid=false;out.value_gap=reason or 'Public actions may have changed the captured abilities.';out.revision=out.revision+1
  return out
end
-- Only public playing-card snapshots enter this count. A Stone Jack has no
-- rank; a debuffed Jack cannot grow Road. Never inspect concealed payloads.
function M.needs_discarded_jacks(b)
  for _,j in ipairs(b and b.inventory or {}) do if j.key=='j_hit_the_road' and not j.debuff then return true end end
  return false
end
function M.discarded_jacks(cards,indices)
  local selected=indices or {};if not indices then for i=1,#(cards or {}) do selected[i]=i end end
  local total,seen=0,{}
  for _,i in ipairs(selected) do
    local c=cards and cards[i]
    if not c or seen[i] or c.face_down or c.facing=='back' or c.identity_redacted or c.unknown then return nil end
    seen[i]=true
    if c.debuff~=nil and type(c.debuff)~='boolean' then return nil end
    if not c.debuff and c.enhancement~='m_stone' then
      if not integer(c.rank) or c.rank<2 or c.rank>14 then return nil end
      if c.rank==11 then total=total+1 end
    end
  end
  return total
end
function M.advance_public(b,event)
  if not M.validate(b) or type(event)~='table' or event.epoch~=b.epoch or event.observed_complete~=true then return nil,'An observed completed public action in the current epoch is required.' end
  if not b.state_valid then return M.invalidate_values(b,b.value_gap) end
  if not M.qualified_values(b) then return M.invalidate_values(b,'Modified public ability cannot be advanced.') end
  if event.kind~='play' and event.kind~='discard' then return M.invalidate_values(b,'This public action has no qualified ability transition.') end
  if event.kind=='discard' and (not integer(event.discarded_count) or event.discarded_count<1 or event.discarded_count>5) then
    return M.invalidate_values(b,'The public discard count is unavailable.')
  end
  local out=copy(b)
  for _,j in ipairs(out.inventory) do
    if not own_signatures(j,true) and not stable_opaque_ability(j) then
      return M.invalidate_values(b,'This Joker has unqualified changes during public actions.')
    end
    if j.key=='j_yorick' and not j.debuff and event.kind=='discard' then
      local a=j.ability;local e=a.extra
      if type(e)~='table' or not integer(e.discards) or e.discards<1 or not finite(e.xmult) or e.xmult<0 or
        not integer(a.yorick_discards) or a.yorick_discards<1 or a.yorick_discards>e.discards or not finite(a.x_mult) then
        return M.invalidate_values(b,'Yorick public growth fields are unavailable.')
      end
      -- Physical growth occurs once per discarded card; copying Jokers do not repeat it.
      for _=1,event.discarded_count do
        if a.yorick_discards<=1 then a.yorick_discards=e.discards;a.x_mult=a.x_mult+e.xmult
        else a.yorick_discards=a.yorick_discards-1 end
      end
    end
    if j.key=='j_green_joker' and not j.debuff then
      -- One physical before-play/discard trigger, not one per card or copy.
      j.ability.mult=math.max(0,j.ability.mult+(event.kind=='play' and 1 or -1))
    end
    if j.key=='j_hit_the_road' and not j.debuff and event.kind=='discard' then
      if not integer(event.discarded_jacks) or event.discarded_jacks<0 or event.discarded_jacks>event.discarded_count then
        return M.invalidate_values(b,'The visible discarded Jack count is unavailable.')
      end
      j.ability.x_mult=j.ability.x_mult+0.5*event.discarded_jacks
    end
    -- Fortune Teller changes only with Tarot usage; Swashbuckler reads retained
    -- sale values; Scary Face is a fixed scoring effect. Ordinary play/discard
    -- changes none of these in this qualified row. Uses/sales/round changes are
    -- separately invalidated by the observer rather than refreshed from backs.
  end
  out.revision=out.revision+1;return out
end
M.copy=copy
M.permutations=permutations
M.signatures=signatures
return M
