-- Deterministic deck mutations and bounded development targets. All identities
-- are local to the detached snapshot; refresh after executing an action.
local M={}
local function num(v,d) return type(v)=='number' and v or (d or 0) end
local function enhancement(c) return c.enhancement or (c.key and c.key:sub(1,2)=='m_' and c.key) or 'c_base' end
local function name(j) return (j.ability or {}).name or j.name end
local function has(s,key,n)
  for _,j in ipairs(s.jokers or {}) do if not j.debuff and (j.key==key or name(j)==n) then return true end end
end
local function is_face(s,c)
  if c.debuff then return false end
  local r=num(c.rank,num((c.base or {}).id))
  return has(s,'j_pareidolia','Pareidolia') or enhancement(c)~='m_stone' and r>=11 and r<=13
end
local function validate_population(s,targets)
  if not s.playing_cards or #s.playing_cards==0 then return nil,'Deck development requires the complete playing-card population.' end
  local ids={}
  for _,c in ipairs(s.playing_cards) do
    if not c.id or ids[c.id] then return nil,'Deck development requires unique playing-card identities.' end
    ids[c.id]=true
  end
  for _,i in ipairs(targets) do
    local c=s.hand[i]
    if not c or not c.id or not ids[c.id] then return nil,'Deck development target is missing from the full population.' end
  end
  return true
end
local function refresh_tallies(s)
  local counts={steel=0,stone=0,enhanced=0}
  for _,c in ipairs(s.playing_cards or {}) do
    local e=enhancement(c)
    if e=='m_steel' then counts.steel=counts.steel+1 end
    if e=='m_stone' then counts.stone=counts.stone+1 end
    if e~='c_base' then counts.enhanced=counts.enhanced+1 end
  end
  for _,j in ipairs(s.jokers or {}) do
    local a=j.ability or {}; j.ability=a
    if j.key=='j_steel_joker' or name(j)=='Steel Joker' then a.steel_tally=counts.steel
    elseif j.key=='j_stone' or name(j)=='Stone Joker' then a.stone_tally=counts.stone
    elseif j.key=='j_drivers_license' or name(j)=="Driver's License" then a.driver_tally=counts.enhanced end
  end
end
function M.apply(state,snapshot,d,targets,owned)
  local ok,reason=validate_population(snapshot,targets); if not ok then return nil,reason end
  if M.spectral and M.spectral.supports(d.key) then return M.spectral.apply(state,snapshot,d,targets,owned) end
  if d.kind~='remove' then return nil,'This deck mutation is not modeled.' end
  if d.key=='c_hanged_man' and snapshot.teacher_profile=='perkeo_yorick_win_v1' and
    #snapshot.playing_cards-#targets<28 then
    return nil,'Win-first Yorick needs at least 28 physical cards after Hanged Man.'
  end
  local removed,faces,glass={},0,0
  for _,i in ipairs(targets) do
    local c=snapshot.hand[i]; removed[c.id]=true
    if is_face(snapshot,c) then faces=faces+1 end
    if enhancement(c)=='m_glass' then glass=glass+1 end
    if c.shattered then return nil,'Already shattered target is not modeled.' end
  end
  -- using_consumeable runs before queued destruction. Glass Joker sees the
  -- highlighted Glass exactly once; Canio sees the original debuff/face state.
  for _,j in ipairs(state.jokers or {}) do if not j.debuff then
    local a=j.ability or {};j.ability=a
    if j.key=='j_caino' or name(j)=='Caino' then a.caino_xmult=num(a.caino_xmult,1)+faces*num(a.extra,1)
    elseif j.key=='j_glass' or name(j)=='Glass Joker' then a.x_mult=num(a.x_mult,1)+glass*num(a.extra,0.75) end
  end end
  for _,area in ipairs({'hand','playing_cards','deck','discard','play'}) do
    if state[area] then
      local filtered={};for _,c in ipairs(state[area]) do if not removed[c.id] then filtered[#filtered+1]=c end end
      state[area]=filtered
    end
  end
  refresh_tallies(state)
  return state
end
function M.remap_indices(before,after,indices)
  local positions={};for i,c in ipairs(after.hand or {}) do if c.id then positions[c.id]=i end end
  local out={}
  for _,i in ipairs(indices or {}) do
    local c=before.hand[i];local position=c and c.id and positions[c.id]
    if not position then return nil end
    out[#out+1]=position
  end
  return out
end
local function card_value(s,c,p,strategy)
  if strategy and strategy.target_value then return strategy.target_value(s,c,p.stats) end
  local r=num(c.rank,num((c.base or {}).id))
  return 8+math.min(r,10)*0.3+(c.seal and 18 or 0)+(enhancement(c)~='c_base' and 15 or 0)
end
local function removal_gain(s,c,p,strategy)
  -- Scarce future draws are a hard constraint before any heuristic growth value.
  local usable,break_exposure=0,0
  for _,card in ipairs(s.playing_cards or {}) do if not (card.ability or {}).perma_debuff then
    usable=usable+1
    if enhancement(card)=='m_glass' then
      break_exposure=break_exposure+math.min(1,math.max(0,num((s.probabilities or {}).normal,1)/math.max(0.000001,num((card.ability or {}).extra,4))))
    end
  end end
  if usable<=math.max(10,num(s.hand_size,8)+2) or break_exposure/math.max(1,usable)>=0.75 then return -1000 end
  local r=num(c.rank,num((c.base or {}).id))
  local value=card_value(s,c,p,strategy)
  local gain=14-value
  if p.rank then gain=gain+(r==p.rank and -35 or 24) end
  if p.hand=='Straight' or p.hand=='Straight Flush' then
    local count=(p.stats.ranks or {})[r] or 0
    gain=gain+(count<=1 and -35 or math.min(12,(count-2)*4))
  end
  for _,j in ipairs(s.jokers or {}) do if not j.debuff then
    local a=j.ability or {}
    if (j.key=='j_caino' or name(j)=='Caino') and is_face(s,c) then gain=gain+55*num(a.extra,1)/math.max(1,num(a.caino_xmult,1)) end
    if (j.key=='j_glass' or name(j)=='Glass Joker') and enhancement(c)=='m_glass' then gain=gain+32*num(a.extra,0.75)/math.max(1,num(a.x_mult,1)) end
    if j.key=='j_erosion' or name(j)=='Erosion' then gain=gain+math.min(16,num(a.extra,4)*2) end
  end end
  -- Do not destroy an irreplaceable copying/retrigger source for small growth.
  if c.seal or c.edition then gain=gain-15 end
  if enhancement(c)=='m_steel' or enhancement(c)=='m_gold' then gain=gain-15 end
  return gain
end
function M.targets(s,owned,p,baseline,strategy)
  if M.spectral and M.spectral.supports(owned.key) then return M.spectral.targets(s,owned,p,baseline,strategy) end
  if owned.key~='c_hanged_man' then return nil end
  if not validate_population(s,{}) then return nil end
  local reserved={};for _,i in ipairs(baseline and baseline.indices or {}) do reserved[i]=true end
  local ranked={}
  for i,c in ipairs(s.hand or {}) do if not reserved[i] then
    local gain=removal_gain(s,c,p,strategy)
    if gain>0 then ranked[#ranked+1]={index=i,gain=gain} end
  end end
  table.sort(ranked,function(a,b) return a.gain>b.gain or a.gain==b.gain and a.index<b.index end)
  local config=(owned.ability or {}).consumeable or {}
  local maximum=math.min(2,num(config.max_highlighted,2))
  if s.teacher_profile=='perkeo_yorick_win_v1' then
    maximum=math.min(maximum,#s.playing_cards-28)
  end
  local result={};for i=1,math.min(maximum,#ranked) do result[i]=ranked[i].index end
  if #result<math.max(1,num(config.min_highlighted,1)) then return nil end
  table.sort(result);return result
end
function M.gain(before,after,targets,p,strategy,owned,baseline)
  if owned and M.spectral and M.spectral.supports(owned.key) then return M.spectral.gain(before,after,targets,p,strategy,owned,baseline) end
  if p.horizon<=0 then return 0 end
  local gain=0
  for _,i in ipairs(targets or {}) do gain=gain+removal_gain(before,before.hand[i],p,strategy) end
  return gain*math.min(1,p.horizon/3)
end
M.supports=function(key) return key=='c_hanged_man' or M.spectral and M.spectral.supports(key) or false end
return M
