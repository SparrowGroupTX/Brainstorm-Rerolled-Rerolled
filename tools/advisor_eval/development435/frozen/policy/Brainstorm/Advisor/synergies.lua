-- Detached, deterministic opportunity estimates. No live callbacks or RNG.
-- Vanilla pool weights and rules are mirrored from get_current_pool and
-- create_card_for_shop; these are chances to FIND a partner, not win rates.
local M = {}
local function num(x, fallback) return type(x) == 'number' and x or (fallback or 0) end
local function ability(c) return c.ability or {} end
local function has(s, key)
  for _, c in ipairs(s.jokers or {}) do if c.key == key and not c.debuff then return c end end
end
local function negative(c) return c.edition == 'negative' or type(c.edition) == 'table' and c.edition.negative end
local function omelette(s) return s.challenge == 'c_omelette_1' or type(s.challenge) == 'table' and s.challenge.id == 'c_omelette_1' end
local pairs_catalog = {
  {a='j_wee',b='j_hanging_chad',value=38,needs='twos',text='Put a scoring 2 first: Hanging Chad repeats it twice, giving Wee three growth triggers.'},
  {a='j_wee',b='j_hack',value=32,needs='twos',text='Hack repeats scored 2s, so each one grows Wee again.'},
  {a='j_ancient',b='j_hanging_chad',value=34,needs='ancient',text='Put Ancient\'s current suit first among scoring cards to repeat its XMult with Hanging Chad.'},
  {a='j_baron',b='j_mime',value=42,needs='kings',text='Hold Kings unplayed: Mime retriggers their Baron XMult.'},
  {a='j_photograph',b='j_hanging_chad',value=48,needs='faces',text='Put a face card first among scoring cards: Chad repeats Photograph\'s first-face XMult.'},
  {a='j_dna',b='j_hologram',value=35,needs='spare_hand',text='DNA\'s single-card first play adds a card and grows Hologram; budget a hand for the setup.'},
  {a='j_certificate',b='j_hologram',value=30,text='Certificate adds a card each round, growing Hologram.'},
  {a='j_fibonacci',b='j_hack',value=26,needs='low_fibonacci',text='Hack repeats scored 2s, 3s, and 5s, applying Fibonacci Mult again.'},
  {a='j_scholar',b='j_hanging_chad',value=25,needs='aces',text='Put a scoring Ace first to repeat Scholar\'s Chips and Mult with Chad.'},
}
local names = {j_wee='Wee Joker',j_hanging_chad='Hanging Chad',j_hack='Hack',j_ancient='Ancient Joker',
  j_baron='Baron',j_mime='Mime',j_photograph='Photograph',j_dna='DNA',j_hologram='Hologram',
  j_certificate='Certificate',j_fibonacci='Fibonacci',j_scholar='Scholar'}

local function condition(s, pair)
  if pair.needs == 'spare_hand' then
    local base=num((s.round_resets or {}).hands,4)
    if (s.next_blind or {}).key=='bl_needle' and not has(s,'j_chicot') then base=1 end
    local bonus=s.round_bonus or (s.shop_forecast or {}).round_bonus or {}
    local burglar=has(s,'j_burglar')
    return base+num(bonus.next_hands)+(burglar and num(ability(burglar).extra,3) or 0)>1 and 1 or 0
  end
  if not pair.needs then return 1 end
  local deck = s.playing_cards or s.deck or {}
  if #deck == 0 then return 0 end -- Do not invent the cards needed by a combo.
  local count = 0
  local suit = ((s.current_round or {}).ancient_card or {}).suit
  for _, c in ipairs(deck) do
    if c.enhancement ~= 'm_stone' then
      local rank = c.rank or (c.base or {}).id
      if pair.needs == 'twos' and rank == 2 or
        pair.needs == 'aces' and rank == 14 or
        pair.needs == 'kings' and rank == 13 or
        pair.needs == 'low_fibonacci' and (rank == 2 or rank == 3 or rank == 5) or
        pair.needs == 'faces' and (has(s,'j_pareidolia') or rank and rank >= 11 and rank <= 13) or
        pair.needs == 'ancient' and (not suit or c.suit == suit or c.enhancement == 'm_wild') then count = count + 1 end
    end
  end
  if count == 0 then return 0 end
  if s.teacher_profile=='perkeo_yorick_win_v1' then
    -- Owned population is an opportunity, not a guaranteed draw/trigger. One
    -- matching card in a broad deck cannot earn the full concentrated combo.
    return math.min(1,count/math.max(4,#deck*0.2))
  end
  if pair.needs == 'kings' then return math.min(1, count / 4) end
  return 1
end

-- Economy-only cards are not evidence that a speculative purchase is safe.
local support = {j_joker=true,j_abstract=true,j_half=true,j_jolly=true,j_zany=true,j_mad=true,j_crazy=true,j_droll=true,
  j_sly=true,j_wily=true,j_clever=true,j_devious=true,j_crafty=true,j_banner=true,j_blue_joker=true,
  j_fibonacci=true,j_scholar=true,j_swashbuckler=true,j_card_sharp=true,j_ancient=true,j_photograph=true,
  j_gros_michel=true,j_popcorn=true,j_ice_cream=true,j_odd_todd=true,j_even_steven=true,j_mystic_summit=true}
local function immediate_support(s)
  for _, c in ipairs(s.jokers or {}) do
    local a = ability(c)
    if not c.debuff and (support[c.key] or num(a.mult) >= 4 or num(a.t_chips) >= 25 or
      num(a.x_mult) > 1 or type(a.extra) == 'table' and num(a.extra.chips) >= 25 or
      type(c.edition) == 'table' and (c.edition.holo or c.edition.foil or c.edition.polychrome)) then return true end
  end
  return false
end

local function partner_space(s, candidate)
  if #(s.jokers or {}) + 2 <= num(s.joker_limit,5) + (negative(candidate) and 1 or 0) then return true end
  for _, c in ipairs(s.jokers or {}) do
    if c.key == 'j_egg' and not ability(c).eternal and not negative(c) and not (s.modifiers or {}).all_eternal then return true end
  end
  return false
end

local function eligible_pools(s, candidate, meta)
  local used, owned = {}, {}
  for key, value in pairs(meta.used or {}) do if value then used[key] = true end end
  -- Current offers disappear before the next refresh. They are not permanent
  -- exclusions; owned cards and the proposed purchase remain excluded.
  for _, area in ipairs({'shop_jokers','pack_cards'}) do for _, c in ipairs(s[area] or {}) do used[c.key] = nil end end
  for _, c in ipairs(s.jokers or {}) do owned[c.key], used[c.key] = true, true end
  used[candidate.key] = true
  local showman = has(s,'j_ring_master') or candidate.key == 'j_ring_master' -- vanilla Showman key
  local out = {}
  for rarity=1,3 do
    if type(meta.pools[rarity]) ~= 'table' then return nil end
    out[rarity] = {}
    for _, entry in ipairs(meta.pools[rarity]) do
      if showman or not used[entry.key] then out[rarity][#out[rarity]+1] = entry end
    end
    -- Vanilla falls back to Joker when an entire rarity pool is unavailable.
    if #out[rarity] == 0 then out[rarity][1] = {key='j_joker',name='Joker',cost=2,rarity=rarity} end
  end
  return out
end

local function price(meta, entry)
  return math.max(1,math.floor((num(entry.cost,8) + num(meta.inflation) + 0.5) *
    math.max(0,100-num(meta.discount_percent))/100))
end

local function round_position(s)
  local key = (s.blind or {}).key
  if key == 'bl_small' then return 1 elseif key == 'bl_big' then return 2 end
  local states = s.blind_states or {}
  if states.Boss == 'Defeated' then return 3 elseif states.Big == 'Defeated' then return 2 end
  if s.blind and s.blind.key then return 3 end
  return 1
end

local function round_income(s, candidate, meta, cash, round_index, next_type)
  local mods, total, rent, growth = s.modifiers or {}, 0, 0, 0
  local owned = {}
  for _, c in ipairs(s.jokers or {}) do owned[#owned+1] = c end
  owned[#owned+1] = candidate
  for _, c in ipairs(owned) do
    local a = ability(c)
    if a.rental then rent = rent + num(meta.rental_rate,3) end
    if not c.debuff and (not a.perishable or num(a.perish_tally,5) >= round_index) then
      local cashout=not a.perishable or num(a.perish_tally,5)>round_index
      if c.key == 'j_golden' and cashout then total = total + num(a.extra,4)
      elseif c.key == 'j_rocket' and cashout then total = total + num(type(a.extra)=='table' and a.extra.dollars,1)
      elseif c.key == 'j_cloud_9' and cashout then
        local nines=0
        for _, playing in ipairs(s.playing_cards or {}) do if playing.rank==9 and playing.enhancement~='m_stone' then nines=nines+1 end end
        total = total + nines*num(a.extra,1)
      elseif c.key == 'j_egg' then growth = growth + num(a.extra,3)
      elseif c.key == 'j_gift' then growth = growth + (#owned+#(s.consumeables or {}))*num(a.extra,1) end
    end
  end
  if not omelette(s) then
    if not (mods.no_blind_reward or {})[next_type] then total=total+num((meta.blind_rewards or {})[next_type]) end
    if not mods.no_extra_hand_money then
      local unused = math.min(num(s.hands_left),math.max(0,num((s.round_resets or {}).hands,4)-1))
      total=total+unused*num(mods.money_per_hand,1)
    end
    if not mods.no_interest then
      total=total+math.min(math.floor(math.max(0,cash-rent)/5),num(s.interest_cap,25)/5)*num(s.interest_amount,1)
    end
  end
  return total-rent, growth, rent
end

-- Budget one current shop plus at most the next three useful shops. Observed
-- offers are never counted again as random opportunities. Preserve money for
-- the partner AND $4 of other upgrades; never assume an Egg will be sold.
function M.opportunities(s, candidate, partner_cost)
  local meta = s.shop_forecast
  if not meta or type(meta.slots)~='number' or meta.slots<1 then return nil end
  local round=s.current_round or {}
  local resets=s.round_resets or {}
  if type(round.reroll_cost)~='number' or type(resets.reroll_cost)~='number' then return nil end
  local initial_cost=s.phase=='pack' and 0 or num(candidate.cost)
  local cash=num(s.dollars)-initial_cost
  local reserve=partner_cost+4
  local position=round_position(s)
  local future=math.min(3,math.max(0,(8-num(s.ante,1))*3+(3-position)-1))
  if ability(candidate).perishable then future=math.min(future,math.max(0,num(ability(candidate).perish_tally,5)-1)) end
  local out={slots=0,rerolls=0,reroll_spend=0,future_shops=future,projected_income=0,
    resale_growth=0,rental_drain=0,reserve=reserve,starting_cash=cash,stages={}}
  local reset_free=0
  for _, c in ipairs(s.jokers or {}) do if c.key=='j_chaos' and not c.debuff then reset_free=reset_free+1 end end
  if candidate.key=='j_chaos' then reset_free=reset_free+1 end
  for stage=0,future do
    local count,rolls,spend=0,0,0
    if stage>0 then
      local next_type=({'Small','Big','Boss'})[(position+stage-1)%3+1]
      local income,growth,rent=round_income(s,candidate,meta,cash,stage,next_type)
      cash=cash+income
      out.projected_income=out.projected_income+income
      out.resale_growth=out.resale_growth+growth
      out.rental_drain=out.rental_drain+rent
      if cash>=partner_cost then count=count+meta.slots end
    end
    local free=stage==0 and math.max(0,num(round.free_rerolls)) or reset_free
    local increase=stage==0 and math.max(0,num(round.reroll_cost_increase)) or 0
    local base=stage==0 and num(resets.temp_reroll_cost,num(resets.reroll_cost)) or num(resets.reroll_cost)
    local cost=stage==0 and math.max(0,num(round.reroll_cost)) or (free>0 and 0 or math.max(0,base))
    -- A finite budget/horizon is not a mandate to spend it: these are optional
    -- refreshes available while reserving the partner's purchase price.
    while rolls<8 and cash>=partner_cost and (cost==0 or cash-cost>=reserve) do
      cash=cash-cost; spend=spend+cost; rolls=rolls+1; count=count+meta.slots
      if free>0 then free=free-1
      else increase=increase+1 end
      cost=free>0 and 0 or math.max(0,base+increase)
    end
    out.slots=out.slots+count; out.rerolls=out.rerolls+rolls; out.reroll_spend=out.reroll_spend+spend
    out.stages[#out.stages+1]={future_shop=stage,slots=count,rerolls=rolls,spend=spend,cash=cash}
  end
  out.remaining_cash=cash
  return out
end

function M.forecast(s,candidate)
  local out={bonus=0,owned_bonus=0,lines={},existing={},potential={}}
  if not candidate or not candidate.key or candidate.debuff or
    ability(candidate).perishable and num(ability(candidate).perish_tally,5)<=0 then return out end
  local matching={}
  for _, pair in ipairs(pairs_catalog) do
    local partner=pair.a==candidate.key and pair.b or pair.b==candidate.key and pair.a
    if partner then
      local factor=condition(s,pair)
      if factor>0 then matching[#matching+1]={key=partner,pair=pair,value=pair.value*factor} end
    end
  end
  if #matching==0 then return out end
  local missing={}
  for _, entry in ipairs(matching) do
    if has(s,entry.key) then
      out.existing[#out.existing+1]=entry.key
      out.bonus=math.max(out.bonus,entry.value)
      out.owned_bonus=math.max(out.owned_bonus,entry.value)
      out.lines[#out.lines+1]='Owned synergy: '..(names[entry.key] or entry.key)..'. '..entry.pair.text
    else missing[#missing+1]=entry end
  end
  if #missing==0 then out.mode='owned'; return out end
  -- Known visible partners are separate from randomized future shops.
  for _, entry in ipairs(missing) do
    local area=s.phase=='pack' and 'pack_cards' or 'shop_jokers'
    for index,visible in ipairs(s[area] or {}) do
      if visible.key==entry.key and not visible.debuff and
        (#(s.jokers or {})+2<=num(s.joker_limit,5)+(negative(candidate) and 1 or 0)+(negative(visible) and 1 or 0)) and
        (s.phase=='pack' and num(s.pack_choices,1)>=2 or s.phase~='pack' and num(s.dollars)>=num(candidate.cost)+num(visible.cost)) then
        out.mode='available'; out.bonus=math.max(out.bonus,entry.value*0.85)
        out.available={key=entry.key,area=area,index=index}
        out.lines[#out.lines+1]='Available now: '..(names[entry.key] or entry.key)..' is already visible and both cards fit the current cash and slots. '..entry.pair.text
        return out
      end
    end
  end
  local meta=s.shop_forecast
  if not meta or not meta.pools or not meta.rates or meta.special_shop_rules then
    out.lines[#out.lines+1]='Speculative partner odds unavailable: complete ordinary-shop pool/rate data is missing or a tag overrides normal offers.'
    return out
  end
  local total=0
  for _, key in ipairs({'joker','tarot','planet','playing','spectral'}) do
    if type(meta.rates[key])~='number' or meta.rates[key]<0 then return out end
    total=total+meta.rates[key]
  end
  if total<=0 then return out end
  local pools=eligible_pools(s,candidate,meta)
  if not pools then return out end
  local bykey={}
  local weights={0.7,0.25,0.05}
  for rarity=1,3 do
    for _, entry in ipairs(pools[rarity]) do
      bykey[entry.key]={probability=(meta.rates.joker/total)*weights[rarity]/#pools[rarity],price=price(meta,entry),rarity=rarity,pool_size=#pools[rarity]}
    end
  end
  local per_slot,max_cost,weighted_value=0,0,0
  local labels={}
  for _, entry in ipairs(missing) do
    local eligible=bykey[entry.key]
    if eligible then
      out.potential[#out.potential+1]={key=entry.key,per_slot=eligible.probability,rarity=eligible.rarity,pool_size=eligible.pool_size,price=eligible.price}
      per_slot=per_slot+eligible.probability; max_cost=math.max(max_cost,eligible.price)
      weighted_value=weighted_value+eligible.probability*entry.value
      labels[#labels+1]=names[entry.key] or entry.key
    end
  end
  if #labels==0 then
    out.probability=0
    out.lines[#out.lines+1]='Speculative partners are currently excluded from the eligible shop pools; no purchase bonus for finding one.'
    return out
  end
  local horizon=M.opportunities(s,candidate,max_cost)
  if not horizon then out.lines[#out.lines+1]='Speculative partner odds unavailable: shop capacity or reroll prices are missing.'; return out end
  out.mode='speculative'; out.horizon=horizon; out.per_slot=per_slot
  out.probability=1-(1-math.min(1,per_slot))^horizon.slots
  local delay=math.max(0.2,1-math.max(0,num(s.ante,1)-3)*0.14)
  local potential_bonus=per_slot>0 and weighted_value/per_slot*out.probability*0.6*delay or 0
  if not immediate_support(s) then
    potential_bonus=0
    out.lines[#out.lines+1]='Cover immediate scoring first; a possible future combo does not justify using the last scoring opportunity.'
  elseif not partner_space(s,candidate) then
    potential_bonus=0
    out.lines[#out.lines+1]='No spare or expendable Egg slot for the partner; do not replace the scoring engine to speculate.'
  end
  out.bonus=out.bonus+math.min(22,potential_bonus)
  out.lines[#out.lines+1]=string.format('Speculative: ~%.1f%% to find %s across %d affordable shop slots (current rerolls + next %d shops; %d optional rerolls costing $%g).',
    out.probability*100,table.concat(labels,' or '),horizon.slots,horizon.future_shops,horizon.rerolls,horizon.reroll_spend)
  out.lines[#out.lines+1]=string.format('Budget after this purchase: $%g; projected net cash change $%g, with $%g rental drain and $%g reserved for partner plus other upgrades. Egg/Gift resale growth $%g is not spendable unless sold.',
    horizon.starting_cash,horizon.projected_income,horizon.rental_drain,horizon.reserve,horizon.resale_growth)
  out.lines[#out.lines+1]='Approximate independent shop draws using current eligible rarity pools; offers/exclusions change after purchases. Assumes surviving the horizon and recent unused-hand income; excludes packs, editions, uncertain triggered income and future deck changes. This is not a run-win probability.'
  return out
end

return M
