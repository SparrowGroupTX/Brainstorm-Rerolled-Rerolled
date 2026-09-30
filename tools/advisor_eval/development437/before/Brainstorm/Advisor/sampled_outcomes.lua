-- Private common random numbers for compared continuations. Outcomes are keyed
-- by sample, turn and physical card; branch enumeration cannot consume a
-- different random stream. Ordinary calls are Monte Carlo estimates. The
-- opt-in concealed continuation can use an all-failed optional Lucky floor
-- with owned Jokers when the normal probability leaves failure possible.
local M={}
local floor=math.floor
local UINT32=4294967296
local function enhancement(c)
  local a=c.ability or {}
  return c.enhancement or (c.key and c.key:sub(1,2)=='m_' and c.key) or
    (a.effect=='Glass Card' and 'm_glass') or (a.effect=='Lucky Card' and 'm_lucky') or 'c_base'
end
-- Exact 32-bit arithmetic on vanilla Lua doubles. Splitting the multiply into
-- 16-bit limbs keeps every intermediate below 2^53 on Lua 5.1 and LuaJIT.
local function mul32(a,b)
  local al,bl=a%65536,b%65536
  return (al*bl+((floor(a/65536)*bl+al*floor(b/65536))%65536)*65536)%UINT32
end
local xor_nibble={}
for a=0,15 do for b=0,15 do
  local left,right,value,place=a,b,0,1
  for _=1,4 do
    if left%2~=right%2 then value=value+place end
    left=floor(left/2);right=floor(right/2);place=place*2
  end
  xor_nibble[a*16+b]=value
end end
local bitlib=rawget(_G,'bit') or rawget(_G,'bit32')
local function portable_xor(a,b)
  local value,place=0,1
  for _=1,8 do
    value=value+xor_nibble[(a%16)*16+b%16]*place
    a=floor(a/16);b=floor(b/16);place=place*16
  end
  return value
end
local bxor=bitlib and type(bitlib.bxor)=='function' and
  function(a,b) return bitlib.bxor(a,b)%UINT32 end or portable_xor
local function xor_byte(a,b)
  local low=a%256
  return a-low+xor_nibble[(low%16)*16+b%16]+16*xor_nibble[floor(low/16)*16+floor(b/16)]
end
function M.roll(seed,turn,channel,id)
  -- FNV byte mixing followed by Murmur3's nonlinear 32-bit avalanche. Merely
  -- multiplying a polynomial ID hash leaves related cards' rolls affine and
  -- makes Hook sample only cyclic subsets instead of uniform card subsets.
  local h=mul32(bxor(2166136261,seed%UINT32),16777619)
  h=mul32(bxor(h,turn%UINT32),16777619)
  local text=channel..':'..tostring(id or '')
  for i=1,#text do h=mul32(xor_byte(h,text:byte(i)),16777619) end
  h=mul32(bxor(h,floor(h/65536)),2246822507)
  h=mul32(bxor(h,floor(h/8192)),3266489909)
  h=bxor(h,floor(h/65536))
  return h/UINT32
end
function M.context(s,indices,seed,turn,options,scorer)
  local ctx={glass_outcomes={},defer_crimson=true};local used={}
  for _,i in ipairs(indices) do used[i]=true end
  -- Owned events require the scorer's public repetition/row contract. This
  -- private stream is evaluated only after a public play has been selected.
  local owned=next(s.jokers or {})~=nil
  local lucky_floor=owned and options and options.lucky_floor_with_owned_jokers==true
  local plan
  if owned and not lucky_floor and scorer and scorer.sampled_lucky_plan then
    plan=scorer.sampled_lucky_plan(s,indices)
    if plan then ctx.lucky_outcomes={};ctx.lucky_owned=true end
  end
  if not owned or lucky_floor then ctx.lucky_outcomes={} end
  if lucky_floor then ctx.lucky_floor=true end
  local lucky_ids_checked=false
  local function lucky_identities()
    if lucky_ids_checked then return true end
    local ids={}
    for _,area in ipairs({s.hand or {},s.deck or {}}) do for _,c in ipairs(area) do
      local id=c.id
      if not (type(id)=='string' and id~='' or type(id)=='number' and id==id and math.abs(id)<math.huge) then
        return nil,'Sampled Lucky effects require present physical card identities.'
      end
      local key=tostring(id)
      if ids[key] then return nil,'Sampled Lucky effects require distinct physical card identities.' end
      ids[key]=true
    end end
    lucky_ids_checked=true;return true
  end
  local normal=(s.probabilities or {}).normal
  if normal==nil then normal=1 end
  -- Preflight this family before another effect (for example Glass) uses the
  -- same probability. A malformed Lucky world returns unsupported, not an
  -- arithmetic exception dependent on hand order.
  for i,c in ipairs(s.hand or {}) do
    if ctx.lucky_outcomes and used[i] and enhancement(c)=='m_lucky' and not c.debuff then
      local valid,reason=lucky_identities()
      if not valid then ctx.lucky_error=reason;return ctx end
      if type(normal)~='number' or normal~=normal or normal<0 or normal==math.huge then
        ctx.lucky_error='Sampled Lucky effects require a nonnegative finite normal probability.';return ctx
      end
      if lucky_floor and normal>=5 then
        ctx.lucky_error='Owned-Joker Lucky no-trigger floor requires optional Mult and dollar outcomes.';return ctx
      end
      if lucky_floor then
        -- Extra Lucky dollars can shrink a Tax hand. In that case the
        -- no-trigger branch is not a conservative continuation bound.
        local tax=(s.modifiers or {}).minus_hand_size_per_X_dollar
        if normal>0 and type(tax)=='number' and tax>0 then
          ctx.lucky_error='Lucky dollar triggers can change the Tax hand size.';return ctx
        end
        for _,j in ipairs(s.jokers or {}) do if not j.debuff and
          (j.key=='j_lucky_cat' or (j.ability or {}).name=='Lucky Cat') then
          local growth=(j.ability or {}).extra
          if normal>0 and growth~=nil and
            (type(growth)~='number' or growth~=growth or growth<0 or growth==math.huge) then
            ctx.lucky_error='Lucky Cat growth is not nonnegative in the no-trigger floor.';return ctx
          end
        end end
        if normal>0 then for _,j in ipairs(s.jokers or {}) do if not j.debuff then
          local a=j.ability or {}
          if j.key=='j_bull' or a.name=='Bull' then
            local factor=a.extra==nil and 2 or a.extra
            if type(factor)~='number' or factor~=factor or factor<0 or factor==math.huge then
              ctx.lucky_error='Dollar-dependent Bull scoring is not monotone.';return ctx
            end
          elseif j.key=='j_bootstraps' or a.name=='Bootstraps' then
            local extra=a.extra or {}
            if type(extra)~='table' then
              ctx.lucky_error='Dollar-dependent Bootstraps scoring is not monotone.';return ctx
            end
            local mult=extra.mult or 2;local dollars=extra.dollars or 5
            if type(mult)~='number' or mult~=mult or mult<0 or mult==math.huge or
              type(dollars)~='number' or dollars~=dollars or dollars<=0 or dollars==math.huge then
              ctx.lucky_error='Dollar-dependent Bootstraps scoring is not monotone.';return ctx
            end
          end
        end end end
      end
    end
  end
  local b=s.blind or {}
  if not b.disabled and (b.key=='bl_hook' or b.name=='The Hook') then
    local held={}
    for i,c in ipairs(s.hand) do if not used[i] then
      held[#held+1]={index=i,roll=M.roll(seed,turn,'hook',c.id or i)}
    end end
    table.sort(held,function(a,b) return a.roll==b.roll and a.index<b.index or a.roll<b.roll end)
    ctx.hook_indices={};for i=1,math.min(2,#held) do ctx.hook_indices[i]=held[i].index end
  end
  for i,c in ipairs(s.hand) do
    local a=c.ability or {}
    local e=enhancement(c)
    -- No vanilla before-scoring effect creates Glass. DNA creates held copies,
    -- which do not roll destruction on their creation play. Avoid hashing every
    -- ordinary held card just to supply outcomes the scorer never requests.
    if e=='m_glass' and not c.debuff then
      local odds=type(a.extra)=='number' and a.extra or 4
      ctx.glass_outcomes[i]=M.roll(seed,turn,'glass',c.id or i)<math.min(1,((s.probabilities or {}).normal or 1)/math.max(1,odds))
    end
    if ctx.lucky_outcomes and used[i] and e=='m_lucky' and not c.debuff then
      local row={};ctx.lucky_outcomes[i]=row
      for repetition=1,(plan and plan.counts[i] or (c.seal=='Red' and 2 or 1)) do
        row[repetition]=lucky_floor and {mult=false,dollars=false} or {
          mult=M.roll(seed,turn,'lucky-mult:'..repetition,c.id)<math.min(1,normal/5),
          dollars=(type(a.p_dollars)=='number' and a.p_dollars or 20)>0 and
            M.roll(seed,turn,'lucky-dollars:'..repetition,c.id)<math.min(1,normal/15)}
      end
    end
  end
  return ctx
end
function M.after_play(s,indices,scorer,seed,turn,options)
  local context=M.context(s,indices,seed,turn,options,scorer)
  if context.lucky_error then return nil,context.lucky_error end
  local state,effects,result=scorer.after_play(s,indices,context)
  if state then
    local b=state.blind or {}
    if not b.disabled and (b.key=='bl_fish' or b.name=='The Fish') then b.prepped=true end
  end
  return state,effects,result
end
function M.fill(s,ordered,scorer,draws,seed,turn,bell_roll)
  local rolls={};local b=s.blind or {}
  if not b.disabled and (b.key=='bl_wheel' or b.name=='The Wheel') then
    local count=math.min(#ordered,math.max(0,(s.hand_size or 8)-#(s.hand or {})))
    for i=1,count do rolls[i]=M.roll(seed,turn,'visibility',ordered[i].id or i) end
  end
  local state,reason=draws.fill(s,ordered,{bell_roll=bell_roll,visibility_rolls=rolls})
  if not state then return nil,reason end
  if (state.blind or {}).crimson_pending then
    if not scorer.after_draw or not scorer.crimson_candidates then return nil,'Heart draw transition unavailable.' end
    local indices=scorer.crimson_candidates(state);local choice
    if #indices>0 then choice=indices[math.floor(M.roll(seed,turn,'heart',0)*#indices)+1] end
    return scorer.after_draw(state,{crimson_index=choice})
  end
  return state
end
return M
