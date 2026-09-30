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
    suit_nominal_original=old.suit_nominal_original}
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
    local id,face_down=destination.id,destination.face_down
    state.hand[left]=copy(source); state.hand[left].id=id; state.hand[left].face_down=face_down
    state.hand[left].base=copy(source.base or {}); state.hand[left].base.times_played=0
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

-- Cheap development beside an already verified clear. Choose one target set
-- per type from the shared deck profile, then rescore only the known play.
-- No subset search, draw rollout, or multi-use sequence enters this path.
function M.develop(snapshot,scorer,baseline,options)
  options=options or {}
  local strategy=options.strategy
  local diagnostics={warnings={},retention_reasons={},evaluated_candidates=0,bounded_development=true}
  local remaining=math.max(1,number((snapshot.blind or {}).chips)-number(snapshot.chips))
  if not strategy or not strategy.build_profile or not baseline or baseline.uncertain or
      baseline.legal==false or number(baseline.score)<remaining or not baseline.indices then return nil,0,diagnostics end
  local profile=strategy.build_profile(snapshot)
  if profile.horizon<=0 or #(snapshot.hand or {})>20 then return nil,0,diagnostics end
  local cap=math.min(6,math.max(0,math.floor(number(options.max_development_evaluations,6))))
  local best,seen=nil,{}
  for index,owned in ipairs(snapshot.consumeables or {}) do
    local d=definition(owned)
    if d and not owned.debuff and not seen[d.key] and diagnostics.evaluated_candidates<cap then
      seen[d.key]=true
      if d.kind~='hermit' and d.kind~='temperance' and d.kind~='generator' then
        local deck_action=M.deck_development and M.deck_development.supports(owned.key)
        local targets
        if deck_action then targets=M.deck_development.targets(snapshot,owned,profile,baseline,strategy)
        else targets=strategy.development_targets(snapshot,owned,profile) end
        if targets then
          local state=M.apply(snapshot,index,targets)
          if state then
            local gain=deck_action and M.deck_development.gain(snapshot,state,targets,profile,strategy,owned,baseline) or
              strategy.development_gain(snapshot,state,targets,profile)
            local cost,reason,last=strategy.preservation_cost(snapshot,state,index)
            if last and reason then diagnostics.retention_reasons[#diagnostics.retention_reasons+1]=reason end
            local merit=gain-cost-4 -- one extra action and consumable scarcity
            if not last and merit>0 then
              diagnostics.evaluated_candidates=diagnostics.evaluated_candidates+1
              local indices=d.kind=='remove' and M.deck_development.remap_indices(snapshot,state,baseline.indices) or baseline.indices
              local play=indices and scorer.score(state,indices)
              local modeled=play and play.legal~=false and not play.uncertain and play.score>=remaining
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
              if modeled and (not best or merit>best.merit) then
                play.indices=list(indices)
                best={index=index,targets=targets,definition=d,play=play,merit=merit}
              end
            end
          end
        end
      end
    end
  end
  if not best then return nil,diagnostics.evaluated_candidates,diagnostics end
  local lines={}
  if best.definition.kind=='death' then
    lines[#lines+1]='Copy hand card '..best.targets[2]..' (right) onto card '..best.targets[1]..' (left).'
  elseif #best.targets>0 then lines[#lines+1]='Target hand card'..(#best.targets>1 and 's ' or ' ')..table.concat(best.targets,', ')..'.' end
  lines[#lines+1]='This develops '..(profile.rank and (value_name(profile.rank)..'s for ') or '')..profile.hand..' for later blinds.'
  lines[#lines+1]='The existing clearing play was rescored after the change and still clears; refresh advice after using it.'
  return {title='Use '..best.definition.name..' to develop the deck',lines=lines,warnings={},
    action={kind='use',area='consumeables',index=best.index,targets=list(best.targets)},play=best.play,
    development={utility=best.merit,hand=profile.hand,rank=profile.rank}},diagnostics.evaluated_candidates,diagnostics
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
  if number(snapshot.hands_left,number(round.hands_left))~=1 or
      number(snapshot.discards_left,number(round.discards_left))~=0 or not scorer.upper_bound then return nil,evaluations end
  for _,j in ipairs(snapshot.jokers or {}) do
    if j.key=='j_mr_bones' or (j.ability or {}).name=='Mr. Bones' or j.name=='Mr. Bones' then return nil,evaluations end
    -- Unknown generated types change the entire future copying pool. Removing
    -- a weak source alone can improve its value while revealing replacements
    -- dilutes it again, so a removal-only premium cannot justify this action.
    if not j.debuff and (j.key=='j_perkeo' or (j.ability or {}).name=='Perkeo' or j.name=='Perkeo') then return nil,evaluations end
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
          if not last and type(loss)=='number' and loss<=0.000001 then
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
      public_replan=true}},evaluations
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
  if options.strategy and safe and not safe.uncertain and safe.legal~=false and
      safe.score>=math.max(1,number((snapshot.blind or {}).chips)-number(snapshot.chips)) then
    return M.develop(snapshot,scorer,safe,options)
  end
  local n=#(snapshot.hand or {}); local limit=math.min(5,snapshot.hand_limit or 5)
  if n==0 or limit<1 then return nil,0,diagnostics end
  if n>20 then
    diagnostics.truncated=true
    warn('Consumable comparison skipped above 20 held cards; use the bounded play recommendation or inspect consumables manually.')
    return nil,0,diagnostics
  end
  local cost=count_plays(n,limit)
  if cost>maximum then
    diagnostics.truncated=true
    warn('Consumable comparison skipped: the budget cannot finish one full play comparison for this hand size.')
    return nil,0,diagnostics
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
  local clearing=baseline and baseline_score>=remaining
  local discard=search_result.kind=='discard' and search_result.discard or nil
  local blind=snapshot.blind or {}
  local arm=not blind.disabled and (blind.key=='bl_arm' or blind.name=='The Arm')
  local best, sequence_best, completed, one_card_clear = nil,nil,{},false
  local function better_play(a,b)
    if not b then return true end
    if a.score>=remaining and b.score>=remaining then
      if (a.arm_cost or 0)~=(b.arm_cost or 0) then return (a.arm_cost or 0)<(b.arm_cost or 0) end
      if #a.indices~=#b.indices then return #a.indices<#b.indices end
    end
    if a.score~=b.score then return a.score>b.score end
    return #a.indices<#b.indices
  end
  local function score_state(state)
    local play,arm_costs=nil,{}
    if #(state.hand or {})>20 or evaluations+count_plays(#(state.hand or {}),limit)>maximum then
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
      end
    end)
    local modeled=true
    for _,message in ipairs(play and play.warnings or {}) do
      if message:find('Unmodeled',1,true) then modeled=false;warn(message) end
    end
    return play,modeled
  end
  local function evaluate_single(candidate)
    local d=candidate.definition
    if not clearing or d.kind=='planet' or d.kind=='all_hands' then
      local state,reason=M.apply(snapshot,candidate.index,candidate.targets)
      if not state then warn(reason)
      else
        local play,modeled=score_state(state)
        diagnostics.evaluated_candidates=diagnostics.evaluated_candidates+1
        candidate.play=play
        if modeled then
          completed[#completed+1]=candidate
          if d.kind=='planet' or d.kind=='all_hands' then candidate.state=state end
          if play and play.score>=remaining then one_card_clear=true end
        end
        if play and modeled then
          local score=play.score
          local permanent=d.kind=='planet' or d.kind=='all_hands'
          local safe_upgrade=permanent and score>baseline_score
          if clearing and arm and (not options.arm_cost or (play.arm_cost or 0)>(baseline.arm_cost or 0)) then safe_upgrade=false end
          local wins=score>=remaining
          local reference=math.max(baseline_score,discard and number(discard.mean) or 0)
          local useful=false
          if clearing then useful=safe_upgrade
          elseif wins then useful=not discard or number(discard.probability)<0.98 or safe_upgrade
          elseif (snapshot.hands_left or 1)>1 then useful=score>reference+math.max(10,reference*0.15) end
          local inventory_cost,retention,last_source=0,nil,false
          local development=0
          if options.strategy and options.strategy.preservation_cost then
            inventory_cost,retention,last_source=options.strategy.preservation_cost(snapshot,state,candidate.index)
            local owned=(snapshot.consumeables or {})[candidate.index]
            development=M.deck_development and M.deck_development.supports(owned.key) and M.deck_development.gain(snapshot,state,candidate.targets,
              options.strategy.build_profile(snapshot),options.strategy,owned) or options.strategy.development_gain(snapshot,state,candidate.targets)
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
            if best and wins and best.play.score>=remaining and (play.arm_cost or 0)~=(best.play.arm_cost or 0) then
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
    evaluate_single(candidates[next_candidate]);next_candidate=next_candidate+1
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
        'Together they enable '..sequence_best.play.hand..' at '..tostring(sequence_best.play.score)..' chips, reaching the remaining blind target.'},
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
  lines[#lines+1]='Then '..best.play.hand..' is estimated at '..tostring(best.play.score)..' chips.'
  if best.retention_exception then lines[#lines+1]='Spend the last copying source because this use provides the needed modeled clear.' end
  if best.play.score>=remaining and not clearing then lines[#lines+1]='This reaches the remaining blind target in the scoring model.'
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
