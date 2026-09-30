-- Detached replacement draws. A deck card's back is ordinary orientation, not
-- hidden information once drawn. Existing held cards retain their visibility.
local M={}
local function copy(t) local r={};for k,v in pairs(t or {}) do r[k]=v end;return r end
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
  c.face_down=hidden and (source.face_down~=false) or false
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
  return state
end
return M
