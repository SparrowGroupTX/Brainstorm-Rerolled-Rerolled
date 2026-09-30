-- Four declared first-draw generation composition worlds. Never source RNG,
-- a predicted front/seal, or exhaustive coverage of the 208 vanilla outcomes.
local M={}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function integer(v) return finite(v) and v%1==0 end
local function copy(v)
  if type(v)~='table' then return v end
  local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r
end
local suits={Clubs=true,Diamonds=true,Hearts=true,Spades=true}
local ranks={[11]='Jack',[12]='Queen',[13]='King',[14]='Ace'}
local by_value={};for rank=2,14 do by_value[ranks[rank] or tostring(rank)]=rank end
local function front(c)
  if type(c)~='table' or getmetatable(c) or not suits[c.suit] or c.mod or c.mod_id then return nil end
  -- Original Card:set_base derives id/nominal from the front's value. Raw
  -- G.P_CARDS definitions need not contain those constructed-card fields.
  local rank=by_value[c.value];if not rank then return nil end
  local nominal=rank==14 and 11 or math.min(rank,10)
  if c.id~=nil and c.id~=rank or c.nominal~=nil and c.nominal~=nominal then return nil end
  return {id=rank,suit=c.suit,value=c.value,nominal=nominal}
end
local function pool(rows)
  if type(rows)~='table' or getmetatable(rows) then return nil end
  local result,seen={},{}
  for _,v in pairs(rows) do
    local f=front(v);if not f then return nil end
    local key=f.suit..':'..f.id;if seen[key] then return nil end
    seen[key]=true;result[#result+1]=f
  end
  if #result~=52 then return nil end
  table.sort(result,function(a,b)return a.suit==b.suit and a.id<b.id or a.suit<b.suit end)
  return result
end
function M.capture(g)
  local needed=false
  for _,area in ipairs({g.jokers or {},g.shop_jokers or {},g.pack_cards or {}}) do
    for _,c in ipairs(area.cards or {}) do
      if ((c.config or {}).center or {}).key=='j_certificate' then needed=true end
    end
  end
  if not needed then return nil end
  local c=(g.P_CENTERS or {}).c_base
  local fronts=pool(g.P_CARDS)
  if not fronts or not c or c.key~='c_base' or c.set~='Default' or c.name~='Default Base' or
      c.mod or c.mod_id or type(c.config)~='table' or getmetatable(c.config) or next(c.config) then
    return {schema=1,status='unsupported',reason='Certificate requires the loaded unmodified52-front registry and ordinary base center.'}
  end
  return {schema=1,status='complete',kind='vanilla_certificate_fronts_v1',fronts=fronts,
    base_center={key='c_base',name='Default Base',set='Default',config={}},
    seals={'Purple','Gold','Blue','Red'},distribution_qualified=false}
end
function M.valid_pool(p)
  if type(p)~='table' or p.schema~=1 or p.status~='complete' or p.kind~='vanilla_certificate_fronts_v1' or
      type(p.base_center)~='table' or p.base_center.key~='c_base' or p.base_center.name~='Default Base' or
      p.base_center.set~='Default' or type(p.base_center.config)~='table' or next(p.base_center.config) or
      type(p.seals)~='table' or #p.seals~=4 or p.seals[1]~='Purple' or p.seals[2]~='Gold' or
      p.seals[3]~='Blue' or p.seals[4]~='Red' then return nil end
  return pool(p.fronts)
end
local function active(j)
  local a=j.ability or {}
  return not j.debuff and not a.perma_debuff and not (a.perishable and type(a.perish_tally)=='number' and a.perish_tally<=0)
end
function M.present(s)
  for _,j in ipairs(s.jokers or {}) do if j.key=='j_certificate' then return true end end
  return false
end
function M.project(state,p,sample)
  if not integer(sample) or sample<1 or sample>4 then return nil,'Certificate needs one of four declared composition worlds.' end
  local fronts=M.valid_pool(p)
  if not fronts then return nil,'Certificate front/base/seal metadata is unsupported.' end
  if type(state.hand)~='table' or type(state.deck)~='table' or type(state.playing_cards)~='table' or
      not integer(state.hand_size) or state.hand_size<1 or state.hand_size>8 or #state.hand>state.hand_size then
    return nil,'Certificate requires the completed ordinary draw before generation.'
  end
  local actor,count=nil,0
  for _,j in ipairs(state.jokers or {}) do
    local a=j.ability or {}
    if a.perishable and (not integer(a.perish_tally) or a.perish_tally<0) then return nil,'Certificate row has unknown perish timing.' end
    if j.key=='j_certificate' and active(j) then
      if a.name~='Certificate' or a.set~='Joker' or j.getting_sliced or j.face_down or
          not (type(j.id)=='string' and j.id~='' or finite(j.id)) then return nil,'Certificate identity is not a settled vanilla actor.' end
      actor=j;count=count+1
    end
    if active(j) and (j.key=='j_blueprint' or j.key=='j_brainstorm') then
      return nil,'Multiple/copied Certificate generation needs a joint ordered model.'
    end
    if active(j) and j.key=='j_perkeo' and (next(state.consumeables or {}) or (state.consumeable_buffer or 0)~=0) then
      return nil,'Nonempty shop-exit Perkeo copying is outside this Certificate family.'
    end
  end
  if count~=1 then return nil,'Exactly one active physical Certificate is admitted.' end
  local id='advisor_certificate:'..tostring(actor.id)
  local identities={}
  for _,card in ipairs(state.playing_cards) do
    if card.id==nil or identities[tostring(card.id)] or card.id==id then return nil,'Certificate needs a distinct complete public population.' end
    identities[tostring(card.id)]=true
  end
  local areas={}
  for _,area in ipairs({state.hand,state.deck}) do for _,card in ipairs(area) do
    if not identities[tostring(card.id)] or areas[tostring(card.id)] then return nil,'Initial draw does not match the public population.' end
    areas[tostring(card.id)]=true
  end end
  for known in pairs(identities) do if not areas[known] then return nil,'Initial Certificate world omits a population member.' end end
  local result=copy(state)
  -- Every comparison uses these same four fixed front ordinals and seal
  -- classes. Neither candidate scores nor the game seed chooses an outcome.
  local index=((sample-1)*17+5)%52+1
  local f=fronts[index];local base=copy(f);base.times_played=0
  local generated={id=id,key='c_base',name='Default Base',rank=f.id,nominal=f.nominal,suit=f.suit,base=base,
    seal=p.seals[sample],debuff=false,face_down=false,advisor_generated='certificate_composition_sample',
    ability={set='Default',name='Default Base',effect='',bonus=0,mult=0,h_mult=0,h_x_mult=0,h_dollars=0,
      p_dollars=0,t_mult=0,t_chips=0,x_mult=1,h_size=0,d_size=0,extra_value=0,type='',perma_bonus=0}}
  -- The source dispatches playing_card_joker_effects before queued creation.
  -- Its admitted Hologram callback is physical and never copied here.
  for _,j in ipairs(result.jokers) do if active(j) and j.key=='j_hologram' then
    local a=j.ability or {}
    if not finite(a.x_mult) or a.x_mult<1 or not finite(a.extra) or a.extra<0 or j.getting_sliced then
      return nil,'Certificate Hologram generation growth is unsupported.'
    end
    a.x_mult=a.x_mult+a.extra
  end end
  result.hand[#result.hand+1]=generated;result.playing_cards[#result.playing_cards+1]=generated
  local receipt={schema=1,kind='certificate_four_composition_worlds_v1',sample=sample,
    actor_id=actor.id,generated_id=id,front_index=index,front=copy(f),seal=generated.seal,
    fronts_in_registry=52,seal_classes=4,complete_outcome_coverage=false,distribution_qualified=false,
    stochastic=true,ordinary_draw_count=#state.hand,extra_held=1,hand_capacity=state.hand_size,
    population_before=#state.playing_cards,population_after=#result.playing_cards,
    existing_deck_order_unchanged=true,purple_discard_policy='Retain all Purple-sealed cards; no generated Tarot outcome is invented.'}
  result.certificate_generation=receipt
  return result,receipt
end
return M
