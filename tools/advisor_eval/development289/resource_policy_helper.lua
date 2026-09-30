-- Development staging only. Integrate this factory's body inside consumables.lua
-- after the preceding runtime slice is frozen and installed.
return function(Consumables)
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
