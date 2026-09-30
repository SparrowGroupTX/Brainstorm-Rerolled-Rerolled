-- Paired opening-hand scoring evidence for shop decisions. This is a small,
-- deterministic sample of the owned deck, never the game's future draw order.
local Shop={}
local function num(x,d) return type(x)=='number' and x or (d or 0) end
local function clone(x,seen)
  if type(x)~='table' then return x end
  seen=seen or {}; if seen[x] then return seen[x] end
  local out={}; seen[x]=out
  for k,v in pairs(x) do if k~='_shop_scoring' and type(v)~='function' then out[k]=clone(v,seen) end end
  return out
end
local function encode(x)
  if type(x)~='table' then return type(x)..':'..tostring(x) end
  local keys,out={},{}
  for k in pairs(x) do if k~='_shop_scoring' then keys[#keys+1]=k end end
  table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
  for _,k in ipairs(keys) do out[#out+1]=encode(k)..'='..encode(x[k]) end
  return '{'..table.concat(out,';')..'}'
end
local function name(j) return (j.ability or {}).name or j.name or j.key end
-- A generic x_mult field is not evidence that an unknown modded Joker has no
-- additional effects. Vanilla identities still pass through scorer warnings.
local vanilla={}
for key in ([=[j_joker j_greedy_joker j_lusty_joker j_wrathful_joker j_gluttenous_joker j_jolly j_zany j_mad j_crazy j_droll
j_sly j_wily j_clever j_devious j_crafty j_half j_stencil j_four_fingers j_mime j_credit_card j_ceremonial j_banner
j_mystic_summit j_marble j_loyalty_card j_8_ball j_misprint j_dusk j_raised_fist j_chaos j_fibonacci j_steel_joker
j_scary_face j_abstract j_delayed_grat j_hack j_pareidolia j_gros_michel j_even_steven j_odd_todd j_scholar j_business
j_supernova j_ride_the_bus j_space j_egg j_burglar j_blackboard j_runner j_ice_cream j_dna j_splash j_blue_joker
j_sixth_sense j_constellation j_hiker j_faceless j_green_joker j_superposition j_todo_list j_cavendish j_card_sharp
j_red_card j_madness j_square j_seance j_riff_raff j_vampire j_shortcut j_hologram j_vagabond j_baron j_cloud_9
j_rocket j_obelisk j_midas_mask j_luchador j_photograph j_gift j_turtle_bean j_erosion j_reserved_parking j_mail
j_to_the_moon j_hallucination j_fortune_teller j_juggler j_drunkard j_stone j_golden j_lucky_cat j_baseball j_bull
j_diet_cola j_trading j_flash j_popcorn j_trousers j_ancient j_ramen j_walkie_talkie j_selzer j_castle j_smiley
j_campfire j_ticket j_mr_bones j_acrobat j_sock_and_buskin j_swashbuckler j_troubadour j_certificate j_smeared
j_throwback j_hanging_chad j_rough_gem j_bloodstone j_arrowhead j_onyx_agate j_glass j_ring_master j_flower_pot
j_blueprint j_wee j_merry_andy j_oops j_idol j_seeing_double j_matador j_hit_the_road j_duo j_trio j_family j_order
j_tribe j_stuntman j_invisible j_brainstorm j_satellite j_shoot_the_moon j_drivers_license j_cartomancer
j_astronomer j_burnt j_bootstraps j_caino j_triboulet j_yorick j_chicot j_perkeo]=]):gmatch('%S+') do vanilla[key]=true end
local skip_rows={j_ceremonial=true,j_madness=true,j_burglar=true,
  j_riff_raff=true,j_cartomancer=true,j_certificate=true,j_marble=true,
  ['Ceremonial Dagger']=true,Madness=true,Burglar=true,
  ['Riff-raff']=true,Cartomancer=true,Certificate=true,['Marble Joker']=true}
local later_hand={j_dusk='last',j_acrobat='last',j_card_sharp='repeat',j_mystic_summit='discards',
  Dusk='last',Acrobat='last',['Card Sharp']='repeat',['Mystic Summit']='discards'}
local function expired(j)
  local a=j.ability or {}; return a.perma_debuff or a.perishable and num(a.perish_tally,5)<=0
end
local function deck(cards)
  local out={}
  for i,original in ipairs(cards or {}) do
    local c=clone(original); c.ability=c.ability or {}
    c.debuff=not not c.ability.perma_debuff; c.face_down=false; c.vampired=nil
    c.ability.forced_selection=nil; c.ability.wheel_flipped=nil
    out[#out+1]={card=c,key=tostring(c.id or '')..':'..encode(c),index=i}
  end
  table.sort(out,function(a,b) return a.key<b.key or a.key==b.key and a.index<b.index end)
  local result={}; for i,v in ipairs(out) do result[i]=v.card end
  return result
end
local function permutations(n)
  local out={}
  for _,seed in ipairs({977,1999,3253,4751}) do
    local order={}; for i=1,n do order[i]=i end
    for i=n,2,-1 do
      seed=(seed*1664525+1013904223)%4294967296
      local j=seed%i+1; order[i],order[j]=order[j],order[i]
    end
    out[#out+1]=order
  end
  return out
end
local add_mult={j_joker=true,j_abstract=true,j_half=true,j_swashbuckler=true,j_fortune_teller=true,
  j_supernova=true,j_fibonacci=true,j_bootstraps=true,j_misprint=true,j_mystic_summit=true}
local main_xmult={j_cavendish=true,j_blackboard=true,j_stencil=true,j_steel_joker=true,
  j_drivers_license=true,j_flower_pot=true,j_seeing_double=true,j_card_sharp=true,
  j_acrobat=true,j_loyalty_card=true,j_caino=true}
local function tier(j)
  local a,e=j.ability or {},j.edition or {}; local extra=type(a.extra)=='table' and a.extra or {}
  if type(e)=='table' and e.polychrome or e=='polychrome' or num(a.x_mult)>1 or
    num(extra.Xmult)>1 or main_xmult[j.key] then return 3 end
  if num(a.mult)>0 or num(a.t_mult)>0 or add_mult[j.key] or
    type(e)=='table' and e.holo or e=='holo' then return 1 end
  return 2
end
local function copy_kind(j)
  if j.key=='j_blueprint' or name(j)=='Blueprint' then return 'blueprint' end
  if j.key=='j_brainstorm' or name(j)=='Brainstorm' then return 'brainstorm' end
end
local function pinned(j) return j.pinned or (j.ability or {}).pinned end
local function orders(jokers,limit)
  local current,free,sorted,keys={},{},{},{}
  for i,j in ipairs(jokers) do
    current[i]=i; keys[i]=tostring(j.id or '')..':'..encode(j)
    if not pinned(j) then free[#free+1]=i; sorted[#sorted+1]=i end
  end
  local function stable(a,b) return keys[a]<keys[b] or keys[a]==keys[b] and a<b end
  table.sort(sorted,function(a,b)
    local left,right=tier(jokers[a]),tier(jokers[b]); return left<right or left==right and stable(a,b)
  end)
  local arranged={}; for i,v in ipairs(current) do arranged[i]=v end
  for i,pos in ipairs(free) do arranged[pos]=sorted[i] end
  local result,seen,shortlisted={},{},false
  local function add(order)
    if not order then return end
    local key=table.concat(order,','); if seen[key] then return end
    seen[key]=true
    if #result>=limit then shortlisted=true; return end
    result[#result+1]=order
  end
  add(current); add(arranged)
  -- A destruction target must be chosen before the draw. Include each reachable
  -- neighbor (and a safe final slot) in the same bounded setup shortlist.
  for i,j in ipairs(jokers) do if j.key=='j_ceremonial' and not j.debuff then
    for _,base in ipairs({current,arranged}) do
      local position;for p,id in ipairs(base) do if id==i then position=p end end
      if position and position<#jokers and not pinned(jokers[base[position+1]]) then
        for p,id in ipairs(base) do if p~=position and not pinned(jokers[id]) then
          local trial={};for k,v in ipairs(base) do trial[k]=v end
          trial[position+1],trial[p]=trial[p],trial[position+1];add(trial)
        end end
      end
      if not pinned(j) and #jokers>1 and not pinned(jokers[base[#jokers]]) then
        local trial={};for k,v in ipairs(base) do trial[k]=v end
        trial[position],trial[#jokers]=trial[#jokers],trial[position];add(trial)
      end
    end
  end end
  local blueprints,brainstorms,targets={},{},{}
  for i,j in ipairs(jokers) do if not j.debuff then
    local kind=copy_kind(j)
    if kind=='blueprint' then blueprints[#blueprints+1]=i
    elseif kind=='brainstorm' then brainstorms[#brainstorms+1]=i
    elseif j.blueprint_compat~=false then targets[#targets+1]=i end
  end end
  table.sort(blueprints,function(a,b)
    -- A copy-incompatible Blueprint can still copy, but must be the OUTSIDE
    -- link of a chain rather than the target of another copy.
    local ac,bc=jokers[a].blueprint_compat==false,jokers[b].blueprint_compat==false
    return ac~=bc and ac or ac==bc and stable(a,b)
  end)
  table.sort(brainstorms,stable)
  local potential={j_photograph=12,j_baron=10,j_ancient=10,j_triboulet=14,j_hanging_chad=10,
    j_mime=8,j_hack=8,j_sock_and_buskin=8,j_scholar=8,j_wee=8,j_fibonacci=6,
    j_dusk=8,j_acrobat=8,j_card_sharp=8,j_mystic_summit=6}
  local function value(i)
    local j=jokers[i]; local a=j.ability or {}; local e=type(a.extra)=='table' and a.extra or {}
    return num(potential[j.key])+num(a.mult)/4+num(a.t_mult)/4+
      num(a.t_chips,num(e.chips,num(e.chip_mod)))/40+
      8*math.log(math.max(1,num(a.x_mult,num(e.Xmult,1))))
  end
  table.sort(targets,function(a,b) local av,bv=value(a),value(b); return av>bv or av==bv and stable(a,b) end)
  -- Each goal creates copy->target blocks, with Brainstorm's resolved target
  -- anchored first. Greedy placement honors every pinned position. The scorer
  -- still resolves compatibility/chains itself; no copied effect is invented.
  local function goal(assignments,first_target)
    local groups,group_for={},{}
    for _,bp in ipairs(blueprints) do
      local target=assignments[bp]
      if target then
        if not group_for[target] then group_for[target]={target=target,members={}}; groups[#groups+1]=group_for[target] end
        local g=group_for[target]; g.members[#g.members+1]=bp
      end
    end
    local grouped={}
    for _,g in ipairs(groups) do
      g.members[#g.members+1]=g.target
      for _,i in ipairs(g.members) do grouped[i]=true end
    end
    for i=1,#jokers do if not grouped[i] then groups[#groups+1]={target=i,members={i}} end end
    local function resolved_tier(i)
      if copy_kind(jokers[i])=='brainstorm' and first_target then return tier(jokers[first_target]) end
      return tier(jokers[i])
    end
    for _,g in ipairs(groups) do
      g.tier=resolved_tier(g.target)
      for _,i in ipairs(g.members) do
        local e=jokers[i].edition
        if e=='polychrome' or type(e)=='table' and e.polychrome then g.tier=3 end
      end
    end
    table.sort(groups,function(a,b) return a.tier<b.tier or a.tier==b.tier and stable(a.target,b.target) end)
    local first
    if first_target then
      for _,g in ipairs(groups) do for _,i in ipairs(g.members) do if i==first_target then first=g end end end
    end
    local out,placed={},{}
    for i,j in ipairs(jokers) do if pinned(j) then out[i]=i; placed[i]=i end end
    local function fits(g,start)
      if start+#g.members-1>#jokers then return false end
      for offset,id in ipairs(g.members) do
        local pos=start+offset-1
        if out[pos] and out[pos]~=id or placed[id] and placed[id]~=pos or pinned(jokers[id]) and id~=pos then return false end
      end
      return true
    end
    local function put(g,start)
      for offset,id in ipairs(g.members) do local pos=start+offset-1; out[pos]=id; placed[id]=pos end
    end
    if first then if not fits(first,1) then return end; put(first,1) end
    local preferred=first and #first.members+1 or 1
    for _,g in ipairs(groups) do if g~=first then
      g.preferred=preferred; preferred=preferred+#g.members
    end end
    for _,g in ipairs(groups) do if g~=first and #g.members>1 then
      local start,distance
      for i=1,#jokers do if fits(g,i) then
        local d=math.abs(i-g.preferred)
        if not start or d<distance then start,distance=i,d end
      end end
      if not start then return end
      put(g,start)
    end end
    local pos=1
    for _,g in ipairs(groups) do for _,id in ipairs(g.members) do if not placed[id] then
      while out[pos] do pos=pos+1 end
      out[pos]=id; placed[id]=pos
    end end end
    return out
  end
  local has_copies=#blueprints+#brainstorms>0
  if has_copies then
    for _,target in ipairs(targets) do
      local assignments={}; for _,bp in ipairs(blueprints) do assignments[bp]=target end
      add(goal(assignments,#brainstorms>0 and target or nil))
    end
    -- Blueprint->Brainstorm->leftmost keeps the copied XMult activations late
    -- without forcing a Blueprint+XMult block ahead of all additive Mult.
    if #brainstorms>0 and #blueprints>0 then
      for _,target in ipairs(targets) do
        for _,bs in ipairs(brainstorms) do if jokers[bs].blueprint_compat~=false then
          local assignments={}; for _,bp in ipairs(blueprints) do assignments[bp]=bs end
          add(goal(assignments,target))
        end end
      end
    end
    -- Mixed targets are useful when one copied scorer supports another. This
    -- is a deterministic shortlist, never the factorial set of Joker orders.
    if #blueprints>0 and (#brainstorms>0 or #blueprints>1) then
      for _,a in ipairs(targets) do for _,b in ipairs(targets) do if a~=b then
        local assignments={}
        for k,bp in ipairs(blueprints) do assignments[bp]=#brainstorms>0 and b or k==1 and a or b end
        add(goal(assignments,#brainstorms>0 and a or nil))
      end end end
    end
    -- If a pinned first card prevents Brainstorm's requested target, still
    -- examine reachable Blueprint targets with that real constraint intact.
    if #brainstorms>0 then for _,target in ipairs(targets) do
      local assignments={}; for _,bp in ipairs(blueprints) do assignments[bp]=target end
      add(goal(assignments,nil))
    end end
  end
  return result,shortlisted,has_copies
end
local function subsets(n,maximum)
  local out,chosen={},{}
  local function walk(first)
    if #chosen>0 then local c={}; for i,v in ipairs(chosen) do c[i]=v end; out[#out+1]=c end
    if #chosen==maximum then return end
    for i=first,n do chosen[#chosen+1]=i; walk(i+1); chosen[#chosen]=nil end
  end
  walk(1); return out
end
local function unsupported_history(before,after)
  local count={}
  for sign,row in ipairs({before.jokers or {},after.jokers or {}}) do
    local has_copy,has_road=false,false
    for _,j in ipairs(row) do if not expired(j) then
      has_copy=has_copy or copy_kind(j)~=nil
      has_road=has_road or j.key=='j_hit_the_road' or name(j)=='Hit the Road'
    end end
    -- Future Jack discards are not a free multiplier. An unchanged, uncopied
    -- Hit the Road can retain its current value, but buying/copying/removing it
    -- needs the real discard path, so keeps the strategy's existing estimate.
    if has_copy and has_road then return true end
    for _,j in ipairs(row) do if j.key=='j_hit_the_road' or name(j)=='Hit the Road' then
      local key=encode(j); count[key]=(count[key] or 0)+(sign==1 and -1 or 1)
    end end
  end
  for _,n in pairs(count) do if n~=0 then return true end end
  return false
end
local function round_resources(s)
  local resets=s.round_resets or {}
  local bonus=s.round_bonus or (s.shop_forecast or {}).round_bonus or {}
  return math.max(1,num(resets.hands,4)+num(bonus.next_hands)),
    math.max(0,num(resets.discards,3)+num(bonus.discards))
end
local hand_names={'High Card','Pair','Two Pair','Three of a Kind','Straight','Flush','Full House',
  'Four of a Kind','Straight Flush','Five of a Kind','Flush House','Flush Five'}
local function repeat_target(s)
  local best,played,level='High Card',-1,-1
  for _,label in ipairs(hand_names) do
    local h=(s.hands or {})[label] or {}
    local p,l=num(h.played),num(h.level,1)
    if p>played or p==played and l>level then best,played,level=label,p,l end
  end
  return best
end
local function temporal_flags(rows)
  local flags={}
  for _,row in ipairs(rows) do for _,j in ipairs(row or {}) do if not expired(j) then
    local kind=later_hand[j.key] or later_hand[name(j)]
    if kind then flags[kind]=true end
  end end end
  return flags
end

local boss_names={bl_small='Small Blind',bl_big='Big Blind',bl_club='The Club',bl_goad='The Goad',
  bl_window='The Window',bl_head='The Head',bl_plant='The Plant',bl_pillar='The Pillar',
  bl_psychic='The Psychic',bl_arm='The Arm',bl_flint='The Flint',bl_ox='The Ox',bl_tooth='The Tooth',
  bl_eye='The Eye',bl_mouth='The Mouth',bl_water='The Water',bl_needle='The Needle',bl_manacle='The Manacle',
  bl_wall='The Wall',bl_final_vessel='Violet Vessel',bl_final_leaf='Verdant Leaf',
  bl_house='The House',bl_wheel='The Wheel',bl_mark='The Mark',bl_fish='The Fish',bl_serpent='The Serpent'}
local boss_suits={bl_club='Clubs',bl_goad='Spades',bl_window='Diamonds',bl_head='Hearts'}
local function next_blind(s)
  local b=s.next_blind
  if type(b)~='table' or not b.key then return nil,'upcoming blind metadata unavailable' end
  if not boss_names[b.key] or b.name and b.name~=boss_names[b.key] then
    return nil,'upcoming random or unknown boss mechanics are outside this comparison'
  end
  b=clone(b);b.name=b.name or boss_names[b.key];b.disabled=false;b.hands={};b.only_hand=nil
  b.debuff=b.debuff or {}
  if boss_suits[b.key] then b.debuff.suit=boss_suits[b.key] end
  if b.key=='bl_plant' then b.debuff.is_face='face' end
  if b.key=='bl_psychic' then b.debuff.h_size_ge=5 end
  return b
end

-- Fresh-round restriction projection follows Blind:set_blind/debuff_card.
-- Draw samples are composition evidence, never actual future draws. Unknown
-- random blind-start effects retain the explicitly labelled neutral fallback.
local function apply_blind(state,definition,card_only,defer_disable)
  if not definition then return end
  local b=card_only and state.blind or clone(definition);state.blind=b
  local smeared,faces,chicot=false,false,false
  for _,j in ipairs(state.jokers) do if not j.debuff then
    smeared=smeared or j.key=='j_smeared';faces=faces or j.key=='j_pareidolia';chicot=chicot or j.key=='j_chicot'
  end end
  if not card_only and not defer_disable and chicot and b.boss then
    b.disabled=true
    if b.key=='bl_wall' then b.chips=num(b.chips)/2
    elseif b.key=='bl_final_vessel' then b.chips=num(b.chips)/3 end
    return
  end
  if b.disabled then return end
  if not card_only then
    if b.key=='bl_manacle' then state.hand_size=state.hand_size-1 end
    if b.key=='bl_water' then
      b.discards_sub=state.discards_left;state.discards_left=0;state.current_round.discards_left=0
    end
    if b.key=='bl_needle' then
      b.hands_sub=num((state.round_resets or {}).hands,4)-1
      state.hands_left=state.hands_left-b.hands_sub
      state.current_round.hands_left=state.hands_left
    end
  end
  local bd=b.debuff
  for _,c in ipairs(state.playing_cards) do
    local stone=c.enhancement=='m_stone' or (c.ability or {}).effect=='Stone Card'
    local wild=c.enhancement=='m_wild' or (c.ability or {}).name=='Wild Card'
    local red=c.suit=='Hearts' or c.suit=='Diamonds'
    local target_red=bd.suit=='Hearts' or bd.suit=='Diamonds'
    local suit_match=bd.suit and not stone and (wild or c.suit==bd.suit or smeared and red==target_red)
    local rank=num(c.rank,num((c.base or {}).id))
    local face_match=bd.is_face=='face' and (faces or not stone and rank>=11 and rank<=13)
    local a=c.ability or {};local base=c.base or {}
    c.debuff=not not (a.perma_debuff or suit_match or face_match or b.key=='bl_pillar' and a.played_this_ante
      or b.key=='bl_final_leaf' or bd.value and bd.value==base.value or bd.nominal and bd.nominal==num(c.nominal,base.nominal))
  end
end

local function refresh_derived(state)
  local row,cards=state.jokers,state.playing_cards
  local resale,stencils,stone,steel,enhanced=0,0,0,0,0
  for _,j in ipairs(row) do
    resale=resale+num(j.sell_cost)
    if j.key=='j_stencil' or name(j)=='Joker Stencil' then stencils=stencils+1 end
  end
  for _,c in ipairs(cards) do
    local e=c.enhancement or (c.key and c.key:sub(1,2)=='m_' and c.key) or 'c_base'
    if e=='m_stone' then stone=stone+1 end
    if e=='m_steel' then steel=steel+1 end
    if e~='c_base' then enhanced=enhanced+1 end
  end
  for _,j in ipairs(row) do
    j.ability=j.ability or {};local a=j.ability
    if j.key=='j_swashbuckler' or name(j)=='Swashbuckler' then a.mult=resale-num(j.sell_cost) end
    if j.key=='j_stencil' or name(j)=='Joker Stencil' then a.x_mult=math.max(1,num(state.joker_limit,5)-#row+stencils) end
    if j.key=='j_stone' or name(j)=='Stone Joker' then a.stone_tally=stone end
    if j.key=='j_steel_joker' or name(j)=='Steel Joker' then a.steel_tally=steel end
    if j.key=='j_drivers_license' or name(j)=="Driver's License" then a.driver_tally=enhanced end
  end
end

function Shop.new(root_snapshot,scorer,yield_fn,options)
  options=options or {}
  local context={evaluations=0,truncated=false,unavailable_reason=nil,
    metrics={profile_requests=0,profile_cache_hits=0,completed_profiles=0,paired_comparisons=0},
    order_limit=math.max(2,math.min(8,math.floor(num(options.max_orders,8)))),orders_shortlisted=false,
    max_evaluations=math.max(0,math.min(50000,math.floor(num(options.max_evaluations,50000))))}
  local root_deck=deck(root_snapshot.playing_cards)
  local root_key=encode(root_deck)
  local draws=permutations(#root_deck)
  local paired=Shop.paired_deck and Shop.paired_deck.new(root_deck)
  local root_hands=round_resources(root_snapshot)
  local upcoming,boss_fallback=next_blind(root_snapshot)
  if upcoming and upcoming.key=='bl_needle' then
    local chicot=false;for _,j in ipairs(root_snapshot.jokers or {}) do if j.key=='j_chicot' and not expired(j) then chicot=true end end
    if not chicot then root_hands=root_hands-num((root_snapshot.round_resets or {}).hands,4)+1 end
  end
  local repeat_hand=repeat_target(root_snapshot)
  local visible_temporal=temporal_flags({root_snapshot.jokers or {},root_snapshot.shop_jokers or {},root_snapshot.pack_cards or {}})
  local cache,selection_cache,finishing_cache={},{},{}
  local function unavailable(reason) context.unavailable_reason=reason; return nil end
  local function prepared_order(snapshot,row)
    local order={};for i=1,#row do order[i]=i end
    local has_dagger,has_copy,has_start=false,false,false
    for _,j in ipairs(row) do if not j.debuff then
      has_dagger=has_dagger or j.key=='j_ceremonial'
      has_copy=has_copy or j.key=='j_blueprint' or j.key=='j_brainstorm'
      has_start=has_start or j.key=='j_burglar' or j.key=='j_marble'
    end end
    if not has_dagger and not (has_copy and has_start) then return order end
    if not Shop.blind_prep or not Shop.strategy then return nil,'Executable blind preparation dependencies are unavailable.' end
    local state=clone(snapshot);state.phase='blind';state.jokers=clone(row)
    state._shop_scoring=nil;state._readiness=nil
    local seen={}
    for step=1,13 do
      local signature=table.concat(order,',')
      if seen[signature] then return nil,'Blind preparation did not reach a stable executable setup.' end
      seen[signature]=true
      local suggestion=Shop.blind_prep.suggest(state,Shop.strategy)
      if not suggestion then return order end
      local action=suggestion.action or {}
      if action.kind~='reorder_jokers' or #action.order~=#row then return nil,'The projected preparation action is unsupported.' end
      local next_row,next_order,used={},{},{}
      for i,index in ipairs(action.order) do
        if not state.jokers[index] or used[index] or pinned(state.jokers[index]) and i~=index then
          return nil,'The projected preparation order is not legal.'
        end
        used[index]=true;next_row[i]=state.jokers[index];next_order[i]=order[index]
      end
      state.jokers=next_row;order=next_order
    end
    return nil,'Blind preparation exceeds the bounded setup steps.'
  end
  local function prepare(s,temporal)
    if #root_deck==0 or not scorer or type(scorer.score)~='function' then return unavailable('No complete owned deck or scorer is available.') end
    local cards=deck(s.playing_cards)
    local changed_deck=encode(cards)~=root_key
    if changed_deck and not paired then return unavailable('Deck-changing purchases need a paired identity model.') end
    local plan_draws=draws
    if changed_deck then
      plan_draws={}
      for sample=1,4 do
        local order,why=paired:sample(cards,sample)
        if not order then return unavailable(why) end
        plan_draws[sample]=order
      end
    end
    local size=math.floor(num(s.hand_size,8))
    if size<1 or size>10 then return unavailable('Hand sizes outside 1–10 are not sampled.') end
    local max_cards=math.min(5,math.floor(num(s.hand_limit,5)))
    if max_cards<1 then return unavailable('There is no legal played-hand size.') end
    local row,startup={},false
    for i,j in ipairs(s.jokers or {}) do
      if not vanilla[j.key] then return unavailable('Unknown Joker effects are left to the existing strategy.') end
      local supported=Shop.blind_start and Shop.blind_start.supports(j)
      if (skip_rows[j.key] or skip_rows[name(j)]) and not supported then return unavailable('Blind-start Joker changes are left to the existing strategy.') end
      startup=startup or supported
      local c=clone(j); c.debuff=not not expired(c)
      row[i]=c
    end
    if #row>12 then return unavailable('Large Joker rows are outside this scoring budget.') end
    -- These values are refreshed by Card:update in the live game. A detached
    -- add/remove must derive them from its final row/deck instead of retaining
    -- the pre-purchase cache (notably Swashbuckler and Joker Stencil).
    local round={idol_card=clone((s.current_round or {}).idol_card),
      ancient_card=clone((s.current_round or {}).ancient_card),
      most_played_poker_hand=(s.current_round or {}).most_played_poker_hand}
    round.hands_left,round.discards_left=round_resources(s)
    round.hands_played=0; round.discards_used=0
    local hands=clone(s.hands or {})
    for _,h in pairs(hands) do h.played_this_round=0 end
    local state={phase='hand',jokers=row,playing_cards=cards,hands=hands,current_round=round,
      hands_left=round.hands_left,discards_left=round.discards_left,hands_played=0,discards_used=0,
      chips=0,blind={disabled=true},dollars=num(s.dollars),modifiers=clone(s.modifiers or {}),
      probabilities=clone(s.probabilities or {normal=1}),joker_limit=num(s.joker_limit,5),
      hand_size=size,hand_limit=max_cards,starting_deck_size=s.starting_deck_size,
      consumeables=clone(s.consumeables or {}),consumeable_usage_total=clone(s.consumeable_usage_total or {}),
      used_vouchers=clone(s.used_vouchers or {}),hands_played_total=s.hands_played_total,
      first_used_hand_level=s.first_used_hand_level,deck_key=s.deck_key,
      round_resets=clone(s.round_resets),bankrupt_at=s.bankrupt_at,interest_amount=s.interest_amount,
      consumable_limit=s.consumable_limit,consumeable_buffer=s.consumeable_buffer,
      ante=s.ante,win_ante=s.win_ante,rental_rate=s.rental_rate,interest_cap=s.interest_cap,
      jokers_shuffling=s.jokers_shuffling,ordering_safe=s.ordering_safe}
    refresh_derived(state)
    -- Chicot's queued disable follows setting_blind. Applying it before Dagger
    -- chooses a victim can promise an inactive boss after Chicot is destroyed.
    apply_blind(state,upcoming,false,Shop.blind_start~=nil)
    size=state.hand_size
    if size<1 or size>10 then return unavailable('The upcoming blind leaves a hand size outside 1-10.') end
    round=state.current_round
    local key=encode(state)..':'..encode(temporal)
    -- A shop purchase must never receive credit merely for rearranging the
    -- exact same row. Ignore only freely movable positions in this identity;
    -- every card, edition, counter, cash value and pinned slot remains present.
    local equivalent={}; for k,v in pairs(state) do equivalent[k]=v end
    equivalent.jokers={}; local movable={}
    for i,j in ipairs(row) do
      if pinned(j) then equivalent.jokers[i]=j else movable[#movable+1]=j end
    end
    table.sort(movable,function(a,b) return encode(a)<encode(b) end)
    local next_card=1
    for i=1,#row do if not equivalent.jokers[i] then
      equivalent.jokers[i]=movable[next_card]; next_card=next_card+1
    end end
    local selection_key=math.min(size,#cards)..':'..max_cards
    if not selection_cache[selection_key] then selection_cache[selection_key]=subsets(math.min(size,#cards),max_cards) end
    local selections=selection_cache[selection_key]
    local layouts,shortlisted,has_copies
    if startup then
      local order,why=prepared_order(s,row)
      if not order then return unavailable(why) end
      layouts={order};shortlisted=false;has_copies=false
      for _,j in ipairs(row) do has_copies=has_copies or copy_kind(j)~=nil end
    else layouts,shortlisted,has_copies=orders(row,context.order_limit) end
    context.orders_shortlisted=context.orders_shortlisted or shortlisted
    local function scenarios_for(state)
    local round=state.current_round
    local scenarios={{state=state,weight=temporal and 1-temporal.weight or 1}}
    if temporal then
      -- This is conditional capacity on a representative hand, not a simulated
      -- turn sequence. No discarded Jacks, future Joker growth, improved draw,
      -- or survival probability is invented. The exact same assumption and
      -- root-fixed repeat target are supplied to every compared purchase.
      local late=clone(state)
      local used=round.hands_left-1
      late.hands_left=1; late.hands_played=used
      late.current_round.hands_left=1; late.current_round.hands_played=used
      if temporal.repeat_hand and used>0 then
        late.hands[temporal.repeat_hand]=late.hands[temporal.repeat_hand] or {}
        late.hands[temporal.repeat_hand].played_this_round=1
        if late.blind.key=='bl_eye' and not late.blind.disabled then late.blind.hands[temporal.repeat_hand]=true end
        if late.blind.key=='bl_mouth' and not late.blind.disabled then late.blind.only_hand=temporal.repeat_hand end
      end
      if temporal.no_discards then
        late.discards_left=0; late.discards_used=round.discards_left
        late.current_round.discards_left=0; late.current_round.discards_used=round.discards_left
      end
      for _,j in ipairs(late.jokers) do if not j.debuff then
        local a=j.ability or {}
        if temporal.no_discards and round.discards_left>0 and
          (j.key=='j_green_joker' or j.key=='j_ramen' or j.key=='j_castle' or j.key=='j_yorick' or j.key=='j_hit_the_road') then
          return unavailable('Spending discards changes this Joker build; the conditional shop scenario needs a real discard path.')
        end
        if j.key=='j_ice_cream' then
          a.extra=type(a.extra)=='table' and a.extra or {}
          a.extra.chips=num(a.extra.chips,100)-used*num(a.extra.chip_mod,5)
          if a.extra.chips<=0 then return unavailable('A Joker would expire before the conditional late hand.') end
        elseif j.key=='j_selzer' then
          a.extra=num(a.extra,10)-used
          if a.extra<=0 then return unavailable('A Joker would expire before the conditional late hand.') end
        end
      end end
      scenarios[#scenarios+1]={state=late,weight=temporal.weight}
    end
    return scenarios
    end
    local scenarios=scenarios_for(state);if not scenarios then return end
    local plan={key=key,equivalent_key=encode(equivalent),state=state,scenarios=scenarios,selections=selections,orders=layouts,draws=plan_draws,
      temporal=temporal,shortlisted=shortlisted,has_copies=has_copies,cost=4*#selections*#layouts*#scenarios}
    if startup then
      if not paired then return unavailable('Blind-start generation needs the paired population module.') end
      plan.startup={};plan.cost=0
      -- This is the setup the actual pre-blind preparation policy publishes,
      -- including its protected-victim rules. Unpublished free rearrangements
      -- cannot create forecast hands, cards or sacrifice Mult.
      local executable=clone(state);executable.jokers={}
      for i,index in ipairs(layouts[1]) do executable.jokers[i]=state.jokers[index] end
      plan.equivalent_key=encode(executable)..':'..encode(temporal)
      for layout,order in ipairs(layouts) do
        local setup=clone(state);setup.jokers={}
        for i,index in ipairs(order) do setup.jokers[i]=state.jokers[index] end
        plan.startup[layout]={}
        for sample=1,4 do
          local projected,diagnostics=Shop.blind_start.project(setup,{sample_index=sample})
          if not projected then return unavailable(diagnostics) end
          refresh_derived(projected)
          if diagnostics.requires_card_debuff_refresh then apply_blind(projected,upcoming,true) end
          local n=math.floor(projected.hand_size)
          if n<1 or n>10 then return unavailable('Blind-start changes leave a hand size outside 1-10.') end
          local permutation,why=paired:sample(projected.playing_cards,sample,encode(projected.playing_cards)==root_key)
          if not permutation then return unavailable(why) end
          projected.hand,projected.deck={},{}
          for i,index in ipairs(permutation) do
            local target=i<=n and projected.hand or projected.deck;target[#target+1]=projected.playing_cards[index]
          end
          local selection_key=math.min(n,#projected.playing_cards)..':'..max_cards
          if not selection_cache[selection_key] then selection_cache[selection_key]=subsets(math.min(n,#projected.playing_cards),max_cards) end
          local conditional=scenarios_for(projected);if not conditional then return end
          local trial={state=projected,scenarios=conditional,selections=selection_cache[selection_key],diagnostics=diagnostics}
          plan.startup[layout][sample]=trial
          plan.cost=plan.cost+#trial.selections*#conditional
        end
      end
    end
    return plan
  end
  local function profile(plan)
    context.metrics.profile_requests=context.metrics.profile_requests+1
    if cache[plan.key]~=nil then
      context.metrics.profile_cache_hits=context.metrics.profile_cache_hits+1
      return cache[plan.key] or nil
    end
    if plan.startup then
      local best
      for layout,trials in ipairs(plan.startup) do
        local value={mean=0,scores={},opening_scores={},opening_hands={},opening_sizes={},uncertain=false,worlds={},
          state=trials[1].state,startup={order=clone(plan.orders[layout]),samples={}}}
        for sample,trial in ipairs(trials) do
          local weighted=0
          value.uncertain=value.uncertain or trial.diagnostics.stochastic
          value.startup.samples[sample]=clone(trial.diagnostics)
          for scenario_index,scenario in ipairs(trial.scenarios) do
            local score,label,size,opening_play
            for _,selected in ipairs(trial.selections) do
              context.evaluations=context.evaluations+1
              if yield_fn and context.evaluations%64==0 then yield_fn() end
              local result=scorer.score(scenario.state,selected)
              if not result or type(result.score)~='number' or result.score~=result.score or result.score==math.huge or result.score<0 then
                cache[plan.key]=false;return unavailable('The scorer could not produce a finite blind-start estimate.')
              end
              for _,warning in ipairs(result.warnings or {}) do
                if warning:find('Unmodeled',1,true) or warning:find('unknown card',1,true) or
                  warning:find('not included',1,true) or warning:find('not modeled',1,true) then
                  cache[plan.key]=false;return unavailable(warning)
                end
              end
              value.uncertain=value.uncertain or result.uncertain
              if Shop.blind_finishing and scenario_index==1 and result.legal~=false then
                result.indices=clone(selected)
                if Shop.blind_finishing.better_play(scenario.state,result,opening_play) then opening_play=result end
              end
              if result.legal~=false and (not score or result.score>score) then score,label,size=result.score,result.hand,#selected end
            end
            if not score then cache[plan.key]=false;return unavailable('No legal play after blind-start effects.') end
            if scenario_index==1 then
              value.opening_scores[sample]=score;value.opening_hands[sample]=label;value.opening_sizes[sample]=size
              if Shop.blind_finishing then value.worlds[sample]={state=clone(scenario.state),opening_play=clone(opening_play)} end
            end
            weighted=weighted+scenario.weight*score
          end
          value.scores[sample]=weighted;value.mean=value.mean+weighted/4
        end
        -- The setup is chosen once across every sample, before any draw. Choosing
        -- a different sacrifice after seeing each hypothetical hand is illegal.
        if not best or value.mean>best.mean then best=value end
      end
      context.metrics.completed_profiles=context.metrics.completed_profiles+1
      cache[plan.key]=best;return best
    end
    local scores,opening_scores,opening_hands,opening_sizes,total,uncertain,worlds={},{},{},{},0,false,{}
    local fixed={}
    if Shop.blind_finishing then for index,order in ipairs(plan.orders) do
      local row={};local changed=false
      for i,j in ipairs(order) do row[i]=plan.state.jokers[j];changed=changed or i~=j end
      fixed[index]={mean=0,scores={},opening_scores={},opening_hands={},opening_sizes={},worlds={},
        order=clone(order),identity=encode(row),changed=changed}
    end end
    local supported_random_choices=true
    for draw,permutation in ipairs(plan.draws) do
      local sampled_hand,sampled_deck={},{}
      for i,index in ipairs(permutation) do
        local target=i<=plan.state.hand_size and sampled_hand or sampled_deck
        target[#target+1]=plan.state.playing_cards[index]
      end
      local weighted=0
      for scenario_index,scenario in ipairs(plan.scenarios) do
      local state=scenario.state; state.hand=sampled_hand; state.deck=sampled_deck
      local best,best_hand,best_size
      for order_index,order in ipairs(plan.orders) do
        local row={}; for i,index in ipairs(order) do row[i]=state.jokers[index] end
        local trial={}; for k,v in pairs(state) do trial[k]=v end; trial.jokers=row
        local opening_play,order_best,order_hand,order_size
        for _,selected in ipairs(plan.selections) do
          context.evaluations=context.evaluations+1
          if yield_fn and context.evaluations%64==0 then yield_fn() end
          local result=scorer.score(trial,selected)
          if not result or type(result.score)~='number' or result.score~=result.score or result.score==math.huge or result.score<0 then
            cache[plan.key]=false; return unavailable('The scorer could not produce a finite estimate.')
          end
          for _,warning in ipairs(result.warnings or {}) do
            if warning:find('Unmodeled',1,true) or warning:find('unknown card',1,true) or
              warning:find('not included',1,true) or warning:find('not modeled',1,true) then
              cache[plan.key]=false; return unavailable(warning)
            end
          end
          uncertain=uncertain or result.uncertain
          if result.uncertain and not (Shop.blind_finishing and Shop.blind_finishing.choice_supported and
            Shop.blind_finishing.choice_supported(trial,result)) then supported_random_choices=false end
          if Shop.blind_finishing and scenario_index==1 and result.legal~=false then
            result.indices=clone(selected)
            if Shop.blind_finishing.better_play(trial,result,opening_play) then opening_play=result end
          end
          if result.legal~=false and (not best or result.score>best) then best,best_hand,best_size=result.score,result.hand,#selected end
          if result.legal~=false and (not order_best or result.score>order_best) then
            order_best,order_hand,order_size=result.score,result.hand,#selected
          end
        end
        if Shop.blind_finishing then
          local candidate=fixed[order_index]
          if not order_best then cache[plan.key]=false;return unavailable('A fixed layout has no legal opening play.') end
          candidate.scores[draw]=num(candidate.scores[draw])+scenario.weight*order_best
          candidate.mean=candidate.mean+scenario.weight*order_best/4
          if scenario_index==1 then
            candidate.opening_scores[draw]=order_best;candidate.opening_hands[draw]=order_hand;candidate.opening_sizes[draw]=order_size
            -- Retain the physical input row. The forecast must actually apply
            -- and count this legal reorder before using its opening play.
            candidate.worlds[draw]={state=clone(state),opening_play=clone(opening_play),
              setup_action=candidate.changed and {kind='reorder_jokers',area='jokers',order=clone(order)} or nil}
          end
        end
      end
      if not best then cache[plan.key]=false; return unavailable('No legal opening play was found.') end
      if scenario_index==1 then opening_scores[draw]=best;opening_hands[draw]=best_hand;opening_sizes[draw]=best_size end
      weighted=weighted+scenario.weight*best
      end
      scores[draw]=weighted; total=total+weighted
    end
    local value={mean=total/4,scores=scores,opening_scores=opening_scores,opening_hands=opening_hands,opening_sizes=opening_sizes,uncertain=not not uncertain,worlds=worlds,
      supported_random_choices=supported_random_choices}
    if Shop.blind_finishing then
      -- One fixed arrangement is chosen once across ALL four common worlds,
      -- before forecasting either continuation. This reuses already complete
      -- opening comparisons; it never picks the winning order per future world.
      local best
      for _,candidate in ipairs(fixed) do
        if not best or candidate.mean>best.mean or candidate.mean==best.mean and candidate.identity<best.identity then best=candidate end
      end
      value=best;value.uncertain=not not uncertain;value.supported_random_choices=supported_random_choices
      value.ordering={order=clone(best.order),identity=best.identity,action_count=best.changed and 1 or 0,
        selection='one_fixed_layout_by_complete_common_opening_mean',layouts=#fixed,samples=4,
        scope='Legal projected first-hand reorder, then one fixed observed continuation; future actions require fresh advice.'}
    end
    context.metrics.completed_profiles=context.metrics.completed_profiles+1
    cache[plan.key]=value; return value
  end
  local function temporal_for(before,after)
    if Shop.blind_finishing and upcoming and root_hands<=4 and
      num(before.hand_size,8)<=8 and num(after.hand_size,8)<=8 and #root_deck<=128 then
      -- Actual observed continuations replace invented repeat/last-hand or
      -- all-discards-spent states. An unsupported transition falls back to its
      -- labelled opening estimate; it never revives those assumed resources.
      return nil
    end
    local flags=temporal_flags({before.jokers or {},after.jokers or {}})
    for k,v in pairs(visible_temporal) do flags[k]=v end
    if flags.last or flags['repeat'] or flags.discards then
      return {weight=1/math.max(2,root_hands),repeat_hand=flags['repeat'] and repeat_hand or nil,
        no_discards=not not flags.discards,conditional=true}
    end
  end
  local function finishing(plan,value)
    if not Shop.blind_finishing then return end
    if finishing_cache[plan.key] then return finishing_cache[plan.key] end
    context.metrics.finishing_requests=num(context.metrics.finishing_requests)+1
    local result
    -- Only ordinary no-Joker Lucky means may enter the existing fixed policies;
    -- they are resolved after each committed play, including the final play.
    -- Startup stochasticity has separate semantics and is never admitted here.
    if not upcoming or value.uncertain and not (not value.startup and value.supported_random_choices) then
      result={complete=false,supported=false,reason='A known target and supported opening/startup mechanics are required.'}
    else
      local function charge()
        if context.evaluations>=context.max_evaluations then
          context.truncated=true;unavailable('The shared scoring budget cannot complete paired whole-blind policies.');return false
        end
        context.evaluations=context.evaluations+1
        if yield_fn and context.evaluations%64==0 then yield_fn() end
        return true
      end
      local before=context.evaluations
      result=Shop.blind_finishing.forecast(value.worlds,scorer,charge)
      result.evaluations=context.evaluations-before
      context.metrics.finishing_evaluations=num(context.metrics.finishing_evaluations)+result.evaluations
      if result.complete then context.metrics.completed_finishing_profiles=num(context.metrics.completed_finishing_profiles)+1 end
    end
    finishing_cache[plan.key]=result;return result
  end
  local function readiness(plan,value,snapshot,opening_only)
    local state=value.state or plan.state
    local target=num(state.blind.chips)
    local hidden=not state.blind.disabled and ({bl_house=true,bl_wheel=true,bl_mark=true})[state.blind.key]
    if not upcoming or target<=0 or hidden or value.uncertain and not (not value.startup and value.supported_random_choices) then
      return {status='unsupported',supported=false,reason=hidden and 'Concealed opening cards prevent a supported readiness plan.' or
        value.startup and value.uncertain and 'Sampled blind-start card generation cannot establish next-blind readiness.' or
        value.uncertain and 'Random scoring cannot establish next-blind readiness.' or 'Actual upcoming blind target is unavailable.'}
    end
    local low,high,total,clears=math.huge,0,0,0
    for _,v in ipairs(value.opening_scores) do
      low=math.min(low,v);high=math.max(high,v);total=total+v
      if v>=target then clears=clears+1 end
    end
    -- This deliberately generous pressure proxy is NOT a score upper bound:
    -- later hands, real discards and growth are not simulated here. In particular,
    -- repeating the same sampled cards cannot establish a safe finishing plan.
    local hands=math.min(state.hands_left,#state.playing_cards)
    local capacity=high*hands
    local status=low>=target*1.25 and 'sampled_safe' or capacity<target and 'sampled_deficit' or 'unresolved'
    local finish=not opening_only and finishing(plan,value) or finishing_cache[plan.key]
    local complete=finish and finish.complete and finish.supported and not opening_only
    if Shop.blind_finishing then
      status=complete and (finish.all_worlds_clear and 'sampled_safe' or finish.selected.clearing_samples==0 and 'sampled_deficit' or 'unresolved') or 'unresolved'
    end
    local result={status=status,supported=true,target=target,hands=hands,discards=state.discards_left,
      samples=4,opening_min=low,opening_max=high,opening_mean=total/4,clearing_samples=clears,
      opening_hands=clone(value.opening_hands),opening_sizes=clone(value.opening_sizes),opening_scores=clone(value.opening_scores),capacity_proxy=capacity,
      ordering=clone(value.ordering),
      requires_discards=status=='sampled_deficit' and state.discards_left>0 or nil,
      reason=status=='sampled_safe' and 'All four composition samples have a supported opening clear with at least 25% margin; this is not a win probability.' or
        status=='sampled_deficit' and 'Even the strongest sampled opening repeated across the available hands falls short; a better draw or timely scoring upgrade is needed. This pressure proxy is not a global score bound.' or
        'The bounded opening samples do not establish a finishing plan; future hands and discards remain unresolved.'}
    if Shop.blind_finishing then
      result.finishing=clone(finish)
      result.finishing_basis=complete and 'complete_paired_observed_policies' or 'opening_only_fallback'
      result.reason=complete and (status=='sampled_safe' and 'One fixed observed policy clears all four composition worlds with actual cumulative scoring and resources; this is not a guarantee or measured win probability.' or
        status=='sampled_deficit' and 'Both complete bounded policies fall short in all four composition worlds after actual plays and the admitted discard; broader policies and unseen draws remain unresolved.' or
        'The complete observed policy comparison clears only some composition worlds; the next blind remains at risk.') or
        'Whole-blind finishing is unresolved: '..tostring(finish and finish.reason or 'The paired endpoints could not both complete.')
      if complete then
        result.cumulative_mean=finish.selected.mean_score;result.shortfall_mean=finish.selected.mean_shortfall
        result.finishing_clearing_samples=finish.selected.clearing_samples
        result.requires_discards=finish.selected.max_discards_used>0
        local key=Shop.liquidity and Shop.liquidity.observation_key(snapshot)
        result.resource_plan={complete=true,supported=true,known_mechanics=true,cost_model='actual_actions',samples=4,
          all_worlds_clear=finish.all_worlds_clear,observation_key=key,target=target,
          discards_available=state.discards_left,max_discards_used=finish.selected.max_discards_used,
          policy=finish.selected.name,finishing_guarantee=false}
      end
    end
    return result
  end
  function context:readiness(snapshot)
    if self.truncated then return nil end
    local plan=prepare(snapshot,temporal_for(snapshot,snapshot))
    if not plan then return {status='unsupported',supported=false,reason=self.unavailable_reason} end
    if cache[plan.key]==nil and self.evaluations+plan.cost>self.max_evaluations then
      self.truncated=true;return unavailable('The shared scoring budget cannot complete readiness samples.')
    end
    local value=profile(plan)
    return value and readiness(plan,value,snapshot) or {status='unsupported',supported=false,reason=self.unavailable_reason}
  end
  function context:compare(before,after)
    if self.truncated then return nil end
    if unsupported_history(before,after) then return unavailable('Hit the Road growth needs a real discard path.') end
    local temporal=temporal_for(before,after)
    local left,right=prepare(before,temporal),prepare(after,temporal)
    if not left or not right then return nil end
    if left.equivalent_key==right.equivalent_key then right=left end
    if cache[left.key]==false or cache[right.key]==false then return nil end
    local needed=cache[left.key]==nil and left.cost or 0
    if right.key~=left.key and cache[right.key]==nil then needed=needed+right.cost end
    if self.evaluations+needed>self.max_evaluations then
      self.truncated=true; return unavailable('The shared scoring budget cannot complete this paired comparison.')
    end
    local a,b=profile(left),profile(right)
    if not a or not b then return nil end
    local af,bf=finishing(left,a),finishing(right,b)
    if self.truncated then return nil end
    local complete_finishing=af and bf and af.complete and bf.complete and af.supported and bf.supported
    self.metrics.paired_comparisons=self.metrics.paired_comparisons+1
    if a.mean<=0 then return unavailable('A zero-score baseline cannot support a useful relative estimate.') end
    local ratio=b.mean/a.mean
    local left_state,right_state=a.state or left.state,b.state or right.state
    local left_target,right_target=num(left_state.blind.chips),num(right_state.blind.chips)
    local capacity_ratio=ratio
    if left_target>0 and right_target>0 then capacity_ratio=ratio*left_target/right_target end
    if complete_finishing and af.selected.mean_progress>0 then
      capacity_ratio=bf.selected.mean_progress/af.selected.mean_progress
    end
    local adjustment=math.max(-35,math.min(35,36*math.log(math.max(capacity_ratio,0.000001))/math.log(2)-14))
    if left.key==right.key then adjustment=0 end
    self.metrics.coefficient_opportunities=self.metrics.coefficient_opportunities or {}
    local opportunities=self.metrics.coefficient_opportunities
    if math.abs(adjustment)>0.000001 then
      opportunities.shop_scoring_gain_weight=(opportunities.shop_scoring_gain_weight or 0)+1
    end
    local before_readiness,after_readiness=readiness(left,a,before,not complete_finishing),readiness(right,b,after,not complete_finishing)
    local ordering_cost
    if complete_finishing then
      local prior,following=num(af.selected.mean_setup_actions),num(bf.selected.mean_setup_actions)
      ordering_cost={before_actions=prior,after_actions=following,extra_actions=following-prior,
        adjustment=-2*(following-prior),seconds_per_action=1.5,calibrated=false,
        scope='One actual projected Joker reorder costs the existing two action-utility units; no free restoration.'}
    end
    local work_cost
    if Shop.policy_weights then adjustment=adjustment*Shop.policy_weights.get('shop_scoring_gain_weight') end
    if ordering_cost then adjustment=adjustment+ordering_cost.adjustment end
    if Shop.work_cost and left.key~=right.key then
      work_cost=Shop.work_cost.compare(left_state,right_state,before_readiness,after_readiness,
        Shop.policy_weights and Shop.policy_weights.get('computation_cost_scale') or 1)
      if work_cost then adjustment=adjustment+work_cost.adjustment end
      if work_cost and math.abs(work_cost.extra_seconds)>0.000001 then
        opportunities.computation_cost_scale=(opportunities.computation_cost_scale or 0)+1
      end
    end
    local low=math.huge
    for i=1,4 do low=math.min(low,b.scores[i]-a.scores[i]) end
    local order_note=(left.has_copies or right.has_copies) and
      string.format('copy-target order shortlist (%d/%d layouts)',#left.orders,#right.orders) or 'sensible Joker order'
    if left.shortlisted or right.shortlisted then order_note=order_note..', not exhaustive' end
    if left.startup or right.startup then order_note=order_note..'; one fixed pre-blind setup matching executable preparation across all samples, including retained-row effects' end
    local scope='Opening-hand scoring estimate'
    if temporal then
      scope=string.format('Opening/conditional last-hand estimate (late weight %.0f%%',temporal.weight*100)
      if temporal.repeat_hand then scope=scope..'; repeat '..temporal.repeat_hand..' assumed' end
      if temporal.no_discards then scope=scope..'; no discards assumed' end
      scope=scope..'; no future growth or survival probability)'
    end
    if complete_finishing then scope=scope..'; complete paired whole-blind policy progress informs build value' end
    local blind_note=upcoming and ('upcoming '..upcoming.name) or ('neutral blind; '..boss_fallback)
    if upcoming and right_target>0 then blind_note=blind_note..string.format('; target %.0f',right_target) end
    if upcoming and ({bl_house=true,bl_wheel=true,bl_mark=true,bl_fish=true,bl_serpent=true})[upcoming.key] then
      blind_note=blind_note..'; opening capacity only, later concealed draws are not projected'
    end
    local clears_before,clears_after=0,0
    for i=1,4 do
      if left_target>0 and a.scores[i]>=left_target then clears_before=clears_before+1 end
      if right_target>0 and b.scores[i]>=right_target then clears_after=clears_after+1 end
    end
    return {adjustment=adjustment,ratio=ratio,capacity_ratio=capacity_ratio,before_mean=a.mean,after_mean=b.mean,samples=4,
      before_readiness=before_readiness,after_readiness=after_readiness,work_cost=work_cost,
      before_ordering=clone(a.ordering),after_ordering=clone(b.ordering),ordering_cost=ordering_cost,
      before_finishing=clone(af),after_finishing=clone(bf),complete_finishing=not not complete_finishing,
      before_startup=clone(a.startup),after_startup=clone(b.startup),
      blind=upcoming and upcoming.key or nil,boss_fallback=not upcoming and boss_fallback or nil,
      before_target=left_target>0 and left_target or nil,after_target=right_target>0 and right_target or nil,
      clearing_samples_before=left_target>0 and clears_before or nil,clearing_samples_after=right_target>0 and clears_after or nil,
      low_sample_delta=low,uncertain=a.uncertain or b.uncertain or temporal~=nil,
      temporal=clone(temporal),scenarios=#left.scenarios,
      before_orders=#left.orders,after_orders=#right.orders,order_shortlisted=left.shortlisted or right.shortlisted,
      reason=string.format('%s: %.0f -> %.0f chips across 4 paired deck samples, allowing %s; %s. Samples are not a blind-win probability.',scope,a.mean,b.mean,order_note,blind_note)}
  end
  return context
end
Shop.apply_blind=apply_blind
Shop.next_blind=next_blind
Shop.known_joker=function(key) return vanilla[key]==true end
return Shop
