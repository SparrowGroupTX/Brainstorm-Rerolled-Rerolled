-- Per-decision exact classification reuse. Callers supply detached immutable
-- states; every decision gets a fresh bounded cache. No global state or RNG.
local M={}
local suits={Spades=1,Hearts=2,Clubs=4,Diamonds=8}
local effects={['Stone Card']='m_stone',['Wild Card']='m_wild',['Bonus']='m_bonus',['Mult']='m_mult',
  ['Glass Card']='m_glass',['Steel Card']='m_steel',['Gold Card']='m_gold',['Lucky Card']='m_lucky'}
local function enhancement(c)
  return c.enhancement or (c.key and c.key:sub(1,2)=='m_' and c.key) or effects[(c.ability or {}).effect] or 'c_base'
end
local function list(v) local r={};for i,x in ipairs(v or {}) do r[i]=x end;return r end
local function copy(v) local r={};for k,x in pairs(v or {}) do r[k]=x end;return r end
function M.new(base,options)
  options=options or {}
  local max_entries=math.max(0,math.min(16384,math.floor(options.max_entries or 8192)))
  local entries,cache=0,{}
  local flags_cache=setmetatable({},{__mode='k'})
  local row_cache=setmetatable({},{__mode='k'})
  local classification_flags_cache=setmetatable({},{__mode='k'})
  local tokens=setmetatable({},{__mode='k'})
  local stats={score_calls=0,classify_calls=0,hits=0,misses=0,stored=0,capacity=max_entries,flag_builds=0,row_builds=0}
  local prepared={}
  prepared.row=function(jokers,builder)
    local found=row_cache[jokers]
    if not found then found=builder(jokers);row_cache[jokers]=found;stats.row_builds=stats.row_builds+1 end
    return found
  end
  prepared.classification_flags=function(snapshot)
    local row=snapshot.jokers or {}
    local f=classification_flags_cache[row]
    if not f then
      f={};local aliases={j_four_fingers='Four Fingers',j_shortcut='Shortcut',j_splash='Splash',j_smeared='Smeared Joker'}
      for _,j in ipairs(row) do if not j.debuff then
        local name=(j.ability or {}).name or j.name or aliases[j.key]
        if name then f[name]=true end
      end end
      classification_flags_cache[row]=f
    end
    return f
  end
  prepared.flags=function(jokers,builder)
    if not jokers then return builder(jokers) end
    local found=flags_cache[jokers]
    if not found then found=builder(jokers);flags_cache[jokers]=found;stats.flag_builds=stats.flag_builds+1 end
    return found
  end
  prepared.classify=function(snapshot,selected,raw)
    stats.classify_calls=stats.classify_calls+1
    -- The raw classifier supplies its exact flags through this cached builder.
    local f=prepared.classification_flags and prepared.classification_flags(snapshot) or nil
    if not f then return raw(snapshot,selected,prepared) end
    -- Five 9-bit card tokens plus the leading rule flags fit exactly in a Lua
    -- number (less than 2^49). Keep order and length in the key without building
    -- a table and string for every scored subset. Larger/non-vanilla rank
    -- inputs retain the raw classifier instead of risking numeric collisions.
    if #selected>5 then return raw(snapshot,selected,prepared) end
    local key=1+(f['Four Fingers'] and 1 or 0)+(f.Shortcut and 2 or 0)+(f.Splash and 4 or 0)
    for _,index in ipairs(selected) do
      local c=snapshot.hand[index]
      if not c then return raw(snapshot,selected,prepared) end
      local mode=f['Smeared Joker'] and 2 or 1
      local card_tokens=tokens[c]
      if not card_tokens then card_tokens={};tokens[c]=card_tokens end
      local token=card_tokens[mode]
      if not token then
        local e=enhancement(c);local stone=e=='m_stone'
        local r=c.rank or (c.base or {}).id;r=type(r)=='number' and r or 0
        if stone then r=0 end
        local suit=c.suit or (c.base or {}).suit
        local mask=stone and 0 or e=='m_wild' and not c.debuff and 15 or
          mode==2 and ((suit=='Hearts' or suit=='Diamonds') and 10 or 5) or (suits[suit] or 0)
        if r<0 or r>14 or r%1~=0 then return raw(snapshot,selected,prepared) end
        token=r*32+mask*2+(stone and 1 or 0);card_tokens[mode]=token
      end
      key=key*512+token
    end
    local found=cache[key]
    if found then
      stats.hits=stats.hits+1
      local scoring={};for i,pos in ipairs(found.scoring) do scoring[i]=selected[pos] end
      return found.category,scoring,found.contains
    end
    stats.misses=stats.misses+1
    local category,scoring,contains=raw(snapshot,selected,prepared)
    if entries<max_entries then
      local positions={};for i,index in ipairs(selected) do positions[index]=i end
      local relative={};for i,index in ipairs(scoring) do relative[i]=positions[index] end
      entries=entries+1;stats.stored=entries
      cache[key]={category=category,scoring=relative,contains=contains}
    end
    return category,scoring,contains
  end
  local wrapped=setmetatable({},{__index=base})
  wrapped.score=function(s,selected,transition,floor_mode)
    stats.score_calls=stats.score_calls+1
    return base.score(s,selected,transition,floor_mode,prepared)
  end
  wrapped.classify=function(s,selected)
    local category,scoring,contains=base.classify(s,selected,prepared)
    return category,scoring,copy(contains)
  end
  if base.lower_bound then wrapped.lower_bound=function(s,selected)
    stats.score_calls=stats.score_calls+1
    return base.lower_bound(s,selected,prepared)
  end end
  if base.upper_bound then wrapped.upper_bound=function(s,selected)
    stats.score_calls=stats.score_calls+1
    return base.upper_bound(s,selected,prepared)
  end end
  return wrapped,function() return copy(stats) end,prepared
end
return M
