-- A complete current-hand comparison of one reversible copy setup. No RNG,
-- game callbacks, consumable use, discard or pending play is executed here.
local M={}
local names={j_perkeo='Perkeo',j_yorick='Yorick',j_blueprint='Blueprint',
  j_brainstorm='Brainstorm',j_droll='Droll Joker',j_supernova='Supernova'}
local blinds={bl_small='Small Blind',bl_big='Big Blind',bl_wall='The Wall',
  bl_water='The Water',bl_manacle='The Manacle',bl_needle='The Needle',
  bl_flint='The Flint',bl_arm='The Arm',bl_ox='The Ox',bl_tooth='The Tooth',
  bl_eye='The Eye',bl_mouth='The Mouth',bl_psychic='The Psychic',
  bl_club='The Club',bl_goad='The Goad',bl_window='The Window',bl_head='The Head',
  bl_plant='The Plant',bl_pillar='The Pillar',bl_house='The House',bl_wheel='The Wheel',
  bl_fish='The Fish',bl_mark='The Mark',bl_final_bell='Cerulean Bell',
  bl_final_leaf='Verdant Leaf',bl_final_vessel='Violet Vessel'}
local enhancements={c_base=true,m_bonus=true,m_mult=true,m_wild=true,m_glass=true,
  m_steel=true,m_stone=true,m_gold=true}
local modifiers={no_interest=true,no_extra_hand_money=true,no_blind_reward=true,no_reward=true,
  money_per_hand=true,money_per_discard=true,discard_cost=true,inflation=true,scaling=true,
  enable_eternals_in_shop=true,enable_perishables_in_shop=true,enable_rentals_in_shop=true,
  all_eternal=true,no_shop_jokers=true,chips_dollar_cap=true,balance=true,
  debuff_played_cards=true,minus_hand_size_per_X_dollar=true}
local decks={}
for _,name in ipairs({'red','blue','yellow','green','black','magic','nebula','ghost','abandoned',
  'checkered','zodiac','painted','anaglyph','plasma','erratic','challenge'}) do decks['b_'..name]=true end
local consumables={}
for set,keys in pairs({Tarot={'fool','magician','high_priestess','empress','emperor','heirophant','lovers',
  'chariot','justice','hermit','wheel_of_fortune','strength','hanged_man','death','temperance','devil',
  'tower','star','moon','sun','judgement','world'},Planet={'pluto','mercury','uranus','venus','saturn',
  'jupiter','earth','mars','neptune','planet_x','ceres','eris'},Spectral={'familiar','grim','incantation',
  'talisman','aura','wraith','sigil','ouija','ectoplasm','immolate','ankh','deja_vu','hex','trance',
  'medium','cryptid','soul','black_hole'}}) do
  for _,key in ipairs(keys) do consumables['c_'..key]=set end
end
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function num(v,d) return finite(v) and v or d or 0 end
local limits={nodes=32768,depth=12,string_bytes=4096,total_string_bytes=524288,
  playing_cards=128,deck=128,consumeables=32}
local function plain(value,path,budget,depth)
  budget=budget or {nodes=0,bytes=0};depth=depth or 0
  budget.nodes=budget.nodes+1
  if budget.nodes>limits.nodes or depth>limits.depth then return false end
  local kind=type(value)
  if kind=='number' then return finite(value) end
  if kind=='string' then
    budget.bytes=budget.bytes+#value
    return #value<=limits.string_bytes and budget.bytes<=limits.total_string_bytes
  end
  if kind~='table' then return kind=='nil' or kind=='boolean' end
  if getmetatable(value)~=nil then return false end
  path=path or {};if path[value] then return false end;path[value]=true
  for k,v in pairs(value) do
    if type(k)=='string' then
      budget.bytes=budget.bytes+#k
      if #k>limits.string_bytes or budget.bytes>limits.total_string_bytes then path[value]=nil;return false end
    elseif not finite(k) or k%1~=0 or math.abs(k)>1048576 then path[value]=nil;return false end
    if not plain(v,path,budget,depth+1) then path[value]=nil;return false end
  end
  path[value]=nil;return true
end
local function copy(v)
  if type(v)~='table' then return v end
  local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r
end
local function equal(a,b,path_a,path_b,budget,depth)
  budget=budget or {nodes=0};depth=depth or 0;budget.nodes=budget.nodes+1
  if budget.nodes>limits.nodes or depth>limits.depth then return false end
  if type(a)~=type(b) then return false end
  if type(a)~='table' then
    if type(a)=='number' then return finite(a) and finite(b) and a==b end
    if type(a)=='string' then return #a<=limits.string_bytes and #b<=limits.string_bytes and a==b end
    return (a==nil or type(a)=='boolean') and a==b
  end
  if getmetatable(a)~=nil or getmetatable(b)~=nil then return false end
  path_a=path_a or {};path_b=path_b or {};if path_a[a] or path_b[b] then return false end
  path_a[a]=true;path_b[b]=true
  local function release(v)path_a[a]=nil;path_b[b]=nil;return v end
  for k,v in pairs(a) do
    if (type(k)~='string' and not finite(k)) or not equal(v,b[k],path_a,path_b,budget,depth+1) then return release(false) end
  end
  for k in pairs(b) do if a[k]==nil then return release(false) end end
  release(true)
  return true
end
local function list(v) local r={};for i,x in ipairs(v or {}) do r[i]=x end;return r end
local function ordinary_edition(e) return e==nil or type(e)=='table' and next(e)==nil end
local function consumable_edition(e)
  if e==nil then return true end
  if type(e)~='table' then return false end
  local kinds=0
  for k,v in pairs(e) do
    if k=='type' then
      if v~='negative' and v~='foil' and v~='holo' and v~='polychrome' then return false end
    elseif k=='negative' or k=='foil' or k=='holo' or k=='polychrome' then
      if type(v)~='boolean' then return false end
      if v then kinds=kinds+1 end
    else return false end
  end
  return kinds<=1 and (not e.type or e[e.type]==true)
end
local function active(j)
  local a=j.ability or {}
  return not j.debuff and not a.perma_debuff and not (a.perishable and num(a.perish_tally,5)<=0)
end
local function resolved(row,index,seen)
  if seen[index] then return nil end;seen[index]=true
  local j=row[index];if not j or not active(j) then return nil end
  if j.key=='j_blueprint' then return resolved(row,index+1,seen) end
  if j.key=='j_brainstorm' then return resolved(row,1,seen) end
  if j.blueprint_compat~=true then return nil end
  return j.id,j.key
end
local function routes(row)
  local out={}
  for i,j in ipairs(row) do if active(j) and (j.key=='j_blueprint' or j.key=='j_brainstorm') then
    local id,key=resolved(row,i,{})
    if not id then return nil end
    out[j.id]={id=id,key=key}
  end end
  return out
end
local function dense(v)
  if type(v)~='table' then return false end
  local n=0;for k in pairs(v) do if not finite(k) or k%1~=0 or k<1 then return false end;n=n+1 end
  return n==#v
end
local function key(indices) return table.concat(indices,',') end
local function reliable(p) return type(p)=='table' and p.legal==true and p.uncertain==false and finite(p.score) end

function M.prepare(s,modules,retry)
  if type(s)~='table' or not plain(s) or s.phase~='hand' or type(modules)~='table' or
    not modules.phase_copy or not modules.phase_copy.target_order or not modules.phase_copy.reorder then return nil end
  if retry and (retry.active or retry.matched or retry.pending or retry.unavailable) then return nil end
  local round=s.current_round or {};local left=s.discards_left
  if left==nil then left=round.discards_left end
  if not finite(left) or left<0 or left%1~=0 or num(s.hands_left,round.hands_left)<=0 then return nil end
  if not dense(s.hand) or #s.hand==0 or #s.hand>8 or not dense(s.jokers) or #s.jokers<3 or #s.jokers>8 then return nil end
  if s.deck_key and not decks[s.deck_key] then return nil end
  for k,v in pairs(s.modifiers or {}) do
    if v~=nil and v~=false and v~=0 and not modifiers[k] then return nil end
  end
  if s.hand_limit~=nil and (not finite(s.hand_limit) or s.hand_limit%1~=0 or s.hand_limit<1) then return nil end
  if s.ordering_safe==false or s.jokers_shuffling or (s.blind or {}).shuffle_pending then return nil end
  local b=s.blind or {}
  if not b.disabled and (not blinds[b.key] or b.name and b.name~=blinds[b.key]) then return nil end
  if not finite(b.chips) or not finite(s.chips) or b.chips<=s.chips then return nil end
  if not dense(s.consumeables) or not dense(s.playing_cards) or not dense(s.deck) then return nil end
  if #s.consumeables>limits.consumeables or #s.playing_cards>limits.playing_cards or #s.deck>limits.deck then return nil end
  if not finite(s.consumable_limit) or s.consumable_limit<0 or s.consumable_limit%1~=0 or
    not finite(s.consumeable_buffer) or s.consumeable_buffer<0 or s.consumeable_buffer%1~=0 then return nil end
  local population={}
  for _,c in ipairs(s.playing_cards) do
    if type(c.id)~='string' or c.id=='' or population[c.id] then return nil end
    population[c.id]=c
  end
  local observed={}
  for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do
    if observed[c.id] or not population[c.id] or not equal(c,population[c.id]) then return nil end
    observed[c.id]=true
  end end
  local ids,perkeo,yorick={},false,false
  for _,j in ipairs(s.jokers) do
    local a=j.ability
    if not names[j.key] or type(a)~='table' or a.name~=names[j.key] or
      j.name and j.name~=names[j.key] or a.set and a.set~='Joker' or
      type(j.id)~='string' or j.id=='' or ids[j.id] or not ordinary_edition(j.edition) or
      j.face_down or j.facing=='back' or j.getting_sliced or j.unknown then return nil end
    ids[j.id]=true
    if j.key=='j_perkeo' and active(j) then perkeo=true end
    if j.key=='j_yorick' and active(j) and finite(a.x_mult) and a.x_mult>1 then yorick=true end
    if left>0 and j.key=='j_yorick' and active(j) and
      (not finite(a.yorick_discards) or type(a.extra)~='table' or not finite(a.extra.discards) or
       not finite(a.extra.xmult) or a.extra.discards<1 or a.yorick_discards<1) then return nil end
  end
  if not perkeo or not yorick then return nil end
  for _,c in ipairs(s.hand) do
    local a=c.ability or {};local e=c.enhancement or 'c_base'
    if c.face_down or c.facing=='back' or c.unknown or a.wheel_flipped or
      type(c.id)~='string' or c.id=='' or not finite(c.rank) or not finite(c.nominal) or
      c.seal and c.seal~='Blue' and c.seal~='Red' and c.seal~='Gold' and c.seal~='Purple' or
      not consumable_edition(c.edition) or c.edition and c.edition.negative or
      num(a.h_size)~=0 or num(a.d_size)~=0 or
      not enhancements[e] or e=='m_glass' and not c.debuff and
      num((s.probabilities or {}).normal,1)>0 and num((s.probabilities or {}).normal,1)<num(a.extra,4) then return nil end
    if left>0 and c.seal=='Purple' and not c.debuff and
      #s.consumeables+s.consumeable_buffer<s.consumable_limit then return nil end
  end
  -- No owned card is excluded from scoring or the Perkeo pool, including
  -- Negative cards. Unknown identities, editions and modifiers are rejected.
  for _,c in ipairs(s.consumeables) do
    if type(c.id)~='string' or c.id=='' or type(c.key)~='string' or type(c.ability)~='table' or
      ids[c.id] or population[c.id] or consumables[c.key]~=c.ability.set or
      not consumable_edition(c.edition) or c.unknown then return nil end
    ids[c.id]=true
  end
  local order=modules.phase_copy.target_order(s,'j_yorick')
  local original={};for i=1,#s.jokers do original[i]=i end
  if equal(order,original) then return nil end
  local changed=modules.phase_copy.reorder(s,order)
  local before,after=routes(s.jokers),routes(changed.jokers)
  if not before or not after then return nil end
  local shifts=0
  for id,route in pairs(before) do
    local other=after[id];if not other then return nil end
    if route.id~=other.id then
      if route.key~='j_perkeo' or other.key~='j_yorick' then return nil end
      shifts=shifts+1
    end
  end
  if shifts==0 then return nil end
  return {snapshot=s,changed=changed,order=order,max_cards=math.min(5,num(s.hand_limit,5)),
    copy_routes_before=before,copy_routes_after=after,copy_events_shifted=shifts,discards_left=left}
end

function M.compare(plan,scorer,family,context)
  local d={complete=false,scope='complete_held_copy_setup_with_discard_receipts_v1',
    paired_subsets=0,score_calls=0,extra_setup_actions=1,needs_refresh=true,bounded=true}
  local function fail(reason) d.reason=reason;return nil,d end
  if not plan or not scorer or not scorer.after_play or not context or not context.after_play then
    return fail('Complete play-resource transitions are unavailable.')
  end
  local s,changed=plan.snapshot,plan.changed
  local expected,found={},{}
  local chosen={}
  local function walk(start)
    if #chosen>0 then
      local selected={};for _,i in ipairs(chosen) do selected[i]=true end
      local allowed=true
      for i,c in ipairs(s.hand) do if (c.ability or {}).forced_selection and not selected[i] then allowed=false end end
      if allowed then expected[key(chosen)]=list(chosen) end
    end
    if #chosen>=plan.max_cards then return end
    for i=start,#s.hand do chosen[#chosen+1]=i;walk(i+1);chosen[#chosen]=nil end
  end
  walk(1)
  local subsets={}
  for _,play in ipairs(family or {}) do
    if not reliable(play) or not dense(play.indices) then return fail('The original score family is not fully supported.') end
    local k=key(play.indices)
    if not expected[k] or found[k] then return fail('The current held family is incomplete or duplicated.') end
    found[k]=play;subsets[#subsets+1]=expected[k]
  end
  -- Missing subsets must be explained by exact fixed blind legality; copying
  -- these six centers cannot change classification or physical selection.
  for k,indices in pairs(expected) do if not found[k] then
    local result=scorer.classify and {scorer.classify(s,indices)}
    if not result then return fail('Missing current held subset.') end
    local category,contains=result[1],result[3] or {};local b=s.blind or {};local bd=not b.disabled and b.debuff or {}
    local illegal=not b.disabled and ((b.key=='bl_psychic' and #indices~=5) or
      bd.h_size_ge and #indices<bd.h_size_ge or bd.h_size_le and #indices>bd.h_size_le or
      bd.hand and contains[bd.hand] or b.key=='bl_eye' and (b.hands or {})[category] or
      b.key=='bl_mouth' and b.only_hand and b.only_hand~=category)
    if not illegal then return fail('A legal current held subset is missing.') end
  end end
  if #subsets==0 or #subsets>218 then return fail('The complete held family is outside the bound.') end
  table.sort(subsets,function(a,b)return key(a)<key(b) end)
  d.required_score_calls=2*#subsets;d.subsets=#subsets
  if context.budget_left()<d.required_score_calls then return fail('The complete paired resource family cannot fit the remaining decision budget.') end
  local needed=s.blind.chips-s.chips;local witness
  for _,indices in ipairs(subsets) do
    local before,be,bp=context.after_play(s,indices);d.score_calls=d.score_calls+1
    local after,ae,ap=context.after_play(changed,indices);d.score_calls=d.score_calls+1
    if not before or not after or not reliable(bp) or not reliable(ap) then return fail('A paired play-resource transition is unsupported.') end
    local baseline=found[key(indices)]
    if bp.score~=baseline.score or bp.hand~=baseline.hand or not equal(bp.scoring_indices,baseline.scoring_indices) then
      return fail('The original transition does not match the reused exact held score.')
    end
    if bp.score>=needed then return fail('An original held clear belongs to the existing clear path.') end
    if ap.score<bp.score or ap.hand~=bp.hand or not equal(ap.scoring_indices,bp.scoring_indices) then
      return fail('The changed row loses a paired held score or changes classification.')
    end
    -- Normalize only physical row order and accumulated scored chips. Cash,
    -- every inventory/card field, hand histories, development, destruction and
    -- original physical Yorick state must otherwise match in full.
    if #after.jokers~=#plan.order or #before.jokers~=#s.jokers then return fail('A play changes physical Joker membership.') end
    local restored={};for position,index in ipairs(plan.order) do restored[index]=after.jokers[position] end
    after.jokers=restored;after.chips=before.chips
    if not equal(be,ae) or not equal(before,after) then return fail('The paired resource states differ outside Joker order and scored chips.') end
    d.paired_subsets=d.paired_subsets+1
    if ap.score>=needed and (not witness or #indices<#witness.indices or
      #indices==#witness.indices and key(indices)<key(witness.indices)) then
      witness={indices=list(indices),score=ap.score,hand=ap.hand,baseline_score=bp.score}
    end
  end
  if not witness then d.complete=true;return fail('No changed-row held clear was established.') end
  d.discard_transition_calls=0;d.paired_discards=0
  if plan.discards_left>0 then
    if not scorer.after_discard then return fail('The whole discard resource family is unavailable.') end
    local discards={};for _,indices in pairs(expected) do discards[#discards+1]=indices end
    table.sort(discards,function(a,b)return key(a)<key(b)end)
    if #discards>218 then return fail('The complete discard family exceeds its transition bound.') end
    d.required_discard_transitions=2*#discards
    for _,indices in ipairs(discards) do
      local before,be=scorer.after_discard(s,indices);d.discard_transition_calls=d.discard_transition_calls+1
      local after,ae=scorer.after_discard(changed,indices);d.discard_transition_calls=d.discard_transition_calls+1
      if not before or not after or #after.jokers~=#plan.order or #before.jokers~=#s.jokers then
        return fail('A discard effect, generation or physical Joker transition is unsupported.')
      end
      local restored={};for position,index in ipairs(plan.order) do restored[index]=after.jokers[position] end
      after.jokers=restored
      if not equal(be,ae) or not equal(before,after) then
        return fail('A paired discard changes cash, growth, inventory or another resource with this order.')
      end
      d.paired_discards=d.paired_discards+1
      if context.progress and d.discard_transition_calls%16==0 then context.progress() end
    end
  end
  d.complete=true
  d.held_clear=copy(witness);d.copy_routes_before=copy(plan.copy_routes_before)
  d.copy_routes_after=copy(plan.copy_routes_after);d.copy_events_shifted=plan.copy_events_shifted
  d.reason='The complete paired held family gains an exact clear with identical non-score resources.'
  d.resource_scope='Full after_play states/effects normalize only scored chips and row order; every legal current discard normalizes only row order; no future draw or cashout modeled.'
  local order_text={};for _,index in ipairs(plan.order) do
    order_text[#order_text+1]='#'..index..' '..names[s.jokers[index].key]
  end
  return {kind='reorder_jokers',title='Copy Yorick before reassessing the hand',needs_refresh=true,
    action={kind='reorder_jokers',area='jokers',order=list(plan.order)},
    lines={table.concat(order_text,' -> '),'Reorder first, then refresh advice.',
      'The complete held-hand comparison gains a supported clear without spending a consumable.',
      'This is one setup action. The next play or consumable choice requires fresh advice.'},
    warnings={},copy_preflight=d},d
end
return M
