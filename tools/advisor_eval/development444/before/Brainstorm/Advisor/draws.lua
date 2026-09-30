-- Detached replacement draws. A deck card's back is ordinary orientation, not
-- hidden information once drawn. Existing held cards retain their visibility.
local M={}
local function copy(t) local r={};for k,v in pairs(t or {}) do r[k]=v end;return r end
local function finite(v)return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
function M.sort_hand(s)
  local state=copy(s);state.hand={}
  for i,c in ipairs(s.hand or {})do state.hand[i]=c end
  local mode=s.hand_sort
  if mode==nil then
    state.draw_order_scope='legacy_append_order_unverified';return state
  end
  if mode~='desc' and mode~='asc' and mode~='suit desc' and mode~='suit asc' then
    return nil,'Unsupported public automatic hand sort.'
  end
  local keys,seen={},{}
  for _,c in ipairs(state.hand)do
    local b=c.base or {};local mult=(mode=='suit desc' or mode=='suit asc')and 1000 or 1
    if (c.ability or {}).effect=='Stone Card' then mult=-1000 end
    if c.identity_redacted or c.identity_unknown or c.unknown or
        not finite(b.nominal) or not finite(b.suit_nominal) or not finite(b.face_nominal) or
        not finite(b.suit_nominal_original or 0) or not finite(c.sort_tie) then
      return nil,'Automatic hand sorting lacks public finite card metadata.'
    end
    local key=b.nominal+b.suit_nominal*mult+(b.suit_nominal_original or 0)*0.0001*mult+
      b.face_nominal+0.000001*c.sort_tie
    if not finite(key) or seen[key] then return nil,'Automatic hand sorting has an unresolved physical tie.' end
    keys[c]=key;seen[key]=true
  end
  local asc=mode=='asc' or mode=='suit asc'
  table.sort(state.hand,function(a,b)if asc then return keys[a]<keys[b]end;return keys[a]>keys[b]end)
  state.draw_order_scope='public_automatic_sort';return state
end
function M.card(s,source,roll)
  local b=s.blind or {};local hidden=false
  if not b.disabled then
    local key,name=b.key,b.name
    if key=='bl_wheel' or name=='The Wheel' then
      if roll==nil then return nil,'Wheel replacement visibility requires a sampled outcome.' end
      hidden=roll<((s.probabilities or {}).normal or 1)/7
    elseif key=='bl_house' or name=='The House' then
      hidden=(s.hands_played or 0)==0 and (s.discards_used or 0)==0
    elseif key=='bl_mark' or name=='The Mark' then
      hidden=source.enhancement~='m_stone' and (source.rank or 0)>=11 and (source.rank or 0)<=13
      for _,j in ipairs(s.jokers or {}) do if not j.debuff and
        (j.key=='j_pareidolia' or (j.ability or {}).name=='Pareidolia') then hidden=true end end
    elseif key=='bl_fish' or name=='The Fish' then hidden=not not b.prepped end
  end
  -- This independent random source needs its own supplied draw. Do not reuse a
  -- Wheel roll and silently correlate two distinct source events.
  if (s.modifiers or {}).flipped_cards then
    return nil,'Challenge replacement visibility is not sampled.'
  end
  local c=copy(source);c.ability=copy(source.ability)
  c.face_down=hidden
  if hidden then c.ability.wheel_flipped=true end
  return c
end
function M.fill(s,ordered,options)
  options=options or {};local state=copy(s);state.hand={};state.deck={}
  for i,c in ipairs(s.hand or {}) do
    local held=copy(c);held.ability=copy(c.ability);held.ability.forced_selection=nil
    state.hand[i]=held
  end
  local b=s.blind or {};local serpent=not b.disabled and (b.key=='bl_serpent' or b.name=='The Serpent')
  local n=math.min(#ordered,options.count or (serpent and 3 or math.max(0,(s.hand_size or 8)-#state.hand)))
  for i,c in ipairs(ordered) do
    if i<=n then
      local drawn,reason=M.card(s,c,(options.visibility_rolls or {})[i]);if not drawn then return nil,reason end
      state.hand[#state.hand+1]=drawn
    else state.deck[#state.deck+1]=c end
  end
  if #state.hand>0 and not b.disabled and (b.key=='bl_final_bell' or b.name=='Cerulean Bell') then
    if options.bell_roll==nil then return nil,'Cerulean Bell needs a sampled forced card.' end
    local i=options.bell_roll%#state.hand+1;state.hand[i].ability.forced_selection=true
  end
  return M.sort_hand(state)
end
return M
