-- Detached vanilla setting_blind callbacks, before the first draw. The caller
-- supplies the chosen pre-blind row and already applies next-blind restrictions.
-- No game RNG, seed or hidden card identities are consulted. Marble fronts are
-- four fixed composition samples, explicitly uncertain rather than predictions.
local Start={}
local function num(v,d) return type(v)=='number' and v or (d or 0) end
local function clone(v,seen)
  if type(v)~='table' then return v end
  seen=seen or {};if seen[v] then return seen[v] end
  local out={};seen[v]=out
  for k,x in pairs(v) do if type(x)~='function' and k~='_shop_scoring' then out[k]=clone(x,seen) end end
  return out
end
local names={['Ceremonial Dagger']='j_ceremonial',['Marble Joker']='j_marble',
  Burglar='j_burglar',Blueprint='j_blueprint',Brainstorm='j_brainstorm',
  Hologram='j_hologram',Chicot='j_chicot',Madness='j_madness',
  ['Riff-raff']='j_riff_raff',Cartomancer='j_cartomancer',Certificate='j_certificate'}
local function key(j) return j.key or names[(j.ability or {}).name or j.name] end
local supported={j_ceremonial=true,j_marble=true,j_burglar=true,j_chicot=true}
local unsupported={j_madness=true,j_riff_raff=true,j_cartomancer=true,j_certificate=true}
function Start.supports(j) return not not supported[key(j)] end
local function active(j)
  local a=j.ability or {}
  return not j.debuff and not a.perma_debuff and not (a.perishable and num(a.perish_tally,5)<=0)
end
local function negative(j) return j.edition=='negative' or type(j.edition)=='table' and j.edition.negative end
local function remove_resources(s,j)
  local a=j.ability or {};local e=type(a.extra)=='table' and a.extra or {};local k=key(j)
  if negative(j) then s.joker_limit=num(s.joker_limit,5)-1 end
  if not active(j) then return end -- source already removed debuffed passive effects
  local delta=num(a.h_size)
  if k=='j_turtle_bean' or k=='j_troubadour' then delta=delta+num(e.h_size) end
  if k=='j_stuntman' then delta=delta-num(e.h_size,2) end
  s.hand_size=num(s.hand_size,8)-delta
  local discards=math.max(0,num(a.d_size))
  s.discards_left=math.max(0,num(s.discards_left,num(s.current_round.discards_left))-discards)
  s.current_round.discards_left=s.discards_left
  s.round_resets=s.round_resets or {}
  if s.round_resets.discards~=nil then s.round_resets.discards=s.round_resets.discards-discards end
  -- Removing Troubadour affects the NEXT reset, not this already-reset hand count.
  if k=='j_troubadour' and s.round_resets.hands~=nil then s.round_resets.hands=s.round_resets.hands-num(e.h_plays,-1) end
  if k=='j_oops' then for n,v in pairs(s.probabilities or {}) do s.probabilities[n]=v/2 end end
  if k=='j_credit_card' then s.bankrupt_at=num(s.bankrupt_at)+num(a.extra,20) end
  if k=='j_to_the_moon' then s.interest_amount=num(s.interest_amount,1)-num(a.extra,1) end
  if k=='j_chaos' then s.current_round.free_rerolls=num(s.current_round.free_rerolls)-1 end
end
local function stone(sample,ordinal,owner,source)
  -- Samples span all suits and low/high ranks; they are common between compared
  -- rows. Stone normally ignores its front, but the latent base stays explicit.
  local rank=2+((sample-1)*11+(ordinal-1)*7)%13
  local suit=({'Clubs','Diamonds','Hearts','Spades'})[(sample+ordinal-2)%4+1]
  local value=({[11]='Jack',[12]='Queen',[13]='King',[14]='Ace'})[rank] or tostring(rank)
  local nominal=rank==14 and 11 or math.min(rank,10)
  return {id='advisor_marble:'..tostring(owner)..':'..tostring(source)..':'..ordinal,
    key='m_stone',name='Stone Card',enhancement='m_stone',rank=rank,suit=suit,nominal=nominal,
    base={id=rank,suit=suit,value=value,nominal=nominal,times_played=0},
    ability={set='Enhanced',name='Stone Card',effect='Stone Card',bonus=50,
      mult=0,h_mult=0,h_x_mult=0,h_dollars=0,p_dollars=0,t_mult=0,t_chips=0,
      x_mult=1,h_size=0,d_size=0,extra_value=0,type='',perma_bonus=0},
    debuff=false,face_down=false,advisor_generated='marble_composition_sample'}
end
local disable_supported={bl_club=true,bl_goad=true,bl_window=true,bl_head=true,bl_plant=true,
  bl_pillar=true,bl_psychic=true,bl_arm=true,bl_flint=true,bl_ox=true,bl_tooth=true,
  bl_eye=true,bl_mouth=true,bl_water=true,bl_needle=true,bl_wall=true,bl_final_vessel=true,
  bl_final_leaf=true,bl_house=true,bl_wheel=true,bl_mark=true,bl_fish=true,bl_serpent=true}
local function disable_boss(s)
  local b=s.blind or {}
  if not disable_supported[b.key] then
    return false,'Boss disable needs supported restrictions; draw/shuffle or unknown effects remain unresolved.'
  end
  if b.key=='bl_water' then
    if type(b.discards_sub)~='number' then return false,'Water disable requires its observed initial discard reduction.' end
    s.discards_left=num(s.discards_left,num(s.current_round.discards_left))+b.discards_sub
    s.current_round.discards_left=s.discards_left
  elseif b.key=='bl_needle' then
    if type(b.hands_sub)~='number' then return false,'Needle disable requires its observed initial hand reduction.' end
    s.hands_left=num(s.hands_left,num(s.current_round.hands_left))+b.hands_sub
    s.current_round.hands_left=s.hands_left
  elseif b.key=='bl_wall' then b.chips=num(b.chips)/2
  elseif b.key=='bl_final_vessel' then b.chips=num(b.chips)/3 end
  b.disabled=true
  for _,c in ipairs(s.playing_cards) do
    c.debuff=not not (c.ability or {}).perma_debuff
    if c.ability then c.ability.wheel_flipped=nil end
  end
  -- Disabling the blind occurs after the entire setting_blind dispatch. It
  -- cannot retroactively let a previously debuffed Dagger take its callback.
  for _,j in ipairs(s.jokers) do
    local a=j.ability or {}
    j.debuff=not not (a.perma_debuff or a.perishable and num(a.perish_tally,5)<=0)
  end
  return true
end
function Start.project(prepared,options)
  options=options or {};local sample=num(options.sample_index,1)
  if sample~=math.floor(sample) or sample<1 or sample>4 then return nil,'Blind-start composition sample must be 1–4.' end
  local s=clone(prepared);s.current_round=s.current_round or {};s.playing_cards=s.playing_cards or {};s.jokers=s.jokers or {}
  local row=s.jokers;local diagnostics={supported=true,removed={},generated={},events={},
    stochastic=false,composition_sample=sample,requires_card_debuff_refresh=false}
  for _,j in ipairs(row) do
    if j.getting_sliced then return nil,'A blind-start projection cannot begin during an unresolved destruction.' end
  end
  local sliced,queue,disablers,generated_count={},{},{},0
  local function added()
    -- playing_card_joker_effects runs synchronously when Marble queues creation.
    -- Hologram growth is not copied and sliced/debuffed Holograms do not trigger.
    for _,j in ipairs(row) do if active(j) and not sliced[j] and key(j)=='j_hologram' then
      local a=j.ability or {}
      if type(a.x_mult)~='number' or type(a.extra)~='number' then return false end
      a.x_mult=a.x_mult+a.extra
    end end
    return true
  end
  local failure
  local function callback(index,origin,depth)
    local j=row[index];if not j or not active(j) then return end
    if depth>#row+1 then return end -- source Blueprint/Brainstorm recursion bound
    local k=key(j);local a=j.ability or {}
    if k=='j_blueprint' then callback(index+1,origin or j,depth+1);return end
    if k=='j_brainstorm' then if index~=1 then callback(1,origin or j,depth+1) end;return end
    if sliced[j] then return end
    if unsupported[k] then failure='Unsupported blind-start or first-draw callback: '..tostring(k);return end
    if k=='j_ceremonial' and not origin then
      local victim=row[index+1]
      if victim and not (victim.ability or {}).eternal and not sliced[victim] then
        if type(a.mult)~='number' or type(victim.sell_cost)~='number' then failure='Dagger requires observed Mult and victim sell value.';return end
        sliced[victim]=true
        queue[#queue+1]={kind='dagger',actor=j,victim=victim,mult=victim.sell_cost*2}
      end
    elseif k=='j_chicot' and not origin and (s.blind or {}).boss then
      disablers[#disablers+1]=j
    elseif k=='j_burglar' and not sliced[origin or j] then
      if type(a.extra)~='number' then failure='Burglar hand gain is unknown.';return end
      queue[#queue+1]={kind='burglar',actor=origin or j,hands=a.extra}
    elseif k=='j_marble' and not sliced[origin or j] then
      generated_count=generated_count+1
      if generated_count>12 then failure='Blind-start generation exceeds the bounded row budget.';return end
      if not added() then failure='Hologram addition growth is unknown.';return end
      queue[#queue+1]={kind='marble',actor=origin or j,source=j,ordinal=generated_count}
    end
  end
  for i=1,#row do callback(i,nil,0);if failure then return nil,failure end end
  if #disablers>0 then
    for _,j in ipairs(row) do
      local a=j.ability or {}
      if j.debuff and not a.perma_debuff and not (a.perishable and num(a.perish_tally,5)<=0) and
        (key(j)~='j_ceremonial' or num(a.h_size)~=0 or num(a.d_size)~=0) then
        return nil,'Boss disable reactivating debuffed passive effects remains unsupported.'
      end
    end
  end
  if #disablers>0 and ((s.blind or {}).key=='bl_water' or (s.blind or {}).key=='bl_needle') then
    for _,e in ipairs(queue) do if e.kind=='burglar' then
      return nil,'Burglar and resource-restoring boss disable need an ordered queued-resource model.'
    end end
    for victim in pairs(sliced) do
      local a=victim.ability or {};local e=type(a.extra)=='table' and a.extra or {}
      if num(a.d_size)~=0 or num(a.h_size)~=0 or num(e.h_size)~=0 or num(e.h_plays)~=0 then
        return nil,'Resource-restoring disable with a destroyed resource Joker needs queued-resource timing.'
      end
    end
  end
  for _,e in ipairs(queue) do
    if e.kind=='dagger' then
      e.actor.ability.mult=e.actor.ability.mult+e.mult
      diagnostics.events[#diagnostics.events+1]={kind='dagger',actor=e.actor.id,victim=e.victim.id,mult=e.mult}
    elseif e.kind=='burglar' then
      s.hands_left=num(s.hands_left,num(s.current_round.hands_left))+e.hands
      s.current_round.hands_left=s.hands_left;s.discards_left=0;s.current_round.discards_left=0
      diagnostics.events[#diagnostics.events+1]={kind='burglar',actor=e.actor.id,hands=e.hands}
    else
      local c=stone(sample,e.ordinal,e.actor.id or key(e.actor),e.source.id or key(e.source))
      s.playing_cards[#s.playing_cards+1]=c
      diagnostics.generated[#diagnostics.generated+1]=c.id
      diagnostics.events[#diagnostics.events+1]={kind='marble',actor=e.actor.id,card=c.id}
      diagnostics.stochastic=true;diagnostics.requires_card_debuff_refresh=true
    end
  end
  -- Chicot queues a nested event; every eligible actor is decided during the
  -- original left-to-right dispatch, after preceding Daggers mark their victim.
  -- Each actual Chicot calls disable, including repeated Wall/Vessel reductions.
  for _,j in ipairs(disablers) do
    local ok,why=disable_boss(s);if not ok then return nil,why end
    diagnostics.events[#diagnostics.events+1]={kind='chicot',actor=j.id,blind=s.blind.key}
    diagnostics.requires_card_debuff_refresh=true
  end
  local retained={}
  for _,j in ipairs(row) do
    if sliced[j] then
      remove_resources(s,j);diagnostics.removed[#diagnostics.removed+1]=j.id or key(j)
      diagnostics.requires_card_debuff_refresh=true
    else retained[#retained+1]=j end
  end
  s.jokers=retained
  diagnostics.reason=diagnostics.stochastic and 'Source Stone additions with four fixed uncertain front/composition samples.' or
    'Observed ordered blind-start effects; the retained row is fixed before draw.'
  return s,diagnostics
end
return Start
