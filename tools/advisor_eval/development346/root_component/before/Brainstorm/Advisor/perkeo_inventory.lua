-- Homogeneous Planet copying and complete bounded pre-hand use families.
-- Detached transitions only. No RNG, source callbacks, player files or odds.
local M={}
local planets={c_pluto={'Pluto','High Card'},c_mercury={'Mercury','Pair'},c_uranus={'Uranus','Two Pair'},
  c_venus={'Venus','Three of a Kind'},c_saturn={'Saturn','Straight'},c_jupiter={'Jupiter','Flush'},
  c_earth={'Earth','Full House'},c_mars={'Mars','Four of a Kind'},c_neptune={'Neptune','Straight Flush'},
  c_planet_x={'Planet X','Five of a Kind'},c_ceres={'Ceres','Flush House'},c_eris={'Eris','Flush Five'}}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function integer(v) return finite(v) and v>=0 and v%1==0 end
local function array(v)
  if type(v)~='table' or getmetatable(v) then return false end
  local n=0;for k in pairs(v) do if not integer(k) or k<1 or k>#v then return false end;n=n+1 end
  return n==#v
end
local function copy(v) if type(v)~='table' then return v end;local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out end
local function encode(v)
  if type(v)~='table' then return type(v)..':'..tostring(v) end
  local keys,out={},{};for k in pairs(v) do keys[#keys+1]=k end
  table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
  for _,k in ipairs(keys) do out[#out+1]=encode(k)..'='..encode(v[k]) end
  return '{'..table.concat(out,';')..'}'
end
local function plain(v,seen,budget)
  budget=budget or {remaining=4096};budget.remaining=budget.remaining-1
  if budget.remaining<0 then return false end
  if type(v)=='number' then return finite(v) end
  if type(v)~='table' then return v==nil or type(v)=='string' or type(v)=='boolean' end
  if getmetatable(v) then return false end
  seen=seen or {};if seen[v] then return false end;seen[v]=true
  for k,x in pairs(v) do
    if (type(k)~='string' and not integer(k)) or not plain(x,seen,budget) then seen[v]=nil;return false end
  end
  seen[v]=nil;return true
end
local function negative(card)
  if card.edition==nil then return false end
  local e=card.edition
  if type(e)~='table' or e.negative~=true or e.type~='negative' then return nil end
  for k in pairs(e) do if k~='negative' and k~='type' then return nil end end
  return true
end
local empty_base={nominal=0,suit_nominal=0,face_nominal=0,times_played=0}
local parameter_keys={discover=true,bypass_discovery_center=true,bypass_discovery_ui=true,bypass_lock=true}
local function safe_params(params)
  if type(params)~='table' or not plain(params) then return false end
  for key,value in pairs(params) do if not parameter_keys[key] or type(value)~='boolean' then return false end end
  return true
end
local function source_key(card)
  local p=card.copy_source
  if type(p)~='table' or p.schema~=1 or p.supported~=true or p.scope~='ordinary_planet_source' then return nil end
  local d=planets[card.key];local a=card.ability
  if not d or card.name~=d[1] or type(a)~='table' or a.name~=d[1] or a.set~='Planet' or
      not plain(card) or not finite(card.base_cost) or card.base_cost~=p.center_cost or
      not finite(card.cost) or card.cost<0 or not finite(card.sell_cost) or card.sell_cost<0 or
      not finite(a.extra_value) or a.extra_value<0 or a.h_size~=0 or a.d_size~=0 or
      card.debuff~=false or card.face_down~=false or card.pinned~=false or card.seal~=nil or negative(card)==nil or
      p.center_key~=card.key or p.center_name~=d[1] or p.center_set~='Planet' or p.center_consumeable~=true or
      encode(p.center_config)~=encode({hand_type=d[2]}) or encode(a.consumeable)~=encode(p.center_config) or
      encode(p.ability)~=encode(a) or encode(p.base)~=encode(card.base) or encode(card.base)~=encode(empty_base) or
      p.front_empty~=true or p.params_safe~=true or not safe_params(p.params) then return nil end
  local source=copy(card)
  for _,key in ipairs({'id','edition','cost','sell_cost','projected_identity'}) do source[key]=nil end
  return encode(source)
end

-- This callback only reads already public Card metadata. Registry identity,
-- parameters and constructor inputs are observed explicitly rather than guessed
-- from the Planet's display name. No Card method is called.
function M.capture(card,registry)
  local center=card and card.config and card.config.center
  if type(center)~='table' or not planets[center.key] then return nil end
  local function no(reason) return {schema=1,supported=false,reason=reason} end
  local definition=planets[center.key]
  local params=card.params
  if type(registry)~='table' or registry[center.key]~=center or getmetatable(center) or
      center.set~='Planet' or center.name~=definition[1] or center.consumeable~=true or
      not finite(center.cost) or center.cost<0 or card.base_cost~=center.cost or
      not plain(center.config) or encode(center.config)~=encode({hand_type=definition[2]}) then
    return no('The loaded Planet center and copy constructor input are not qualified.')
  end
  if not safe_params(params) then return no('Copy parameters contain an unsupported field or physical playing-card identity.') end
  if type(card.config.card)~='table' or next(card.config.card)~=nil or getmetatable(card.config.card) or
      type(card.base)~='table' or not plain(card.base) then return no('An exact empty nonplaying front is required.') end
  if encode(card.base)~=encode(empty_base) then return no('The consumable base differs from the exact empty-front constructor result.') end
  local a=card.ability
  if not plain(a) or type(a)~='table' or a.name~=definition[1] or a.set~='Planet' or
      a.effect~=center.effect or a.h_size~=0 or a.d_size~=0 or a.type~='' or
      a.order~=center.order or encode(a.consumeable)~=encode(center.config) or
      a.extra~=nil or not finite(a.extra_value) or a.extra_value<0 or
      card.playing_card~=nil or card.facing~='front' or card.debuff~=false or card.pinned==true or card.seal~=nil then
    return no('The full copied Planet ability or physical state is unsupported.')
  end
  for _,key in ipairs({'mult','h_mult','h_x_mult','h_dollars','p_dollars','t_mult','t_chips','x_mult','bonus','perma_bonus','hands_played_at_create'}) do
    if not finite(a[key]) then return no('A source-initialized Planet field is absent or nonfinite.') end
  end
  return {schema=1,supported=true,scope='ordinary_planet_source',center_key=center.key,
    center_name=center.name,center_set=center.set,center_cost=center.cost,center_consumeable=true,
    center_config=copy(center.config),ability=copy(a),base=copy(card.base),params=copy(params),
    params_safe=true,front_empty=true,
    scope_note='Observed vanilla constructor inputs, not qualification of arbitrary live mod callbacks.'}
end

local function row_sources(s)
  local row=s.jokers or {};local ids={}
  if not array(row) or #row>8 or s.ordering_safe==false or s.jokers_shuffling then return nil,'The physical copying row is not settled and bounded.' end
  for _,j in ipairs(row) do
    local a=j.ability or {}
    if not (type(j.id)=='string' and j.id~='' or finite(j.id)) or ids[tostring(j.id)] or
        j.face_down or j.unknown or j.getting_sliced or a.perishable and not integer(a.perish_tally) then
      return nil,'The whole copying row needs visible unique identities and exact perish timing.'
    end
    ids[tostring(j.id)]=true
    if j.key=='j_perkeo' and (a.name~='Perkeo' or a.set~='Joker' or j.blueprint_compat~=true) then
      return nil,'The Perkeo identity is unsupported.'
    end
  end
  local function active(j) local a=j.ability or {};return not j.debuff and not a.perma_debuff and not (a.perishable and a.perish_tally<=0) end
  local function resolve(i,seen)
    local j=row[i];if not j or seen[i] or not active(j) then return nil end;seen[i]=true
    local target=j.key=='j_blueprint' and i+1 or j.key=='j_brainstorm' and 1 or nil
    if target then
      if not row[target] or row[target].blueprint_compat~=true then return nil end
      return resolve(target,seen)
    end
    return j.key=='j_perkeo' and i or nil
  end
  local result={}
  for i,j in ipairs(row) do local target=resolve(i,{})
    if target then result[#result+1]={source_id=j.id,perkeo_id=row[target].id} end
  end
  if #result>4 then return nil,'More than four immediate copy events exceed the declared family.' end
  return result
end

function M.project(snapshot)
  if type(snapshot)~='table' or snapshot.phase~='shop' or not array(snapshot.consumeables) or
      #snapshot.consumeables<1 or #snapshot.consumeables>8 or snapshot.consumeable_buffer~=0 or
      not integer(snapshot.consumable_limit) or #snapshot.consumeables>snapshot.consumable_limit then
    return nil,'A settled nonempty inventory of at most eight cards is required.'
  end
  local sources,why=row_sources(snapshot);if not sources then return nil,why end
  if #snapshot.consumeables+#sources>8 then return nil,'The complete post-copy inventory exceeds eight cards.' end
  local forecast=snapshot.shop_forecast or {}
  if not finite(forecast.inflation) or forecast.inflation<0 or not finite(forecast.discount_percent) or
      forecast.discount_percent<0 or forecast.discount_percent>100 or not finite(snapshot.dollars) then
    return nil,'Exact copy pricing and cash metadata are required.'
  end
  local class,ids=nil,{}
  for _,card in ipairs(snapshot.consumeables) do
    local current=source_key(card)
    if not current or class and class~=current or not (type(card.id)=='string' and card.id~='' or finite(card.id)) or ids[tostring(card.id)] then
      return nil,'Every owned card must belong to the same fully qualified Planet copy class.'
    end
    class=current;ids[tostring(card.id)]=true
  end
  local state=copy(snapshot);local prototype=copy(snapshot.consumeables[1]);local a=prototype.ability
  prototype.edition={negative=true,type='negative'}
  prototype.cost=math.max(1,math.floor((prototype.base_cost+forecast.inflation+5+0.5)*(100-forecast.discount_percent)/100))
  for _,j in ipairs(state.jokers or {}) do if j.key=='j_astronomer' and not j.debuff then prototype.cost=0 end end
  if a.rental then prototype.cost=1 end
  prototype.sell_cost=math.max(1,math.floor(prototype.cost/2))+a.extra_value
  -- Recopying a newly produced Negative has exactly the same relevant result.
  -- This closure check covers the pool growing between queued callbacks.
  if source_key(prototype)~=class then return nil,'Generated copies do not remain in the same source class.' end
  local generated={}
  for event,source in ipairs(sources) do
    local card=copy(prototype);local id='perkeo-projection:'..event
    if ids[id] then return nil,'A projected identity collides with an existing physical identity.' end
    card.id=id;card.projected_identity=true;ids[id]=true
    state.consumeables[#state.consumeables+1]=card
    state.consumable_limit=state.consumable_limit+1
    generated[#generated+1]={id=id,source=copy(source),edition=copy(card.edition),cost=card.cost,sell_cost=card.sell_cost}
  end
  return state,{schema=1,supported=true,scope='homogeneous_planet_copy_exit',copy_events=#sources,
    source_class=class,physical_sources=copy(sources),generated=generated,
    inventory_before=copy(snapshot.consumeables),inventory_after=copy(state.consumeables),
    capacity_before=snapshot.consumable_limit,capacity_after=state.consumable_limit,
    cash_before=snapshot.dollars,cash_after=state.dollars,random_identity_irrelevant_by_closed_class=true,
    requires_complete_first_hand_use_family=true,
    identity_scope='Generated identities are distinct projection symbols, never predicted live sort IDs.'}
end

function M.planet_family(snapshot,consumables)
  if not consumables or not consumables.apply or not array(snapshot.consumeables) or #snapshot.consumeables>8 or
      not integer(snapshot.consumable_limit) or snapshot.consumable_limit<#snapshot.consumeables or snapshot.consumeable_buffer~=0 then
    return nil,'The complete owned Planet transition dependency is unavailable.'
  end
  local ordinary,negatives,class,ids={},{},nil,{}
  for _,card in ipairs(snapshot.consumeables) do
    local current=source_key(card)
    if not current or class and class~=current or not (type(card.id)=='string' and card.id~='' or finite(card.id)) or
        ids[tostring(card.id)] then return nil,'The whole use family must remain homogeneous with qualified unique physical identities.' end
    ids[tostring(card.id)]=true
    class=current
    local target=negative(card) and negatives or ordinary;target[#target+1]=card.id
  end
  local count=(#ordinary+1)*(#negatives+1)
  if count>25 then return nil,'The complete hold/use family exceeds twenty-five members.' end
  local result={}
  for o=0,#ordinary do for n=0,#negatives do
    local state=copy(snapshot);local actions={};local selected={}
    for i=1,o do selected[#selected+1]=ordinary[i] end
    for i=1,n do selected[#selected+1]=negatives[i] end
    for _,id in ipairs(selected) do
      local index
      for i,c in ipairs(state.consumeables) do if c.id==id then index=i end end
      if not index then return nil,'An exact retained identity was lost during Planet use.' end
      local after,why=consumables.apply(state,index,{})
      if not after then return nil,why end
      if after.dollars~=state.dollars or encode(after.playing_cards)~=encode(state.playing_cards) then
        return nil,'Planet use unexpectedly changed cash or physical population.'
      end
      actions[#actions+1]={kind='use',area='consumeables',index=index,id=id,key=state.consumeables[index].key}
      state=after
    end
    result[#result+1]={state=state,actions=actions,ordinary_used=o,negative_used=n,
      key='ordinary:'..o..';negative:'..n,action_count=#actions,free_slots=state.consumable_limit-#state.consumeables}
  end end
  return result,{schema=1,complete=true,scope='all_homogeneous_planet_ordinary_negative_use_counts',
    members=#result,ordinary=#ordinary,negative=#negatives,
    equivalence='Members within each edition class have identical source fields except physical identity. All use-count pairs include hold; ordinary/Negative slot effects remain distinct.',
    future_copy_value_claimed=false,score_evaluations=0}
end

-- Complete all declared fixed pre-hand alternatives before selecting anything.
-- The callback validates the existing exact shop/Bell receipt and returns its
-- minimum after score and same-world delta. By default one after policy must
-- preserve ALL references. A Gold endpoint may explicitly protect its own use
-- family while trading surplus score from other Joker endpoints for progress.
-- Every reference is still compared; per-world policy switching is forbidden.
-- This exports comparison evidence only, never an immediately executable buy.
function M.compare_families(before,after,context,validate,target,options)
  local d={complete=false,comparisons=0,policies={},scope='one_fixed_after_policy_against_all_complete_before_use_alternatives'}
  local function no(reason) d.reason=reason;return nil,d end
  if type(before)~='table' or type(after)~='table' or #before<1 or #before>75 or #after<1 or #after>25 or
      not context or not context.compare or not finite(context.evaluations) or not finite(context.max_evaluations) or
      context.max_evaluations>50000 or context.truncated or type(validate)~='function' or not finite(target) or target<=0 then
    return no('Complete bounded families and their existing shared shop scorer are required.')
  end
  local protected,indices={},{}
  if options~=nil then
    if type(options)~='table' or getmetatable(options) then return no('Protected reference options must be a plain table.') end
    for key in pairs(options) do if key~='protected_reference_indices' then return no('An unknown reference option is unsupported.') end end
  end
  local declared=options and options.protected_reference_indices
  if declared~=nil then
    if not array(declared) or #declared<1 or #declared>#before then return no('Protected references must be a nonempty dense index list.') end
    for _,index in ipairs(declared) do
      if not integer(index) or index<1 or index>#before or protected[index] then return no('Every protected reference index must be unique and present.') end
      protected[index]=true;indices[#indices+1]=index
    end
  else
    for index=1,#before do protected[index]=true;indices[#indices+1]=index end
  end
  d.protected_reference_indices=copy(indices)
  local start=context.evaluations;local selected
  for index,following in ipairs(after) do
    if type(following.state)~='table' or not integer(following.action_count) or not integer(following.free_slots) then return no('A declared after policy is malformed.') end
    local low,delta,protected_delta=math.huge,math.huge,math.huge;local representative;local compared={}
    for prior_index,prior in ipairs(before) do
      if type(prior.state)~='table' then return no('A declared before policy is malformed.') end
      if context.truncated or context.evaluations>=context.max_evaluations then return no('The aggregate shop allowance cannot finish every alternative.') end
      local evidence=context:compare(prior.state,following.state);d.comparisons=d.comparisons+1
      if context.truncated or context.evaluations>context.max_evaluations then return no('The shared scorer did not finish the complete family within its allowance.') end
      local value,change=validate(evidence,target)
      if not finite(value) or not finite(change) then return no('An admitted use alternative lacks complete nonrandom same-world evidence.') end
      if low~=math.huge and low~=value then return no('The same fixed after policy produced inconsistent paired floors.') end
      low,delta=value,math.min(delta,change);representative=representative or evidence
      if protected[prior_index] then protected_delta=math.min(protected_delta,change) end
      compared[#compared+1]={before_index=prior_index,before_key=prior.key,minimum_after=value,minimum_delta=change,
        protected=not not protected[prior_index]}
    end
    local policy={after_index=index,key=following.key,actions=copy(following.actions),action_count=following.action_count,free_slots=following.free_slots,
      minimum_after=low,minimum_delta=delta,minimum_protected_delta=protected_delta,
      eligible=low>=1.25*target and protected_delta>=0,comparisons=compared}
    d.policies[#d.policies+1]=policy
    if not selected or policy.eligible and not selected.policy.eligible or policy.eligible==selected.policy.eligible and
        (low>selected.policy.minimum_after or low==selected.policy.minimum_after and
          (policy.action_count<selected.policy.action_count or policy.action_count==selected.policy.action_count and
            (policy.free_slots>selected.policy.free_slots or policy.free_slots==selected.policy.free_slots and
              tostring(policy.key)<tostring(selected.policy.key)))) then
      selected={policy=policy,variant=following,evidence=representative}
    end
  end
  d.complete=true;d.score_evaluations=context.evaluations-start
  d.selected=copy(selected.policy);d.next_action_is_projected=true
  return {variant=selected.variant,evidence=selected.evidence,low=selected.policy.minimum_after,
    delta=selected.policy.minimum_delta,protected_delta=selected.policy.minimum_protected_delta,
    eligible=selected.policy.eligible,comparison=d},d
end

M.source_key=source_key
return M
