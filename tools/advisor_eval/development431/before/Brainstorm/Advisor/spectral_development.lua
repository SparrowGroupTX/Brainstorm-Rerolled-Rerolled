-- Exact deterministic seal/copy mutations. Generated Tarot/Planet identities
-- remain outside this transition; their future usefulness is heuristic only.
local M={}
local function num(v,d) return type(v)=='number' and v or (d or 0) end
local function clone(v,seen)
 if type(v)~='table' then return v end;seen=seen or {};if seen[v] then return seen[v] end
 local t={};seen[v]=t;for k,x in pairs(v) do if type(x)~='function' then t[k]=clone(x,seen) end end;return t
end
local effects={c_talisman='Gold',c_deja_vu='Red',c_trance='Blue',c_medium='Purple',c_cryptid='copy'}
local function enhancement(c) return c.enhancement or (c.key and c.key:sub(1,2)=='m_' and c.key) or 'c_base' end
local function name(j) return (j.ability or {}).name or j.name end
local function has(s,key,n)
 for _,j in ipairs(s.jokers or {}) do if not j.debuff and (j.key==key or name(j)==n) then return true end end
end
local function refresh(state)
 local steel,stone,enhanced=0,0,0
 for _,c in ipairs(state.playing_cards) do
  local e=enhancement(c);steel=steel+(e=='m_steel' and 1 or 0);stone=stone+(e=='m_stone' and 1 or 0);enhanced=enhanced+(e~='c_base' and 1 or 0)
 end
 for _,j in ipairs(state.jokers or {}) do
  local a=j.ability or {};j.ability=a
  if j.key=='j_steel_joker' or name(j)=='Steel Joker' then a.steel_tally=steel
  elseif j.key=='j_stone' or name(j)=='Stone Joker' then a.stone_tally=stone
  elseif j.key=='j_drivers_license' or name(j)=="Driver's License" then a.driver_tally=enhanced end
 end
end
function M.apply(state,before,d,targets,owned)
 local effect=effects[d.key];local target=targets[1];local source=state.hand[target]
 if not effect or #targets~=1 or not source then return nil,'Invalid targeted Spectral action.' end
 local ids={};for _,c in ipairs(before.playing_cards or {}) do
  if not c.id or ids[c.id] then return nil,'Spectral development requires unique full-population identities.' end;ids[c.id]=true
 end
 if not source.id or not ids[source.id] then return nil,'Spectral target is absent from the full population.' end
 local extra=(owned and owned.ability or {}).extra
 if effect~='copy' then
  if extra~=nil and extra~=effect then return nil,'Modified Spectral seal is not modeled.' end
  source.seal=effect
  for _,area in ipairs({'playing_cards','deck','discard','play'}) do for i,c in ipairs(state[area] or {}) do
   if c.id==source.id then state[area][i]=source end
  end end
 else
  if extra~=nil and extra~=2 then return nil,'Modified Cryptid copy count is not modeled.' end
  if #state.hand+2>20 then return nil,'Cryptid would exceed the bounded hand-size model.' end
  local a=source.ability or {}
  if num(a.h_size)~=0 or num(a.d_size)~=0 or source.edition=='negative' or type(source.edition)=='table' and source.edition.negative then
   return nil,'Copied playing-card resource modifiers are not modeled.'
  end
  if state.hand==state.playing_cards then
   local hand={};for i,c in ipairs(state.hand) do hand[i]=c end;state.hand=hand
  end
  for i=1,2 do
   local new=clone(source)
   local suffix=1;local id
   repeat id='advisor-copy:'..source.id..':'..suffix;suffix=suffix+1 until not ids[id]
   ids[id]=true;new.id=id;new.face_down=false;new.shattered=nil;new.removed=nil
   new.base=clone(source.base or {});new.base.times_played=0;new.base.original_value=nil
   new.base.suit_nominal_original=({Diamonds=0.001,Clubs=0.002,Hearts=0.003,Spades=0.004})[source.suit or new.base.suit]
   state.hand[#state.hand+1]=new;state.playing_cards[#state.playing_cards+1]=new
  end
  for _,j in ipairs(state.jokers or {}) do if not j.debuff and not j.getting_sliced and (j.key=='j_hologram' or name(j)=='Hologram') then
   j.ability=j.ability or {};j.ability.x_mult=num(j.ability.x_mult,1)+2*num(j.ability.extra,0.25)
  end end
  refresh(state)
 end
 return state
end
local function free_after_use(s,owned)
 local count=#(s.consumeables or {});local limit=num(s.consumable_limit,2)
 for _,c in ipairs(s.consumeables or {}) do if c==owned then
  count=count-1
  if c.edition=='negative' or type(c.edition)=='table' and c.edition.negative then limit=limit-1 end
  break
 end end
 return math.max(0,limit-count)
end
local function card_value(s,c,p,strategy)
 if strategy and strategy.target_value then return strategy.target_value(s,c,p.stats) end
 return (enhancement(c)~='c_base' and 25 or 0)+(c.seal and 25 or 0)
end
local function gain(s,c,owned,p,strategy,reserved)
 local effect=effects[owned.key];if not effect then return -1000 end
 local original=card_value(s,c,p,strategy)
 local r=num(c.rank,num((c.base or {}).id));local e=enhancement(c)
 if effect=='copy' then
  if #s.hand+2>20 then return -1000 end
  local average=0;for _,v in ipairs(s.playing_cards or {}) do average=average+card_value(s,v,p,strategy) end
  average=average/math.max(1,#(s.playing_cards or {}))
  local benefit=2*(original-average)
  if p.rank then benefit=benefit+(r==p.rank and 32 or -35) end
  if e=='m_steel' or e=='m_gold' or c.seal then benefit=benefit+12 end
  if e=='m_glass' and num((s.probabilities or {}).normal,1)>=num((c.ability or {}).extra,4) then benefit=benefit-22 end
  for _,j in ipairs(s.jokers or {}) do if not j.debuff then
   if j.key=='j_hologram' or name(j)=='Hologram' then benefit=benefit+65*2*num((j.ability or {}).extra,0.25)/math.max(1,num((j.ability or {}).x_mult,1)) end
   if j.key=='j_erosion' or name(j)=='Erosion' then benefit=benefit-16 end
  end end
  return benefit
 end
 if c.seal==effect then return -1000 end
 local changed=clone(c);changed.seal=effect
 local benefit=card_value(s,changed,p,strategy)-original
 local on_plan=not p.rank or r==p.rank
 if effect=='Red' then
  if e=='m_steel' or e=='m_gold' or r==13 and has(s,'j_baron','Baron') then benefit=benefit+12
  elseif on_plan then benefit=benefit+8 else benefit=benefit*0.4 end
 elseif effect=='Blue' then
  -- Consuming a Negative card also removes its granted slot. Full inventories
  -- cannot be credited with a Planet merely because Trance is being spent.
  if free_after_use(s,owned)<1 then return -1000 end
  if reserved then benefit=benefit-20 else benefit=benefit+10 end
  if p.rank and r~=p.rank then benefit=benefit+8 end
 elseif effect=='Purple' then
  if free_after_use(s,owned)<1 or num((s.round_resets or {}).discards,num(s.discards_left,3))<=0 then return -1000 end
  benefit=benefit+(on_plan and -12 or 12)-math.max(0,original)*0.1
 elseif effect=='Gold' then benefit=benefit+(on_plan and 8 or -8) end
 if c.debuff or (c.ability or {}).perma_debuff then benefit=benefit*0.3 end
 return benefit
end
function M.targets(s,owned,p,baseline,strategy)
 if not effects[owned.key] or #(s.playing_cards or {})==0 then return nil end
 local reserved={};for _,i in ipairs(baseline and baseline.indices or {}) do reserved[i]=true end
 local best,merit=nil,0
 for i,c in ipairs(s.hand or {}) do
  local value=gain(s,c,owned,p,strategy,reserved[i])
  if value>merit then best,merit=i,value end
 end
 return best and {best} or nil
end
function M.gain(before,after,targets,p,strategy,owned,baseline)
 if p.horizon<=0 then return 0 end
 local reserved={};for _,i in ipairs(baseline and baseline.indices or {}) do reserved[i]=true end
 local target=targets[1]
 return gain(before,before.hand[target],owned,p,strategy,reserved[target])*math.min(1,p.horizon/3)
end
M.supports=function(key) return effects[key]~=nil end
return M
