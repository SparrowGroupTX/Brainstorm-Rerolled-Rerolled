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
local function signatures(b,world,slot)
  local j=b.inventory[world[slot]];local out={}
  local function edition(card)
    local e=card.edition
    if e==nil then return true end
    if type(e)=='string' then e={[e]=true} end
    if type(e)~='table' then return false end
    if e.type~=nil and not ({foil=true,holo=true,polychrome=true,negative=true})[e.type] then return false end
    if e.foil then out[#out+1]={channel='chips',amount=50} end
    if e.holo then out[#out+1]={channel='mult',amount=10} end
    if e.polychrome then out[#out+1]={channel='x_mult',amount=1.5} end
    for k,v in pairs(e) do if k~='foil' and k~='holo' and k~='polychrome' and k~='negative' and k~='type' and v then return false end end
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
function M.advance_public(b,event)
  if not M.validate(b) or type(event)~='table' or event.epoch~=b.epoch or event.observed_complete~=true then return nil,'An observed completed public action in the current epoch is required.' end
  if not b.state_valid then return M.invalidate_values(b,b.value_gap) end
  if event.kind~='play' and event.kind~='discard' then return M.invalidate_values(b,'This public action has no qualified ability transition.') end
  if event.kind=='discard' and (not integer(event.discarded_count) or event.discarded_count<1 or event.discarded_count>5) then
    return M.invalidate_values(b,'The public discard count is unavailable.')
  end
  local out=copy(b)
  for _,j in ipairs(out.inventory) do
    if not own_signatures(j,true) then return M.invalidate_values(b,'This Joker has unqualified changes during public actions.') end
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
