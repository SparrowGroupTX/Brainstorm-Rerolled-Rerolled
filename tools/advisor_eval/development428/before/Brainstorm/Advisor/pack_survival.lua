-- Current-blind priority for a complete free-Joker choice family. Root-owned
-- assets and separately supported rewards are protected; a forgone optional
-- generator is not an already owned card. No later-run dominance or odds claim.
local M={}
local allowed={j_yorick='Yorick',j_perkeo='Perkeo',j_card_sharp='Card Sharp',j_certificate='Certificate'}
local planets={['High Card']='c_pluto',Pair='c_mercury',['Two Pair']='c_uranus',['Three of a Kind']='c_venus',
  Straight='c_saturn',Flush='c_jupiter',['Full House']='c_earth',['Four of a Kind']='c_mars',
  ['Straight Flush']='c_neptune',['Five of a Kind']='c_planet_x',['Flush House']='c_ceres',['Flush Five']='c_eris'}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function integer(v,lo,hi)return finite(v)and v%1==0 and v>=lo and v<=hi end
local function encode(v,seen,budget)
  seen=seen or {};budget=budget or {left=20000};budget.left=budget.left-1
  assert(budget.left>=0,'Resource data limit')
  if type(v)~='table'then
    assert(v==nil or type(v)=='boolean'or type(v)=='string'and #v<1000000 or finite(v),'Unknown resource data')
    local s=type(v)..':'..tostring(v);return #s..':'..s
  end
  assert(not getmetatable(v)and not seen[v],'Cyclic resource data');seen[v]=true
  local keys,out={},{}
  for k in pairs(v)do assert(type(k)=='string'or finite(k),'Unknown resource key');keys[#keys+1]=k end
  table.sort(keys,function(a,b)return type(a)..tostring(a)<type(b)..tostring(b)end)
  for _,k in ipairs(keys)do out[#out+1]=encode(k,seen,budget)..encode(v[k],seen,budget)end
  seen[v]=nil;return '{'..table.concat(out)..'}'
end
local function equal(a,b)
  local remaining,seen_a,seen_b=20000,{},{}
  local function same(x,y)
    remaining=remaining-1;if remaining<0 or type(x)~=type(y)then return false end
    if type(x)~='table'then
      return x==y and (x==nil or type(x)=='boolean'or type(x)=='string'and #x<1000000 or finite(x))
    end
    if getmetatable(x)~=nil or getmetatable(y)~=nil or seen_a[x]or seen_b[y]then return false end
    seen_a[x],seen_b[y]=true,true
    for key,value in pairs(x)do
      remaining=remaining-1
      if remaining<0 or not (type(key)=='string'and #key<1000000 or finite(key))or
        y[key]==nil or not same(value,y[key])then return false end
    end
    for key in pairs(y)do if x[key]==nil then return false end end
    seen_a[x],seen_b[y]=nil,nil;return true
  end
  return same(a,b)
end
-- A complete forecast contains every policy plus the selected policy.
-- Do not serialize that aggregate under one receipt limit.
-- Compare every metadata field and every bounded child; nothing is omitted.
local function plain(v)return type(v)=='table'and getmetatable(v)==nil end
local function dense(v,count)
  if not plain(v)or #v~=count then return false end
  local seen=0
  for key in pairs(v)do
    if not integer(key,1,count)then return false end
    seen=seen+1;if seen>count then return false end
  end
  return seen==count
end
local function record_metadata(a,b,children)
  if not plain(a)or not plain(b)then return false end
  local function fields(record)
    local out,count={},0
    for key,value in pairs(record)do
      count=count+1;if count>20000 then return nil end
      if not children[key]then out[key]=value end
    end
    return out
  end
  local left,right=fields(a),fields(b)
  return left and right and equal(left,right)
end
local function policy_equal(a,b)
  if not record_metadata(a,b,{worlds=true})or not dense(a.worlds,4)or not dense(b.worlds,4)then return false end
  for i=1,4 do if not equal(a.worlds[i],b.worlds[i])then return false end end
  return true
end
local five_card_family='fixed_play_only_or_one_targeted_or_one_five_card_observed_discard_v1'
local ordinary_family='fixed_play_only_or_one_targeted_observed_discard_v1'
local function policy_count(f)
  if not plain(f)then return nil end
  if f.policy_family==nil then return 2 end
  if f.policy_family==five_card_family then return 3 end
end
local function forecast_equal(a,b)
  local count=policy_count(a)
  if not count or policy_count(b)~=count then return false end
  if not record_metadata(a,b,{policies=true,selected=true})or
    not dense(a.policies,count)or not dense(b.policies,count)or not policy_equal(a.selected,b.selected)then return false end
  for i=1,count do if not policy_equal(a.policies[i],b.policies[i])then return false end end
  return true
end
local function copy(v,seen)
  if type(v)~='table'then return v end
  seen=seen or {};assert(not getmetatable(v)and not seen[v],'Unsupported resource table');seen[v]=true
  local out={};for k,x in pairs(v)do out[k]=copy(x,seen)end;seen[v]=nil;return out
end
local function identity(v)
  return (type(v)=='string'and #v>0 and #v<=256 or finite(v))and type(v)..':'..tostring(v)or nil
end
local function cards(list)
  if type(list)~='table'or #list>120 then return nil end
  local out,history={},{}
  for _,card in ipairs(list)do
    if type(card)~='table'or card.unknown then return nil end
    local id=identity(card.id);if not id or out[id]then return nil end
    local ability,base=copy(card.ability or {}),copy(card.base or {})
    if ability.discarded~=nil and type(ability.discarded)~='boolean'then return nil end
    history[id]={played_this_ante=ability.played_this_ante,times_played=base.times_played,discarded=ability.discarded}
    ability.played_this_ante=nil;ability.discarded=nil;base.times_played=nil
    ability.perma_bonus=ability.perma_bonus or 0
    out[id]={key=card.key,rank=card.rank,suit=card.suit,nominal=card.nominal,enhancement=card.enhancement,
      seal=card.seal,edition=copy(card.edition),ability=ability,base=base,vampired=card.vampired}
  end
  return out,history
end
-- Receipt only: no score/evaluation calls and no alteration of a trajectory.
-- Optional dependency keeps all old finishing consumers unchanged.
function M.capture(state)
  local ok,result=pcall(function()
    local population,history=cards(state.playing_cards);if not population then return nil end
    local r={schema=1,kind='pack_endpoint_resources_v1',population=population,play_history=history,hands=copy(state.hands),
      jokers=copy(state.jokers),inventory=copy(state.consumeables),consumable_limit=state.consumable_limit,
      consumeable_buffer=state.consumeable_buffer or 0,dollars=state.dollars,bankrupt_at=state.bankrupt_at,
      hands_left=state.hands_left,discards_left=state.discards_left,modifiers=copy(state.modifiers),
      interest_amount=state.interest_amount,interest_cap=state.interest_cap,blind=copy(state.blind),
      vouchers=copy(state.vouchers),used_vouchers=copy(state.used_vouchers)}
    encode(r);return r
  end)
  return ok and result or nil
end
local function ordinary(j)
  local a=j and j.ability
  return j and allowed[j.key]and type(a)=='table'and a.set=='Joker'and a.name==allowed[j.key]and
    not j.unknown and not j.face_down and not j.debuff and not j.pinned and not a.pinned and
    not a.eternal and not a.rental and not a.perishable and j.edition==nil
end
local function qualified_row(jokers,inventory)
  if type(jokers)~='table'or #jokers>5 or type(inventory)~='table'then return nil end
  for _,c in ipairs(inventory)do if c.edition or c.unknown or c.face_down then return nil end end
  local seen,keys={},{}
  for _,j in ipairs(jokers)do
    local id=identity(j.id);if not ordinary(j)or not id or seen[id]or keys[j.key]then return nil end
    seen[id]=j;keys[j.key]=true
    if j.key=='j_perkeo'and next(inventory)then return nil end
    if j.key=='j_yorick'then
      local a=j.ability;local e=a.extra
      if type(e)~='table'or not integer(e.discards,1,100)or not finite(e.xmult)or e.xmult<=0 or
        not integer(a.yorick_discards,1,e.discards)or not finite(a.x_mult)or a.x_mult<1 then return nil end
    end
  end
  return seen
end
local function hand_state(hands)
  if type(hands)~='table'then return nil end
  local out,leaders,max_played={},{},-1
  for name,h in pairs(hands)do
    if type(name)~='string'or type(h)~='table'or not integer(h.level,1,100000)or
      not finite(h.chips)or h.chips<0 or not finite(h.mult)or h.mult<0 or not integer(h.played,0,1000000)then return nil end
    out[name]={level=h.level,chips=h.chips,mult=h.mult,played=h.played}
    if h.visible~=false then
      if h.played>max_played then max_played=h.played;leaders={}end
      if h.played==max_played then leaders[#leaders+1]=name end
    end
  end
  if next(out)==nil then return nil end
  table.sort(leaders);return out,table.concat(leaders,'|')
end
local function endpoint(r)
  if not plain(r)or r.schema~=1 or r.kind~='pack_endpoint_resources_v1'or
    type(r.population)~='table'or not next(r.population)or type(r.inventory)~='table'or
    not finite(r.dollars)or not finite(r.bankrupt_at)or not integer(r.consumable_limit,0,100)or
    r.consumeable_buffer~=0 or not integer(r.hands_left,0,4)or not integer(r.discards_left,0,100)or
    not finite(r.interest_amount)or r.interest_amount<0 or not finite(r.interest_cap)or r.interest_cap<0 then return nil end
  local count=0;for _ in pairs(r.population)do count=count+1;if count>120 then return nil end end
  if (r.used_vouchers or {}).v_observatory or (r.vouchers or {}).v_observatory then return nil end
  local mods=r.modifiers or {};local blind=r.blind or {}
  if mods.debuff_played_cards or (mods.minus_hand_size_per_X_dollar or 0)>0 or
    not blind.disabled and (blind.key=='bl_arm'or blind.key=='bl_hook')then return nil end
  local row=qualified_row(r.jokers,r.inventory);local hands,leaders=hand_state(r.hands)
  if not row or not hands then return nil end
  return {raw=r,jokers=row,hands=hands,leaders=leaders}
end
local function finish(world,end_state)
  if not world.clear then return false end
  local f=world.finish_details;local r=end_state.raw
  if type(f)~='table'or f.schema~=1 or f.kind~='held_finish_components_v1'or f.final_blind or
    f.held_supported~=true or f.blue_supported~=true or f.cash_after_play~=r.dollars or
    f.consumable_limit~=r.consumable_limit or f.consumeable_buffer~=0 or
    not equal(f.inventory_before,f.inventory_after_play)or not equal(f.inventory_after_play,r.inventory)then return nil end
  local last=world.actions[#world.actions]
  if not last or last.kind~='play'or last.hand~=f.planet_hand or planets[f.planet_hand]~=f.planet_key then return nil end
  for _,key in ipairs({'held_dollars','hand_dollars','discard_dollars','blue_planets','slots_before_blue','slots_after_blue'})do
    if not finite(f[key])or f[key]<0 then return nil end
  end
  if not integer(f.blue_planets,0,100)or not integer(f.slots_before_blue,0,100)or
    f.slots_before_blue~=math.max(0,r.consumable_limit-#r.inventory)or f.slots_after_blue~=f.slots_before_blue-f.blue_planets or
    f.blue_planets>0 and (type(f.planet_hand)~='string'or type(f.planet_key)~='string')then return nil end
  local mods=r.modifiers or {};local per_hand=mods.money_per_hand==nil and 1 or mods.money_per_hand
  local per_discard=mods.money_per_discard==nil and 0 or mods.money_per_discard
  if not finite(per_hand)or per_hand<0 or not finite(per_discard)or per_discard<0 or
    f.hand_dollars~=(mods.no_extra_hand_money and 0 or r.hands_left*per_hand)or
    f.discard_dollars~=r.discards_left*per_discard then return nil end
  -- All admitted Joker identities have no end-of-round cashout payment or
  -- rental/expiry callback. This qualification does not alter the raw receipt.
  local held_cash=r.dollars+f.held_dollars
  local interest=not mods.no_interest and held_cash>=5 and r.interest_amount*math.min(math.floor(held_cash/5),r.interest_cap/5)or 0
  local cash=held_cash+interest+f.hand_dollars+f.discard_dollars
  if not finite(cash)then return nil end
  return {cash=cash,blue=f.blue_planets,planet=f.planet_key,hand=f.planet_hand,
    slots_before=f.slots_before_blue,slots_after=f.slots_after_blue,inventory=r.inventory,raw=f}
end
local function outcome(w,target,index)
  if not plain(w)or w.composition_world_id~=index or type(w.clear)~='boolean'or type(w.actions)~='table'then return nil end
  if not equal(w,w)then return nil end
  for _,key in ipairs({'score','shortfall','progress','dollars_after','population_loss'})do if not finite(w[key])then return nil end end
  for _,key in ipairs({'hands_used','discards_used','setup_actions','action_count'})do if not integer(w[key],0,100)then return nil end end
  if w.score<0 or w.shortfall~=math.max(0,target-w.score)or w.progress~=math.min(1,w.score/target)or
    w.clear~=(w.score>=target)or w.action_count~=#w.actions or w.population_loss<0 then return nil end
  local e=endpoint(w.endpoint_resources)
  if not e or e.raw.dollars~=w.dollars_after then return nil end
  local rewards=finish(w,e);if w.clear and not rewards then return nil end
  return {world=w,endpoint=e,finish=rewards}
end
-- The expanded family must retain the exact producer action contract. This
-- validates receipts; it never supplies legality or selects a hidden outcome.
local function fixed_policy_actions(policy,world)
  if not dense(world.actions,world.action_count)or #world.actions>6 then return false end
  local plays,discards,setups,discarded=0,0,0,{}
  for _,action in ipairs(world.actions)do
    if not plain(action)then return false end
    if action.kind=='play'then plays=plays+1
    elseif action.kind=='reorder_jokers'then setups=setups+1
    elseif action.kind=='discard'then
      discards=discards+1
      local indices=action.indices;local count=type(indices)=='table'and #indices or 0
      if not integer(count,1,5)or not dense(indices,count)or
        policy=='one_five_card_targeted_discard'and count~=5 then return false end
      local seen={}
      for _,index in ipairs(indices)do if not integer(index,1,9)or seen[index]then return false end;seen[index]=true end
      if not dense(action.card_ids,count)then return false end
      local ids={}
      for _,card_id in ipairs(action.card_ids)do
        local key=identity(card_id);if not key or ids[key]then return false end
        ids[key]=true;discarded[key]=true
      end
    else return false end
  end
  return plays==world.hands_used and discards==world.discards_used and setups==world.setup_actions and
    plays<=4 and discards<=1 and setups<=1 and (policy~='play_only'or discards==0)and discarded
end
-- The scorer marks each retained physical discard with ability.discarded=true.
-- Keep that event history explicit, requiring precisely the recorded identity
-- transitions; it is neither a destroyed card nor permission to omit metadata.
local function discarded_history(raw,root_history,discarded)
  if not plain(raw.play_history)or not plain(root_history)then return false end
  for id in pairs(discarded)do if not raw.population[id]then return false end end
  for id in pairs(raw.population)do
    local history=raw.play_history[id];if not plain(history)then return false end
    local expected=root_history[id]and root_history[id].discarded
    if discarded[id]then expected=true end
    if history.discarded~=expected then return false end
  end
  for id in pairs(raw.play_history)do if not raw.population[id]then return false end end
  return true
end
local function policies(f,target,root_history)
  local count=policy_count(f)
  if not plain(f)or not f.complete or not f.supported or not f.known_mechanics or
    f.samples~=4 or not count or not dense(f.policies,count)or not plain(f.selected)then return nil end
  local names,results,selected={},{},nil
  for _,p in ipairs(f.policies)do
    if not plain(p)or (p.name~='play_only'and p.name~='one_targeted_discard'and not (count==3 and p.name=='one_five_card_targeted_discard'))or names[p.name]or not dense(p.worlds,4)then return nil end
    names[p.name]=true;local r={name=p.name,worlds={},clears=0,raw=p}
    for i,w in ipairs(p.worlds)do
      local discarded=fixed_policy_actions(p.name,w);if not discarded then return nil end
      r.worlds[i]=outcome(w,target,i);if not r.worlds[i]or not discarded_history(r.worlds[i].endpoint.raw,root_history,discarded)then return nil end
      r.clears=r.clears+(w.clear and 1 or 0)
    end
    if r.clears~=p.clearing_samples then return nil end
    results[#results+1]=r
    if p.name==f.selected.name then if not policy_equal(p,f.selected)then return nil end;selected=r end
  end
  return selected and results,selected
end
local function protected(a,b,root)
  for id,card in pairs(root.population)do
    if not a.raw.population[id]or not equal(a.raw.population[id],card)or
      b.raw.population[id]and not equal(a.raw.population[id],b.raw.population[id])then return false end
  end
  if not equal(a.raw.inventory,root.inventory)or not equal(a.raw.inventory,b.raw.inventory)then return false end
  for hand,h in pairs(root.hands)do
    local av,bv=a.hands[hand],b.hands[hand]
    if not av or not bv or av.level<h.level or av.chips<h.chips or av.mult<h.mult or
      av.level<bv.level or av.chips<bv.chips or av.mult<bv.mult or bv.played>0 and av.played==0 then return false end
  end
  for id,j in pairs(root.jokers)do
    local av,bv=a.jokers[id],b.jokers[id]
    if not av or not bv or av.key~=j.key or bv.key~=j.key then return false end
    if j.key=='j_yorick'then
      local x,y,z=av.ability,bv.ability,j.ability
      if not equal(x.extra,z.extra)or not equal(y.extra,z.extra)then return false end
      local xd,yd,zd=copy(x),copy(y),copy(z)
      for _,v in ipairs({xd,yd,zd})do v.x_mult=nil;v.yorick_discards=nil end
      if not equal(xd,zd)or not equal(yd,zd)then return false end
      local growth=(x.x_mult-y.x_mult)/z.extra.xmult*z.extra.discards+y.yorick_discards-x.yorick_discards
      local owned=(x.x_mult-z.x_mult)/z.extra.xmult*z.extra.discards+z.yorick_discards-x.yorick_discards
      if growth<0 or owned<0 then return false end
    elseif not equal(av.ability,j.ability)or not equal(bv.ability,j.ability)then return false end
  end
  return true
end
local function choose(snapshot,candidates,incumbent,diagnostics)
  local d={complete=false,scope='Current-blind survival priority over one complete free-Joker family; forgone optional generation and later-run value remain unproven.'}
  local function no(reason)d.reason=reason;return nil,d end
  local ctx=snapshot and snapshot._shop_scoring
  if not snapshot or snapshot.phase~='pack'or snapshot.pack_type~='BUFFOON_PACK'or snapshot.pack_choices~=1 or
    not ctx or ctx.truncated or not diagnostics or diagnostics.incomplete then return no('Complete free-pack evidence is required.')end
  local offers=snapshot.pack_cards or {};local target=(snapshot.next_blind or {}).chips
  if #offers<2 or #offers>4 or type(candidates)~='table'or #candidates~=#offers or not incumbent or
    not integer(snapshot.joker_limit,1,5)or #(snapshot.jokers or {})>=snapshot.joker_limit or
    not finite(target)or target<=0 or not finite(snapshot.dollars)then return no('Every direct offer and an ordinary free Joker slot are required.')end
  local root_population,root_history=cards(snapshot.playing_cards);local root_row=qualified_row(snapshot.jokers,snapshot.consumeables)
  local root_hands=hand_state(snapshot.hands)
  if not root_population or not root_row or not root_hands then return no('Owned assets or Joker cashout/growth scope are unsupported.')end
  local root={population=root_population,jokers=root_row,hands=root_hands,inventory=snapshot.consumeables}
  local rows,seen,family,baseline,prior={},{},nil,nil,nil
  for _,c in ipairs(candidates)do
    if not ordinary(c.card)or offers[c.index]~=c.card or seen[c.index]or not finite(c.score)or c.score<=0 or c.hand_order then
      return no('Every offer must have a supported direct ordinary choice.')end
    seen[c.index]=true;local e=c.scoring_evidence;local worlds=e and e.common_worlds
    if not e or e.incomplete or e.complete_finishing~=true or e.samples~=4 or e.temporal or
      e.uncertain and e.generation_only_uncertainty~=true or e.before_target~=target or e.after_target~=target or
      not worlds or worlds.schema~=1 or worlds.kind~='shop_four_common_worlds_v1'or worlds.samples~=4 or
      type(worlds.family_key)~='string'or worlds.family_key==''or not equal(worlds.world_ids,{1,2,3,4})then
      return no('Complete explicitly shared worlds and supported uncertainty are required for every offer.')end
    if not equal(worlds,family or worlds)or not forecast_equal(e.before_finishing,baseline or e.before_finishing)then
      return no('The offers do not share one complete bounded root family.')
    end
    local count=policy_count(e.before_finishing)
    if not count or policy_count(e.after_finishing)~=count or
      worlds.continuation_family~=(count==3 and five_card_family or ordinary_family)then
      return no('Every endpoint must contain the same explicitly declared fixed policy family.')
    end
    family=worlds;baseline=e.before_finishing
    local _,before=policies(e.before_finishing,target,root_history);local after,selected=policies(e.after_finishing,target,root_history)
    if not before or not after then return no('A trajectory lacks complete endpoint assets, cashout or reward receipts.')end
    rows[#rows+1]={candidate=c,policies=after};if c==incumbent then prior=selected end
  end
  if not prior then return no('The heuristic incumbent is absent from the full family.')end
  d.complete=true;d.incumbent_index=incumbent.index;d.before_clearing_samples=prior.clears
  if prior.clears==4 then return no('The incumbent already clears all worlds; retain its development preference.')end
  local best
  for _,entry in ipairs(rows)do for _,policy in ipairs(entry.policies)do if policy.clears==4 then
    local acceptable=true
    for i=1,4 do
      local a,b=policy.worlds[i],prior.worlds[i];local aw,bw=a.world,b.world
      local received=a.endpoint.jokers[identity(entry.candidate.card.id)]
      acceptable=acceptable and #a.endpoint.raw.jokers==#snapshot.jokers+1 and received and received.key==entry.candidate.card.key
      -- Failed incumbent worlds have no realized cashout/Blue award. Preserve
      -- root-owned development there; compare successful endpoints separately.
      local protected_b=bw.clear and b.endpoint or {raw={population=root.population,inventory=root.inventory},hands=root.hands,jokers=root.jokers}
      acceptable=acceptable and protected(a.endpoint,protected_b,root)and aw.progress>=bw.progress and
        aw.hands_used<=bw.hands_used and aw.discards_used<=bw.discards_used and aw.action_count<=bw.action_count and
        aw.population_loss<=bw.population_loss and aw.dollars_after>=(bw.clear and bw.dollars_after or snapshot.dollars)and
        aw.dollars_after>=a.endpoint.raw.bankrupt_at
      if bw.clear then
        local af,bf=a.finish,b.finish
        acceptable=acceptable and af.cash>=bf.cash and af.blue>=bf.blue and
          (bf.blue==0 or af.hand==bf.hand and af.planet==bf.planet)and
          af.slots_before>=bf.slots_before and af.slots_after>=bf.slots_after and
          a.endpoint.leaders==b.endpoint.leaders
      end
    end
    if acceptable and (not best or entry.candidate.score>best.candidate.score or
      entry.candidate.score==best.candidate.score and entry.candidate.index<best.candidate.index)then
      best={candidate=entry.candidate,policy=policy}
    end
  end end end
  if not best then return no('No fixed all-clearing policy preserves the admitted owned assets and separate successful-world rewards.')end
  d.selected_index=best.candidate.index;d.selected_policy=best.policy.name;d.after_clearing_samples=4
  d.forgone_generation_unpriced=true
  d.future_play_history_unpriced=true
  d.reason='Prefer a free Joker with one complete policy clearing all four common worlds while preserving owned assets and separate supported rewards. Optional generation from the unchosen Joker and later-run value remain unproven.'
  return best.candidate,d
end
function M.choose(...)
  local ok,selected,receipt=pcall(choose,...)
  if ok then return selected,receipt end
  return nil,{complete=false,reason='Malformed or unsupported resource evidence; retain the original pack preference.'}
end
return M
