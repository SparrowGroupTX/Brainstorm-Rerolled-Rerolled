-- Bounded one-discard lookahead. The PRNG below is private to the advisor.
local M = {}
local function weight(key,default) return M.policy_weights and M.policy_weights.get(key) or default end
local EXACT_HAND_LIMIT = 20
local CONTINUATION_HAND_LIMIT = 12
local function clone(t) local r = {}; for k, v in pairs(t) do r[k] = v end; return r end
local function copy_list(t) local r = {}; for i, v in ipairs(t) do r[i] = v end; return r end
local function concealed(state)
  for _,card in ipairs(state.hand or {}) do if card.face_down then return true end end
  return false
end

-- The Arm's permanent downgrade has a cost after this blind. Among clears,
-- preserve the hand the run is built around rather than maximizing overkill.
local function arm_cost(state, category)
  local blind, hands = state.blind or {}, state.hands or {}
  if blind.disabled or (blind.key ~= 'bl_arm' and blind.name ~= 'The Arm') then return 0 end
  local hand = hands[category] or {}
  if (hand.level or 1) <= 1 then return 0 end
  local total, usage = 0, hand.played or 0
  for _, h in pairs(hands) do total = total + (h.played or 0) end
  local relevance = 1 + 4 * usage / math.max(1, total)
  for _, joker in ipairs(state.jokers or {}) do
    local a = joker.ability or {}
    if not joker.debuff and a.type == category then relevance = relevance + 2 end
    if not joker.debuff and (joker.key == 'j_trousers' or a.name == 'Spare Trousers')
      and (category == 'Two Pair' or category == 'Full House') then relevance = relevance + 2 end
  end
  -- Composition provides additional evidence when hand usage is sparse. This
  -- is a relevance heuristic, not a calibrated probability of drawing a hand.
  local ranks, suits, size, paired = {}, {}, 0, 0
  for _, card in ipairs(state.playing_cards or state.deck or {}) do
    if card.enhancement ~= 'm_stone' then
      local rank, suit = card.rank or (card.base or {}).id, card.suit
      if rank then ranks[rank] = (ranks[rank] or 0) + 1 end
      if suit then suits[suit] = (suits[suit] or 0) + 1 end
      size = size + 1
    end
  end
  for _, count in pairs(ranks) do paired = paired + count * (count - 1) end
  if category == 'Pair' or category == 'Two Pair' or category == 'Three of a Kind' or category == 'Four of a Kind' then
    relevance = relevance + 4 * paired / math.max(1, size * (size - 1))
  elseif category == 'Flush' or category == 'Straight Flush' then
    local largest = 0; for _, count in pairs(suits) do largest = math.max(largest, count) end
    relevance = relevance + 2 * largest / math.max(1, size)
  end
  local chips, mult = hand.chips or 0, hand.mult or 1
  local loss = chips * mult - math.max(0, chips - (hand.l_chips or 0)) * math.max(1, mult - (hand.l_mult or 0))
  return relevance * math.max(1, loss)
end
M.arm_cost = arm_cost

-- These continuations never spend a later discard. For an ordinary inventory,
-- crossed sampled worlds cannot justify overriding a useful discard with a
-- setup play while further discard decisions are still omitted. This is an
-- admission rule for that override, not a proof that either policy wins.
function M.resource_override_supported(s,prior,best)
  if prior.kind~='discard' or best.kind~='play' or (s.discards_left or 0)<=1 or
    #(s.jokers or {})>0 or (s.used_vouchers or {}).v_observatory or (s.vouchers or {}).v_observatory then return true end
  local before,after=prior.worlds,best.worlds
  local reason='Remaining discard decisions are not modeled; crossed or incomplete worlds cannot justify a play-now override.'
  if type(before)~='table' or type(after)~='table' or #before<4 or #before~=#after then return false,reason end
  for i=1,#before do
    local a,b=before[i],after[i]
    if type(a)~='table' or type(b)~='table' then return false,reason end
    for _,key in ipairs({'utility','win'}) do
      local x,y=a[key],b[key]
      if type(x)~='number' or type(y)~='number' or x~=x or y~=y or math.abs(x)==math.huge or math.abs(y)==math.huge or
        x<0 or x>1 or y<0 or y>1 or y<x then return false,reason end
    end
  end
  return true
end

-- Value the finite reusable scoring population, independently of overkill.
-- Counts permanent debuffs and Glass loss once per card. Temporary boss debuffs
-- do not erase a card's future value. This is a conservation heuristic only.
function M.population_profile(s)
  local p={values={},usable=0};local ranks={};local kings=false
  for _,j in ipairs(s.jokers or {}) do if not j.debuff and
    (j.key=='j_baron' or (j.ability or {}).name=='Baron') then kings=true end end
  for _,c in ipairs(s.playing_cards or s.hand or {}) do
    if not (c.ability or {}).perma_debuff then p.usable=p.usable+1;ranks[c.rank or 0]=(ranks[c.rank or 0] or 0)+1 end
  end
  for i,c in ipairs(s.hand or {}) do
    local a,e=c.ability or {},c.edition or {}
    p.values[i]=a.perma_debuff and 0 or (1+2*(ranks[c.rank or 0] or 0)/math.max(1,p.usable)+
      math.max(0,a.perma_bonus or 0)/25+(c.seal and 1 or 0)+(e.polychrome and 2 or e.holo and 1 or 0)+
      (c.enhancement=='m_steel' and 2 or 0)+(kings and c.rank==13 and 3 or 0))
  end
  return p
end
function M.population_cost(s,result,p)
  local loss,weighted,exposure=0,0,{}
  for _,e in ipairs(result.glass_exposure or {}) do exposure[e.index]=e.probability end
  for _,i in ipairs(result.scoring_indices or {}) do
    if (s.modifiers or {}).debuff_played_cards and not ((s.hand[i] or {}).ability or {}).perma_debuff then exposure[i]=1 end
  end
  for i,probability in pairs(exposure) do
    if (p.values[i] or 0)>0 then loss=loss+probability;weighted=weighted+probability*p.values[i] end
  end
  local usable=math.max(0,p.usable-loss)
  local future=not ((s.ante or 1)>=(s.win_ante or 8) and (s.blind or {}).boss)
  return future and weighted*(1+(s.hand_size or 8)/math.max(1,usable)) or 0,usable,loss
end

local function joker_name(j)
  return (j.ability or {}).name or j.name or
    ({j_banner = 'Banner', j_green_joker = 'Green Joker', j_ramen = 'Ramen', j_stencil = 'Joker Stencil',
      j_swashbuckler = 'Swashbuckler'})[j.key]
end

-- These discard triggers change growth, money or the card population beyond
-- discard_score_penalties. Do not turn an omitted trigger into cumulative
-- survival evidence. Original Card:calculate_joker pre_discard/discard paths.
local function continuation_discard_blocker(s,scorer)
  local unsupported={['Burnt Joker']=true,['Trading Card']=true,Yorick=true,Castle=true,
    ['Mail-In Rebate']=true,['Hit the Road']=true,['Faceless Joker']=true}
  local keys={j_burnt='Burnt Joker',j_trading='Trading Card',j_yorick='Yorick',j_castle='Castle',
    j_mail='Mail-In Rebate',j_hit_the_road='Hit the Road',j_faceless='Faceless Joker'}
  for _,j in ipairs(s.jokers or {}) do
    local name=joker_name(j) or keys[j.key]
    if not j.debuff and unsupported[name] and not scorer.after_discard then
      return name..' discard effects are not modeled in continuation.'
    end
  end
  for _,c in ipairs(s.hand or {}) do
    if not c.debuff and c.seal=='Purple' then return 'Purple Seal discard generation is not modeled in continuation.' end
  end
end

-- Apply the two discard effects that otherwise overstate the next hand's score.
-- Every candidate receives detached abilities, including nested extra fields.
local function discard_score_penalties(state, count)
  local updated, removed = {}, false
  for _, source in ipairs(state.jokers or {}) do
    local j = clone(source)
    j.ability = clone(source.ability or {})
    if type(j.ability.extra) == 'table' then j.ability.extra = clone(j.ability.extra) end
    local a, remove = j.ability, false
    if not j.debuff then
      if joker_name(j) == 'Green Joker' then
        local loss = type(a.extra) == 'table' and a.extra.discard_sub or 1
        a.mult = math.max(0, (a.mult or 0) - (loss or 1))
      elseif joker_name(j) == 'Ramen' then
        local loss = type(a.extra) == 'number' and a.extra or 0.01
        local multiplier = a.x_mult or 2
        for _ = 1, count do
          -- Vanilla Ramen has no eternal exception in its consumption branch.
          if multiplier - loss <= 1 then remove = true; break end
          multiplier = multiplier - loss
        end
        a.x_mult = multiplier
      end
    end
    if remove then
      removed = true
      if j.edition and j.edition.negative then state.joker_limit = (state.joker_limit or 5) - 1 end
    else updated[#updated + 1] = j end
  end
  state.jokers = updated
  if removed then
    local stencils = 0
    for _, j in ipairs(updated) do if joker_name(j) == 'Joker Stencil' then stencils = stencils + 1 end end
    for i, j in ipairs(updated) do
      if joker_name(j) == 'Joker Stencil' then
        j.ability.x_mult = (state.joker_limit or 5) - #updated + stencils
      elseif joker_name(j) == 'Swashbuckler' then
        local value = 0
        for k, other in ipairs(updated) do if k ~= i then value = value + (other.sell_cost or 0) end end
        j.ability.mult = value
      end
    end
  end
end

function M.combinations(n, limit, visit)
  local chosen = {}
  local function walk(start)
    if #chosen > 0 and visit(chosen) == false then return false end
    if #chosen >= limit then return end
    for i = start, n do
      chosen[#chosen + 1] = i
      local proceed = walk(i + 1)
      chosen[#chosen] = nil
      if proceed == false then return false end
    end
  end
  walk(1)
end

local function count_plays(n, limit)
  local total, term = 0, 1
  for k = 1, math.min(n, limit) do term = term * (n - k + 1) / k; total = total + term end
  return total
end

-- Upgraded hand families need representation in a bounded redraw shortlist.
-- Rank/suit counts alone otherwise favor keeping a low-level pair over a
-- valuable incomplete Straight (including A2345). These probabilities describe
-- drawing the missing public ranks/suit, never winning a blind or a run. Actual
-- choices still use the same fully matched scoring comparisons and score cap.
function M.draw_targets(s)
  if #(s.jokers or {})>0 or (s.used_vouchers or {}).v_observatory or (s.vouchers or {}).v_observatory or concealed(s) or
    #(s.hand or {})<3 or #s.hand>12 or #(s.deck or {})>120 or #(s.deck or {})<1 or
    (s.hand_limit or 5)<5 then return {} end
  local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
  local function choose(n,k)
    if k<0 or k>n then return 0 end
    local v=1;for i=1,k do v=v*(n-i+1)/i end;return v
  end
  local known_suits={Spades=true,Hearts=true,Clubs=true,Diamonds=true}
  local wild=false
  for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do
    -- Ordinary remaining-deck cards are rendered as backs by the source game;
    -- their public composition is still known. Only a held back is concealed.
    if c.unknown or c.concealed or (area==s.hand and c.face_down) or not finite(c.rank) or c.rank%1~=0 or
      c.rank<2 or c.rank>14 or not known_suits[c.suit] or
      (c.nominal~=nil and not finite(c.nominal)) then return {} end
    if c.enhancement=='m_wild' then wild=true end
  end end
  local counts,suits,nominal={},{},0
  for _,c in ipairs(s.deck) do
    nominal=nominal+(c.nominal or math.min(c.rank,10))
    if c.enhancement~='m_stone' then
      counts[c.rank]=(counts[c.rank] or 0)+1
      suits[c.suit]=(suits[c.suit] or 0)+1
    end
  end
  local n=#s.deck;local result={}
  local function payoff(category)
    local h=(s.hands or {})[category]
    if not h or not finite(h.level) or h.level<=1 or not finite(h.chips) or not finite(h.mult) then return nil end
    local value=(h.chips+5*nominal/n)*h.mult
    return finite(value) and value>0 and value or nil
  end
  local function selection(core)
    local kept={};for _,i in ipairs(core) do kept[i]=true end
    local needed=math.max(0,#s.hand-5-#core)
    if needed>0 then
      local extras={}
      for i,c in ipairs(s.hand) do if not kept[i] and not (c.ability or {}).forced_selection then
        extras[#extras+1]={i=i,value=(c.enhancement=='m_steel' and 100 or 0)+(c.seal=='Blue' and 60 or 0)+(c.nominal or c.rank or 0)}
      end end
      table.sort(extras,function(a,b) return a.value==b.value and a.i<b.i or a.value>b.value end)
      if #extras<needed then return end
      for i=1,needed do kept[extras[i].i]=true end
    end
    local indices={}
    for i,c in ipairs(s.hand) do
      if kept[i] and (c.ability or {}).forced_selection then return end
      if not kept[i] then indices[#indices+1]=i end
    end
    if #indices==0 or #indices>5 then return end
    local draws=math.min(n,math.max(0,(s.hand_size or #s.hand)-(#s.hand-#indices)))
    if not (s.blind or {}).disabled and ((s.blind or {}).key=='bl_serpent' or (s.blind or {}).name=='The Serpent') then draws=math.min(n,3) end
    return indices,draws
  end
  local function add(category,core,probability,hint,pattern)
    local indices,draws=selection(core);if not indices or draws==0 then return end
    local p=math.max(0,math.min(1,probability(draws)))
    if not finite(p) or p<=0 then return end
    result[#result+1]={indices=indices,category=category,completion_probability=p,
      score_hint=hint,expected_score_hint=p*hint,pattern=pattern,scope='public_composition_shortlist_only'}
  end
  local straight=payoff('Straight')
  if straight then
    for start=1,10 do
      local core,missing={},{}
      for rank=start,start+4 do
        local actual=rank==1 and 14 or rank;local selected
        for i,c in ipairs(s.hand) do
          if c.rank==actual and c.enhancement~='m_stone' and not (c.ability or {}).forced_selection and
            (not selected or (c.nominal or 0)>(s.hand[selected].nominal or 0)) then selected=i end
        end
        if selected then core[#core+1]=selected else missing[#missing+1]=counts[actual] or 0 end
      end
      if #core>=2 and #missing>0 then
        add('Straight',core,function(draws)
          if #missing>draws then return 0 end
          local total=0;local denominator=choose(n,draws)
          local function subsets(i,removed,sign)
            if i>#missing then total=total+sign*choose(n-removed,draws)/denominator;return end
            subsets(i+1,removed,sign);subsets(i+1,removed+missing[i],-sign)
          end
          subsets(1,0,1);return total
        end,straight,{straight_start=start,ace_low=start==1})
      end
    end
  end
  local flush=payoff('Flush')
  if flush and not wild then
    for _,suit in ipairs({'Spades','Hearts','Clubs','Diamonds'}) do
      local core={}
      for i,c in ipairs(s.hand) do if c.suit==suit and c.enhancement~='m_stone' and not (c.ability or {}).forced_selection then core[#core+1]=i end end
      if #core>=2 and #core<5 then
        local need=5-#core;local available=suits[suit] or 0
        add('Flush',core,function(draws)
          local p=0;for k=need,math.min(available,draws) do p=p+choose(available,k)*choose(n-available,draws-k)/choose(n,draws) end
          return p
        end,flush,{suit=suit})
      end
    end
  end
  -- A larger held group is not necessarily the better draw: a smaller pair
  -- can have many more matching cards left after visible rank development.
  -- Represent upgraded Four/Five of a Kind using the exact finite-population
  -- tail, then let the unchanged shared scoring comparison choose the action.
  for _,family in ipairs({{name='Four of a Kind',size=4},{name='Five of a Kind',size=5}}) do
    local hint=payoff(family.name)
    if hint then for rank=2,14 do
      local core={}
      for i,c in ipairs(s.hand) do
        if c.rank==rank and c.enhancement~='m_stone' and not (c.ability or {}).forced_selection then core[#core+1]=i end
      end
      if #core>=2 and #core<family.size then
        local need,available=family.size-#core,counts[rank] or 0
        add(family.name,core,function(draws)
          local p=0
          for k=need,math.min(available,draws) do p=p+choose(available,k)*choose(n-available,draws-k)/choose(n,draws) end
          return p
        end,hint,{rank=rank,required=family.size,held=#core,remaining=available})
      end
    end end
  end
  table.sort(result,function(a,b)
    if a.expected_score_hint~=b.expected_score_hint then return a.expected_score_hint>b.expected_score_hint end
    return table.concat(a.indices,',')<table.concat(b.indices,',')
  end)
  local unique,seen={},{ }
  for _,target in ipairs(result) do
    local key=target.category..':'..table.concat(target.indices,',')
    if not seen[key] then seen[key]=true;unique[#unique+1]=target end
  end
  return unique
end

-- Very large/modded hands still receive a bounded playable proposal. Preserve
-- every forced card and rank the remaining pool without inspecting future RNG.
-- The original snapshot hand remains intact for all held-card scoring effects.
local function bounded_pool(state)
  local forced, ranked, pool = {}, {}, {}
  for i, card in ipairs(state.hand) do
    if (card.ability or {}).forced_selection then forced[#forced + 1] = i
    else ranked[#ranked + 1] = i end
  end
  local function merit(i)
    local c = state.hand[i]
    return (c.nominal or math.min(c.rank or 0, 10)) + ((c.ability or {}).perma_bonus or 0)
      + (c.enhancement == 'm_stone' and 50 or c.enhancement == 'm_bonus' and 30 or 0)
  end
  table.sort(ranked, function(a, b) local x,y=merit(a),merit(b); return x==y and a<b or x>y end)
  for _, i in ipairs(forced) do pool[#pool + 1] = i end
  for _, i in ipairs(ranked) do if #pool < EXACT_HAND_LIMIT then pool[#pool + 1] = i end end
  return pool, forced, ranked
end

local function same_indices(a, b)
  if not a or not b or #a ~= #b then return false end
  for i, v in ipairs(a) do if b[i] ~= v then return false end end
  return true
end

local function reliable_clear(play, target)
  return play and play.legal ~= false and not play.uncertain and play.score >= target
end
M.reliable_clear = reliable_clear

-- Rank groups first make established matching-rank builds cheap to recognize.
-- This is only a seed list: legality and all scoring effects still use score().
local function obvious_candidates(state, limit)
  local groups, ranks, singles, out, seen = {}, {}, {}, {}, {}
  local function merit(i)
    local c=state.hand[i]
    return (c.enhancement=='m_glass' and -10000 or 0)+(c.rank or 0)*10+
      ((c.ability or {}).perma_bonus or 0)
  end
  local function order(a,b) local x,y=merit(a),merit(b); return x==y and a<b or x>y end
  local forced={}
  for i,c in ipairs(state.hand) do
    singles[#singles+1]=i
    if (c.ability or {}).forced_selection then forced[#forced+1]=i end
    if c.enhancement~='m_stone' then
      local r=c.rank or (c.base or {}).id or 0
      if not groups[r] then groups[r]={}; ranks[#ranks+1]=r end
      groups[r][#groups[r]+1]=i
    end
  end
  table.sort(singles,order)
  table.sort(ranks,function(a,b) return #groups[a]==#groups[b] and a>b or #groups[a]>#groups[b] end)
  local blind=state.blind or {}
  local minimum=not blind.disabled and math.max((blind.debuff or {}).h_size_ge or 1,
    (blind.key=='bl_psychic' or blind.name=='The Psychic') and 5 or 1) or 1
  local function add(indices)
    if #out>=32 then return end
    local selected,have={},{}
    for _,i in ipairs(indices) do if not have[i] then selected[#selected+1]=i; have[i]=true end end
    for _,i in ipairs(forced) do if not have[i] then selected[#selected+1]=i; have[i]=true end end
    for _,i in ipairs(singles) do if #selected<minimum and not have[i] then selected[#selected+1]=i; have[i]=true end end
    if #selected==0 or #selected>limit then return end
    table.sort(selected)
    local key=table.concat(selected,',')
    if not seen[key] then out[#out+1]=selected; seen[key]=true end
  end
  for _,r in ipairs(ranks) do
    local group=groups[r]; table.sort(group,order)
    for n=math.min(limit,#group),2,-1 do local a={}; for i=1,n do a[i]=group[i] end; add(a) end
  end
  -- A few singletons allow cheap High Card, held-Steel and Arm alternatives.
  for i=1,math.min(8,#singles) do add({singles[i]}) end
  for _,suit in ipairs({'Spades','Hearts','Clubs','Diamonds'}) do
    local a={}; for _,i in ipairs(singles) do if state.hand[i].suit==suit and #a<limit then a[#a+1]=i end end
    if #a>=4 then add(a) end
  end
  for start=10,1,-1 do
    local a={}; for r=start,start+4 do local group=groups[r==1 and 14 or r]; if group then a[#a+1]=group[1] end end
    if #a==5 then add(a) end
  end
  return out
end
M.obvious_candidates=obvious_candidates

-- Exact finite-population rank-pattern frequency in one uniform opening-sized
-- sample. It is an opportunity model, not a forecast of actual draws, optimal
-- discards, achievable scores or wins. Use only the complete public population;
-- remaining-deck-only data and concealed/modified identities cannot qualify it.
local growth_rank_size={Pair=2,['Three of a Kind']=3,['Four of a Kind']=4}
local function growth_population(s,category)
  local k=growth_rank_size[category]
  local population=s.playing_cards
  local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
  local hand_size=s.hand_size
  if not k or type(population)~='table' or #population<1 or #population>200 or
    not finite(hand_size) or hand_size%1~=0 or hand_size<1 or hand_size>12 or concealed(s) then return nil end
  -- These change future visibility, hand capacity or the base-score proxy.
  local modifiers=s.modifiers or {}
  local ordinary={no_interest=true,no_extra_hand_money=true,discard_cost=true,
    money_per_hand=true,money_per_discard=true,no_blind_reward=true,
    enable_eternals_in_shop=true,enable_perishables_in_shop=true,enable_rentals_in_shop=true,
    all_eternal=true,no_shop_jokers=true,no_reward=true,inflation=true}
  for key,value in pairs(modifiers) do
    if value~=false and value~=nil and value~=0 and not ordinary[key] then return nil end
  end
  if s.deck_key=='b_plasma' then return nil end
  local ranks,ids={},{}
  local enhancements={c_base=true,m_bonus=true,m_mult=true,m_wild=true,m_stone=true,
    m_steel=true,m_gold=true,m_glass=true,m_lucky=true}
  for _,c in ipairs(population) do
    if type(c)~='table' or c.unknown or c.concealed or c.id==nil or ids[c.id] or
      not enhancements[c.enhancement or 'c_base'] or (c.ability or {}).perma_debuff then return nil end
    local r=c.rank or (c.base or {}).id
    if not finite(r) or r%1~=0 or r<2 or r>14 then return nil end
    ids[c.id]=c
    if c.enhancement~='m_stone' then ranks[r]=(ranks[r] or 0)+1 end
  end
  for _,area in ipairs({s.hand or {},s.deck or {}}) do for _,c in ipairs(area) do
    local original=ids[c.id]
    if not original or c.unknown or c.concealed or
      (original.rank or (original.base or {}).id)~=(c.rank or (c.base or {}).id) or
      (original.enhancement or 'c_base')~=(c.enhancement or 'c_base') then return nil end
  end end
  local draws=math.min(hand_size,#population)
  local limit=s.hand_limit or 5
  if not finite(limit) or limit%1~=0 or limit<1 or limit>5 then return nil end
  if k>limit or k>draws then return {frequency=0,draws=draws,population=#population,rank_size=k} end
  local function choose(n,t)
    if t<0 or t>n then return 0 end
    local v=1;for i=1,t do v=v*(n-i+1)/i end;return v
  end
  -- Count samples with fewer than k cards at every rank; Stone cards occupy
  -- sample slots but do not contribute a rank. The complement is the event.
  local ways={[0]=1};local stones=#population
  for rank=2,14 do
    local count=ranks[rank] or 0;stones=stones-count
    local next_ways={}
    for used=0,draws do for taken=0,math.min(count,k-1,draws-used) do
      next_ways[used+taken]=(next_ways[used+taken] or 0)+(ways[used] or 0)*choose(count,taken)
    end end
    ways=next_ways
  end
  local misses=0
  for used=0,draws do misses=misses+(ways[used] or 0)*choose(stones,draws-used) end
  local frequency=math.max(0,math.min(1,1-misses/choose(#population,draws)))
  return {frequency=frequency,draws=draws,population=#population,rank_size=k}
end
M.hand_growth_population=growth_population

local function contains_hand(category,required)
  if category==required then return true end
  local contains={
    ['Two Pair']={Pair=true},['Three of a Kind']={Pair=true},
    ['Full House']={Pair=true,['Two Pair']=true,['Three of a Kind']=true},
    ['Four of a Kind']={Pair=true,['Three of a Kind']=true},
    ['Five of a Kind']={Pair=true,['Three of a Kind']=true,['Four of a Kind']=true},
    ['Straight Flush']={Straight=true,Flush=true},
    ['Flush House']={Pair=true,['Two Pair']=true,['Three of a Kind']=true,['Full House']=true,Flush=true},
    ['Flush Five']={Pair=true,['Three of a Kind']=true,['Four of a Kind']=true,['Five of a Kind']=true,Flush=true},
  }
  return (contains[category] or {})[required] or false
end

-- A small, uncalibrated future preference. Current survival remains primary;
-- levels, actual use, supported Joker containment and public rank opportunities
-- change this value. Absolute marginal gain avoids treating an undeveloped
-- low-base hand's large percentage increase as the entire development objective.
local function hand_growth_value(s,category,profile)
  if profile and (profile.final or (type(profile.horizon)=='number' and profile.horizon<=0)) then return 0 end
  local h=(s.hands or {})[category] or {}
  local total=0; for _,v in pairs(s.hands or {}) do total=total+(v.played or 0) end
  local relevance=0.15+2*(h.played or 0)/math.max(1,total)
  local affinity=false
  for _,j in ipairs(s.jokers or {}) do
    if not j.debuff and contains_hand(category,(j.ability or {}).type) then relevance=relevance+1;affinity=true end
  end
  -- build_profile defaults to Pair in a new run; that fallback alone is not
  -- evidence that the deck is committed to Pair.
  if profile and profile.hand==category and ((h.played or 0)>0 or (h.level or 1)>1 or affinity) then
    relevance=relevance+2
  end
  local chips,mult=h.chips or 0,h.mult or 1
  local after=(chips+(h.l_chips or 10))*(mult+(h.l_mult or 1))
  local gain=after/math.max(1,chips*mult)-1
  local value=relevance*math.min(2,math.max(0,gain))
  local opportunity=growth_population(s,category)
  if opportunity and type(h.chips)=='number' and type(h.mult)=='number' and
    type(h.l_chips)=='number' and type(h.l_mult)=='number' and chips>=0 and mult>=1 and
    h.l_chips>=0 and h.l_mult>=0 then
    local frequency=opportunity.frequency
    local horizon=profile and type(profile.horizon)=='number' and math.min(1,math.max(0,profile.horizon)/3) or 1
    -- The additive preference is capped at two utility units; neither this
    -- heuristic nor the frequency can replace complete current-survival checks.
    value=value*math.sqrt(frequency)+math.min(2,math.sqrt(frequency*math.max(0,after-chips*mult))/10)*horizon
  end
  local b=s.blind or {}
  if not b.disabled and b.only_hand and b.only_hand~=category then value=value*0.5 end
  return value
end
M.hand_growth_value=hand_growth_value

local function protected_extra(card)
  local a = card.ability or {}
  -- End-of-round resources and reusable scoring cards have value beyond the
  -- next draw, even when their effects do not contribute to this particular play.
  return (card.enhancement and card.enhancement ~= 'c_base') or card.seal
    or (card.edition and (type(card.edition) ~= 'table' or next(card.edition)))
    or (a.h_dollars or 0) > 0 or (a.h_mult or 0) > 0 or (a.h_x_mult or 0) > 1
end

local function retained_merit(s, selected)
  local used, ranks, suits, high = {}, {}, {}, 0
  for _, i in ipairs(selected) do used[i] = true end
  for i, card in ipairs(s.hand) do if not used[i] then
    local rank, suit = card.rank or 0, card.suit or '?'
    ranks[rank], suits[suit] = (ranks[rank] or 0) + 1, (suits[suit] or 0) + 1
    high = math.max(high, rank)
  end end
  local merit = high / 4
  for _, count in pairs(ranks) do merit = merit + count * (count - 1) * 6 end
  for _, count in pairs(suits) do if count >= 3 then merit = merit + count * count * 2 end end
  local straight = 0
  for start = 1, 10 do
    local count = 0
    for rank = start, start + 4 do if ranks[rank == 1 and 14 or rank] then count = count + 1 end end
    straight = math.max(straight, count)
  end
  if straight >= 3 then merit = merit + straight * straight end
  return merit
end

-- Compare free card cycling only after deciding to play. All candidate plays
-- retain the same scoring cards/category and at least the same immediate score.
-- Common shuffled decks make comparisons paired, so one option cannot win just
-- because it was assigned a luckier independent set of replacement cards.
local function choose_cycle(s, scorer, result, options, context)
  local play = result.play
  if not play or result.kind ~= 'play' or not play.scoring_indices or not scorer.after_play then return end
  local remaining = math.max(1, (s.blind.chips or 0) - (s.chips or 0))
  if play.score >= remaining or (s.hands_left or 0) <= 1 or #s.deck == 0 or #play.indices >= 5 then return end
  local b = s.blind or {}
  if not b.disabled and (b.key == 'bl_tooth' or b.name == 'The Tooth') then return end
  -- Future Pillar debuffs and resource loss are not valued by this short horizon.
  if (s.modifiers or {}).debuff_played_cards then return end
  for _, j in ipairs(s.jokers or {}) do if not j.debuff and (s.hands_played or 0) == 0 and #play.indices == 1 then
    local name = (j.ability or {}).name or j.name
    if j.key == 'j_dna' or name == 'DNA' then return end
    if (j.key == 'j_sixth_sense' or name == 'Sixth Sense') and s.hand[play.indices[1]].rank == 6 then return end
  end end
  local required, groups = {}, {}
  for _, i in ipairs(play.indices) do required[i] = true end
  for _, candidate in ipairs(result.alternatives or {}) do
    if #candidate.indices > #play.indices and candidate.hand == play.hand
      and candidate.score >= play.score
      and (candidate.expected_dollars or 0) >= (play.expected_dollars or 0)
      and same_indices(candidate.scoring_indices, play.scoring_indices) then
      local chosen, valid = {}, true
      for _, i in ipairs(candidate.indices) do
        chosen[i] = true
        if not required[i] and protected_extra(s.hand[i]) then valid = false end
      end
      for i in pairs(required) do if not chosen[i] then valid = false end end
      if valid then
        local size = #candidate.indices
        groups[size] = groups[size] or {}
        groups[size][#groups[size] + 1] = {play = candidate, merit = retained_merit(s, candidate.indices)}
      end
    end
  end
  local candidates = {{play = play}}
  -- Include several alternatives for each number of extra cards. This keeps
  -- both larger redraws and useful retained pairs/flush draws in the shortlist.
  for size = #play.indices + 1, math.min(5, s.hand_limit or 5) do
    local group = groups[size] or {}
    table.sort(group, function(a, b)
      if a.merit ~= b.merit then return a.merit > b.merit end
      return table.concat(a.play.indices, ',') < table.concat(b.play.indices, ',')
    end)
    for i = 1, math.min(3, #group) do candidates[#candidates + 1] = group[i] end
  end
  if #candidates <= 1 then return end

  local prepared, pass_cost = {}, 0
  for i, candidate in ipairs(candidates) do
    local after = context.after_play(s, candidate.play.indices)
    if after then
      local serpent = not b.disabled and (b.key == 'bl_serpent' or b.name == 'The Serpent')
      candidate.draws = math.min(#after.deck, serpent and 3 or math.max(0, (after.hand_size or #s.hand) - #after.hand))
      local size = #after.hand + candidate.draws
      if size > 0 and size <= CONTINUATION_HAND_LIMIT then
        candidate.after, candidate.scores, candidate.total = after, {}, 0
        prepared[#prepared + 1] = candidate
        local term, cost = 1, 0
        for k = 1, math.min(5, size, s.hand_limit or 5) do
          term = term * (size - k + 1) / k
          cost = cost + term
        end
        pass_cost = pass_cost + cost
      elseif i == 1 then return end
    elseif i == 1 then return end
  end
  if #prepared <= 1 or pass_cost <= 0 then return end
  local samples = math.min(options.cycle_samples or 12, math.floor(context.budget_left() / pass_cost))
  if samples < 4 then return end
  for sample = 1, samples do
    local order = {}
    for i = 1, #s.deck do order[i] = i end
    for i = #order, 2, -1 do local j = context.random(i); order[i], order[j] = order[j], order[i] end
    local bell = #s.hand > 0 and not b.disabled and (b.key == 'bl_final_bell' or b.name == 'Cerulean Bell')
    local bell_roll = bell and context.random(1000000) or 0
    for _, candidate in ipairs(prepared) do
      local state = clone(candidate.after)
      state.hand, state.deck = copy_list(state.hand), {}
      state.suppress_warnings = true
      for position, index in ipairs(order) do
        local card = candidate.after.deck[index]
        if position <= candidate.draws then
          if options.draws then card=options.draws.card(state,card);if not card then return end end
          state.hand[#state.hand + 1] = card
        else state.deck[#state.deck + 1] = card end
      end
      if bell and #state.hand > 0 then
        local index = (bell_roll % #state.hand) + 1
        state.hand[index] = clone(state.hand[index])
        state.hand[index].ability = clone(state.hand[index].ability or {})
        state.hand[index].ability.forced_selection = true
      end
      if concealed(state) then return end
      local next_play = context.best_play(state)
      if context.truncated() then return end
      local score = next_play and next_play.score or 0
      -- Excess beyond the remaining target does not improve survival.
      local useful = math.min(math.max(0, remaining - candidate.play.score), score)
      candidate.scores[sample], candidate.total = useful, candidate.total + useful
    end
  end
  local baseline, best = prepared[1], prepared[1]
  for _, candidate in ipairs(prepared) do
    if candidate.total > best.total then best = candidate
    elseif candidate.total == best.total and #candidate.play.indices < #best.play.indices then best = candidate end
  end
  local gain = (best.total - baseline.total) / samples
  -- Require a useful paired improvement; keep the original on no-gain ties.
  if best ~= baseline and gain > math.max(0.5, baseline.total / samples * 0.01) then
    local selected = clone(best.play)
    selected.cycle_indices = {}
    for _, i in ipairs(selected.indices) do if not required[i] then selected.cycle_indices[#selected.cycle_indices + 1] = i end end
    selected.cycle_samples = samples
    selected.cycle_next_mean, selected.cycle_baseline_mean = best.total / samples, baseline.total / samples
    selected.cycle_note = 'Sampled redraws favor cycling these extra cards while keeping the current estimated score.'
    result.play = selected
  end
end

function M.run(s, scorer, options, progress)
  options = options or {}
  local max_evaluations = math.max(0, math.min(140000, math.floor(options.max_evaluations or 140000)))
  local samples = options.samples or 24
  local evaluations, seed = 0, 19491001
  local remaining = math.max(1, (s.blind.chips or 0) - (s.chips or 0))
  local max_cards = math.min(5, s.hand_limit or 5)
  local truncated = false
  local arm_costs = setmetatable({}, {__mode='k'})
  local glass_values=setmetatable({},{__mode='k'})
  local population_profiles=setmetatable({},{__mode='k'})
  local finish_prepared
  local bound_checks,future_clear_stops=0,0
  local function random(n)
    seed = (seed * 48271) % 2147483647
    return (seed % n) + 1
  end
  local function evaluate(state, indices)
    if evaluations >= max_evaluations then truncated = true; return nil end
    evaluations = evaluations + 1
    if progress and evaluations % 32 == 0 then progress(evaluations) end
    for i, card in ipairs(state.hand) do
      if card.ability and card.ability.forced_selection then
        local found = false
        for _, index in ipairs(indices) do if i == index then found = true end end
        if not found then return nil end
      end
    end
    local result = scorer.score(state, indices)
    -- Random upside can hide an already certain win. Spend at most four extra
    -- scoring calls on promising current plays; unsupported uncertainty stays.
    if state==s and result and result.legal~=false and result.uncertain and result.score>=remaining
      and scorer.lower_bound and options.score_bounds~=false and bound_checks<4 and evaluations<max_evaluations then
      evaluations=evaluations+1;bound_checks=bound_checks+1
      local bound=scorer.lower_bound(state,indices)
      if bound and bound.reliable_bound and reliable_clear(bound,remaining) then
        bound.expected_score=result.score;result=bound
      end
    end
    if result and result.legal ~= false then
      result.indices = copy_list(indices)
      local costs = arm_costs[state]
      if not costs then costs = {}; arm_costs[state] = costs end
      if costs[result.hand] == nil then costs[result.hand] = arm_cost(state, result.hand) end
      result.arm_cost = costs[result.hand]
      if state==s and options.finish_rewards and reliable_clear(result,remaining) then
        if not finish_prepared then finish_prepared=options.finish_rewards.prepare(s,options.strategy) end
        result.finish_reward,result.finish_rewards=options.finish_rewards.value(s,result,finish_prepared)
      end
      if (state.modifiers or {}).debuff_played_cards or #(result.glass_exposure or {})>0 then
        local p=population_profiles[state]
        if not p then p=M.population_profile(state);population_profiles[state]=p end
        result.population_cost,result.usable_after,result.population_loss=M.population_cost(state,result,p)
      end
      if result.glass_exposure then
        local values=glass_values[state]
        if not values then
          values={}; local ranks,total={},0
          for _,c in ipairs(state.playing_cards or state.deck or state.hand) do
            if c.rank then ranks[c.rank]=(ranks[c.rank] or 0)+1; total=total+1 end
          end
          for i,c in ipairs(state.hand) do
            values[i]=1+4*(ranks[c.rank] or 0)/math.max(1,total)+
              (c.seal and 0.5 or 0)+((c.edition or {}).polychrome and 1 or 0)+
              ((c.ability or {}).perma_bonus or 0)/50
          end
          glass_values[state]=values
        end
        result.glass_loss=0
        for _,exposure in ipairs(result.glass_exposure) do
          result.glass_loss=result.glass_loss+exposure.probability*(values[exposure.index] or 1)
        end
      end
      return result
    end
  end
  local function better(a, b, target)
    if not a then return false end
    if not b then return true end
    target = target or remaining
    local ac,bc=reliable_clear(a,target),reliable_clear(b,target)
    if ac~=bc then return ac end
    if ac and bc and (a.population_cost or 0)~=(b.population_cost or 0) then
      return (a.population_cost or 0)<(b.population_cost or 0)
    end
    if ac and bc and (a.glass_loss or 0)~=(b.glass_loss or 0) then
      return (a.glass_loss or 0)<(b.glass_loss or 0)
    end
    if a.score >= target and b.score >= target and a.arm_cost ~= b.arm_cost then
      return (a.arm_cost or 0) < (b.arm_cost or 0)
    end
    if ac and bc and (a.finish_reward or 0)~=(b.finish_reward or 0) then
      return (a.finish_reward or 0)>(b.finish_reward or 0)
    end
    -- Preserve useful held cards once the modeled hand already clears the blind.
    if a.score >= target and b.score >= target and #a.indices ~= #b.indices then
      return #a.indices < #b.indices
    end
    if a.score == b.score then
      if #a.indices ~= #b.indices then return #a.indices < #b.indices end
      for i = 1, #a.indices do
        if a.indices[i] ~= b.indices[i] then return a.indices[i] < b.indices[i] end
      end
      return false
    end
    return a.score > b.score
  end
  local alternatives, initial_play_complete = {}, false
  local fast_diagnostics
  local function best_play(state, collect)
    local best,clear,seen=nil,nil,{}
    local target = math.max(1, (state.blind.chips or 0) - (state.chips or 0))
    local available = max_evaluations - evaluations
    local limited = #state.hand > EXACT_HAND_LIMIT or count_plays(#state.hand, max_cards) > available
    local function inspect(indices)
      local key=table.concat(indices,',')
      if seen[key] then return evaluations<max_evaluations end
      seen[key]=true
      local result = evaluate(state, indices)
      if better(result, best, target) then best = result end
      if collect and result then
        alternatives[#alternatives + 1] = result
      end
      if collect and options.fast_clear~=false and reliable_clear(result,target) then clear=result; return false end
      if not collect and options.future_clear~=false and reliable_clear(result,target) then clear=result; return false end
      return evaluations < max_evaluations
    end
    local shortlist=((collect and options.fast_clear~=false) or (not collect and options.future_clear~=false))
      and obvious_candidates(state,max_cards) or {}
    for _,indices in ipairs(shortlist) do if inspect(indices)==false then break end end
    local function conserve(search_path)
      if not clear then return end
      local start=evaluations
      local proposals={}
      local no_glass={}
      for _,i in ipairs(clear.indices) do if state.hand[i].enhancement~='m_glass' then no_glass[#no_glass+1]=i end end
      if #no_glass>0 then proposals[#proposals+1]=no_glass end
      local ranked=copy_list(clear.indices)
      table.sort(ranked,function(a,b)
        local ca,cb=state.hand[a],state.hand[b]
        local va=(ca.enhancement=='m_glass' and -1000 or 0)+(ca.rank or 0)
        local vb=(cb.enhancement=='m_glass' and -1000 or 0)+(cb.rank or 0)
        return va==vb and a<b or va>vb
      end)
      for n=1,#ranked-1 do
        local a={}; for i=1,n do a[i]=ranked[i] end; table.sort(a); proposals[#proposals+1]=a
      end
      for _,removed in ipairs(clear.indices) do
        local a={}; for _,i in ipairs(clear.indices) do if i~=removed then a[#a+1]=i end end
        if #a>0 then proposals[#proposals+1]=a end
      end
      -- The first clear may consume a Blue seal or Glass card even when a
      -- duplicate rank (or another Flush card) can replace it safely. Include
      -- a few substitutions in the existing conservation budget. Their scores,
      -- legality, population cost and whole-inventory rewards are still checked
      -- by evaluate/better; the representation hint is never a clear guarantee.
      local selected,exchanges={},{}
      for _,i in ipairs(clear.indices) do selected[i]=true end
      local function retain(c)
        if c.debuff then return 0 end
        return (c.enhancement=='m_glass' and 1000 or 0)+(c.seal=='Blue' and 20 or 0)+
          (c.enhancement=='m_gold' and 3 or math.max(0,(c.ability or {}).h_dollars or 0))
      end
      local flush=clear.hand=='Flush' or clear.hand=='Straight Flush'
      for _,i in ipairs(clear.indices) do
        local from=state.hand[i]
        if not (from.ability or {}).forced_selection and from.enhancement~='m_stone' and retain(from)>0 then
          for j,to in ipairs(state.hand) do
            local gain=retain(from)-retain(to)
            if not selected[j] and to.enhancement~='m_stone' and gain>0 then
              local a={};for _,k in ipairs(clear.indices) do a[#a+1]=k==i and j or k end;table.sort(a)
              local affinity=(type(from.rank)=='number' and from.rank==to.rank) and 2 or
                (flush and from.suit and from.suit==to.suit) and 1 or 0
              exchanges[#exchanges+1]={indices=a,gain=gain,affinity=affinity,key=table.concat(a,',')}
            end
          end
        end
      end
      table.sort(exchanges,function(a,b)
        if a.affinity~=b.affinity then return a.affinity>b.affinity end
        return a.gain==b.gain and a.key<b.key or a.gain>b.gain
      end)
      local added={};local count=0
      for _,exchange in ipairs(exchanges) do
        if not added[exchange.key] and not seen[exchange.key] then
          proposals[#proposals+1]=exchange.indices;added[exchange.key]=true;count=count+1
          if count>=8 then break end
        end
      end
      for _,a in ipairs(shortlist) do proposals[#proposals+1]=a end
      for _,indices in ipairs(proposals) do
        if evaluations-start>=16 or evaluations>=max_evaluations then break end
        local key=table.concat(indices,',')
        if not seen[key] then
          seen[key]=true
          local candidate=evaluate(state,indices)
          if candidate then alternatives[#alternatives+1]=candidate end
          if reliable_clear(candidate,target) and better(candidate,best,target) then best=candidate end
        end
      end
      fast_diagnostics={reliable_clear=true,shortlist_limit=32,conservation_limit=16,
        conservation_evaluations=evaluations-start,clear_found_at=start,search_path=search_path,
        aggregate_limit=search_path=='shortlist' and 70 or 140000}
      initial_play_complete=false
      return best
    end
    if clear then
      if not collect then future_clear_stops=future_clear_stops+1;return best end
      return conserve('shortlist')
    end
    local pool
    if limited then
      local forced, ranked
      pool, forced, ranked = bounded_pool(state)
      local seed_play = copy_list(forced)
      local blind = state.blind or {}
      local minimum = not blind.disabled and math.max((blind.debuff or {}).h_size_ge or 1,
        (blind.key == 'bl_psychic' or blind.name == 'The Psychic') and 5 or 1) or 1
      for _, index in ipairs(ranked) do if #seed_play < math.max(minimum, #forced) then seed_play[#seed_play + 1] = index end end
      table.sort(seed_play)
      -- Under a small custom budget, try a legal forced-card/minimum-size
      -- proposal before spending it on a lexicographic prefix of invalid plays.
      if #seed_play > 0 and #seed_play <= max_cards then inspect(seed_play) end
    end
    if evaluations < max_evaluations and not clear then
      if #state.hand <= EXACT_HAND_LIMIT then M.combinations(#state.hand, max_cards, inspect)
      else
        M.combinations(#pool, max_cards, function(indices)
          local original = {}; for _, i in ipairs(indices) do original[#original + 1] = pool[i] end
          table.sort(original)
          return inspect(original)
        end)
      end
    end
    if clear then
      if not collect then future_clear_stops=future_clear_stops+1;return best end
      return conserve('enumeration')
    end
    if limited then truncated = true end
    if collect then initial_play_complete = not limited end
    return best
  end
  local cycle_evaluated = false
  local function after_play(state, indices, outcome_seed, turn)
    if evaluations >= max_evaluations then truncated = true; return nil end
    evaluations = evaluations + 1
    if progress and evaluations % 32 == 0 then progress(evaluations) end
    if outcome_seed and options.sampled_outcomes then
      return options.sampled_outcomes.after_play(state,indices,scorer,outcome_seed,turn or 1)
    end
    return scorer.after_play(state, indices)
  end
  local cycle_context = {
      random = random, best_play = best_play,
      after_play = after_play,
      budget_left = function() return max_evaluations - evaluations end,
      truncated = function() return truncated end,
  }
  local function finish(result)
    if fast_diagnostics then
      -- A reliable clear can also stop later enumeration. Only the initial
      -- shortlist has the seventy-score whole-decision fast-clear contract.
      if fast_diagnostics.search_path=='shortlist' then result.fast_clear=fast_diagnostics
      else result.clear_shortcut=fast_diagnostics end
    end
    if not fast_diagnostics and not truncated and not cycle_evaluated then choose_cycle(s, scorer, result, options, cycle_context) end
    if not fast_diagnostics and #s.hand > CONTINUATION_HAND_LIMIT then
      result.search_diagnostics = result.search_diagnostics or {}
      result.search_diagnostics.continuation_hand_limit = CONTINUATION_HAND_LIMIT
      local warning = #s.hand > EXACT_HAND_LIMIT and
        'More than 20 held cards: a bounded card pool was searched; the best play is not guaranteed. Discard and continuation comparisons were skipped.' or
        (initial_play_complete and 'All current plays were searched, but cycling and multi-hand continuation are limited to 12 held cards.' or
        'The current play search was budget-limited; cycling and multi-hand continuation are limited to 12 held cards.')
      if result.play then
        result.play.warnings = copy_list(result.play.warnings or {})
        result.play.warnings[#result.play.warnings + 1] = warning
      end
    end
    result.evaluations, result.truncated = evaluations, truncated
    result.search_performance={lower_bound_checks=bound_checks,lower_bound_limit=4,future_clear_stops=future_clear_stops,
      future_objective='score capped at remaining blind target; reported mean uses selected clearing plays'}
    result.play_complete = initial_play_complete
    return result
  end
  local play = best_play(s, true)
  table.sort(alternatives, better)
  local result = {play = play, alternatives = alternatives, kind = 'play', evaluations = evaluations, truncated = truncated}
  if play and play.score >= remaining and not s.blind.disabled and
    (s.blind.key == 'bl_arm' or s.blind.name == 'The Arm') then
    for _, alternative in ipairs(alternatives) do
      if alternative.score >= remaining and (alternative.arm_cost or 0) > (play.arm_cost or 0) then
        play.future_note = (play.arm_cost or 0) == 0 and
          'The Arm: this hand clears at Level 1, preserving upgraded hands for later blinds.' or
          'The Arm: this clear sacrifices less estimated future hand value than the other clearing plays.'
        break
      end
    end
  end
  if progress then progress(evaluations, result) end
  -- Reuse the complete held family before spending discard/continuation work.
  -- A proposal contains only a reversible row action; no play is dispatched.
  if options.copy_preflight and options.copy_preflight.compare and initial_play_complete and
    not truncated and not fast_diagnostics and not reliable_clear(play,remaining) then
    local proposal,diagnostics=options.copy_preflight.compare(scorer,alternatives,{
      budget_left=function()return max_evaluations-evaluations end,after_play=after_play,
      progress=function()if progress then progress(evaluations) end end})
    result.copy_preflight_diagnostics=diagnostics
    if proposal and diagnostics and diagnostics.complete then
      result.kind='reorder_jokers';result.ordering=proposal;result.action=proposal.action
      result.copy_preflight=diagnostics;result.reorder_only=true;result.needs_refresh=true
      result.evaluations=evaluations;result.play_complete=true;result.truncated=false
      return result -- Do not invoke finish(), which can start cycling work.
    end
  end
  if truncated or reliable_clear(play,remaining) or s.discards_left <= 0 or #s.deck == 0 then return finish(result) end

  -- Shortlist keeps matching ranks, suits, runs, and the strongest existing hands.
  -- This is deliberately bounded; it is not an exhaustive game-tree solver.
  local candidates, seen = {}, {}
  local profile=options.strategy and options.strategy.build_profile and options.strategy.build_profile(s)
  local burnt=false
  for _,j in ipairs(s.jokers or {}) do
    if not j.debuff and (j.key=='j_burnt' or joker_name(j)=='Burnt Joker') and (s.discards_used or 0)==0 then burnt=true end
  end
  local growth_cache={}
  local function growth_category(indices)
    if not burnt or not scorer.classify then return 0 end
    local category=scorer.classify(s,indices)
    if not growth_cache[category] then growth_cache[category]=hand_growth_value(s,category,profile) end
    return growth_cache[category]
  end
  local function add(indices, priority)
    if #indices == 0 or #indices > max_cards then return end
    local selected={};for _,i in ipairs(indices) do selected[i]=true end
    for i,c in ipairs(s.hand) do if (c.ability or {}).forced_selection and not selected[i] then return end end
    local key = table.concat(indices, ',')
    if not seen[key] then
      local growth=growth_category(indices)
      local c = {indices = copy_list(indices), priority = priority+8*growth, total = 0, wins = 0, count = 0, utility = 0,growth=growth}
      candidates[#candidates + 1] = c
      seen[key] = c
    else seen[key].priority = math.max(seen[key].priority, priority+8*seen[key].growth) end
  end
  for i = 1, math.min(10, #alternatives) do
    local keep, discard = {}, {}
    for _, index in ipairs(alternatives[i].indices) do keep[index] = true end
    for index = 1, #s.hand do if not keep[index] then discard[#discard + 1] = index end end
    add(discard, 100 - i)
  end
  M.combinations(#s.hand, max_cards, function(indices)
    local removed, ranks, suits, values = {}, {}, {}, {}
    for _, i in ipairs(indices) do removed[i] = true end
    local priority = 0
    for i, c in ipairs(s.hand) do
      if not removed[i] then
        local rank, suit = c.rank or 0, c.suit or '?'
        ranks[rank] = (ranks[rank] or 0) + 1
        suits[suit] = (suits[suit] or 0) + 1
        values[rank] = true
        if c.enhancement == 'm_steel' then priority = priority + 6 end
      end
    end
    for _, count in pairs(ranks) do priority = priority + count * (count - 1) * 8 end
    for _, count in pairs(suits) do if count >= 3 then priority = priority + count * count * 3 end end
    for start = 2, 10 do
      local count = 0
      for rank = start, start + 4 do if values[rank] then count = count + 1 end end
      if count >= 3 then priority = priority + count * 5 end
    end
    add(indices, priority)
  end)
  table.sort(candidates, function(a, b)
    if a.priority == b.priority then return table.concat(a.indices, ',') < table.concat(b.indices, ',') end
    return a.priority > b.priority
  end)
  -- Keeping more cards always inflates raw pair/suit/run counts. Taking only
  -- the global top priorities can therefore exclude every substantial redraw.
  -- Compare promising options at each draw size instead of letting one-card
  -- discards occupy the whole bounded shortlist.
  local buckets, shortlist = {}, {}
  for _, candidate in ipairs(candidates) do
    local size = #candidate.indices
    buckets[size] = buckets[size] or {}
    buckets[size][#buckets[size] + 1] = candidate
  end
  local depth, limit = 1, options.candidates or 16
  while #shortlist < limit do
    local added = false
    for size = 1, max_cards do
      local candidate = buckets[size] and buckets[size][depth]
      if candidate and #shortlist < limit then
        shortlist[#shortlist + 1], added = candidate, true
      end
    end
    if not added then break end
    depth = depth + 1
  end
  candidates = shortlist
  -- Reserve at most two existing slots for valuable upgraded completion
  -- families. Keep the ordinary first candidate at every redraw size and the
  -- incumbent keep-play proposal; do not increase shortlist or sampling work.
  local target_diagnostics={};local represented,anchored,primary,sizes={},{},{},{}
  for _,candidate in ipairs(candidates) do
    if not sizes[#candidate.indices] then sizes[#candidate.indices]=true;primary[candidate]=true end
  end
  local keep,complement={},{}
  for _,i in ipairs(play and play.indices or {}) do keep[i]=true end
  for i=1,#s.hand do if not keep[i] then complement[#complement+1]=i end end
  local incumbent_keep=seen[table.concat(complement,',')]
  for _,target in ipairs(options.draw_targets==false and {} or M.draw_targets(s)) do
    if #target_diagnostics>=2 then break end
    if not represented[target.category] and target.expected_score_hint>(play and play.score or 0) then
      represented[target.category]=true
      local id=table.concat(target.indices,',');local candidate=seen[id]
      local present=false;for _,c in ipairs(candidates) do if c==candidate then present=true end end
      if candidate and not present then
        for i=#candidates,1,-1 do
          if not primary[candidates[i]] and candidates[i]~=incumbent_keep and not anchored[candidates[i]] then
            candidates[i]=candidate;present=true;break
          end
        end
      end
      if present then target_diagnostics[#target_diagnostics+1]=target;anchored[candidate]=true end
    end
  end
  -- Enlarged hands cost substantially more per draw. Keep enough budget for
  -- four complete paired rounds before starting any sampled comparison.
  local available, pass_cost = max_evaluations - evaluations, 0
  local eligible,discard_warnings = {},{}
  for _, candidate in ipairs(candidates) do
    local reason
    if scorer.after_discard then candidate.prepared,reason=scorer.after_discard(s,candidate.indices) end
    local supported=not scorer.after_discard or candidate.prepared~=nil
    if not supported then discard_warnings[reason or 'Unsupported discard transition.']=true end
    local kept = #s.hand - #candidate.indices
    local capacity=candidate.prepared and candidate.prepared.hand_size or s.hand_size or #s.hand
    local draws = math.min(#s.deck, math.max(0, capacity - kept))
    if not s.blind.disabled and (s.blind.key == 'bl_serpent' or s.blind.name == 'The Serpent') then draws = math.min(#s.deck, 3) end
    local future_size = kept + draws
    if supported and future_size <= EXACT_HAND_LIMIT then
      candidate.cost = count_plays(future_size, max_cards)
      eligible[#eligible + 1] = candidate
      pass_cost = pass_cost + candidate.cost
    end
  end
  candidates = eligible
  -- Reserve complete paired remaining-blind comparisons before one-draw
  -- sampling can exhaust the budget. This applies to supported ordinary decks
  -- too: consuming a useful card/draw can lose a blind without a resource Joker.
  local continuation, reserve = nil, 0
  local continuation_blocker = continuation_discard_blocker(s,scorer)
  if play and play.scoring_indices and scorer.after_play and (s.hands_left or 0)>1
    and (options.resource_samples or 8)>=4 and not continuation_blocker then
    local horizon=math.min(s.hands_left,math.max(1,options.resource_horizon or 4))
    local serpent=not s.blind.disabled and (s.blind.key=='bl_serpent' or s.blind.name=='The Serpent')
    local future_size=serpent and #s.hand+2*horizon or math.max(#s.hand,s.hand_size or #s.hand)
    if future_size<=CONTINUATION_HAND_LIMIT then
      local cost=count_plays(future_size,max_cards)
      local required=4*4*horizon*(cost+1) -- four rounds, at most four branches
      local cheapest=math.huge; for _,candidate in ipairs(candidates) do cheapest=math.min(cheapest,candidate.cost) end
      if required+4*cheapest<=available then
        continuation={horizon=horizon,future_size=future_size,cost=cost,serpent=serpent}
        reserve=required
      end
    end
  end
  local discard_budget = available - reserve
  if pass_cost * 4 > discard_budget then
    -- Start with a substantial redraw when only one candidate can fit; with
    -- more room, alternate small and large sizes before adding deeper options.
    local sized, ordered, included = {}, {}, {}
    for _, candidate in ipairs(candidates) do
      local size = #candidate.indices
      if not sized[size] then sized[size] = candidate end
    end
    local sizes = {}; for size in pairs(sized) do sizes[#sizes + 1] = size end
    table.sort(sizes)
    local left, right = 1, #sizes
    while left <= right do
      local candidate = sized[sizes[right]]; right = right - 1
      ordered[#ordered + 1], included[candidate] = candidate, true
      if left <= right then candidate = sized[sizes[left]]; left = left + 1; ordered[#ordered + 1], included[candidate] = candidate, true end
    end
    for _, candidate in ipairs(candidates) do if not included[candidate] then ordered[#ordered + 1] = candidate end end
    candidates, pass_cost = {}, 0
    for _, candidate in ipairs(ordered) do
      if 4 * (pass_cost + candidate.cost) <= discard_budget then
        candidates[#candidates + 1] = candidate; pass_cost = pass_cost + candidate.cost
      end
    end
    result.search_diagnostics = {discard_shortlist_reduced = true}
  end
  result.search_diagnostics = result.search_diagnostics or {}
  local compared_targets={}
  for _,target in ipairs(target_diagnostics) do
    for _,candidate in ipairs(candidates) do
      if table.concat(candidate.indices,',')==table.concat(target.indices,',') then
        compared_targets[#compared_targets+1]=target;break
      end
    end
  end
  if #compared_targets>0 then result.search_diagnostics.upgraded_draw_targets=compared_targets end
  if next(discard_warnings) then
    local warnings={};for reason in pairs(discard_warnings) do warnings[#warnings+1]=reason end;table.sort(warnings)
    result.search_diagnostics.discard_transition_warnings=warnings
  end
  result.search_diagnostics.discard_candidates = #candidates
  result.search_diagnostics.discard_pass_cost = pass_cost
  if continuation_blocker then result.search_diagnostics.continuation_skipped=continuation_blocker end
  if continuation then
    result.search_diagnostics.continuation_reserve=reserve
    local bounded=math.min(samples,math.floor(discard_budget/math.max(1,pass_cost)))
    result.search_diagnostics.discard_samples_limited=bounded<samples
    samples=bounded
  end
  if #candidates == 0 or samples < 4 then
    result.search_diagnostics.discard_skipped = 'Budget or draw size cannot support four complete paired discard samples.'
    if #candidates == 0 then truncated = true end
    return finish(result)
  end
  local function discard_state(candidate, order, bell_roll, outcome_seed)
    local state,effects
    if candidate.prepared then state=clone(candidate.prepared)
    elseif scorer.after_discard then state,effects=scorer.after_discard(s,candidate.indices) end
    local exact=state~=nil
    if not exact then
      if scorer.after_discard then
        result.search_diagnostics.discard_transition_warning=effects
        continuation=nil
        result.search_diagnostics.continuation_skipped=effects
      end
      state=clone(s)
    end
    local removed, hand, pool = {}, {}, {}
    for _, index in ipairs(order) do pool[#pool + 1] = s.deck[index] end
    for _, i in ipairs(candidate.indices) do removed[i] = true end
    if exact then hand=copy_list(state.hand)
    else for i, c in ipairs(s.hand) do if not removed[i] then hand[#hand + 1] = c end end end
    local draws = math.min(#pool, math.max(0, (state.hand_size or #s.hand) - #hand))
    if not s.blind.disabled and (s.blind.key == 'bl_serpent' or s.blind.name == 'The Serpent') then
      -- After any discard The Serpent draws three, even above hand capacity.
      draws = math.min(#pool, 3)
    end
    for i = 1, draws do
      local card=table.remove(pool,1)
      if options.draws then
        local roll=options.sampled_outcomes and options.sampled_outcomes.roll(outcome_seed or 19491001,0,'visibility',card.id or i)
        local reason;card,reason=options.draws.card(state,card,roll)
        if not card then return nil,reason end
      end
      hand[#hand + 1] = card
    end
    -- A discard clears the old forced selection before the next draw. Bell
    -- then chooses a new card; model that choice without touching live RNG.
    for i, c in ipairs(hand) do
      if c.ability and c.ability.forced_selection then
        hand[i] = clone(c)
        hand[i].ability = clone(c.ability)
        hand[i].ability.forced_selection = nil
      end
    end
    if #hand > 0 and not s.blind.disabled and
      (s.blind.key == 'bl_final_bell' or s.blind.name == 'Cerulean Bell') then
      local index = (bell_roll % #hand) + 1
      hand[index] = clone(hand[index])
      hand[index].ability = clone(hand[index].ability or {})
      hand[index].ability.forced_selection = true
    end
    state.hand, state.deck = hand, pool
    if not exact then
      state.discards_left, state.discards_used = s.discards_left - 1, (s.discards_used or 0) + 1
      state.current_round = clone(s.current_round or {})
      state.current_round.discards_left, state.current_round.discards_used = state.discards_left, state.discards_used
      state.dollars = s.dollars - ((s.modifiers or {}).discard_cost or 0)
      discard_score_penalties(state, #candidate.indices)
    end
    state.suppress_warnings = true
    return state
  end
  local function trial(candidate, order, bell_roll, outcome_seed)
    local state,reason = discard_state(candidate, order, bell_roll,outcome_seed)
    if not state then result.search_diagnostics.discard_skipped=reason;return nil end
    if concealed(state) then
      result.search_diagnostics.discard_skipped='A future hand is concealed; identity-based play optimization is unsupported.';return nil
    end
    local next_play = best_play(state)
    if truncated then return end -- Never count a partially enumerated trial.
    local b=state.blind or {}
    if next_play and not b.disabled and (b.key=='bl_hook' or b.name=='The Hook') then
      if not options.sampled_outcomes then
        result.search_diagnostics.discard_skipped='Hook discard forecasts need sampled held-card outcomes.';return nil
      end
      local after,effects,actual=after_play(state,next_play.indices,outcome_seed,1)
      if not after then result.search_diagnostics.discard_skipped=effects;return nil end
      actual.indices=next_play.indices;next_play=actual
      -- The Hook can change cash, Yorick and held multipliers BEFORE scoring.
      -- Its resolved score, rather than the optimistic unmodified held hand,
      -- is the evidence for this sampled clear (also on the last hand).
    end
    local score = next_play and next_play.score or 0
    local clear=reliable_clear(next_play,remaining)
    if next_play and next_play.uncertain and score>=remaining and scorer.lower_bound then
      local bound_state,bound_indices=state,next_play.indices
      if not b.disabled and (b.key=='bl_hook' or b.name=='The Hook') and scorer.prepare_play then
        bound_state,bound_indices=scorer.prepare_play(state,next_play.indices,
          options.sampled_outcomes.context(state,next_play.indices,outcome_seed,1))
      end
      if bound_state then
        if evaluations>=max_evaluations then truncated=true;return nil end
        evaluations=evaluations+1
        local bound=scorer.lower_bound(bound_state,bound_indices)
        clear=bound and bound.reliable_bound and reliable_clear(bound,remaining)
      end
    end
    if next_play and next_play.uncertain then
      result.search_diagnostics.sampled_clear_scope='Supported score floors count as clears; random means and hidden identities do not.'
    end
    return {score = score, win = clear and 1 or 0,
      utility = math.min(score / remaining, 1)}
  end
  local last_hand = (s.hands_left or (s.current_round or {}).hands_left or 1) <= 1
  -- Give every candidate the same sampled deck order. Commit a sample only
  -- after every candidate finishes, so a budget cutoff cannot leave earlier
  -- candidates with extra observations or luckier independent draw samples.
  for sample = 1, samples do
    local order, outcomes = {}, {}
    for i = 1, #s.deck do order[i] = i end
    for i = #order, 2, -1 do local j = random(i); order[i], order[j] = order[j], order[i] end
    local bell = not s.blind.disabled and (s.blind.key == 'bl_final_bell' or s.blind.name == 'Cerulean Bell')
    local bell_roll = bell and random(1000000) or 0
    -- Effect sampling has its own counter stream. Enabling Glass/Hook/Heart
    -- must not perturb otherwise identical ordinary replacement-deck samples.
    local outcome_seed=options.sampled_outcomes and (19491001+sample*104729) or nil
    for i, candidate in ipairs(candidates) do
      outcomes[i] = trial(candidate, order, bell_roll,outcome_seed)
      if not outcomes[i] and not truncated then return finish(result) end
      if truncated then break end
    end
    if truncated then break end
    for i, candidate in ipairs(candidates) do
      local outcome = outcomes[i]
      candidate.total = candidate.total + outcome.score
      candidate.wins = candidate.wins + outcome.win
      candidate.count = candidate.count + 1
      candidate.utility = candidate.utility + outcome.utility
    end
    -- Final-hand survival ranks by successful draws. Stop only when even the
    -- most favorable uncomputed tail cannot let any rival catch the leader.
    -- This is an exact bound for this finite planned sample set, not a
    -- statistical confidence interval or a claim about the underlying deck.
    if options.adaptive_samples~=false and last_hand and #candidates>1 and candidates[1].count>=4 then
      local leader=candidates[1]
      for _,candidate in ipairs(candidates) do if candidate.wins>leader.wins then leader=candidate end end
      local left=samples-leader.count;local decided=left>0
      for _,candidate in ipairs(candidates) do
        if candidate~=leader and leader.wins<=candidate.wins+left then decided=false end
      end
      if decided then
        result.search_diagnostics.adaptive_samples={completed=leader.count,planned=samples,
          winner=copy_list(leader.indices),uncomputed_tail=left,rule='strict finite-tail survival dominance'}
        break
      end
    end
  end
  local best_discard
  local function better_discard(a, b)
    if not b then return true end
    -- On the final hand only a clear survives. A higher average losing score
    -- must not outrank a redraw that actually clears in more sampled outcomes.
    if last_hand and a.probability ~= b.probability then return a.probability > b.probability end
    if a.value ~= b.value then return a.value > b.value end
    if #a.indices ~= #b.indices then return #a.indices < #b.indices end
    return table.concat(a.indices, ',') < table.concat(b.indices, ',')
  end
  for _, c in ipairs(candidates) do
    if c.count >= 4 then
      c.mean, c.probability = c.total / c.count, c.wins / c.count
      c.value = 0.7 * c.utility / c.count + 0.3 * c.probability
      if not last_hand and profile and profile.horizon>0 then
        c.value=c.value+math.min(0.035,0.008*(c.growth or 0))*c.probability
      end
      if better_discard(c, best_discard) then best_discard = c end
    end
  end
  result.discard, result.evaluations, result.truncated = best_discard, evaluations, truncated
  -- Retry exploration may reuse only the whole committed comparison. An
  -- adaptive winner certificate does not finish ranking the remaining choices
  -- after that winner's line has failed; its uncomputed tail is not exported.
  local retry_complete=not truncated and #candidates>0 and
    not (result.search_diagnostics.adaptive_samples and result.search_diagnostics.adaptive_samples.uncomputed_tail>0)
  local retry_samples=candidates[1] and candidates[1].count or 0
  if retry_samples<4 then retry_complete=false end
  for _,candidate in ipairs(candidates) do if candidate.count~=retry_samples then retry_complete=false end end
  result.discard_comparison_complete=retry_complete
  if retry_complete then
    result.discard_alternatives={}
    for _,candidate in ipairs(candidates) do
      result.discard_alternatives[#result.discard_alternatives+1]={indices=copy_list(candidate.indices),
        count=candidate.count,mean=candidate.mean,probability=candidate.probability,value=candidate.value,growth=candidate.growth}
    end
  end
  local play_value = play and (0.7 * math.min(play.score / remaining, 1) + (play.score >= remaining and 0.3 or 0)) or 0
  if best_discard and (not play or last_hand or best_discard.value > play_value + weight('discard_action_penalty',0.06) / math.max(1, s.discards_left)) then
    result.kind = 'discard'
  end
  -- Compare cumulative blind completion, not just the next play's score.
  -- Every branch shares a sampled deck order and carries supported state
  -- changes forward; subsequent discard decisions remain outside this horizon.
  if continuation and best_discard and not last_hand and not truncated then
    local branches={{kind='play',total=0,wins=0,utility=0,turns=0,worlds={}}}
    local ranked={}
    for _,candidate in ipairs(candidates) do if candidate.count>=4 then ranked[#ranked+1]=candidate end end
    table.sort(ranked,better_discard)
    local seen={}
    local function add_branch(candidate)
      if candidate and not seen[candidate] then
        seen[candidate]=true
        branches[#branches+1]={kind='discard',discard=candidate,total=0,wins=0,utility=0,turns=0,worlds={}}
      end
    end
    add_branch(ranked[1]); add_branch(ranked[2])
    local smallest
    for _,candidate in ipairs(ranked) do
      if not smallest or #candidate.indices<#smallest.indices or
        (#candidate.indices==#smallest.indices and better_discard(candidate,smallest)) then smallest=candidate end
    end
    add_branch(smallest)
    local horizon=continuation.horizon
    local serpent=continuation.serpent
    local bell=not s.blind.disabled and (s.blind.key=='bl_final_bell' or s.blind.name=='Cerulean Bell')
    local future_size,cost=continuation.future_size,continuation.cost
    local pass_cost=#branches*horizon*(cost+1)
    local cycle_bound=(1+3*(max_cards-#play.indices))*(4*cost+1)
    if future_size<=CONTINUATION_HAND_LIMIT and pass_cost>0 and max_evaluations-evaluations>=4*pass_cost then
      local preview={kind='play',play=play,alternatives=alternatives}
      local cycle_options=clone(options); cycle_options.cycle_samples=4
      if max_evaluations-evaluations>=4*pass_cost+cycle_bound then
        choose_cycle(s,scorer,preview,cycle_options,cycle_context)
      else result.search_diagnostics.continuation_cycle_skipped=true end
      cycle_evaluated=true
      result.play=preview.play
      local count=math.min(options.resource_samples or 8,math.floor((max_evaluations-evaluations)/pass_cost))
      local completed,compatible,unsupported_reason=0,true,nil
      local function rollout(branch,order,bell_rolls,outcome_seed)
        local state,selected
        if branch.kind=='discard' then state=discard_state(branch.discard,order,bell_rolls[1],outcome_seed)
        else
          state=clone(s); state.deck={}; state.suppress_warnings=true
          for _,index in ipairs(order) do state.deck[#state.deck+1]=s.deck[index] end
          selected=preview.play.indices
        end
        local turns=0
        for turn=1,horizon do
          if not selected then
            local next_play=best_play(state)
            if truncated or not next_play then return nil end
            selected=next_play.indices
          end
          if not state then return nil end
          local after,reason,actual=after_play(state,selected,outcome_seed,turn)
          if truncated or not after then unsupported_reason=reason or 'Continuation exceeded its supported state or budget.'; return nil end
          if actual and actual.uncertain then
            unsupported_reason='Random score or growth outcomes are not sampled by this continuation.';return nil
          end
          state,selected=after,nil; turns=turns+1
          if state.chips>=state.blind.chips or state.hands_left<=0 then break end
          if options.draws and options.sampled_outcomes then
            state,reason=options.sampled_outcomes.fill(state,state.deck,scorer,options.draws,outcome_seed,turn,bell_rolls[turn+1])
            if not state then unsupported_reason=reason;return nil end
          else
            local draws=math.min(#state.deck,serpent and 3 or math.max(0,(state.hand_size or #s.hand)-#state.hand))
            for _=1,draws do state.hand[#state.hand+1]=table.remove(state.deck,1) end
          end
          if #state.hand==0 then break end
          if concealed(state) then unsupported_reason='A future hand is concealed; no hidden-card play policy is modeled.';return nil end
          if #state.hand>CONTINUATION_HAND_LIMIT then unsupported_reason='A future hand exceeded the continuation size limit.'; return nil end
          if bell then
            local index=(bell_rolls[turn+1]%#state.hand)+1
            state.hand[index].ability=state.hand[index].ability or {}
            state.hand[index].ability.forced_selection=true
          end
        end
        local gain=math.max(0,state.chips-(s.chips or 0))
        return {score=math.min(gain,remaining),win=state.chips>=state.blind.chips and 1 or 0,
          utility=math.min(gain/remaining,1),turns=turns}
      end
      for sample=1,count do
        local order,rolls,outcomes={},{},{}
        for i=1,#s.deck do order[i]=i end
        for i=#order,2,-1 do local j=random(i); order[i],order[j]=order[j],order[i] end
        for i=1,horizon+1 do rolls[i]=bell and random(1000000) or 0 end
        local outcome_seed=options.sampled_outcomes and (9081721+sample*104729) or nil
        local valid=true
        for i,branch in ipairs(branches) do
          outcomes[i]=rollout(branch,order,rolls,outcome_seed)
          if not outcomes[i] then valid=false; break end
        end
        -- Unsupported transitions (for example Hook/DNA/Glass destruction)
        -- invalidate this comparison, rather than selecting only the samples
        -- whose draws happened to avoid the unsupported effect.
        if not valid then compatible=false; break end
        completed=completed+1
        for i,branch in ipairs(branches) do local outcome=outcomes[i]
          branch.total=branch.total+outcome.score; branch.wins=branch.wins+outcome.win
          branch.utility=branch.utility+outcome.utility; branch.turns=branch.turns+outcome.turns
          branch.worlds[#branch.worlds+1]=outcome
        end
      end
      if completed>=4 and compatible then
        local best,prior=branches[1],result.kind=='play' and branches[1] or branches[2]
        local full_horizon=horizon>=s.hands_left
        for _,branch in ipairs(branches) do
          branch.mean=branch.total/completed; branch.probability=branch.wins/completed
          branch.value=0.7*branch.utility/completed+0.3*branch.probability
          branch.mean_hands=branch.turns/completed
          if full_horizon and branch.wins~=best.wins then
            if branch.wins>best.wins then best=branch end
          elseif branch.value>best.value then best=branch end
        end
        local function summary(branch)
          return {kind=branch.kind,indices=copy_list(branch.kind=='play' and preview.play.indices or branch.discard.indices),
            mean=branch.mean,probability=branch.probability,value=branch.value,mean_hands=branch.mean_hands,worlds=branch.worlds}
        end
        local aggregate_best=best
        local allowed,override_reason=M.resource_override_supported(s,prior,best)
        if not allowed then best=prior end
        result.resource_comparison={samples=completed,horizon=horizon,play=summary(branches[1]),
          prior_discard=summary(branches[2]),prior=summary(prior),best=summary(best),future_discards=false,
          full_remaining_horizon=full_horizon,scope='remaining_blind'}
        if not allowed then
          result.resource_comparison.aggregate_best=summary(aggregate_best)
          result.resource_comparison.override_rejected=override_reason
        end
        if options.sampled_outcomes then result.resource_comparison.sampled_effects='shared Glass/Hook/Heart and supported no-Joker Lucky outcomes; uncalibrated Monte Carlo' end
        -- Require a meaningful matched improvement before overriding the
        -- ordinary search. Winning an already risky final hand still has priority.
        local survival_gain=full_horizon and best.probability>prior.probability+0.10
        if best~=prior and best.wins>=prior.wins and (survival_gain or best.value>prior.value+0.04) then
          result.kind=best.kind
          if best.kind=='discard' then result.discard=best.discard
          else
            result.play=clone(preview.play)
            result.play.future_note='Paired remaining-blind estimates favor playing now; a stronger immediate redraw can leave too little score for the remaining hands.'
          end
        end
      end
      if not compatible then result.search_diagnostics.continuation_skipped=unsupported_reason or 'A compared continuation could not be modeled.' end
    end
  end
  return finish(result)
end

return M
