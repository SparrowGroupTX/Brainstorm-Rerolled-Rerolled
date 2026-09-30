-- Reward tie-breaks for already verified clearing plays. This module never
-- scores a hand or turns a reward estimate into evidence that a blind clears.
local M = {}
local floor, min, max = math.floor, math.min, math.max
local function num(v, fallback) return type(v)=='number' and v or (fallback or 0) end
local function name(c) return (c.ability or {}).name or c.name or c.key end
local function gold(c)
  return c.enhancement=='m_gold' or c.enhancement=='Gold Card'
    or (c.ability or {}).name=='Gold Card' or (c.ability or {}).effect=='Gold Card'
end
local planets={['High Card']='c_pluto',Pair='c_mercury',['Two Pair']='c_uranus',
  ['Three of a Kind']='c_venus',Straight='c_saturn',Flush='c_jupiter',
  ['Full House']='c_earth',['Four of a Kind']='c_mars',['Straight Flush']='c_neptune',
  ['Five of a Kind']='c_planet_x',['Flush House']='c_ceres',['Flush Five']='c_eris'}
local generators={['8 Ball']=true,Vagabond=true,Seance=true,Superposition=true,['Sixth Sense']=true,
  j_8_ball=true,j_vagabond=true,j_seance=true,j_superposition=true,j_sixth_sense=true}

local function active_at_end(c)
  local a=c.ability or {}
  -- Rental/perishable callbacks happen before the held-card loop. An expiring
  -- Mime or copying Joker no longer retriggers Gold or Blue seals this round.
  return not c.debuff and not (a.perishable and num(a.perish_tally)<=1)
end
local function mime_count(jokers)
  local function resolve(i,seen)
    local c=jokers[i]
    if not c or not active_at_end(c) or seen[i] then return 0 end
    seen[i]=true
    local n=name(c)
    if n=='Mime' or c.key=='j_mime' then return max(0,floor(num((c.ability or {}).extra,1))) end
    if n=='Blueprint' or c.key=='j_blueprint' then return resolve(i+1,seen) end
    if n=='Brainstorm' or c.key=='j_brainstorm' then return resolve(1,seen) end
    return 0
  end
  local count=0
  for i=1,#jokers do count=count+resolve(i,{}) end
  return count
end

local function interest(p,cash)
  if p.no_interest or cash<5 then return 0 end
  return p.interest_amount*min(floor(cash/5),p.interest_cap/5)
end
local function held(c,mimes)
  local a=c.ability or {};local repetitions=1+mimes+(c.seal=='Red' and 1 or 0)
  return {gold=(not c.debuff and max(0,num(a.h_dollars,gold(c) and 3 or 0)) or 0)*repetitions,
    blue=(not c.debuff and c.seal=='Blue') and repetitions or 0}
end

function M.prepare(s,strategy)
  local mods=s.modifiers or {}; local blind=s.blind or {}
  local p={cards={},slots=max(0,floor(num(s.consumable_limit,2)-#(s.consumeables or {})-
      num(s.consumeable_buffer))),planet_values={},strategy=strategy,
    no_interest=mods.no_interest,interest_amount=num(s.interest_amount,1),
    interest_cap=num(s.interest_cap,25),rental=0,
    final=blind.boss and num(s.ante,1)>=num(s.win_ante,8),
    held_supported=not (not blind.disabled and (blind.key=='bl_hook' or blind.name=='The Hook')),
    blue_supported=true,scope='held Gold/Blue and play income; heuristic Planet utility'}
  local jokers=s.jokers or {};local mimes=mime_count(jokers);p.mimes=mimes
  for _,j in ipairs(jokers) do
    local a=j.ability or {}
    if a.rental then p.rental=p.rental+num(s.rental_rate,3) end
    -- These may consume inventory slots during the play. Until their card
    -- generation is projected, do not promise a Blue Seal Planet afterward.
    if not j.debuff and (generators[name(j)] or generators[j.key]) then p.blue_supported=false end
    if not j.debuff and (name(j)=='DNA' or j.key=='j_dna') and num(s.hands_played)==0 then
      p.dna_possible=true
    end
  end
  local max_blue,largest_blue=0,0
  for i,c in ipairs(s.hand or {}) do
    p.cards[i]=held(c,mimes)
    max_blue=max_blue+p.cards[i].blue
    largest_blue=max(largest_blue,p.cards[i].blue)
  end
  if p.dna_possible then max_blue=max_blue+largest_blue*#jokers end
  p.hands=max(0,num(s.hands_left,(s.current_round or {}).hands_left)-1)
  p.hand_dollars=not mods.no_extra_hand_money and p.hands*num(mods.money_per_hand,1) or 0
  p.discard_dollars=max(0,num(s.discards_left,(s.current_round or {}).discards_left))*num(mods.money_per_discard)
  -- All prospective rewards use a small cached table: at most twelve hand
  -- types by eight generation counts, independent of the number of scored plays.
  -- Quantities above eight remain exact; only heuristic utility saturates.
  max_blue=min(8,p.slots,max_blue)
  if p.final or not p.held_supported or not p.blue_supported or max_blue==0 then return p end
  local profile=strategy and strategy.build_profile and strategy.build_profile(s)
  p.profile=profile
  local inventory=s.consumeables or {}
  local original=strategy and strategy.inventory_value and strategy.inventory_value(s,inventory,{profile=profile})
  for hand,key in pairs(planets) do
    local values={[0]=0};p.planet_values[hand]=values
    local cards={};for i,c in ipairs(inventory) do cards[i]=c end
    for count=1,max_blue do
      cards[#cards+1]={key=key,name=hand..' Planet',ability={set='Planet',consumeable={hand_type=hand}}}
      if original then
        local changed=strategy.inventory_value(s,cards,{profile=profile})
        -- Strategic inventory points are not dollars or calibrated win chance.
        -- Dollar-equivalent scaling makes their comparison with earned cash
        -- explicit and keeps marginal copy-pool dilution in the calculation.
        values[count]=max(-24,min(36,(changed-original)/12))
      else
        local h=(s.hands or {})[hand] or {}
        local total=0;for _,v in pairs(s.hands or {}) do total=total+num(v.played) end
        local relevance=0.25+0.75*num(h.played)/max(1,total)
        values[count]=count*(1+3*relevance)
      end
    end
  end
  return p
end

function M.value(s,play,p)
  p=p or M.prepare(s)
  local details={scope=p.scope,held_dollars=0,blue_planets=0,planet_hand=play.hand,
    planet_utility=0,play_dollars=num(play.expected_dollars),hand_dollars=p.hand_dollars,
    discard_dollars=p.discard_dollars,held_supported=p.held_supported,blue_supported=p.blue_supported,
    heuristic=true}
  if p.final then details.final_blind=true;return 0,details end
  local chosen={};for _,i in ipairs(play.indices or {}) do chosen[i]=true end
  local slots=p.slots
  if p.held_supported then
    -- Source processes retained hand order, filling consumable capacity at
    -- each Blue trigger. All generated Planets match this play's final hand.
    for i,c in ipairs(p.cards) do if not chosen[i] then
      details.held_dollars=details.held_dollars+c.gold
      if p.blue_supported and planets[play.hand] then
        local created=min(slots,c.blue);slots=slots-created
        details.blue_planets=details.blue_planets+created
      end
    end end
    -- DNA's exact pre-score copies are appended to the retained hand. Metadata
    -- comes from score(), after order-sensitive Vampire/DNA effects, so copied
    -- Gold/Blue rewards use the actual copied card rather than its old source.
    for _,card in ipairs(play.created_cards or {}) do
      local c=held(card,p.mimes)
      details.held_dollars=details.held_dollars+c.gold
      if p.blue_supported and planets[play.hand] then
        local created=min(slots,c.blue);slots=slots-created
        details.blue_planets=details.blue_planets+created
      end
    end
  end
  local values=p.planet_values[play.hand]
  details.planet_utility=values and values[min(8,details.blue_planets)] or 0
  local before=num(s.dollars)-p.rental
  -- Blind/cashout Joker/unused-hand awards arrive after interest is calculated;
  -- scored and held-card dollars arrive before it. Do not include hand payout
  -- in this threshold or count scoring income a second time.
  details.marginal_interest=interest(p,before+details.play_dollars+details.held_dollars)-interest(p,before)
  details.dollars=details.play_dollars+details.held_dollars+p.hand_dollars+p.discard_dollars+details.marginal_interest
  details.utility=details.dollars+details.planet_utility
  return details.utility,details
end

return M
