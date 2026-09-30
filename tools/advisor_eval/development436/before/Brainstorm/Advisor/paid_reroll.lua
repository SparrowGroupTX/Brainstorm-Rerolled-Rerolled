-- Budget one optional ordinary-shop refresh. Finding an affordable candidate
-- is only an opportunity estimate; it is never presented as a win probability.
local M={}
local function finite(x) return type(x)=='number' and x==x and x~=math.huge and x~=-math.huge end
local function n(x,d) return finite(x) and x or (d or 0) end
local function challenge(s) return type(s.challenge)=='table' and s.challenge.id or s.challenge end
local function negative(j) return j.edition=='negative' or type(j.edition)=='table' and j.edition.negative end
local function active(j)
  local a=j.ability or {}
  return not j.debuff and not a.perma_debuff and not (a.perishable and n(a.perish_tally,5)<=0)
end
-- Source create_card uses one mutually exclusive Eternal/Perishable poll and
-- a separate Rental poll. Credit only the event in which neither poll applies
-- a sticker; center incompatibilities can only add outcomes we leave uncredited.
-- This is catalog-model mass, not observed search yield or a run-win chance.
function M.no_sticker_probability(mods)
  if type(mods)~='table' or getmetatable(mods) then return nil,'Shop modifier metadata is unavailable.' end
  for _,key in ipairs({'all_eternal','enable_eternals_in_shop','enable_perishables_in_shop','enable_rentals_in_shop'}) do
    if mods[key]~=nil and type(mods[key])~='boolean' then return nil,'A prospective shop-sticker flag is unknown.' end
  end
  if mods.all_eternal then return nil,'Forced Eternal offers have no qualified ordinary unstickered event.' end
  local permanent=mods.enable_eternals_in_shop and 0.3 or 0
  local perishable=mods.enable_perishables_in_shop and 0.3 or 0
  return (1-permanent-perishable)*(mods.enable_rentals_in_shop and 0.7 or 1),
    'Only the source no-sticker event is credited; compatible/incompatible sticker outcomes remain unassessed.'
end
local function opening_gain(evidence)
  local before=evidence and evidence.before_readiness
  local after=evidence and evidence.after_readiness
  if not before or not after or not before.supported or not after.supported or evidence.uncertain or
    not finite(before.target) or before.target<=0 or before.target~=after.target or
    type(before.opening_scores)~='table' or type(after.opening_scores)~='table' or
    #before.opening_scores~=4 or #after.opening_scores~=4 then return nil end
  local gain=0
  for i=1,4 do
    local left,right=before.opening_scores[i],after.opening_scores[i]
    if not finite(left) or not finite(right) or left<0 or right<0 then return nil end
    gain=gain+(math.min(before.target,right)-math.min(before.target,left))/before.target/4
  end
  return gain
end
M.opening_gain=opening_gain
function M.planet_card(entry,price)
  if type(entry)~='table' or entry.source_set~='Planet' or type(entry.key)~='string' or
    type(entry.name)~='string' or type(entry.source_config)~='table' or
    type(entry.source_config.hand_type)~='string' or not finite(price) or price<0 then return nil end
  local config={}
  for key,value in pairs(entry.source_config) do
    if key~='hand_type' and key~='softlock' then return nil end
    config[key]=value
  end
  return {id='catalog:'..entry.key,key=entry.key,name=entry.name,cost=price,
    sell_cost=math.max(1,math.floor(price/2)),debuff=false,
    ability={name=entry.name,set='Planet',effect=entry.source_effect,consumeable=config}}
end

-- The first non-Joker extension deliberately credits only the first new shop
-- slot. Its pool is known before any new offers alter duplicate exclusions;
-- later slots and unassessed types receive zero credit, without independence
-- assumptions. This is a bounded catalog estimate, never a seed or win oracle.
function M.planet_suggest(s,assess,readiness,options)
  local meta=s.shop_forecast;local mods=s.modifiers or {}
  local cost=n(s.reroll_cost,n((s.current_round or {}).reroll_cost,5))
  local before=readiness and readiness.before_readiness
  if s.phase~='shop' or cost<=0 or cost>8 or n(s.ante,1)>8 or not meta or not meta.rates or
    meta.rates.joker~=0 or meta.special_shop_rules or mods.inflation or
    meta.consumable_pool_schema~='source_shop_consumables_v1' or type(meta.planet_pool)~='table' or
    type(meta.consumable_used)~='table' or type(assess)~='function' or not options or
    type(options.compare)~='function' or type(options.compare_miss)~='function' or
    not before or not before.supported or before.status=='sampled_safe' or
    not finite(before.target) or before.target<=0 or opening_gain(readiness)==nil then return nil end
  local pressured=before.status=='sampled_deficit' or before.status=='unresolved' and
    n(before.clearing_samples)<=1 and n(before.opening_mean)>=0 and n(before.opening_mean)<before.target*0.75
  if not pressured or #(s.consumeables or {})>=n(s.consumable_limit,2) then return nil end
  local total=0
  for _,kind in ipairs({'joker','tarot','planet','playing','spectral'}) do
    if not finite(meta.rates[kind]) or meta.rates[kind]<0 then return nil end
    total=total+meta.rates[kind]
  end
  if total<=0 or meta.rates.planet<=0 or not finite(meta.slots) or meta.slots<1 or meta.slots>10 or
    meta.slots~=math.floor(meta.slots) or not finite(meta.inflation) or meta.inflation<0 or
    not finite(meta.discount_percent) or meta.discount_percent<0 or meta.discount_percent>100 then return nil end
  local survival=math.max(0,n(mods.discard_cost))*math.max(0,n(before.discards))
  local used={};for key,value in pairs(meta.consumable_used) do if value then used[key]=true end end
  for _,card in ipairs(s.shop_jokers or {}) do if card.key then used[card.key]=nil end end
  for _,card in ipairs(s.consumeables or {}) do if card.key then used[card.key]=true end end
  local showman,astronomer=false,false
  for _,card in ipairs(s.jokers or {}) do
    if (card.ability or {}).rental then survival=survival+n(meta.rental_rate,3) end
    if active(card) then
      showman=showman or card.key=='j_ring_master'
      astronomer=astronomer or card.key=='j_astronomer'
    end
  end
  local floor=math.min(0,n(s.bankrupt_at))+survival
  local liquidity=M.liquidity and M.liquidity.estimate(s,before)
  if liquidity then survival=liquidity.reserve;floor=liquidity.purchase_floor end
  local cash=n(s.dollars)
  if cash-cost<floor then return nil end
  local pool={}
  for _,entry in ipairs(meta.planet_pool) do
    if type(entry.key)~='string' then return nil end
    if showman or not used[entry.key] then pool[#pool+1]=entry end
  end
  -- Original empty-pool Pluto fallback is deliberately unassessed, including
  -- the exceptional case where Pluto itself was banned or already held.
  if #pool==0 then return nil end
  local candidates={};local mass=meta.rates.planet/total/#pool
  for _,entry in ipairs(pool) do
    if finite(entry.cost) and entry.cost>=0 then
      local price=astronomer and 0 or math.max(1,math.floor((entry.cost+meta.inflation+0.5)*(100-meta.discount_percent)/100))
      if cash-cost-price>=floor and M.planet_card(entry,price) then
        local rank=assess(entry,price)
        rank=rank==true and 1 or finite(rank) and rank or 0
        if rank>0 then candidates[#candidates+1]={entry=entry,price=price,rank=rank} end
      end
    end
  end
  table.sort(candidates,function(a,b)
    if a.rank~=b.rank then return a.rank>b.rank end
    if a.price~=b.price then return a.price<b.price end
    return a.entry.key<b.entry.key
  end)
  local evaluated,covered,opportunity,weighted_gain,weighted_price={},0,0,0,0
  for i=1,math.min(6,#candidates) do
    local candidate=candidates[i]
    local evidence,why=options.compare(candidate.entry,candidate.price)
    if why=='incomplete' or evidence and evidence.incomplete then return nil end
    local gain=opening_gain(evidence)
    evaluated[#evaluated+1]={key=candidate.entry.key,price=candidate.price,pool_mass=mass,
      opening_gain=gain,status=gain and 'complete' or 'unsupported',reason=why,
      planet_plan=evidence and evidence.planet_plan}
    if gain then
      covered=covered+mass
      if gain>0.015 then
        opportunity=opportunity+mass;weighted_gain=weighted_gain+mass*gain
        weighted_price=weighted_price+mass*candidate.price
      end
    end
  end
  if opportunity<=0 then return nil end
  local miss,why=options.compare_miss()
  if why=='incomplete' or miss and miss.incomplete then return nil end
  local miss_gain=opening_gain(miss)
  if miss_gain==nil then return nil end
  local charged_miss_gain=math.min(0,miss_gain)
  local expected_gain=weighted_gain+(1-opportunity)*charged_miss_gain
  local expected_spend=cost+weighted_price
  local visible_gain=opening_gain(options.visible_evidence)
  if options.visible_evidence and visible_gain==nil then return nil end
  local visible_efficiency=math.max(0,visible_gain or 0)/math.max(1,n(options.visible_cost,1))
  local minimum=M.policy_weights and M.policy_weights.get('reroll_min_target_gain') or 0.02
  if expected_gain<minimum or expected_gain/expected_spend<=visible_efficiency*1.10 then return nil end
  return {title='Reroll for a timely Planet ($'..cost..')',action={kind='reroll'},warnings={},
    lines={'The current opening samples are under pressure. Compared source-supported Planet purchases and safe uses against the visible choice.',
      'Only the first new shop slot contributes catalog opportunity credit; other offers and unassessed outcomes remain unknown. This is not a win chance.',
      'The $'..cost..' refresh is paid on a miss too. Preserve the purchase reserve and reassess the publicly revealed offers before buying or using anything.'},
    reroll_forecast={mode='planet_shortfall',cost=cost,slots=meta.slots,credited_slots=1,urgent=true,
      opportunity_mass=opportunity,covered_pool_mass=covered,unknown_pool_mass=math.max(0,1-covered),
      candidates=#evaluated,shortlist=evaluated,shortlist_complete=true,comparison_limit=12,
      purchase_floor=floor,survival_reserve=survival,liquidity=liquidity,
      expected_shortfall_reduction=expected_gain,expected_cash_spend=expected_spend,
      miss_evidence=miss,miss_gain=miss_gain,charged_miss_gain=charged_miss_gain,
      miss_refresh_cost=cost,failed_search_cost=cost,minimum_target_gain=minimum,
      visible_shortfall_reduction=visible_gain or 0,visible_cash_spend=n(options.visible_cost),
      visible_actions=options.visible_actions,unknown_types='Tarot, Spectral, playing cards and later shop slots receive zero credit',
      scope='public first-slot catalog share and complete sampled Planet endpoints; no seed prediction or blind-win probability'}}
end
local function tactical_suggest(s,assess,readiness,options)
  if not options or type(options.compare)~='function' or not M.catalog then return nil,false end
  local before=readiness and readiness.before_readiness
  if not before or not before.supported or not finite(before.target) or before.target<=0 or
    type(before.opening_scores)~='table' or #before.opening_scores~=4 then return nil,false end
  if before.status=='sampled_safe' then return nil,true end
  local pressured=before.status=='sampled_deficit' or before.status=='unresolved' and
    n(before.clearing_samples)<=1 and n(before.opening_mean)>=0 and n(before.opening_mean)<before.target*0.75
  if not pressured then return nil,false end
  local mods=s.modifiers or {};local meta=s.shop_forecast
  local ordinary=M.catalog.no_edition_probability and M.catalog.no_edition_probability(meta.edition_rate)
  if not ordinary then return nil,false end
  if ordinary<=0 then return nil,true end
  local unstickered=M.no_sticker_probability(mods)
  if not unstickered then return nil,false end
  local full_row=#(s.jokers or {})>=n(s.joker_limit,5)
  -- Actual sticker-bearing offers remain outside this family. Full rows still
  -- require explicit legal, complete replacement callbacks for ordinary hits.
  if full_row and type(options.replacement_plans)~='function' then return nil,false end
  local total=0
  for _,kind in ipairs({'joker','tarot','planet','playing','spectral'}) do
    if not finite(meta.rates[kind]) or meta.rates[kind]<0 then return nil,false end
    total=total+meta.rates[kind]
  end
  local slots=n(meta.slots)
  if total<=0 or meta.rates.joker<=0 or slots<1 or slots>10 or slots~=math.floor(slots) then return nil,false end
  for rarity=1,3 do if type(meta.pools[rarity])~='table' then return nil,false end end
  local cost=n(s.reroll_cost,n((s.current_round or {}).reroll_cost,5));local cash=n(s.dollars)
  local rent=0
  for _,j in ipairs(s.jokers or {}) do if (j.ability or {}).rental then rent=rent+n(meta.rental_rate,3) end end
  local discard_cost=n(mods.discard_cost)
  local survival=rent+math.max(0,discard_cost)*math.max(0,n(before.discards))
  local floor=math.min(0,n(s.bankrupt_at))+survival
  local liquidity=M.liquidity and M.liquidity.estimate(s,before)
  if liquidity then survival=liquidity.reserve;floor=liquidity.purchase_floor end
  -- A miss leaves the owned row intact. A sale conditional on finding an
  -- upgrade cannot finance its reserved costs after an unsuccessful refresh.
  -- Full rows need no extra purchase dollar here: a later verified sale can
  -- fund the hit's purchase while this refresh still preserves the reserve.
  if cash-cost<floor+(full_row and 0 or 1) then return nil,true end
  local used={};for key,value in pairs(meta.used or {}) do if value then used[key]=true end end
  for _,card in ipairs(s.shop_jokers or {}) do used[card.key]=nil end
  local showman=false
  for _,card in ipairs(s.jokers or {}) do
    used[card.key]=true;showman=showman or card.key=='j_ring_master' and active(card)
  end
  local candidates,has_metadata,rejected={},false,{}
  for rarity,weight in ipairs({0.7,0.25,0.05}) do
    local pool={}
    for _,entry in ipairs(meta.pools[rarity]) do if showman or not used[entry.key] then pool[#pool+1]=entry end end
    -- An empty rarity pool has an original-source fallback Joker, but without
    -- its source config here it contributes unknown mass, never guessed stats.
    for _,entry in ipairs(pool) do
      has_metadata=has_metadata or type(entry.source_config)=='table'
      local price=math.max(1,math.floor((n(entry.cost,8)+n(meta.inflation)+0.5)*math.max(0,100-n(meta.discount_percent))/100))
      if (full_row or cash-cost-price>=floor) and M.catalog.supports(entry) then
        local rank=assess(entry,price)
        rank=rank==true and 1 or finite(rank) and rank or 0
        if rank>0 then
          local plans,reason
          if full_row then plans,reason=options.replacement_plans(entry,price) end
          if not full_row or plans and #plans>0 then
            candidates[#candidates+1]={entry=entry,price=price,rank=rank,plans=plans,
              mass=meta.rates.joker/total*weight/#pool*ordinary*unstickered}
          else rejected[#rejected+1]={key=entry.key,price=price,status='unsupported_replacements',reason=reason} end
        end
      end
    end
  end
  if not has_metadata then return nil,false end
  table.sort(candidates,function(a,b)
    if a.rank~=b.rank then return a.rank>b.rank end
    if a.price~=b.price then return a.price<b.price end
    return a.entry.key<b.entry.key
  end)
  local limit=math.max(1,math.min(6,math.floor(n(options.shortlist_limit,6))))
  local comparison_limit=full_row and math.max(1,math.min(12,math.floor(n(options.replacement_comparison_limit,12)))) or 6
  local admitted,comparison_count={},0
  for i=1,math.min(limit,#candidates) do
    local candidate=candidates[i];local count=candidate.plans and #candidate.plans or 1
    -- Admit complete victim sets before doing any paired scoring. Never trim
    -- away the later victims just to make an attractive candidate fit.
    if comparison_count+count>comparison_limit then break end
    admitted[#admitted+1]=candidate;comparison_count=comparison_count+count
  end
  local evaluated,covered,per_slot,weighted_gain,weighted_price={},0,0,0,0
  for _,candidate in ipairs(admitted) do
    local evidence,why=options.compare(candidate.entry,candidate.price,candidate.plans)
    -- A callback can label a supported-comparison budget cutoff explicitly.
    -- Unknown mechanics count zero; an unfinished comparison invalidates the
    -- whole shortlist, so a favorable partial result cannot be selected.
    if why=='incomplete' or evidence and evidence.incomplete then return nil,true end
    local gain=opening_gain(evidence)
    evaluated[#evaluated+1]={key=candidate.entry.key,price=candidate.price,pool_mass=candidate.mass,
      opening_gain=gain,status=gain and 'complete' or 'unsupported',
      replacement=evidence and evidence.catalog_replacement,reason=why}
    if gain then
      covered=covered+candidate.mass
      if gain>0.015 then
        per_slot=per_slot+candidate.mass
        weighted_gain=weighted_gain+candidate.mass*gain
        weighted_price=weighted_price+candidate.mass*math.max(0,n(evidence.catalog_net_purchase_spend,candidate.price))
      end
    end
  end
  if per_slot<=0 then return nil,true end
  local probability=1-(1-math.min(1,per_slot))^slots
  local miss_evidence,miss_gain,miss_comparisons=nil,0,0
  if type(options.compare_miss)=='function' then
    local why
    miss_evidence,why=options.compare_miss();miss_comparisons=1
    if why=='incomplete' or miss_evidence and miss_evidence.incomplete then return nil,true end
    miss_gain=opening_gain(miss_evidence)
    if miss_gain==nil then return nil,true end
  end
  -- Every miss still pays for the refresh. Cash-sensitive scoring can worsen
  -- without an upgrade; positive miss development receives no forecast credit.
  local charged_miss_gain=math.min(0,miss_gain)
  local expected_gain=probability*weighted_gain/per_slot+(1-probability)*charged_miss_gain
  local expected_spend=cost+probability*weighted_price/per_slot
  local visible_gain=opening_gain(options.visible_evidence)
  if options.visible_evidence and visible_gain==nil then return nil,true end
  local visible_efficiency=math.max(0,visible_gain or 0)/math.max(1,n(options.visible_cost,1))
  -- These small thresholds are explicit bounded heuristics, not fitted win
  -- probabilities. Compare actual visible value against a limited, zero-credit
  -- unknown-pool estimate; expected spend includes every failed refresh's fee.
  local minimum_gain=M.policy_weights and M.policy_weights.get('reroll_min_target_gain') or 0.02
  if expected_gain<minimum_gain or expected_gain/expected_spend<=visible_efficiency*1.10 then return nil,true end
  return {title='Reroll for timely scoring ($'..cost..')',action={kind='reroll'},warnings={},
    lines={string.format('The current opening samples are under pressure. Compare up to %d source-supported upgrades; editions, stickers and unmatched catalog outcomes contribute no scoring credit.',#evaluated),
      string.format('About %d%% opportunity to find an affordable sampled upgrade among the checked catalog entries; approximate independent offers, not a win chance.',math.floor(probability*100+0.5)),
      string.format('The $%d refresh is spent even on a miss. Keep $%d above the actual purchase debt limit for rentals and conservatively reserved paid discards; a smaller finishing cost is unverified. Reassess the revealed offers.',cost,survival)},
    reroll_forecast={mode='scoring_shortfall',probability=probability,cost=cost,candidates=#evaluated,
      slots=slots,urgent=true,pressure_capacity=before.capacity_proxy,pressure_target=before.target,
      purchase_floor=floor,survival_reserve=survival,interest_floor=0,reserve=survival+1,
      liquidity=liquidity,
      covered_pool_mass=covered,unknown_pool_mass=math.max(0,1-covered),shortlist=evaluated,
      full_row_replacements=full_row,comparison_count=comparison_count,comparison_limit=comparison_limit,rejected_catalog=rejected,
      no_edition_probability=ordinary,edition_outcomes='unassessed_zero_credit',
      no_sticker_probability=unstickered,ordinary_outcome_probability=ordinary*unstickered,
      sticker_outcomes='unassessed_zero_credit',sticker_mass_scope='source_no_sticker_event_without_compatibility_credit',
      expected_shortfall_reduction=expected_gain,expected_cash_spend=expected_spend,
      expected_success_shortfall_reduction=weighted_gain/per_slot,
      miss_evidence=miss_evidence,miss_gain=miss_gain,charged_miss_gain=charged_miss_gain,
      miss_comparisons=miss_comparisons,miss_refresh_cost=cost,
      miss_growth='positive unmodeled refresh growth and positive sampled miss gains receive no credit',
      minimum_target_gain=minimum_gain,
      visible_shortfall_reduction=visible_gain or 0,visible_cash_spend=n(options.visible_cost),
      visible_actions=options.visible_actions,visible_horizon=options.visible_actions and 'complete_visible_sequence' or 'single_action',
      failed_search_cost=cost,
      debt_limit=math.min(0,n(s.bankrupt_at)),shortlist_complete=true,
      scope='bounded ordinary upgrade opportunities and sampled opening gain; no blind-win probability'}},true
end

-- A safe next blind can still leave a weak long-term Joker row. This is an
-- opt-in one-refresh investment, separate from the shortfall path: only
-- source-supported ordinary, unstickered catalog endpoints receive credit,
-- and the first new shop slot is the only credited draw. Complete paired
-- hit/miss certificates protect the already-supported next-blind clear.
local function complete_safe_pair(e,family)
  local before,after=e and e.before_finishing,e and e.after_finishing
  return e and e.common_worlds and type(e.common_worlds.family_key)=='string' and
    e.common_worlds.family_key==family and e.complete_finishing and
    e.before_readiness and e.before_readiness.supported and e.before_readiness.status=='sampled_safe' and
    e.after_readiness and e.after_readiness.supported and
    before and after and before.complete and after.complete and
    before.supported and after.supported and before.known_mechanics and after.known_mechanics and
    before.selected and after.selected and before.samples==4 and after.samples==4 and
    before.selected.clearing_samples==4 and after.selected.clearing_samples==4
end

function M.development_suggest(s,assess,baseline,options)
  local meta=s.shop_forecast;local mods=s.modifiers or {}
  local ante=n(s.ante,1);local cost=n(s.reroll_cost,n((s.current_round or {}).reroll_cost,5))
  local diagnostic=options and options.diagnostic
  local function stop(status)
    if diagnostic then diagnostic.status=status end
    return nil
  end
  if diagnostic then diagnostic.cost=cost;diagnostic.cash=n(s.dollars) end
  if s.phase~='shop' or s.teacher_profile~='perkeo_yorick_win_v1' or
    ante<1 or ante>6 or n(s.win_ante,8)-ante<2 or cost<=0 or cost>8 or
    mods.no_shop_jokers or challenge(s)=='c_jokerless_1' then return stop('out_of_scope') end
  if not meta or not meta.pools or not meta.rates or meta.special_shop_rules or
    not M.catalog then return stop('forecast_unavailable') end
  if type(assess)~='function' or not options or type(options.compare)~='function' or
    type(options.compare_miss)~='function' then return stop('comparison_unavailable') end
  if not baseline or not baseline.common_worlds or
    not complete_safe_pair(baseline,baseline.common_worlds.family_key) then return stop('baseline_not_safe') end
  local yorick=false
  for _,owned in ipairs(s.jokers or {}) do
    if owned.key=='j_blueprint' or owned.key=='j_brainstorm' then return stop('copy_already_owned') end
    if owned.key=='j_yorick' and active(owned) then yorick=true end
  end
  if not yorick then return stop('no_active_yorick') end
  local ordinary=M.catalog.no_edition_probability and M.catalog.no_edition_probability(meta.edition_rate)
  local unstickered=M.no_sticker_probability(mods)
  if not ordinary or ordinary<=0 or not unstickered or unstickered<=0 or
    not finite(meta.slots) or meta.slots<1 or meta.slots>10 or meta.slots~=math.floor(meta.slots) or
    not finite(meta.inflation) or meta.inflation<0 or not finite(meta.discount_percent) or
    meta.discount_percent<0 or meta.discount_percent>100 then return stop('forecast_unsupported') end
  local total=0
  for _,kind in ipairs({'joker','tarot','planet','playing','spectral'}) do
    if not finite(meta.rates[kind]) or meta.rates[kind]<0 then return stop('forecast_unsupported') end
    total=total+meta.rates[kind]
  end
  if total<=0 or meta.rates.joker<=0 then return stop('no_joker_rate') end
  for rarity=1,3 do if type(meta.pools[rarity])~='table' then return stop('forecast_unsupported') end end
  for _,visible in ipairs(s.shop_jokers or {}) do
    if visible.key=='j_blueprint' or visible.key=='j_brainstorm' then return stop('visible_copy_offer') end
  end
  local cash=n(s.dollars)
  local rent=0
  for _,j in ipairs(s.jokers or {}) do if (j.ability or {}).rental then rent=rent+n(meta.rental_rate,3) end end
  local survival=rent+math.max(0,n(mods.discard_cost))*math.max(0,n((baseline.before_readiness or {}).discards))
  local liquidity=M.liquidity and M.liquidity.estimate(s,baseline.before_readiness)
  if liquidity then survival=liquidity.reserve end
  local interest=not mods.no_interest and challenge(s)~='c_omelette_1' and
    not mods.minus_hand_size_per_X_dollar
  local interest_floor=interest and cash>=n(s.interest_cap,25) and n(s.interest_cap,25) or 0
  -- This is optional development. Credit Card debt is available to tactical
  -- survival purchases, but never turns an elective refresh into spare cash.
  local purchase_floor=survival+interest_floor
  if diagnostic then diagnostic.purchase_floor=purchase_floor;diagnostic.survival_reserve=survival end
  if cash-cost<purchase_floor+8 then return stop('cash_floor') end
  local used={}
  for key,value in pairs(meta.used or {}) do if value then used[key]=true end end
  for _,visible in ipairs(s.shop_jokers or {}) do used[visible.key]=nil end
  local showman=false
  for _,owned in ipairs(s.jokers or {}) do
    used[owned.key]=true
    if owned.key=='j_ring_master' and active(owned) then showman=true end
  end
  local full_row=#(s.jokers or {})>=n(s.joker_limit,5)
  if full_row and type(options.replacement_plans)~='function' then return stop('replacement_scope_unavailable') end
  local ranked={}
  for rarity,weight in ipairs({0.7,0.25,0.05}) do
    local pool={}
    for _,entry in ipairs(meta.pools[rarity]) do if showman or not used[entry.key] then pool[#pool+1]=entry end end
    for _,entry in ipairs(pool) do
      if M.catalog.supports(entry) and finite(entry.cost) and entry.cost>=0 then
        local price=math.max(1,math.floor((entry.cost+meta.inflation+0.5)*(100-meta.discount_percent)/100))
        if full_row or cash-cost-price>=purchase_floor then
          local rank=assess(entry,price)
          rank=rank==true and 1 or finite(rank) and rank or 0
          if rank>0 then ranked[#ranked+1]={entry=entry,price=price,rank=rank,
            mass=meta.rates.joker/total*weight/#pool*ordinary*unstickered} end
        end
      end
    end
  end
  table.sort(ranked,function(a,b)
    if a.rank~=b.rank then return a.rank>b.rank end
    if a.price~=b.price then return a.price<b.price end
    return a.entry.key<b.entry.key
  end)
  if diagnostic then diagnostic.catalog_candidates=#ranked end
  if #ranked==0 then return stop('no_supported_catalog_candidates') end
  local miss,why=options.compare_miss()
  if why=='incomplete' or miss and miss.incomplete then return stop('comparison_incomplete') end
  local family=baseline.common_worlds.family_key
  if not miss or not complete_safe_pair(miss,family) or not finite(miss.development_utility) or
    not finite(miss.refresh_penalty) or miss.refresh_penalty<0 or
    not finite(miss.cash_after) or miss.cash_after~=cash-cost then return stop('charged_miss_unsupported') end
  local shortlist,credited,weighted_gain,compared={},0,0,0
  for i=1,math.min(6,#ranked) do
    local candidate=ranked[i]
    local plans
    if full_row then plans,why=options.replacement_plans(candidate.entry,candidate.price) end
    local count=full_row and plans and #plans or 1
    if count and compared+count>12 then break end
    if not full_row or plans and #plans>0 then
      compared=compared+count
      local hit,reason=options.compare(candidate.entry,candidate.price,plans,purchase_floor)
      if reason=='incomplete' or hit and hit.incomplete then return stop('comparison_incomplete') end
      local evidence=hit and hit.evidence
      local supported=evidence and complete_safe_pair(evidence,family) and finite(hit.merit) and
        finite(hit.cash_after) and hit.cash_after>=purchase_floor
      shortlist[#shortlist+1]={key=candidate.entry.key,price=candidate.price,pool_mass=candidate.mass,
        status=supported and 'complete' or 'unsupported',merit=supported and hit.merit or nil,
        reason=not supported and reason or nil,comparison_count=count,
        sold_index=supported and hit.sold_index or nil,cash_after=supported and hit.cash_after or nil}
      if supported and hit.merit>0 then
        credited=credited+candidate.mass;weighted_gain=weighted_gain+candidate.mass*hit.merit
      end
    else
      shortlist[#shortlist+1]={key=candidate.entry.key,price=candidate.price,pool_mass=candidate.mass,
        status='unsupported_replacements',reason=why}
    end
  end
  if diagnostic then diagnostic.comparison_count=compared;diagnostic.credited_first_slot_mass=credited end
  if credited<=0 then return stop('no_positive_supported_hit') end
  -- Only the first new slot and supported positive endpoints earn development
  -- credit. The charged miss retains its real cash-sensitive row; any
  -- unmodeled offer receives zero improvement, never a guessed Joker.
  local expected=weighted_gain+(1-credited)*math.min(0,miss.development_utility)-miss.refresh_penalty-4
  if diagnostic then diagnostic.expected_development_utility=expected end
  if expected<=0 then return stop('nonpositive_expected_utility') end
  if diagnostic then diagnostic.status='admitted' end
  return {title='Reroll for a durable Joker ($'..cost..')',action={kind='reroll'},warnings={},
    lines={string.format('A supported next-blind clear leaves time to improve the Joker row. Compare %d source-supported ordinary first-slot outcomes and the charged miss.',#shortlist),
      string.format('About %.1f%% first-slot opportunity is credited; other offers, editions and stickers earn zero value. This is not a win chance.',credited*100),
      string.format('The $%d refresh is spent on a miss too. Preserve $%d for interest and reserved costs, and reassess the revealed shop.',cost,purchase_floor)},
    reroll_forecast={mode='durable_engine_development',cost=cost,credited_first_slot_mass=credited,
      credited_slots=1,visible_slots=meta.slots,candidates=#shortlist,comparison_count=compared,
      comparison_limit=12,shortlist=shortlist,complete=true,expected_development_utility=expected,
      miss_utility=math.min(0,miss.development_utility),refresh_penalty=miss.refresh_penalty,
      purchase_floor=purchase_floor,interest_floor=interest_floor,survival_reserve=survival,
      liquidity=liquidity,no_edition_probability=ordinary,no_sticker_probability=unstickered,
      unknown_outcomes='zero credit',scope='one source-catalog first-slot opportunity; complete paired supported hit/miss; no win probability'}}
end

function M.suggest(s,assess,readiness,options)
  local meta=s.shop_forecast;local cost=n(s.reroll_cost,n((s.current_round or {}).reroll_cost,5));local mods=s.modifiers or {}
  if s.phase~='shop' or cost<=0 or cost>8 or not meta or not meta.pools or not meta.rates or meta.special_shop_rules or
    type(assess)~='function' or mods.no_shop_jokers or challenge(s)=='c_jokerless_1' or n(s.ante,1)>8 then return nil end
  local tactical,handled=tactical_suggest(s,assess,readiness,options)
  if handled then return tactical end
  if options and options.tactical_only then return nil end
  if #(s.jokers or {})>=n(s.joker_limit,5) then
    local space=false
    for _,j in ipairs(s.jokers or {}) do
      local a=j.ability or {}
      if not mods.all_eternal and not a.eternal and not negative(j) and
        not (j.key=='j_invisible' and active(j) and n(a.invis_rounds)>=n(a.extra,2)) then space=true end
    end
    if not space then return nil end
  end
  local bonus=s.round_bonus or meta.round_bonus or {}
  local rounds=math.max(1,n((s.round_resets or {}).hands,4)+n(bonus.next_hands))
  local target=n(s.next_blind_chips)
  local capacity=readiness and n(readiness.before_mean)*math.max(1,rounds-1) or 0
  local actual=readiness and readiness.before_readiness
  local urgent
  if actual and actual.supported then
    target=n(actual.target);capacity=n(actual.capacity_proxy)
    -- Boss resource restrictions and real opening plans supersede the older
    -- generic multiplication by reset hands. Repetition alone is never safety.
    if actual.status=='sampled_safe' then return nil end
    urgent=actual.status=='sampled_deficit'
  else
    if target>0 and capacity>=target*1.25 then return nil end
    urgent=target>0 and capacity>0 and capacity<target*0.85
  end
  local cash=n(s.dollars);local rent=0
  for _,j in ipairs(s.jokers or {}) do if (j.ability or {}).rental then rent=rent+n(meta.rental_rate,3) end end
  local survival=rent+(mods.discard_cost and math.max(0,n(mods.discard_cost))*math.min(2,n((s.round_resets or {}).discards,3)) or 0)
  if challenge(s)=='c_golden_needle_1' then survival=math.max(survival,rent+10) end
  local liquidity=M.liquidity and M.liquidity.estimate(s,actual)
  if liquidity then survival=liquidity.reserve end
  local interest=not mods.no_interest and challenge(s)~='c_omelette_1'
  local interest_floor=interest and not urgent and cash>=n(s.interest_cap,25) and n(s.interest_cap,25) or 0
  local purchase_floor=interest_floor>0 and survival+interest_floor or liquidity and liquidity.purchase_floor or survival
  local reserve=purchase_floor+8
  if cash-cost<reserve then return nil end -- No borrowing or promised income.
  local total=0
  for _,kind in ipairs({'joker','tarot','planet','playing','spectral'}) do
    if not finite(meta.rates[kind]) or meta.rates[kind]<0 then return nil end
    total=total+meta.rates[kind]
  end
  if total<=0 or meta.rates.joker<=0 or n(meta.slots)<1 or n(meta.slots)>10 then return nil end
  local slots=math.floor(meta.slots)
  for rarity=1,3 do if type(meta.pools[rarity])~='table' then return nil end end
  local used={}
  for key,v in pairs(meta.used or {}) do if v then used[key]=true end end
  for _,offer in ipairs(s.shop_jokers or {}) do used[offer.key]=nil end
  local showman=false
  for _,j in ipairs(s.jokers or {}) do used[j.key]=true;if j.key=='j_ring_master' and active(j) then showman=true end end
  local per_slot,candidates,assessments=0,0,{}
  for rarity,weight in ipairs({0.7,0.25,0.05}) do
    local pool={}
    for _,entry in ipairs(meta.pools[rarity]) do if showman or not used[entry.key] then pool[#pool+1]=entry end end
    if #pool==0 then pool={{key='j_joker',name='Joker',cost=2,rarity=rarity}} end
    local useful=0
    for _,entry in ipairs(pool) do
      local price=math.max(1,math.floor((n(entry.cost,8)+n(meta.inflation)+0.5)*math.max(0,100-n(meta.discount_percent))/100))
      if cash-cost-price>=purchase_floor then
        local key=tostring(entry.key)..':'..tostring(entry.rarity)..':'..price
        if assessments[key]==nil then assessments[key]=not not assess(entry,price) end
        if assessments[key] then useful=useful+1;candidates=candidates+1 end
      end
    end
    per_slot=per_slot+meta.rates.joker/total*weight*useful/#pool
  end
  if candidates==0 then return nil end
  local probability=1-(1-math.min(1,per_slot))^slots
  if probability<0.20 or cost>2+8*probability then return nil end
  -- Rising prices and a finite reserve bound repeated user clicks.
  return {title='Reroll for a scoring upgrade ($'..cost..')',action={kind='reroll'},warnings={},
    lines={string.format('Budget one refresh, keep $8 available for an upgrade, and preserve a post-purchase balance of at least $%d for interest and conservatively reserved near-term costs.',purchase_floor),
      string.format('About %d%% chance to see an affordable, strategically relevant Joker across %d ordinary shop slots; approximate independent offers, not a win chance.',math.floor(probability*100+0.5),slots),
      'Reassess after this one reroll; no future income or Egg sale is assumed.'},
    reroll_forecast={probability=probability,reserve=reserve,survival_reserve=survival,cost=cost,candidates=candidates,
      slots=slots,urgent=urgent,pressure_capacity=capacity,pressure_target=target,
      purchase_floor=purchase_floor,interest_floor=interest_floor,liquidity=liquidity}}
end
return M
