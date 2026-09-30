-- Owned-consumable actions followed by every legal play. This module never
-- touches live cards, game callbacks, or RNG. Unsupported actions are skipped.
local M = {}
local function number(v, fallback) return type(v) == 'number' and v or (fallback or 0) end
local function copy(v, seen)
  if type(v) ~= 'table' then return v end
  seen = seen or {}; if seen[v] then return seen[v] end
  local out = {}; seen[v] = out
  for k, value in pairs(v) do if type(value) ~= 'function' then out[k] = copy(value, seen) end end
  return out
end
local function list(v) local out = {}; for i, x in ipairs(v or {}) do out[i] = x end; return out end
local function combinations(n, limit, visit)
  local chosen = {}
  local function walk(start)
    if #chosen > 0 then visit(chosen) end
    if #chosen >= limit then return end
    for i = start, n do chosen[#chosen + 1] = i; walk(i + 1); chosen[#chosen] = nil end
  end
  walk(1)
end
local function count_plays(n, limit)
  local term, count = 1, 0
  for k = 1, math.min(n, limit) do term = term * (n - k + 1) / k; count = count + term end
  return count
end
local hands = {
  ['High Card']={5,1,10,1}, Pair={10,2,15,1}, ['Two Pair']={20,2,20,1},
  ['Three of a Kind']={30,3,20,2}, Straight={30,4,30,3}, Flush={35,4,15,2},
  ['Full House']={40,4,25,2}, ['Four of a Kind']={60,7,30,3}, ['Straight Flush']={100,8,40,4},
  ['Five of a Kind']={120,12,35,3}, ['Flush House']={140,14,40,4}, ['Flush Five']={160,16,50,3},
}
local definitions, by_name = {}, {}
local function define(key, name, kind, value, maximum, minimum)
  local d = {key=key, name=name, kind=kind, value=value, maximum=maximum or 0, minimum=minimum or (maximum and 1 or 0)}
  definitions[key], by_name[name] = d, d
end
for _, d in ipairs({
  {'c_pluto','Pluto','High Card'}, {'c_mercury','Mercury','Pair'}, {'c_uranus','Uranus','Two Pair'},
  {'c_venus','Venus','Three of a Kind'}, {'c_saturn','Saturn','Straight'}, {'c_jupiter','Jupiter','Flush'},
  {'c_earth','Earth','Full House'}, {'c_mars','Mars','Four of a Kind'}, {'c_neptune','Neptune','Straight Flush'},
  {'c_planet_x','Planet X','Five of a Kind'}, {'c_ceres','Ceres','Flush House'}, {'c_eris','Eris','Flush Five'},
}) do define(d[1], d[2], 'planet', d[3]) end
define('c_black_hole','Black Hole','all_hands')
for _, d in ipairs({
  {'c_magician','The Magician','m_lucky',2}, {'c_empress','The Empress','m_mult',2},
  {'c_heirophant','The Hierophant','m_bonus',2}, {'c_lovers','The Lovers','m_wild',1},
  {'c_chariot','The Chariot','m_steel',1}, {'c_justice','Justice','m_glass',1},
  {'c_devil','The Devil','m_gold',1}, {'c_tower','The Tower','m_stone',1},
}) do define(d[1], d[2], 'enhance', d[3], d[4]) end
for _, d in ipairs({{'c_star','The Star','Diamonds'}, {'c_moon','The Moon','Clubs'},
  {'c_sun','The Sun','Hearts'}, {'c_world','The World','Spades'}}) do define(d[1],d[2],'suit',d[3],3) end
define('c_strength','Strength','strength',nil,2)
define('c_death','Death','death',nil,2,2)
define('c_hanged_man','The Hanged Man','remove',nil,2)
for _,d in ipairs({{'c_talisman','Talisman','Gold'},{'c_deja_vu','Deja Vu','Red'},
  {'c_trance','Trance','Blue'},{'c_medium','Medium','Purple'}}) do define(d[1],d[2],'seal',d[3],1) end
define('c_cryptid','Cryptid','copy',nil,1)
define('c_hermit','The Hermit','hermit')
define('c_temperance','Temperance','temperance')
define('c_emperor','The Emperor','generator','Tarot')
define('c_high_priestess','The High Priestess','generator','Planet')
define('c_judgement','Judgement','generator','Joker')
local function definition(card)
  local name = (card.ability or {}).name or card.name
  -- A custom key that happens to share a vanilla name may run extra callbacks.
  return card.key and definitions[card.key] or (not card.key and by_name[name])
end
-- Scheduling only: reserve room for complete current-play comparisons before
-- ordinary draw search spends the shared allowance. Legality, transformations,
-- retained inventory and action selection remain owned by suggest/apply.
function M.comparison_reserve(snapshot, options)
  options=options or {}
  local maximum=math.max(0,math.min(25000,math.floor(number(options.max_evaluations,25000))))
  local n=#(snapshot.hand or {})
  local limit=math.min(5,snapshot.hand_limit or 5)
  if snapshot.phase~='hand' or n==0 or n>20 or limit<1 then return 0 end
  local cost=count_plays(n,limit)
  if cost>maximum then return 0 end
  local probes=0
  for index,owned in ipairs(snapshot.consumeables or {}) do
    local d=definition(owned)
    if d and not owned.debuff and d.kind~='generator' then
      local config=(owned.ability or {}).consumeable or {}
      local minimum=math.max(d.minimum,number(config.min_highlighted,d.minimum))
      local targets=math.min(n,d.maximum,number(config.max_highlighted,d.maximum),limit)
      local admitted=false
      local function probe(indices)
        if admitted or probes>=8 or #indices<minimum then return end
        probes=probes+1
        local after=M.apply(snapshot,index,indices)
        local size=after and #(after.hand or {}) or 0
        admitted=size>0 and size<=20 and count_plays(size,limit)<=maximum
      end
      -- A small admission shortlist, not a new target-search policy. Failure
      -- to admit leaves ordinary allocation unchanged. apply owns all metadata,
      -- forced-target, population and module guards, including Negative costs.
      if d.maximum==0 then probe({})
      elseif targets>=minimum then combinations(n,targets,probe) end
      if admitted then return maximum,cost end
      if probes>=8 then return 0 end
    end
  end
  return 0
end
-- Exchange only adjacent, fully equal public consumables. Ignoring the one
-- physical id is safe here: either removal leaves the same ORDERED metadata,
-- count and capacity. Never collapse by name or sort the remaining inventory;
-- held editions/Observatory and Perkeo source metadata still matter. Concealed,
-- cyclic or unusually large metadata falls back to separate comparisons.
local function equivalent_owned(a,b)
  if not a or not b or not definitions[a.key] or a.key~=b.key or
      a.face_down or b.face_down or a.identity_redacted or b.identity_redacted or
      a.unknown or b.unknown or a.concealed or b.concealed then return false end
  local budget,seen_a,seen_b=4096,{},{}
  local function same(x,y,depth)
    budget=budget-1
    if budget<0 or depth>16 or type(x)~=type(y) then return false end
    local kind=type(x)
    if kind=='number' then return x==y and x==x and math.abs(x)<math.huge end
    if kind=='string' then return #x<=8192 and #y<=8192 and x==y end
    if kind=='boolean' or kind=='nil' then return x==y end
    if kind~='table' or getmetatable(x) or getmetatable(y) or seen_a[x] or seen_b[y] then return false end
    seen_a[x],seen_b[y]=true,true
    for k,v in pairs(x) do if depth~=0 or k~='id' then
      if (type(k)~='string' and type(k)~='number') or not same(v,y[k],depth+1) then return false end
    end end
    for k in pairs(y) do if (depth~=0 or k~='id') and x[k]==nil then return false end end
    seen_a[x],seen_b[y]=nil,nil
    return true
  end
  return same(a,b,0)
end
-- Shared by the shop cash planner; no grouping mutates the actual inventory.
M.equivalent_owned=equivalent_owned
local function joker_name(j)
  return (j.ability or {}).name or j.name or ({j_constellation='Constellation',
    j_steel_joker='Steel Joker',j_stone='Stone Joker',j_drivers_license="Driver's License",
    j_pareidolia='Pareidolia',j_smeared='Smeared Joker'})[j.key]
end
local function enhancement(c)
  return c.enhancement or (c.key and c.key:sub(1,2)=='m_' and c.key) or 'c_base'
end
local function value_name(rank) return ({[11]='Jack',[12]='Queen',[13]='King',[14]='Ace'})[rank] or tostring(rank) end
local function recalc_debuff(state, c)
  local b, a = state.blind or {}, c.ability or {}
  local bd = not b.disabled and (b.debuff or {}) or {}
  local stone, wild = enhancement(c)=='m_stone', enhancement(c)=='m_wild'
  local r, face = c.rank or (c.base or {}).id or 0, false
  face = not stone and r >= 11 and r <= 13
  local smeared = false
  for _, j in ipairs(state.jokers or {}) do if not j.debuff then
    if joker_name(j)=='Pareidolia' then face=true end
    if joker_name(j)=='Smeared Joker' then smeared=true end
  end end
  local suit = c.suit or (c.base or {}).suit
  local matches = suit == bd.suit or wild
  if bd.suit and smeared then
    matches = matches or ((suit=='Hearts' or suit=='Diamonds') == (bd.suit=='Hearts' or bd.suit=='Diamonds'))
  end
  c.debuff = not not (a.perma_debuff or (not b.disabled and (
    b.name=='Verdant Leaf' or b.key=='bl_final_leaf' or
    (bd.suit and not stone and matches) or (bd.is_face=='face' and face) or
    ((b.name=='The Pillar' or b.key=='bl_pillar') and a.played_this_ante) or
    (bd.value and bd.value==value_name(r)) or (bd.nominal and bd.nominal==c.nominal))))
end
local enhancement_config = {
  m_bonus={name='Bonus',effect='Bonus Card',bonus=30}, m_mult={name='Mult',effect='Mult Card',mult=4},
  m_wild={name='Wild Card',effect='Wild Card'}, m_glass={name='Glass Card',effect='Glass Card',x_mult=2,extra=4},
  m_steel={name='Steel Card',effect='Steel Card',h_x_mult=1.5},
  m_stone={name='Stone Card',effect='Stone Card',bonus=50},
  m_gold={name='Gold Card',effect='Gold Card',h_dollars=3},
  m_lucky={name='Lucky Card',effect='Lucky Card',mult=20,p_dollars=20},
}
local function set_enhancement(state, c, key)
  local old = c.ability or {}
  local a = {set='Enhanced',mult=0,h_mult=0,h_x_mult=0,h_dollars=0,p_dollars=0,
    t_mult=0,t_chips=0,x_mult=1,h_size=0,d_size=0,extra_value=0,type='',bonus=0,
    forced_selection=old.forced_selection,perma_bonus=old.perma_bonus or 0}
  for k,v in pairs(enhancement_config[key]) do a[k]=v end
  c.ability, c.enhancement, c.key, c.name = a, key, key, a.name
  recalc_debuff(state,c)
end
local function set_base(state, c, rank, suit)
  local old = c.base or {}
  c.rank, c.nominal, c.suit = rank, rank==14 and 11 or math.min(rank,10), suit
  c.base = {id=rank,nominal=c.nominal,value=value_name(rank),suit=suit,times_played=0,
    suit_nominal_original=old.suit_nominal_original or (({Spades=0.04,Hearts=0.03,Clubs=0.02,Diamonds=0.01})[suit] or 0)/10,
    face_nominal=rank>=11 and (rank-10)/10 or 0,
    suit_nominal=({Spades=0.04,Hearts=0.03,Clubs=0.02,Diamonds=0.01})[suit]}
  recalc_debuff(state,c)
end
local function level_up(state, hand)
  local defaults=hands[hand]; if not defaults then return false end
  state.hands=state.hands or {}; local h=state.hands[hand] or {}; state.hands[hand]=h
  local level=number(h.level,1)
  h.l_chips,h.l_mult=number(h.l_chips,defaults[3]),number(h.l_mult,defaults[4])
  h.s_chips=number(h.s_chips,number(h.chips,defaults[1])-h.l_chips*(level-1))
  h.s_mult=number(h.s_mult,number(h.mult,defaults[2])-h.l_mult*(level-1))
  h.level=math.max(0,level+1)
  h.chips=math.max(0,h.s_chips+h.l_chips*(h.level-1))
  h.mult=math.max(1,h.s_mult+h.l_mult*(h.level-1))
  return true
end
local function tally(state, original, targets)
  local changed, deltas = {}, {m_steel=0,m_stone=0,enhanced=0}
  for _, i in ipairs(targets) do
    local before, after = enhancement(original.hand[i]), enhancement(state.hand[i])
    if original.hand[i].id then changed[original.hand[i].id]=state.hand[i] end
    for _,key in ipairs({'m_steel','m_stone'}) do deltas[key]=deltas[key]+(after==key and 1 or 0)-(before==key and 1 or 0) end
    deltas.enhanced=deltas.enhanced+(after~='c_base' and 1 or 0)-(before~='c_base' and 1 or 0)
  end
  local full = state.playing_cards and #state.playing_cards>0
  local counts={m_steel=0,m_stone=0,enhanced=0}
  if full then for i,c in ipairs(state.playing_cards) do
    c=changed[c.id] or c; state.playing_cards[i]=c
    local e=enhancement(c)
    if counts[e] then counts[e]=counts[e]+1 end
    if e~='c_base' then counts.enhanced=counts.enhanced+1 end
  end end
  for _,j in ipairs(state.jokers or {}) do
    local n=joker_name(j); j.ability=j.ability or {}
    local field,key
    if n=='Steel Joker' then field,key='steel_tally','m_steel'
    elseif n=='Stone Joker' then field,key='stone_tally','m_stone'
    elseif n=="Driver's License" then field,key='driver_tally','enhanced' end
    if field then j.ability[field]=full and counts[key] or math.max(0,number(j.ability[field])+deltas[key]) end
  end
end

-- Pure transition exported for headless evaluation. Targets refer to the
-- current left-to-right hand order; Death copies right onto left, never reverse.
function M.apply(snapshot, index, targets)
  local owned=(snapshot.consumeables or {})[index]
  if not owned or owned.debuff then return nil,'Consumable is missing or debuffed.' end
  local d=definition(owned)
  if not d then return nil,'Unsupported consumable: '..tostring(owned.name or (owned.ability or {}).name or owned.key)..'.' end
  if d.kind=='generator' then return nil,'Generated identities require a public reveal and fresh advice.' end
  targets=targets or {}
  local ability, config=owned.ability or {}, (owned.ability or {}).consumeable or {}
  local maximum=math.min(d.maximum,number(config.max_highlighted,d.maximum),snapshot.hand_limit or 5,5)
  local minimum=math.max(d.minimum,number(config.min_highlighted,d.minimum))
  if #targets<minimum or #targets>maximum then return nil,'Invalid number of consumable targets.' end
  local previous=0
  for _,i in ipairs(targets) do
    if type(i)~='number' or i<=previous or not snapshot.hand[i] then return nil,'Targets must follow the current hand order.' end
    local e=enhancement(snapshot.hand[i])
    if e~='c_base' and not enhancement_config[e] then return nil,'Unsupported existing card enhancement: '..tostring(e)..'.' end
    previous=i
  end
  if d.maximum>0 then
    local selected={};for _,i in ipairs(targets) do selected[i]=true end
    for i,c in ipairs(snapshot.hand or {}) do
      if (c.ability or {}).forced_selection and not selected[i] then
        return nil,'Consumable targets must include the card forced by the blind.'
      end
    end
  end
  if config.mod_conv and config.mod_conv~=(d.kind=='enhance' and d.value or d.kind=='strength' and 'up_rank' or d.kind=='death' and 'card' or nil) then
    return nil,'Modified consumable transformation is not modeled.'
  end
  if config.suit_conv and config.suit_conv~=d.value then return nil,'Modified suit transformation is not modeled.' end
  if config.hand_type and config.hand_type~=d.value then return nil,'Modified Planet hand type is not modeled.' end
  if config.remove_card and d.kind~='remove' then return nil,'Modified removal effect is not modeled.' end
  local state=copy(snapshot)
  table.remove(state.consumeables,index)
  if owned.edition=='negative' or type(owned.edition)=='table' and owned.edition.negative then
    state.consumable_limit=math.max(0,number(state.consumable_limit)-1)
  end
  if d.kind=='planet' then level_up(state,d.value)
  elseif d.kind=='all_hands' then for hand in pairs(hands) do level_up(state,hand) end
  elseif d.kind=='enhance' then for _,i in ipairs(targets) do set_enhancement(state,state.hand[i],d.value) end
  elseif d.kind=='suit' or d.kind=='strength' then for _,i in ipairs(targets) do
    local c=state.hand[i]; local r=c.rank or (c.base or {}).id
    if not r or r<2 or r>14 then return nil,'Cannot transform an unknown card rank.' end
    set_base(state,c,d.kind=='strength' and (r==14 and 2 or r+1) or r,
      d.kind=='suit' and d.value or c.suit or (c.base or {}).suit)
  end
  elseif d.kind=='death' then
    local left,right=targets[1],targets[2]
    local destination,source=state.hand[left],state.hand[right]
    local id,face_down,sort_tie=destination.id,destination.face_down,destination.sort_tie
    local original_suit=(destination.base or {}).suit_nominal_original
    state.hand[left]=copy(source); state.hand[left].id=id; state.hand[left].face_down=face_down
    state.hand[left].sort_tie=sort_tie
    state.hand[left].base=copy(source.base or {}); state.hand[left].base.times_played=0
    -- Vanilla copy_card calls set_base on the existing destination. Its first
    -- suit survives the rank/suit copy, just like its physical tie identity.
    state.hand[left].base.suit_nominal_original=original_suit or
      (({Spades=0.04,Hearts=0.03,Clubs=0.02,Diamonds=0.01})[source.suit] or 0)/10
  elseif d.kind=='hermit' then state.dollars=number(state.dollars)+math.max(0,math.min(number(state.dollars),number(ability.extra,20)))
  elseif d.kind=='temperance' then
    local money=0; for _,j in ipairs(state.jokers or {}) do money=money+number(j.sell_cost) end
    state.dollars=number(state.dollars)+math.min(money,number(ability.extra,50))
  elseif d.kind=='remove' or d.kind=='seal' or d.kind=='copy' then
    if not M.deck_development then return nil,'Deck development module is unavailable.' end
    local changed,reason=M.deck_development.apply(state,snapshot,d,targets,owned)
    if not changed then return nil,reason end
  end
  local set=d.kind=='planet' and 'Planet' or (d.kind=='all_hands' or d.kind=='seal' or d.kind=='copy') and 'Spectral' or 'Tarot'
  if ability.set and ability.set~=set then return nil,'Modified consumable type is not modeled.' end
  state.consumeable_usage_total=state.consumeable_usage_total or {}
  local usage=state.consumeable_usage_total
  usage[set:lower()]=number(usage[set:lower()])+1; usage.all=number(usage.all)+1
  if set=='Tarot' or set=='Planet' then usage.tarot_planet=number(usage.tarot_planet)+1; state.last_tarot_planet=owned.key end
  for _,j in ipairs(state.jokers or {}) do if not j.debuff and set=='Planet' and joker_name(j)=='Constellation' then
    j.ability=j.ability or {}; j.ability.x_mult=number(j.ability.x_mult,1)+number(j.ability.extra,0.1)
  end end
  if d.kind~='remove' and d.kind~='copy' then tally(state,snapshot,targets) end
  local tax=number((state.modifiers or {}).minus_hand_size_per_X_dollar)
  if tax>0 then state.hand_size=number(snapshot.hand_size,8)+math.floor(number(snapshot.dollars)/tax)-math.floor(number(state.dollars)/tax) end
  return state
end

-- A narrow, deterministic hand-phase stock transition. Fool first creates the
-- public last-used Jupiter; using that new card is a separate, freshly
-- observed action. The paired endpoint here is for strategic admission only.
local function finite_integer(v,minimum)
  return type(v)=='number' and v==v and v<math.huge and v%1==0 and v>=(minimum or 0)
end
local function fool_edition(card)
  local e=card.edition
  if e==nil then return false end
  if e=='negative' then return true end
  if type(e)~='table' or e.negative~=true then return nil end
  for k,v in pairs(e) do
    if (k~='negative' and k~='type') or k=='type' and v~='negative' then return nil end
  end
  return true
end
local function plain_fool(card)
  if type(card)~='table' or card.key~='c_fool' or card.debuff or card.face_down or card.unknown or
      card.identity_redacted or card.concealed or card.pinned or card.seal or card.enhancement or
      type(card.id)~='string' or card.id=='' or fool_edition(card)==nil then return false end
  local a=card.ability or {}
  if type(a)~='table' then return false end
  if a.name~='The Fool' or a.set~='Tarot' or not finite_integer(a.order,0) or
      type(a.consumeable)~='table' or next(a.consumeable) then return false end
  local defaults={bonus=0,d_size=0,extra_value=0,h_dollars=0,h_mult=0,h_size=0,h_x_mult=0,
    mult=0,p_dollars=0,perma_bonus=0,t_chips=0,t_mult=0,x_mult=1,type='',effect='Disable Blind Effect'}
  for key,value in pairs(a) do
    if defaults[key]~=nil then if value~=defaults[key] then return false end
    elseif key~='consumeable' and key~='name' and key~='set' and key~='order' and key~='hands_played_at_create' then
      return false
    end
  end
  return true
end
local function exact_jupiter_source(source)
  if type(source)~='table' or source.schema~='fool_last_center_v1' or
      source.key~='c_jupiter' or source.name~='Jupiter' or source.set~='Planet' or
      source.effect~='Hand Upgrade' or source.unlocked==false or
      not finite_integer(source.order,0) or type(source.cost)~='number' or
      source.cost~=source.cost or source.cost<0 or math.abs(source.cost)==math.huge or
      type(source.config)~='table' or
      source.config.hand_type~='Flush' then return false end
  for key in pairs(source.config) do if key~='hand_type' then return false end end
  return true
end
local function plain_jupiter(card)
  if type(card)~='table' or card.key~='c_jupiter' or card.edition or card.debuff or card.face_down or
      card.unknown or card.identity_redacted or card.concealed or card.seal or card.enhancement or
      type(card.id)~='string' or card.id=='' then return false end
  local a=card.ability or {}
  if type(a)~='table' then return false end
  local config=a.consumeable
  if a.name~='Jupiter' or a.set~='Planet' or a.effect~='Hand Upgrade' or
      not finite_integer(a.order,0) or type(config)~='table' or config.hand_type~='Flush' then return false end
  for key in pairs(config) do if key~='hand_type' then return false end end
  for _,key in ipairs({'h_size','d_size','mult','h_mult','h_x_mult','h_dollars','p_dollars',
      't_mult','t_chips','bonus','extra_value','perma_bonus'}) do
    if a[key]~=nil and a[key]~=0 then return false end
  end
  if a.x_mult~=nil and a.x_mult~=1 then return false end
  return true
end
local fool_safe_jokers={j_yorick=true,j_perkeo=true,j_ride_the_bus=true,j_mail=true,
  j_delayed_grat=true,j_blueprint=true,j_brainstorm=true}
local function fool_stock_scope(snapshot)
  if snapshot.phase~='hand' or snapshot.teacher_profile~='perkeo_yorick_win_v1' or
      #(snapshot.consumeables or {})>64 or #(snapshot.jokers or {})==0 or
      (snapshot.used_vouchers or {}).v_observatory or (snapshot.vouchers or {}).v_observatory or
      not finite_integer(snapshot.consumable_limit,0) or
      not finite_integer(snapshot.consumeable_buffer or 0,0) or (snapshot.consumeable_buffer or 0)~=0 or
      #(snapshot.consumeables or {})>snapshot.consumable_limit then return false end
  local perkeo=false
  for _,j in ipairs(snapshot.jokers or {}) do
    if type(j)~='table' or j.unknown or j.identity_redacted or j.face_down or not fool_safe_jokers[j.key] then return false end
    if j.key=='j_perkeo' and not j.debuff then perkeo=true end
  end
  if not perkeo then return false end
  local ids={}
  for _,c in ipairs(snapshot.consumeables or {}) do
    if type(c)~='table' or type(c.id)~='string' or c.id=='' or ids[c.id] then return false end
    ids[c.id]=true
  end
  if snapshot.consumeable_usage~=nil and type(snapshot.consumeable_usage)~='table' then return false end
  local totals=snapshot.consumeable_usage_total
  if type(totals)~='table' then return false end
  for _,key in ipairs({'tarot','planet','spectral','tarot_planet','all'}) do
    if not finite_integer(totals[key],0) then return false end
  end
  local h=(snapshot.hands or {}).Flush
  return type(h)=='table' and finite_integer(h.level,1) and finite_integer(h.played,1) and
    type(h.chips)=='number' and h.chips>0 and h.chips<math.huge and
    type(h.mult)=='number' and h.mult>0 and h.mult<math.huge and
    type(h.l_chips)=='number' and h.l_chips>0 and h.l_chips<math.huge and
    type(h.l_mult)=='number' and h.l_mult>0 and h.l_mult<math.huge
end

function M.project_fool_jupiter(snapshot,index)
  if not fool_stock_scope(snapshot) or snapshot.last_tarot_planet~='c_jupiter' or
      not exact_jupiter_source(snapshot.fool_source) then return nil,'Fool/Jupiter public hand scope is unavailable.' end
  local held=snapshot.consumeables;local fool=held[index]
  if not plain_fool(fool) then return nil,'Only a visible unmodified Fool is admitted.' end
  local negative=fool_edition(fool)
  -- Source creation precedes removal of a Negative card's extra slot. A full
  -- Negative Fool would settle one card over capacity; never claim that it is
  -- a within-capacity intermediate endpoint.
  if #held>snapshot.consumable_limit-(negative and 1 or 0) then
    return nil,'The copied Jupiter would settle over Negative capacity.'
  end
  local old_fool_uses=(snapshot.consumeable_usage or {}).c_fool
  if old_fool_uses~=nil and type(old_fool_uses)~='table' then return nil,'Fool use history is malformed.' end
  local before_uses=(old_fool_uses or {}).count or 0
  if not finite_integer(before_uses,0) then return nil,'Fool use count is incomplete.' end
  local generated_id='fool-cycle:'..fool.id..':'..tostring(before_uses+1)
  for _,c in ipairs(held) do if c.id==generated_id then return nil,'Generated identity collides with inventory.' end end
  local after=copy(snapshot)
  table.remove(after.consumeables,index)
  if negative then after.consumable_limit=after.consumable_limit-1 end
  local source=snapshot.fool_source
  after.consumeables[#after.consumeables+1]={id=generated_id,key='c_jupiter',name='Jupiter',
    debuff=false,face_down=false,ability={name='Jupiter',set='Planet',effect='Hand Upgrade',
      order=source.order,consumeable=copy(source.config)}}
  after.last_tarot_planet='c_fool'
  after.consumeable_usage=after.consumeable_usage or {}
  after.consumeable_usage.c_fool={count=before_uses+1,order=(fool.ability or {}).order,set='Tarot'}
  local totals=after.consumeable_usage_total or {}
  for _,key in ipairs({'tarot','tarot_planet','all'}) do totals[key]=number(totals[key])+1 end
  after.consumeable_usage_total=totals
  local endpoint,why=M.apply(after,#after.consumeables,{})
  if not endpoint then return nil,why end
  local old_jupiter_uses=(snapshot.consumeable_usage or {}).c_jupiter
  if old_jupiter_uses~=nil and type(old_jupiter_uses)~='table' then return nil,'Jupiter use history is malformed.' end
  local prior=(old_jupiter_uses or {}).count or 0
  if not finite_integer(prior,0) then return nil,'Jupiter use count is incomplete.' end
  endpoint.consumeable_usage=endpoint.consumeable_usage or {}
  endpoint.consumeable_usage.c_jupiter={count=prior+1,order=source.order,set='Planet'}
  if endpoint.last_tarot_planet~='c_jupiter' or
      endpoint.hands.Flush.level~=(snapshot.hands or {}).Flush.level+1 or
      #endpoint.consumeables~=#held-1 or endpoint.consumable_limit~=after.consumable_limit then
    return nil,'Fool/Jupiter endpoint did not conserve hand, stock or capacity.'
  end
  return after,endpoint,{fool_id=fool.id,generated_id=generated_id,negative=negative,
    inventory_before=#held,inventory_after=#endpoint.consumeables,
    capacity_before=snapshot.consumable_limit,capacity_after=endpoint.consumable_limit}
end

-- This is a strategic one-cycle comparison, not a score forecast or a chained
-- executable command. The next observed Jupiter use is reconsidered below.
function M.fool_jupiter_stock(snapshot,strategy,result)
  if not strategy or not strategy.build_profile or not strategy.development_gain or
      not strategy.preservation_cost or not strategy.inventory_value or
      not result or not result.action or result.action.kind~='play' or
      not result.play or result.play.legal==false or result.play.uncertain or
      result.play.hand~='Flush' or type(result.play.score)~='number' or
      result.play.score~=result.play.score or result.play.score==math.huge then return end
  local remaining=math.max(1,number((snapshot.blind or {}).chips)-number(snapshot.chips))
  if result.play.score>=remaining then return end
  local profile=strategy.build_profile(snapshot)
  if not profile or profile.hand~='Flush' or profile.horizon<=0 or not fool_stock_scope(snapshot) then return end
  local old,old_info=strategy.inventory_value(snapshot,nil,{profile=profile})
  if type(old)~='number' or old~=old or old==math.huge or not old_info or old_info.approximate then return end
  local best,seen_fools=nil,{}
  for index,card in ipairs(snapshot.consumeables or {}) do
    local endpoint,first,steps
    if snapshot.last_tarot_planet=='c_jupiter' and card.key=='c_fool' then
      local kind=fool_edition(card)
      local category=plain_fool(card) and tostring(kind)..':'..tostring(card.sell_cost)
      if category and not seen_fools[category] then
        seen_fools[category]=true
        first,endpoint,steps=M.project_fool_jupiter(snapshot,index)
      end
    elseif snapshot.last_tarot_planet=='c_fool' and plain_jupiter(card) then
      endpoint=M.apply(snapshot,index,{})
    end
    if endpoint then
      local new,new_info=strategy.inventory_value(snapshot,endpoint.consumeables,{profile=profile})
      local loss=strategy.preservation_cost(snapshot,endpoint,index)
      local gain=strategy.development_gain(snapshot,endpoint,{},profile)
      local cost=first and 4 or 2
      -- Direct value of the used card becomes the permanent hand upgrade;
      -- retained/future pool value, cash opportunity and action time remain.
      local sale_value=type(card.sell_cost)=='number' and card.sell_cost==card.sell_cost and
        card.sell_cost<math.huge and math.max(0,card.sell_cost) or 0
      local merit=gain-loss-cost-sale_value
      -- A last Jupiter may be worth using to reset Fool's copy target. The
      -- measured future-pool loss is charged instead of a blanket type veto.
      if type(new)=='number' and new==new and new<math.huge and new_info and not new_info.approximate and
          type(loss)=='number' and loss==loss and loss>=0 and loss<math.huge and
          type(gain)=='number' and gain==gain and gain>0 and gain<math.huge and merit>0 and merit<math.huge and
          (not best or merit>best.merit or merit==best.merit and index<best.index) then
        best={index=index,merit=merit,gain=gain,loss=loss,first=not not first,
          steps=steps,endpoint_level=endpoint.hands.Flush.level,stock_before=old,stock_after=new}
      end
    end
  end
  if not best then return end
  local action={kind='use',area='consumeables',index=best.index,targets={}}
  local title=best.first and 'Use Fool to make Jupiter' or 'Use Jupiter to develop Flush'
  return {title=title,action=action,warnings={},lines={
    'The public one-cycle endpoint improves the played main Flush after whole-inventory and action costs.',
    'Refresh after this single use; the next card and current score must be checked again.'},
    fool_jupiter_stock={complete=true,phase='hand',step=best.first and 'fool' or 'jupiter',
      merit=best.merit,development_gain=best.gain,preservation_cost=best.loss,
      endpoint_flush_level=best.endpoint_level,stock_before=best.stock_before,
      stock_after=best.stock_after,capacity=best.steps,
      scope='One deterministic public Fool/Jupiter stock cycle; no future draw or clear is promised.'}}
end

-- Cheap development beside an already verified clear. Choose one target set
-- per type from the shared deck profile, then rescore only the known play.
-- No subset search, draw rollout, or multi-use sequence enters this path.
function M.develop(snapshot,scorer,baseline,options)
  options=options or {}
  local strategy=options.strategy
  local diagnostics={warnings={},retention_reasons={},evaluated_candidates=0,bounded_development=true,
    baseline_floor_evaluations=0}
  local evaluations=0
  local function done(value) diagnostics.evaluations=evaluations;return value,evaluations,diagnostics end
  local remaining=math.max(1,number((snapshot.blind or {}).chips)-number(snapshot.chips))
  local function finite_score(play)
    return play and type(play.score)=='number' and play.score==play.score and play.score>=remaining and play.score<math.huge
  end
  local function floor_supported(play)
    if not finite_score(play) or play.legal==false or play.uncertain==true or
        play.reliable_bound~=true or play.bound_kind~='supported_random_floor' then return false end
    for _,message in ipairs(play.warnings or {}) do if message:find('Unmodeled',1,true) then return false end end
    return true
  end
  if not strategy or not strategy.build_profile or not baseline or baseline.legal==false or
      not finite_score(baseline) or not baseline.indices then return done() end
  local profile=strategy.build_profile(snapshot)
  if profile.horizon<=0 or #(snapshot.hand or {})>20 then return done() end
  local cap=math.min(6,math.max(0,math.floor(number(options.max_development_evaluations,6))))
  if baseline.uncertain then
    if cap<1 or type(scorer.lower_bound)~='function' then return done() end
    evaluations=evaluations+1;diagnostics.baseline_floor_evaluations=1
    local floor=scorer.lower_bound(snapshot,baseline.indices)
    diagnostics.baseline_floor_verified=floor_supported(floor) or false
    if not diagnostics.baseline_floor_verified then return done() end
    diagnostics.baseline_floor_score=floor.score
  end
  local preservation
  local best,seen=nil,{}
  for index,owned in ipairs(snapshot.consumeables or {}) do
    local d=definition(owned)
    if d and not owned.debuff and not seen[d.key] and evaluations<cap then
      seen[d.key]=true
      if d.kind~='hermit' and d.kind~='temperance' and d.kind~='generator' and
          (not options.discard_preparation or options.discard_preparation.min_count==0 or d.kind=='death') then
        local deck_action=M.deck_development and M.deck_development.supports(owned.key)
        local targets,hand_order
        if deck_action then targets=M.deck_development.targets(snapshot,owned,profile,baseline,strategy)
        else local why;targets,why,hand_order=strategy.development_targets(snapshot,owned,profile) end
        local working,clear_indices=snapshot,baseline.indices
        if hand_order then
          -- A better source left of its recipient needs a real reorder first.
          -- Prove that exact order and endpoint, then publish only the reorder.
          working=copy(snapshot);working.hand={};local map={}
          for i,old in ipairs(hand_order) do working.hand[i]=snapshot.hand[old];map[old]=i end
          clear_indices={};for i,old in ipairs(baseline.indices) do clear_indices[i]=map[old] end
          table.sort(clear_indices)
          targets=strategy.development_targets(working,owned,profile)
          if evaluations+2>cap then targets=nil
          else
            evaluations=evaluations+1
            local reordered=scorer.lower_bound and scorer.lower_bound(working,clear_indices) or scorer.score(working,clear_indices)
            if not finite_score(reordered) or reordered.legal==false or reordered.uncertain or
                scorer.lower_bound and not floor_supported(reordered) then targets=nil end
          end
        end
        if targets then
          local state=M.apply(working,index,targets)
          if state then
            local gain=deck_action and M.deck_development.gain(working,state,targets,profile,strategy,owned,baseline) or
              strategy.development_gain(working,state,targets,profile)
            if not preservation and strategy.preservation_context then
              preservation=strategy.preservation_context(snapshot,profile)
            end
            local cost,reason,last
            if preservation then cost,reason,last=strategy.preservation_cost(snapshot,state,index,preservation)
            else cost,reason,last=strategy.preservation_cost(snapshot,state,index) end
            if last and reason then diagnostics.retention_reasons[#diagnostics.retention_reasons+1]=reason end
            local merit=gain-cost-4-(hand_order and 2 or 0) -- real reorder plus use costs
            if not last and merit>0 then
              diagnostics.evaluated_candidates=diagnostics.evaluated_candidates+1
              local indices=d.kind=='remove' and M.deck_development.remap_indices(working,state,clear_indices) or clear_indices
              -- A Lucky enhancement need not trigger to preserve an existing
              -- clear. Use the supported floor in the same one-call slot; an
              -- uncertain average is never promoted to a proof of survival.
              local bounded=type(scorer.lower_bound)=='function'
              local play
              if indices then
                evaluations=evaluations+1
                if bounded then play=scorer.lower_bound(state,indices) else play=scorer.score(state,indices) end
              end
              local modeled=bounded and floor_supported(play) or not bounded and finite_score(play) and
                play.legal~=false and not play.uncertain
              for _,message in ipairs(play and play.warnings or {}) do if message:find('Unmodeled',1,true) then modeled=false end end
              -- Development must not introduce additional Glass break risk
              -- into this known finish. Compare raw exposure by physical hand
              -- index: search may already have weighted baseline.glass_loss.
              local exposure={}
              for _,entry in ipairs(baseline.glass_exposure or {}) do
                local c=snapshot.hand[entry.index];exposure[c and c.id or entry.index]=number(entry.probability)
              end
              for _,entry in ipairs(play and play.glass_exposure or {}) do
                local c=state.hand[entry.index]
                if number(entry.probability)>number(exposure[c and c.id or entry.index])+0.000001 then modeled=false end
              end
              if modeled and options.arm_cost and strategy then
                modeled=options.arm_cost(state,play.hand)<=options.arm_cost(snapshot,baseline.hand)
              end
              local preparation,prepared_indices
              local prep=options.discard_preparation
              if d.kind=='death' and prep and prep.modules and prep.modules.growth and
                  number(snapshot.discards_left)>0 and evaluations<cap and number(prep.max_evaluations)>0 then
                -- A real copy can create a smaller rank hand. Prove the full
                -- discard endpoint using held cards only, then execute just
                -- the copy (or its necessary reorder) and refresh afterward.
                local rank=state.hand[targets[2]].rank or (state.hand[targets[2]].base or {}).id
                local group={}
                for i,c in ipairs(state.hand) do
                  if not c.unknown and not c.identity_redacted and not c.face_down and
                      (c.rank or (c.base or {}).id)==rank then group[#group+1]=i end
                end
                for size=2,math.min(3,#group,#baseline.indices-1) do
                  if evaluations>=cap or #state.hand-size<=number(prep.min_count) then break end
                  local compact_indices={};for i=1,size do compact_indices[i]=group[i] end
                  evaluations=evaluations+1
                  local compact=scorer.lower_bound and scorer.lower_bound(state,compact_indices) or scorer.score(state,compact_indices)
                  local safe=scorer.lower_bound and floor_supported(compact) or not scorer.lower_bound and
                    finite_score(compact) and compact.legal~=false and not compact.uncertain
                  local previously_played={};for _,i in ipairs(clear_indices) do previously_played[i]=true end
                  for _,i in ipairs(compact_indices) do
                    local held=working.hand[i]
                    if held and not previously_played[i] and not held.debuff and
                        (held.enhancement=='m_gold' or held.seal=='Blue') then safe=false end
                  end
                  for _,entry in ipairs(compact and compact.glass_exposure or {}) do
                    local c=state.hand[entry.index]
                    if number(entry.probability)>number(exposure[c and c.id or entry.index])+0.000001 then safe=false end
                  end
                  if safe and options.arm_cost then safe=options.arm_cost(state,compact.hand)<=options.arm_cost(snapshot,baseline.hand) end
                  local search=prep.modules.search
                  if safe and search and search.population_cost and search.population_profile then
                    compact.indices=compact_indices
                    safe=search.population_cost(state,compact,search.population_profile(state))<=
                      search.population_cost(snapshot,baseline,search.population_profile(snapshot))+0.000000001
                  end
                  local allowance=math.min(cap-evaluations,number(prep.max_evaluations)-number(diagnostics.discard_preparation_evaluations))
                  if safe and allowance>0 then
                    compact.indices=compact_indices
                    local plan,work=prep.modules.growth.suggest(state,prep.modules,compact,
                      {exhaust_discards=true,max_evaluations=allowance})
                    evaluations=evaluations+number(work)
                    diagnostics.discard_preparation_evaluations=number(diagnostics.discard_preparation_evaluations)+number(work)
                    if plan and plan.action.kind=='discard' and #plan.action.indices>number(prep.min_count) then
                      preparation={cards=#plan.action.indices,anchor_cards=size,retained_score=plan.play.score,
                        source_id=state.hand[targets[2]].id,target_id=state.hand[targets[1]].id,
                        scope='copy then supported retained discard; fresh observation required',
                        future_draw_assumed=false,growth_evaluations=number(work)}
                      compact.indices=compact_indices;prepared_indices=compact_indices;play=compact;modeled=true;break
                    end
                  end
                end
              end
              if prep and number(prep.min_count)>0 and not preparation then modeled=false end
              if modeled and (not best or merit>best.merit) then
                play=copy(play);play.indices=list(prepared_indices or indices)
                best={index=index,targets=targets,definition=d,play=play,merit=merit,bounded=bounded,hand_order=hand_order,discard_preparation=preparation}
              end
            end
          end
        end
      end
    end
  end
  if not best then return done() end
  local lines={}
  if best.definition.kind=='death' then
    lines[#lines+1]='Copy hand card '..best.targets[2]..' (right) onto card '..best.targets[1]..' (left).'
  elseif #best.targets>0 then lines[#lines+1]='Target hand card'..(#best.targets>1 and 's ' or ' ')..table.concat(best.targets,', ')..'.' end
  lines[#lines+1]='This develops '..(profile.rank and (value_name(profile.rank)..'s for ') or '')..profile.hand..' for later blinds.'
  lines[#lines+1]=best.discard_preparation and
    'A smaller winning rank hand supports a larger safe discard after this copy; refresh advice after the actual action.' or best.bounded and
    'The supported minimum for the same clearing play still clears without favorable random activations; refresh advice after using it.' or
    'The existing clearing play was rescored after the change and still clears; refresh advice after using it.'
  local development={utility=best.merit,hand=profile.hand,rank=profile.rank,discard_preparation=best.discard_preparation}
  if best.definition.kind=='death' then
    development.death=true;development.source_index=best.targets[2];development.target_index=best.targets[1]
    development.reorder_first=best.hand_order~=nil
  end
  if best.hand_order then
    return done({title='Arrange the strongest Death source on the right',lines={
      'The better source requires a hand reorder; the retained clear and subsequent copy were checked.',
      'Refresh after rearranging. Death is not used until the new hand is observed.'},warnings={},
      action={kind='reorder_hand',area='hand',order=list(best.hand_order)},development=development})
  end
  if best.bounded then
    development.bound_kind='supported_random_floor';development.conservative=true;development.deterministic_exact=false
  end
  return done({title='Use '..best.definition.name..' to develop the deck',lines=lines,warnings={},
    action={kind='use',area='consumeables',index=best.index,targets=list(best.targets)},play=best.play,
    development=development})
end

local function ordered_play_count(n,limit)
  local count,term=0,1
  for k=1,math.min(n,limit) do term=term*(n-k+1);count=count+term end
  return count
end
-- Revealing a generator is not a simulated transition or a promised rescue.
-- It is admitted only after every legal ordered play has a supported maximum
-- below the target, with no hands/discards left after that play. Unknown
-- inventory outcomes are deliberately absent from the returned recommendation.
local function generator_rescue(snapshot,scorer,search_result,options,maximum,evaluations,diagnostics,yield_fn)
  local round=snapshot.current_round or {}
  local terminal_teacher=snapshot.teacher_profile=='perkeo_yorick_win_v1'
  if number(snapshot.hands_left,number(round.hands_left))~=1 or
      number(snapshot.discards_left,number(round.discards_left))~=0 or not scorer.upper_bound then return nil,evaluations end
  for _,j in ipairs(snapshot.jokers or {}) do
    if j.key=='j_mr_bones' or (j.ability or {}).name=='Mr. Bones' or j.name=='Mr. Bones' then return nil,evaluations end
    -- Unknown generated types change the entire future copying pool. Removing
    -- a weak source alone can improve its value while revealing replacements
    -- dilutes it again, so a removal-only premium cannot justify this action.
    if not terminal_teacher and not j.debuff and
      (j.key=='j_perkeo' or (j.ability or {}).name=='Perkeo' or j.name=='Perkeo') then return nil,evaluations end
  end
  if diagnostics.truncated or diagnostics.sequence_truncated then return nil,evaluations end
  local hand_limit=snapshot.hand_limit
  if hand_limit~=nil and (type(hand_limit)~='number' or hand_limit%1~=0 or hand_limit<1 or hand_limit>5) then return nil,evaluations end
  local n,limit=#(snapshot.hand or {}),math.min(5,number(hand_limit,5))
  if n==0 or n>20 or limit<1 then return nil,evaluations end
  local equivalent=false
  if n>8 then
    if not scorer.upper_bound_order_independent then return nil,evaluations end
    local reason;equivalent,reason=scorer.upper_bound_order_independent(snapshot)
    if not equivalent then diagnostics.generator_order_reason=reason;return nil,evaluations end
  end
  local candidates={}
  for index,owned in ipairs(snapshot.consumeables or {}) do
    local d=definition(owned)
    if d and d.kind=='generator' and not owned.debuff then
      local a=owned.ability or {};local config=a.consumeable or {}
      local field=d.value=='Tarot' and 'tarots' or d.value=='Planet' and 'planets' or nil
      local count=d.value=='Joker' and 1 or config[field]
      local negative=owned.edition=='negative' or type(owned.edition)=='table' and owned.edition.negative
      local capacity=snapshot.consumable_limit
      local valid=type(capacity)=='number' and capacity>=0 and capacity<math.huge and capacity%1==0 and
        type(count)=='number' and count>=1 and count<=2 and count%1==0 and
        (not a.name or a.name==d.name) and (not a.set or a.set=='Tarot') and not owned.face_down and
        capacity-(negative and 1 or 0)>=0
      for key in pairs(config) do if key~=field then valid=false end end
      if valid then
        -- Source use_card removes the owned card and its Negative slot before
        -- generation tests capacity. A full ordinary inventory frees one slot.
        local available=capacity-(negative and 1 or 0)-(#snapshot.consumeables-1)
        if d.value=='Joker' then
          local joker_limit=snapshot.joker_limit
          available=type(joker_limit)=='number' and joker_limit>=0 and joker_limit<math.huge and
            joker_limit%1==0 and joker_limit-#(snapshot.jokers or {}) or 0
        end
        local generated=math.min(count,math.max(0,available))
        if generated>0 then
          local after=copy(snapshot);table.remove(after.consumeables,index)
          after.consumable_limit=capacity-(negative and 1 or 0)
          local loss,reason,last=0,nil,false
          if options.strategy and options.strategy.preservation_cost then
            loss,reason,last=options.strategy.preservation_cost(snapshot,after,index)
          else
            for _,j in ipairs(snapshot.jokers or {}) do
              local name=(j.ability or {}).name or j.name
              if not j.debuff and (j.key=='j_perkeo' or name=='Perkeo' or j.key=='j_blueprint' or
                  name=='Blueprint' or j.key=='j_brainstorm' or name=='Brainstorm') then last=true end
            end
          end
          -- Only the complete losing ceiling below can waive future stock
          -- protection in win-first mode. Unknown generated cards are revealed
          -- by the real action; they are never inserted into a scored state.
          if terminal_teacher or not last and type(loss)=='number' and loss<=0.000001 then
            candidates[#candidates+1]={index=index,definition=d,count=generated}
          elseif reason then diagnostics.warnings[#diagnostics.warnings+1]=reason end
        end
      end
    end
  end
  if #candidates==0 then return nil,evaluations end
  local ordered_cost=ordered_play_count(n,limit)
  local cost=equivalent and count_plays(n,limit) or ordered_cost
  diagnostics.generator_ceiling={required_evaluations=cost,evaluations=0,complete=false,
    covered_ordered_plays=ordered_cost,order_equivalence=equivalent,
    enumeration=equivalent and 'all_plain_additive_subsets' or 'all_ordered_plays'}
  local certificate=diagnostics.generator_ceiling
  if evaluations+cost>maximum then
    certificate.reason='The remaining consumable budget cannot complete every ordered play.'
    return nil,evaluations
  end
  local remaining=math.max(1,number((snapshot.blind or {}).chips)-number(snapshot.chips))
  local chosen,used={},{}
  local supported,ceiling,legal,legal_ordered=true,0,0,0
  local permutations={1,2,6,24,120}
  local function inspect(indices)
      evaluations=evaluations+1;certificate.evaluations=certificate.evaluations+1
      if yield_fn and evaluations%32==0 then yield_fn(evaluations) end
      local bound=scorer.upper_bound(snapshot,indices)
      if not bound or not bound.reliable_bound then supported=false
      elseif bound.legal~=false then
        legal=legal+1;legal_ordered=legal_ordered+(equivalent and permutations[#indices] or 1)
        ceiling=math.max(ceiling,number(bound.score))
      end
  end
  local function walk()
    if #chosen>0 then inspect(chosen) end
    if #chosen>=limit then return end
    for i=1,n do if not used[i] then
      used[i]=true;chosen[#chosen+1]=i;walk();chosen[#chosen]=nil;used[i]=nil
    end end
  end
  if equivalent then combinations(n,limit,inspect) else walk() end
  certificate.complete=true;certificate.supported=supported;certificate.legal_plays=legal_ordered
  certificate.legal_comparisons=legal;certificate.ceiling=ceiling
  if not supported then certificate.reason='At least one immediate maximum has unsupported mechanics.';return nil,evaluations end
  if ceiling>=remaining then certificate.reason='A supported random maximum can still reach the target.';return nil,evaluations end
  -- More public cards provide more choices; stable inventory order breaks ties.
  table.sort(candidates,function(a,b) if a.count~=b.count then return a.count>b.count end;return a.index<b.index end)
  local best=candidates[1]
  return {title='Use '..best.definition.name..' for a last-hand chance',
    lines={'No immediate play reaches the remaining target within the supported score maximum.',
      'Reveal '..best.count..' '..best.definition.value..' card'..(best.count==1 and '' or 's')..', then recalculate before playing.'},
    warnings={'Generated cards and any rescue chance are unknown; this use does not guarantee a clear.'},
    action={kind='use',area='consumeables',index=best.index,targets={}},
    generator={set=best.definition.value,count=best.count,immediate_ceiling=ceiling,
      complete_ordered_plays=ordered_cost,ceiling_evaluations=cost,order_equivalence=equivalent,
      public_replan=true,terminal_teacher_override=terminal_teacher}},evaluations
end

function M.suggest(snapshot, scorer, search_result, yield_fn, options)
  options=options or {}; search_result=search_result or {}
  local maximum=math.max(0,math.min(25000,math.floor(number(options.max_evaluations,25000))))
  local evaluations, diagnostics=0,{warnings={},truncated=false,supported_candidates=0,evaluated_candidates=0,
    evaluated_sequences=0,sequence_candidates=0,physical_supported_candidates=0,
    duplicate_copies_skipped=0,duplicate_candidates_skipped=0}
  local warned={}
  local function warn(message)
    if not warned[message] then warned[message]=true; diagnostics.warnings[#diagnostics.warnings+1]=message end
  end
  if snapshot.phase and snapshot.phase~='hand' then return nil,0,diagnostics end
  local safe=search_result.play
  if options.strategy and safe and safe.legal~=false and
      safe.score>=math.max(1,number((snapshot.blind or {}).chips)-number(snapshot.chips)) then
    local development_options={};for key,value in pairs(options) do development_options[key]=value end
    development_options.max_development_evaluations=math.min(maximum,6,
      math.max(0,math.floor(number(options.max_development_evaluations,6))))
    local use,work,development=M.develop(snapshot,scorer,safe,development_options)
    if not safe.uncertain or development.baseline_floor_verified then return use,work,development end
    -- A failed floor proof retains the existing ordinary policy, including its
    -- unresolved random-score limits, but cannot renew the spent allowance.
    evaluations=evaluations+work;diagnostics.development=development
  end
  local n=#(snapshot.hand or {}); local limit=math.min(5,snapshot.hand_limit or 5)
  if n==0 or limit<1 then return nil,evaluations,diagnostics end
  if n>20 then
    diagnostics.truncated=true
    warn('Consumable comparison skipped above 20 held cards; use the bounded play recommendation or inspect consumables manually.')
    return nil,evaluations,diagnostics
  end
  local cost=count_plays(n,limit)
  if evaluations+cost>maximum then
    diagnostics.truncated=true
    warn('Consumable comparison skipped: the budget cannot finish one full play comparison for this hand size.')
    return nil,evaluations,diagnostics
  end
  local groups,previous_owned,previous_group={},nil,nil
  for index,owned in ipairs(snapshot.consumeables or {}) do
    local d=definition(owned)
    local group
    if not d then warn('Not simulated: '..tostring(owned.name or (owned.ability or {}).name or owned.key)..' (unsupported consumable).')
    elseif not owned.debuff and d.kind~='generator' then
      if previous_group and equivalent_owned(owned,previous_owned) then
        group=previous_group
        diagnostics.duplicate_copies_skipped=diagnostics.duplicate_copies_skipped+1
        diagnostics.duplicate_candidates_skipped=diagnostics.duplicate_candidates_skipped+#group
      else
        local config=(owned.ability or {}).consumeable or {}
        group={}; groups[#groups+1]=group
        if d.maximum==0 then group[1]={index=index,targets={},definition=d}
        else combinations(n,math.min(d.maximum,number(config.max_highlighted,d.maximum),limit),function(indices)
          if #indices>=math.max(d.minimum,number(config.min_highlighted,d.minimum)) then
            group[#group+1]={index=index,targets=list(indices),definition=d}
          end
        end) end
        -- Inspect simple targets before larger transformations, distributing a
        -- bounded budget across distinct inventory choices instead of copies.
        table.sort(group,function(a,b)
          if #a.targets~=#b.targets then return #a.targets<#b.targets end
          return table.concat(a.targets,',')<table.concat(b.targets,',')
        end)
        diagnostics.supported_candidates=diagnostics.supported_candidates+#group
      end
      diagnostics.physical_supported_candidates=diagnostics.physical_supported_candidates+#group
    end
    previous_owned,previous_group=owned,group
  end
  local candidates,depth={},1
  while true do
    local added=false
    for _,group in ipairs(groups) do if group[depth] then candidates[#candidates+1]=group[depth]; added=true end end
    if not added then break end; depth=depth+1
  end
  local remaining=math.max(1,number((snapshot.blind or {}).chips)-number(snapshot.chips))
  local baseline=search_result.play
  local baseline_score=baseline and baseline.score or 0
  local function supported_clear(play)
    return play and play.legal~=false and play.score>=remaining and (not play.uncertain or
      play.reliable_bound==true and play.bound_kind=='supported_random_floor')
  end
  local function floor_diagnostics()
    if diagnostics.floor_checks==nil then
      diagnostics.floor_checks=0;diagnostics.floor_candidates=0;diagnostics.floor_verified=0
      diagnostics.floor_limit_per_state=4;diagnostics.floor_coverage='complete_shortlist'
    end
  end
  local function certify_floor(state,play,work_limit)
    if not play or not play.uncertain or type(play.score)~='number' or play.score~=play.score or
        play.score<remaining or play.score==math.huge or options.score_bounds==false or
        type(scorer.lower_bound)~='function' then return end
    floor_diagnostics()
    diagnostics.floor_candidates=diagnostics.floor_candidates+1
    if evaluations>=work_limit then diagnostics.floor_coverage='partial';return end
    evaluations=evaluations+1;diagnostics.floor_checks=diagnostics.floor_checks+1
    if yield_fn and evaluations%32==0 then yield_fn(evaluations) end
    local bound=scorer.lower_bound(state,play.indices)
    if not bound or bound.legal==false or bound.uncertain==true or bound.reliable_bound~=true or
        bound.bound_kind~='supported_random_floor' or type(bound.score)~='number' or
        bound.score~=bound.score or bound.score<remaining or bound.score==math.huge or bound.hand~=play.hand then return end
    for _,message in ipairs(bound.warnings or {}) do if message:find('Unmodeled',1,true) then return end end
    local result={};for k,v in pairs(bound) do result[k]=v end
    result.indices=list(play.indices);result.expected_score=play.score
    result.conservative=true;result.deterministic_exact=false
    result.arm_cost=play.arm_cost
    diagnostics.floor_verified=diagnostics.floor_verified+1
    return result
  end
  if baseline and baseline.indices then
    local bound=certify_floor(snapshot,baseline,maximum)
    if bound then baseline=bound;baseline_score=bound.score;diagnostics.baseline_floor_score=bound.score end
  end
  local clearing=supported_clear(baseline)
  local discard=search_result.kind=='discard' and search_result.discard or nil
  local blind=snapshot.blind or {}
  local arm=not blind.disabled and (blind.key=='bl_arm' or blind.name=='The Arm')
  local best, sequence_best, completed, one_card_clear = nil,nil,{},false
  local function better_play(a,b)
    if not b then return true end
    if supported_clear(a)~=supported_clear(b) then return supported_clear(a) and true or false end
    if supported_clear(a) and supported_clear(b) then
      if (a.arm_cost or 0)~=(b.arm_cost or 0) then return (a.arm_cost or 0)<(b.arm_cost or 0) end
      if #a.indices~=#b.indices then return #a.indices<#b.indices end
    end
    if a.score~=b.score then return a.score>b.score end
    return #a.indices<#b.indices
  end
  local function score_state(state,work_limit)
    work_limit=math.min(maximum,work_limit or maximum)
    local play,arm_costs=nil,{}
    local uncertain,total_uncertain={},0
    if #(state.hand or {})>20 or evaluations+count_plays(#(state.hand or {}),limit)>work_limit then
      diagnostics.truncated=true
      return nil,false
    end
    combinations(#(state.hand or {}),limit,function(indices)
      evaluations=evaluations+1
      if yield_fn and evaluations%32==0 then yield_fn(evaluations) end
      local score=scorer.score(state,indices)
      if score and score.legal~=false then
        score.indices=list(indices)
        if options.arm_cost then
          if arm_costs[score.hand]==nil then arm_costs[score.hand]=options.arm_cost(state,score.hand) end
          score.arm_cost=arm_costs[score.hand]
        elseif arm then score.arm_cost=number(((state.hands or {})[score.hand] or {}).level,1)>1 and 1 or 0 end
        if better_play(score,play) then play=score end
        if score.uncertain and type(score.score)=='number' and score.score==score.score and
            score.score>=remaining and score.score<math.huge then
          total_uncertain=total_uncertain+1
          uncertain[#uncertain+1]=score
          table.sort(uncertain,function(a,b)
            if a.score~=b.score then return a.score>b.score end
            if #a.indices~=#b.indices then return #a.indices<#b.indices end
            for i=1,#a.indices do if a.indices[i]~=b.indices[i] then return a.indices[i]<b.indices[i] end end
            return false
          end)
          if #uncertain>4 then table.remove(uncertain) end
        end
      end
    end)
    -- Complete every mean-score subset first. Only then spend remaining
    -- allowance on the same deterministic top-four floor shortlist. No partial
    -- mean family or guessed success probability is published.
    if total_uncertain>0 and not supported_clear(play) then
      floor_diagnostics()
      diagnostics.floor_total_uncertain=(diagnostics.floor_total_uncertain or 0)+total_uncertain
      if options.score_bounds==false or type(scorer.lower_bound)~='function' then
        diagnostics.floor_coverage='unavailable'
      else
        if diagnostics.floor_coverage=='not_needed' then diagnostics.floor_coverage='complete_shortlist' end
        if total_uncertain>#uncertain then diagnostics.floor_coverage='partial' end
        for _,candidate in ipairs(uncertain) do
          local bound=certify_floor(state,candidate,work_limit)
          if bound and better_play(bound,play) then play=bound end
        end
      end
    end
    local modeled=true
    for _,message in ipairs(play and play.warnings or {}) do
      if message:find('Unmodeled',1,true) then modeled=false;warn(message) end
    end
    return play,modeled
  end
  local preservation
  local function evaluate_single(candidate,work_limit)
    local d=candidate.definition
    if not clearing or d.kind=='planet' or d.kind=='all_hands' then
      local state,reason=M.apply(snapshot,candidate.index,candidate.targets)
      if not state then warn(reason)
      else
        local play,modeled=score_state(state,work_limit)
        diagnostics.evaluated_candidates=diagnostics.evaluated_candidates+1
        candidate.play=play
        if modeled then
          completed[#completed+1]=candidate
          if d.kind=='planet' or d.kind=='all_hands' then candidate.state=state end
          if supported_clear(play) then one_card_clear=true end
        end
        if play and modeled then
          local score=play.score
          local permanent=d.kind=='planet' or d.kind=='all_hands'
          local safe_upgrade=permanent and score>baseline_score
          if clearing and arm and (not options.arm_cost or (play.arm_cost or 0)>(baseline.arm_cost or 0)) then safe_upgrade=false end
          local wins=supported_clear(play)
          local reference=math.max(baseline_score,discard and number(discard.mean) or 0)
          local useful=false
          if clearing then useful=safe_upgrade
          elseif wins then useful=not discard or number(discard.probability)<0.98 or safe_upgrade
          elseif (snapshot.hands_left or 1)>1 or play.uncertain and score>=remaining then
            useful=score>reference+math.max(10,reference*0.15) end
          local inventory_cost,retention,last_source=0,nil,false
          local development=0
          if options.strategy and options.strategy.preservation_cost then
            if not preservation and options.strategy.preservation_context then
              preservation=options.strategy.preservation_context(snapshot)
            end
            if preservation then
              inventory_cost,retention,last_source=options.strategy.preservation_cost(snapshot,state,candidate.index,preservation)
            else inventory_cost,retention,last_source=options.strategy.preservation_cost(snapshot,state,candidate.index) end
            local owned=(snapshot.consumeables or {})[candidate.index]
            if M.deck_development and M.deck_development.supports(owned.key) then
              development=M.deck_development.gain(snapshot,state,candidate.targets,
                preservation and preservation.profile or options.strategy.build_profile(snapshot),options.strategy,owned)
            elseif preservation then
              development=options.strategy.development_gain(snapshot,state,candidate.targets,preservation.profile)
            else development=options.strategy.development_gain(snapshot,state,candidate.targets) end
            local rescue=wins and not play.uncertain and not clearing and
              (not discard or number(discard.probability)<0.98)
            candidate.retention_exception=last_source and rescue
            if last_source and not rescue then useful=false end
            if useful and not rescue and inventory_cost>math.max(0,development)+math.max(0,score-reference)/math.max(1,remaining)*100 then useful=false end
            if not useful and retention then warn(retention) end
          end
          if useful then
            -- Securing this blind outranks surplus points; then favor a larger
            -- useful improvement and fewer changed cards on otherwise equal choices.
            candidate.value=(wins and 1000000000 or 0)+math.min(score,remaining)+(safe_upgrade and 0.25 or 0)+
              development*0.01-inventory_cost*0.01
            local prefer=not best
            if best and wins and supported_clear(best.play) and (play.arm_cost or 0)~=(best.play.arm_cost or 0) then
              prefer=(play.arm_cost or 0)<(best.play.arm_cost or 0)
            elseif best then prefer=candidate.value>best.value or (candidate.value==best.value and #candidate.targets<#best.targets) end
            if prefer then best=candidate end
          end
        end
      end
    end
  end

  -- Reserve a small number of whole comparisons only when a two-card rescue
  -- could matter. The permanent upgrade always goes first, so target indices
  -- remain in the current hand order and the follow-up can be recomputed.
  local has_upgrade,has_target=false,false
  for _,candidate in ipairs(candidates) do
    local d=candidate.definition
    if d.kind=='planet' or d.kind=='all_hands' then has_upgrade=true end
    if d.maximum>0 then has_target=true end
  end
  local resource=search_result.resource_comparison
  local protected=clearing or (discard and number(discard.probability)>=0.98) or
    (resource and number(resource.samples)>=4 and resource.best and number(resource.best.probability)>=0.98)
  local sequence_limit=math.max(0,math.min(8,math.floor(number(options.max_sequences,8))))
  local sequence_allowed=options.sequences~=false and not protected and has_upgrade and has_target and sequence_limit>0
  local reserve=sequence_allowed and math.min(sequence_limit,math.floor(maximum/cost/3)) or 0
  local single_limit=maximum-reserve*cost
  local next_candidate=1
  while next_candidate<=#candidates and evaluations+cost<=single_limit do
    evaluate_single(candidates[next_candidate],single_limit);next_candidate=next_candidate+1
  end

  if sequence_allowed and not one_card_clear and reserve>0 then
    local upgrades,targets={},{}
    for _,candidate in ipairs(completed) do
      if candidate.state then upgrades[#upgrades+1]=candidate
      elseif candidate.definition.maximum>0 then targets[#targets+1]=candidate end
    end
    table.sort(upgrades,function(a,b)
      local av,bv=a.play and a.play.score or 0,b.play and b.play.score or 0
      if av~=bv then return av>bv end
      return a.index<b.index
    end)
    table.sort(targets,function(a,b)
      local av,bv=a.play and a.play.score or 0,b.play and b.play.score or 0
      if av~=bv then return av>bv end
      if #a.targets~=#b.targets then return #a.targets<#b.targets end
      if a.index~=b.index then return a.index<b.index end
      return table.concat(a.targets,',')<table.concat(b.targets,',')
    end)
    -- Rank already completed single-use target comparisons, then interleave
    -- at most three upgrade starts. No factorial inventory/target enumeration.
    local starts=math.min(3,#upgrades)
    diagnostics.sequence_candidates=math.min(sequence_limit,starts*#targets)
    diagnostics.sequence_truncated=starts==0 or #targets==0 or #upgrades>starts or starts*#targets>sequence_limit
    local attempted=0
    for depth=1,math.min(sequence_limit,#targets) do
      for i=1,starts do
        if attempted>=sequence_limit or evaluations+cost>maximum then break end
        attempted=attempted+1
        local first,second=upgrades[i],targets[depth]
        local shifted=second.index-(second.index>first.index and 1 or 0)
        local state,reason=M.apply(first.state,shifted,second.targets)
        if not state then warn(reason)
        else
          local play,modeled=score_state(state)
          diagnostics.evaluated_sequences=diagnostics.evaluated_sequences+1
          -- Spending a second card requires a deterministic modeled rescue,
          -- not merely a higher mean from Lucky or other random scoring.
          if modeled and play and not play.uncertain and play.score>=remaining then
            local proposal={first=first,second=second,play=play,second_index=shifted}
            local prefer=not sequence_best
            if sequence_best then
              local a,b=play,sequence_best.play
              if (a.arm_cost or 0)~=(b.arm_cost or 0) then prefer=(a.arm_cost or 0)<(b.arm_cost or 0)
              elseif #second.targets~=#sequence_best.second.targets then prefer=#second.targets<#sequence_best.second.targets
              else prefer=false end
            end
            if prefer then sequence_best=proposal end
          end
        end
      end
      if attempted>=sequence_limit or evaluations+cost>maximum then break end
    end
    if diagnostics.evaluated_sequences<diagnostics.sequence_candidates then diagnostics.sequence_truncated=true end
  elseif sequence_allowed and not one_card_clear then
    diagnostics.sequence_truncated=true
  end
  -- If sequences were unnecessary or their shortlist left room, give the
  -- remaining budget back to single-card targets. A one-card clear always wins.
  while next_candidate<=#candidates and evaluations+cost<=maximum do
    evaluate_single(candidates[next_candidate]);next_candidate=next_candidate+1
  end
  if next_candidate<=#candidates then diagnostics.truncated=true end
  if diagnostics.sequence_truncated then
    warn('Two-consumable sequences were shortlisted within the shared budget; only complete play comparisons are reported.')
  end
  if diagnostics.floor_coverage=='partial' then
    warn('Score-floor checks were bounded; unverified random estimates are not treated as guaranteed clears.')
  end
  if diagnostics.truncated then warn('Consumable targets were shortlisted by the evaluation budget; every reported play was fully scored.') end
  if sequence_best and not one_card_clear then
    local first,second=sequence_best.first,sequence_best.second
    local warnings=list(diagnostics.warnings)
    for _,message in ipairs(sequence_best.play.warnings or {}) do if not warned[message] then warnings[#warnings+1]=message end end
    warnings[#warnings+1]='Only an upgrade followed by a supported targeted Tarot was searched; later draws and longer sequences are not modeled.'
    local target_text=table.concat(second.targets,', ')
    local followup=second.definition.kind=='death' and
      ('copy hand card '..second.targets[2]..' onto '..second.targets[1]) or ('target hand card'..(#second.targets>1 and 's ' or ' ')..target_text)
    return {title='Use '..first.definition.name..' to set up '..second.definition.name,
      lines={'This first use alone does not clear the blind.',
        'After it resolves, recalculate; the projected next step is '..second.definition.name..' ('..followup..').',
        'Together they enable '..sequence_best.play.hand..
          (sequence_best.play.bound_kind=='supported_random_floor' and ' with a supported minimum of ' or ' at ')..
          tostring(sequence_best.play.score)..' chips, reaching the remaining blind target.'},
      warnings=warnings,action={kind='use',area='consumeables',index=first.index,targets=list(first.targets)},
      play=first.play,sequence={play=sequence_best.play,second_name=second.definition.name,
        second_index=sequence_best.second_index,targets=list(second.targets)}},evaluations,diagnostics
  end
  if not best then
    local reveal;reveal,evaluations=generator_rescue(snapshot,scorer,search_result,options,maximum,evaluations,diagnostics,yield_fn)
    return reveal,evaluations,diagnostics
  end
  local warnings=list(diagnostics.warnings)
  for _,message in ipairs(best.play.warnings or {}) do if not warned[message] then warnings[#warnings+1]=message; warned[message]=true end end
  warnings[#warnings+1]='Every reported play is fully scored; later draws and consumable sequences outside the bounded upgrade-then-Tarot shortlist are not modeled.'
  local lines={}
  if #best.targets>0 then
    if best.definition.kind=='death' then lines[#lines+1]='Copy hand card '..best.targets[2]..' (right) onto card '..best.targets[1]..' (left).'
    else lines[#lines+1]='Target hand card'..(#best.targets>1 and 's ' or ' ')..table.concat(best.targets,', ')..'.' end
  end
  lines[#lines+1]='Then '..best.play.hand..
    (best.play.bound_kind=='supported_random_floor' and ' has a supported minimum of ' or ' is estimated at ')..
    tostring(best.play.score)..' chips.'
  if best.retention_exception then lines[#lines+1]='Spend the last copying source because this use provides the needed modeled clear.' end
  if best.play.bound_kind=='supported_random_floor' then
    lines[#lines+1]='The supported minimum score clears; random upside is not required.'
  elseif supported_clear(best.play) and not clearing then lines[#lines+1]='This reaches the remaining blind target within the supported score.'
  elseif best.play.uncertain then lines[#lines+1]='This is an uncertain score estimate, not a guaranteed clear.'
  elseif clearing then lines[#lines+1]='The permanent hand upgrade preserves the current clearing play.' end
  return {title='Use '..best.definition.name..' before playing',lines=lines,warnings=warnings,
    action={kind='use',area='consumeables',index=best.index,targets=list(best.targets)},play=best.play},evaluations,diagnostics
end

-- Cheap detached candidates for bounded mixed-action rescue. This never scores
-- or explores target combinations; the caller must prove the ensuing clear.
function M.rescue_candidates(snapshot,strategy,limit)
  local out={};limit=math.max(0,math.min(8,math.floor(number(limit,8))))
  if not strategy or not strategy.build_profile or #(snapshot.hand or {})>20 then return out end
  local profile=strategy.build_profile(snapshot);local seen={}
  for index,owned in ipairs(snapshot.consumeables or {}) do
    if #out>=limit then break end
    local d=definition(owned)
    if d and not owned.debuff and not seen[d.key] then
      seen[d.key]=true
      local targets
      if d.maximum==0 then targets={}
      elseif M.deck_development and M.deck_development.supports(d.key) then
        targets=M.deck_development.targets(snapshot,owned,profile,nil,strategy)
      else targets=strategy.development_targets(snapshot,owned,profile) end
      if targets then
        local state=M.apply(snapshot,index,targets)
        if state then out[#out+1]={state=state,index=index,targets=list(targets),name=d.name} end
      end
    end
  end
  return out
end
-- Joint resource policies reuse this exact owned-use implementation.
do
local install_resource_policy=function(Consumables)
local P={}
local min,max=math.min,math.max
local supported={c_magician=true,c_empress=true,c_heirophant=true,c_lovers=true,
  c_chariot=true,c_justice=true,c_devil=true,c_tower=true,c_star=true,c_moon=true,
  c_sun=true,c_world=true,c_strength=true,c_hanged_man=true}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function copy(v,seen)
  if type(v)~='table' then return v end
  seen=seen or {};if seen[v] then return seen[v] end
  local out={};seen[v]=out;for k,x in pairs(v) do out[k]=copy(x,seen) end;return out
end
local function public_state(state)
  local out=copy(state)
  -- The target rule may inspect public composition, never an internal sampled
  -- future sequence. Full population and deck are canonical identity lists.
  for _,field in ipairs({'deck','playing_cards','discard','play'}) do
    if type(out[field])=='table' then table.sort(out[field],function(a,b)
      return tostring(a.id)<tostring(b.id)
    end) end
  end
  return out
end
function P.admits(s)
  local h=s.hands_left or (s.current_round or {}).hands_left
  if not finite(h) or h%1~=0 or h<2 or h>4 or #(s.hand or {})<1 or #s.hand>8 or
    not finite(s.hand_size or #s.hand) or (s.hand_size or #s.hand)%1~=0 or
    (s.hand_size or #s.hand)<1 or (s.hand_size or #s.hand)>8 or
    #(s.consumeables or {})<1 or #s.consumeables>2 or
    next(s.jokers or {}) or (s.used_vouchers or {}).v_observatory or (s.vouchers or {}).v_observatory then return false end
  local capacity,buffer=s.consumable_limit,s.consumeable_buffer or 0
  if not finite(capacity) or capacity<0 or capacity%1~=0 or not finite(buffer) or buffer<0 or buffer%1~=0 or
    #s.consumeables+buffer>capacity then return false end
  local identities={}
  for _,card in ipairs(s.consumeables) do
    if type(card)~='table' or not supported[card.key] or card.debuff or card.face_down or card.unknown or card.concealed or
      not (type(card.id)=='string' and card.id~='' or finite(card.id)) or identities[tostring(card.id)] or
      card.edition~=nil and type(card.edition)~='table' and card.edition~='negative' then return false end
    identities[tostring(card.id)]=true
    if type(card.edition)=='table' then
      for key,value in pairs(card.edition) do if key~='negative' or value~=true then return false end end
    end
  end
  return true
end
local function targets_legal(state,targets)
  if type(targets)~='table' or #targets<1 then return false end
  for key in pairs(targets) do if not finite(key) or key%1~=0 or key<1 or key>#targets then return false end end
  local previous,selected=0,{}
  for _,index in ipairs(targets) do
    if not finite(index) or index%1~=0 or index<=previous or not state.hand[index] then return false end
    selected[index]=true;previous=index
  end
  for index,card in ipairs(state.hand) do
    if (card.ability or {}).forced_selection and not selected[index] then return false end
  end
  return true
end
function P.prepare(s,modules,result)
  if not P.admits(s) then return nil,'Ordinary targeted consumable timing requires one or two held cards, at most eight visible cards and two to four hands.' end
  local strategy=modules and modules.strategy
  if not Consumables.apply or not strategy or not strategy.build_profile or not strategy.development_targets or
    not strategy.development_gain or not strategy.preservation_cost then
    return nil,'Public target, development, inventory and exact-use dependencies are required.'
  end
  local ctx={maximum_uses=#s.consumeables,initial_inventory=copy(s.consumeables),first=nil}
  local incumbent=result and result.consumable
  if incumbent then
    local action=incumbent.action
    -- Reordering/compound product actions must keep their existing priority.
    if incumbent.sequence or type(action)~='table' or action.sequence or action.kind~='use' or action.area~='consumeables' or
      action.order or action.hand_order or incumbent.hand_order or not finite(action.index) or
      action.index%1~=0 or not s.consumeables[action.index] or not targets_legal(s,action.targets) then
      return nil,'The exact incumbent is outside ordinary use with its current target and hand order.'
    end
    ctx.first={kind='use',action=copy(action),index=action.index,targets=copy(action.targets),
      key='use:'..action.index..':'..table.concat(action.targets,',')}
  end
  function ctx.project(state,index,targets)
    if not targets_legal(state,targets) then return nil,'The proposed use is not legal in the current observed hand.' end
    local owned=(state.consumeables or {})[index]
    if not owned or not supported[owned.key] then return nil,'The proposed owned identity is unsupported.' end
    local after,why=Consumables.apply(state,index,targets)
    if not after then return nil,why end
    if #(after.consumeables or {})~=#state.consumeables-1 then return nil,'A use did not consume exactly one owned card.' end
    local negative=owned.edition=='negative' or type(owned.edition)=='table' and owned.edition.negative
    if not finite(after.consumable_limit) or after.consumable_limit~=state.consumable_limit-(negative and 1 or 0) or
      after.consumable_limit<0 or #after.consumeables+(after.consumeable_buffer or 0)>after.consumable_limit then
      return nil,'The owned use did not preserve exact legal inventory capacity.'
    end
    local cost,reason,last=strategy.preservation_cost(state,after,index)
    if not finite(cost) or cost<0 or last or cost>0.000001 then
      return nil,reason or 'The complete inventory preservation cost is unknown or positive.'
    end
    local targets_ids={};for _,i in ipairs(targets) do targets_ids[#targets_ids+1]=state.hand[i].id end
    return after,{kind='use',area='consumeables',index=index,targets=copy(targets),card_id=owned.id,
      card_key=owned.key,target_card_ids=targets_ids,dollars_before=state.dollars,dollars_after=after.dollars,
      inventory_before=#state.consumeables,inventory_after=#after.consumeables,
      capacity_before=state.consumable_limit,capacity_after=after.consumable_limit,
      population_before=#(state.playing_cards or {}),population_after=#(after.playing_cards or {}),
      preservation_cost=cost}
  end
  function ctx.propose(state,best_play)
    if #(state.consumeables or {})==0 then return false end
    local before,no_legal=best_play(state)
    if not before and not no_legal then return nil,'The current observed play comparison is incomplete.' end
    local current=before and before.score or 0
    if not finite(current) or current<0 then return nil,'The current public score is not finite.' end
    local public=public_state(state)
    local profile=strategy.build_profile(public)
    local best
    for index,owned in ipairs(public.consumeables or {}) do
      if not supported[owned.key] then return nil,'A later owned identity is outside the declared target rule.' end
      local targets,_,hand_order=strategy.development_targets(public,owned,profile)
      if hand_order then return nil,'A later target requires unmodeled hand ordering.' end
      if targets and targets_legal(state,targets) then
        local after,details=ctx.project(state,index,targets)
        if not after then return nil,details end
        local play,none=best_play(after)
        if not play and not none then return nil,'A proposed use has an incomplete observed play comparison.' end
        local score=play and play.score or 0
        if not finite(score) or score<0 then return nil,'A proposed use has an invalid public score.' end
        local gain
        local development=Consumables.deck_development
        if development and development.supports and development.supports(owned.key) then
          if not development.gain then return nil,'The removal development value is unavailable.' end
          gain=development.gain(public,public_state(after),targets,profile,strategy,owned)
        else gain=strategy.development_gain(public,public_state(after),targets,profile) end
        if not finite(gain) then return nil,'The public development value is not finite.' end
        local immediate=score>current+max(10,current*.15)
        if immediate or gain>0 then
          local candidate={index=index,targets=copy(targets),after=after,details=details,
            score=score,development_gain=gain,immediate_gain=score-current,
            basis=immediate and 'observed_scoring_gain' or 'positive_public_development'}
          if not best or candidate.score>best.score or candidate.score==best.score and
            (candidate.development_gain>best.development_gain or candidate.development_gain==best.development_gain and candidate.index<best.index) then best=candidate end
        end
      end
    end
    return best or false
  end
  return ctx
end
Consumables.resource_policy=P
return P
end

install_resource_policy(M)
end
return M
