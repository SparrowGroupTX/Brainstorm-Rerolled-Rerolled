-- Public visual observations only. No hidden Card identity, RNG, save, or
-- pre-shuffle object identity enters the retained inventory or slot worlds.
local M={MAX_EVENTS=256,MAX_WORLD_LIMIT=720}
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function copy(v,seen,depth)
  if type(v)~='table' then return (type(v)=='string' or type(v)=='boolean' or finite(v)) and v or nil end
  seen,depth=seen or {},depth or 0
  if seen[v] or depth>16 then return nil end
  seen[v]=true;local out={}
  for k,x in pairs(v)do if type(k)=='string' or type(k)=='number' then out[k]=copy(x,seen,depth+1)end end
  seen[v]=nil;return out
end
local function same_color(a,b)
  if type(a)~='table' or type(b)~='table' then return false end
  for i=1,4 do if a[i]~=b[i] then return false end end
  return true
end
-- Card:update leaves the flip direction set after changing the visible sprite.
-- Only public presentation fields qualify completion; missing or mismatched
-- fields keep a directed flip unsettled. Legacy cards without a flip remain valid.
local function settled_flip(card)
  if not card.flipping then return card.pinch==nil or type(card.pinch)=='table' and not card.pinch.x end
  local target=card.flipping=='f2b' and 'back' or card.flipping=='b2f' and 'front'
  return target and card.facing==target and card.sprite_facing==target and
    type(card.pinch)=='table' and card.pinch.x==false or false
end
local function hidden(card)return card.facing=='back' or card.sprite_facing=='back' or not settled_flip(card) or
  card.face_down==true or card.identity_redacted==true end
local function visible(card)
  return not hidden(card) and settled_flip(card) and
    (card.sprite_facing==nil or card.sprite_facing=='front') and
    (not card.states or card.states.visible~=false)
end
local fields={'key','name','ability','edition','debuff','rarity','blueprint_compat','pinned','sell_cost','cost','base_cost'}
local forbidden={id=true,ID=true,sort_id=true,unique_val=true,position=true,slot=true,T=true,VT=true,
  card=true,object=true,reference=true,config=true,children=true}
local function strip(v)
  if type(v)~='table'then return v end
  for k,x in pairs(v)do if forbidden[k]then v[k]=nil else strip(x)end end
  return v
end
local function encode(v)
  if type(v)~='table'then return type(v)..':'..tostring(v)end
  local keys,out={},{};for k in pairs(v)do keys[#keys+1]=k end
  table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
  for _,k in ipairs(keys)do out[#out+1]=encode(k)..'='..encode(v[k])end
  return '{'..table.concat(out,';')..'}'
end
function M.sanitize(card)
  local out={};for _,key in ipairs(fields)do out[key]=copy(card[key])end
  return strip(out)
end
function M.rendered_number(text,color,colors,localize)
  if type(text)~='string' or #text>256 or type(localize)~='function' then return nil end
  local candidates,seen={},{}
  for token in text:gmatch('[%+%-]?%d[%d%.,eE%+%-]*')do
    for _,raw in ipairs({token,(token:gsub(',',''))})do
      local n=tonumber(raw)
      if finite(n) and n~=0 and not seen[n] then seen[n]=true;candidates[#candidates+1]=n end
    end
  end
  local found
  for _,entry in ipairs({{'chips','a_chips','CHIPS'},{'mult','a_mult','MULT'},{'x_mult','a_xmult','XMULT'}})do
    if same_color(color,(colors or {})[entry[3]]) or entry[1]=='x_mult' and same_color(color,(colors or {}).MULT) then
      for _,n in ipairs(candidates)do
        local ok,rendered=pcall(localize,{type='variable',key=entry[2],vars={n}})
        if ok and rendered==text then
          if found and (found.channel~=entry[1] or found.amount~=n) then return nil end
          found={channel=entry[1],amount=n}
        end
      end
    end
  end
  return found
end
function M.new(deps)
  deps=deps or {};local T={epoch=0,event_count=0,events={},status='No concealed Joker row.'}
  local game_token,inventory,context,drag,play,pending_action,shuffle_pending
  local function emit(event)if deps.emit then pcall(deps.emit,copy(event))end end
  function T:reset(reason)
    self.epoch=self.epoch+1;self.belief=nil;self.events={};self.event_count=0
    inventory,context,drag,play,pending_action,shuffle_pending=nil,nil,nil,nil,nil,nil
    self.status=reason or 'Public Joker memory reset.'
  end
  local function row(g)return g and g.jokers and g.jokers.cards or {}end
  local function same_run(g)
    local token=g and g.GAME
    if token~=game_token then T:reset('New or restored run.');game_token=token end
    return token~=nil
  end
  local function round_context(g)
    local game=g and g.GAME or {};return tostring(game.round)..':'..tostring((game.round_resets or {}).ante)
  end
  local function concealed(g)for _,card in ipairs(row(g))do if hidden(card)then return true end end;return false end
  local function fail(reason)
    if T.belief then T.belief.supported=false;T.belief.reason=reason end
    T.status=reason;play=nil;pending_action=nil;drag=nil
  end
  function T:invalidate(reason)fail(reason or 'Public Joker observation could not be verified.')end
  function T:remember(g)
    if not same_run(g) then return false end
    local cards=row(g)
    if #cards==0 or not deps.card then return false end
    for _,card in ipairs(cards)do if not visible(card)then return false end end
    local out={}
    for i,card in ipairs(cards)do out[i]=M.sanitize(deps.card(card))end
    table.sort(out,function(a,b)return encode(a)<encode(b)end)
    inventory=out;context=round_context(g)
    return true
  end
  function T:before_hide(g)
    if not same_run(g)then return end
    if not concealed(g)then self:remember(g)end
    if not self.belief then self:shuffle(g,'Jokers concealed.')end
  end
  function T:shuffle(g,reason)
    if not same_run(g)then return end
    local previous=self.belief
    if previous and previous.inventory and previous.supported==true and context==round_context(g)then
      inventory=copy(previous.inventory) -- public-derived growth survives; physical positions do not
    end
    self.epoch=self.epoch+1;self.events={};self.event_count=0;drag=nil;play=nil;pending_action=nil;shuffle_pending=true
    if not inventory or #inventory~=#row(g) or context~=round_context(g) then
      self.belief={schema=1,epoch=self.epoch,supported=false,reason='No complete pre-concealment public inventory.'}
    elseif not deps.belief or type(deps.belief.start)~='function' then
      self.belief={schema=1,epoch=self.epoch,supported=false,reason='Public Joker belief engine unavailable.'}
    else
      local b,why=deps.belief.start(copy(inventory),self.epoch,{max_worlds=M.MAX_WORLD_LIMIT,public_before_shuffle=true})
      self.belief=b or {schema=1,epoch=self.epoch,supported=false,reason=why}
      if b and previous and previous.state_valid==false and deps.belief.invalidate_values then
        self.belief=deps.belief.invalidate_values(b,previous.value_gap)
      end
      if previous and previous.supported==false then
        self.belief.supported=false;self.belief.reason='Prior public model gap persists after shuffle.'
      end
    end
    self.status=reason or 'Shuffled row: previous position information discarded.'
  end
  function T:begin_action(kind,g)
    if not same_run(g)then return end
    if not self.belief then self:remember(g);return end
    if kind=='play' or kind=='discard' then
      local current=(g.GAME or {}).current_round or {};local selected=g.hand and g.hand.highlighted or {}
      if pending_action then
        local b=deps.belief and deps.belief.invalidate_values and deps.belief.invalidate_values(self.belief,'Prior public action was not observed complete.')
        if b then self.belief=b end
      end
      pending_action={kind=kind,epoch=self.epoch,context=round_context(g),hands_played=current.hands_played,
        hands_left=current.hands_left,discards_left=current.discards_left,discards_used=current.discards_used,
        discarded_count=kind=='discard' and #selected or nil}
      if kind=='discard' and deps.card and deps.belief and deps.belief.needs_discarded_jacks and
          deps.belief.needs_discarded_jacks(self.belief) then
        local cards,public={},true
        for i,card in ipairs(selected) do
          if not visible(card) then public=false;break end
          cards[i]=deps.card(card)
        end
        if public then pending_action.discarded_jacks=deps.belief.discarded_jacks(cards) end
      end
      play=kind=='play' and pending_action or nil
    else
      play=nil
      -- A hidden sale/use/discard can mutate or replace a retained Joker. Only
      -- the matcher may model such a public transition; stale payloads never
      -- acquire certified current ability values through live reads.
      if kind~='discard' and kind~='cash_out' and kind~='leave_shop' and kind~='select_blind' then
        fail('Unmodelled action can change concealed Joker inventory.')
      end
    end
  end
  function T:public_reorder(order)
    if not self.belief or not deps.belief or type(deps.belief.reorder)~='function' then return false end
    local result=deps.belief.reorder(self.belief,order,self.epoch)
    if type(result)=='table' then self.belief=result end
    emit({kind='joker_public_reorder',epoch=self.epoch,order=copy(order)})
    return type(result)=='table'
  end
  function T:authorize_reorder(g,proof)
    self:sync(g)
    local b=self.belief
    if not b or not deps.belief or not deps.belief.validate(b) or b.state_valid~=true or shuffle_pending or drag or
      not g.STATES or g.STATE~=g.STATES.SELECTING_HAND or not g.STATE_COMPLETE or
      type(proof)~='table' or proof.schema~=1 or proof.complete~=true or proof.complete_order_comparison~=true or
      proof.all_world_clear~=true or proof.bound_kind~='public_joker_world_floor' or
      proof.epoch~=b.epoch or proof.revision~=b.revision or proof.worlds~=#b.worlds or #row(g)~=#b.inventory then return false end
    local last
    for _,card in ipairs(row(g))do
      local x=(card.VT or {}).x
      if not hidden(card) or not settled_flip(card) or not finite(x) or last and x<=last or card.states and card.states.visible==false then return false end
      last=x
    end
    return true
  end
  -- This receipt exists only across one requested physical rearrangement. Its
  -- references are current visible slots, not identities from before hiding.
  -- Never serialize it, retain it in a snapshot, or derive an inventory key.
  function T:prepare_reorder(g,order)
    if not same_run(g) or not self.belief or self.belief.supported~=true or drag then return nil end
    local cards=row(g)
    if type(order)~='table' or #order~=#cards then return nil end
    local seen,before={},{}
    for i,index in ipairs(order)do
      if type(index)~='number' or index%1~=0 or not cards[index] or seen[index]then return nil end
      seen[index]=true;before[i]=cards[i]
    end
    for key in pairs(order)do if type(key)~='number' or key%1~=0 or key<1 or key>#order then return nil end end
    return {epoch=self.epoch,game=g.GAME,before=before,order=copy(order)}
  end
  function T:finish_reorder(g,receipt,accepted,may_have_started)
    if not receipt then
      if self.belief and (accepted or may_have_started~=false)then fail('Public Joker reorder had no complete movement receipt.')end
      return false
    end
    local cards=row(g)
    if not same_run(g) or receipt.game~=g.GAME or receipt.epoch~=self.epoch or #cards~=#receipt.before then
      fail('Public Joker reorder crossed a run, shuffle, or population change.');return false
    end
    local matches,unchanged=true,true
    for i,oldslot in ipairs(receipt.order)do
      matches=matches and cards[i]==receipt.before[oldslot]
      unchanged=unchanged and cards[i]==receipt.before[i]
    end
    if accepted and matches then return self:public_reorder(receipt.order)end
    if not accepted and may_have_started==false and unchanged then return false end
    fail('Public Joker reorder outcome was partial or ambiguous.');return false
  end
  -- Keep a reference only for the duration of an observed drag. It identifies
  -- the physically dragged back, never an inventory member or pre-hide Card.
  function T:drag_start(g,target)
    if not self.belief or self.belief.supported~=true or drag then return end
    for i,card in ipairs(row(g))do if card==target then
      if shuffle_pending or (g.jokers or {}).shuffle_amt and g.jokers.shuffle_amt~=0 then fail('Drag began before the public shuffle settled.');return end
      local last
      for _,item in ipairs(row(g))do
        local x=(item.VT or {}).x
        if not finite(x) or last and x<=last or not settled_flip(item) or item.states and item.states.visible==false then
          fail('Drag origin did not have a settled visible slot order.');return
        end
        last=x
      end
      local before={};for k,item in ipairs(row(g))do before[k]=item end
      drag={target=target,from=i,count=#row(g),epoch=self.epoch,before=before};return
    end end
  end
  function T:drag_active()return drag~=nil end
  function T:drag_finish(g)
    if not drag then return end
    local prior=drag;drag=nil
    if prior.epoch~=self.epoch or prior.count~=#row(g)then fail('Joker row changed during public movement.');return end
    local destination
    for i,card in ipairs(row(g))do if card==prior.target then destination=i end end
    if not destination then fail('Dragged Joker no longer occupies its public row.');return end
    local order={};for i=1,prior.count do order[i]=i end
    table.insert(order,destination,table.remove(order,prior.from))
    for i,slot in ipairs(order)do if prior.before[slot]~=row(g)[i]then fail('Movement was not one completely observed drag.');return end end
    self:public_reorder(order)
  end
  function T:sync(g)
    if not same_run(g)then return end
    local cards=row(g)
    if self.belief and context~=round_context(g)then self:reset('Round changed; prior concealed belief expired.')end
    if self.belief and inventory and #cards~=#inventory then fail('Concealed Joker population changed.');return end
    if concealed(g)then
      if not self.belief then self:before_hide(g)end
      local busy=(g.jokers or {}).shuffle_amt and g.jokers.shuffle_amt~=0
      for _,card in ipairs(cards)do if not settled_flip(card) then busy=true end end
      if g.STATE_COMPLETE and not busy then shuffle_pending=nil end
    elseif #cards>0 then
      local all_visible=true;for _,card in ipairs(cards)do if not visible(card)then all_visible=false end end
      if all_visible and self.belief then self:reset('Joker fronts revealed; concealed belief expired.')end
    end
    local settled=g.STATE_COMPLETE and (g.GAME.STOP_USE or 0)==0 and #(g.play and g.play.cards or {})==0 and
      not (g.CONTROLLER or {}).locked and not ((g.CONTROLLER or {}).dragging or {}).target
    for key,locked in pairs((g.CONTROLLER or {}).locks or {})do if locked and key~='frame' and key~='frame_set'then settled=false end end
    if pending_action and settled and g.STATES and (g.STATE==g.STATES.SELECTING_HAND or g.STATE==g.STATES.ROUND_EVAL or g.STATE==g.STATES.GAME_OVER) then
      local current=g.GAME.current_round or {}
      local pending=pending_action
      local completed=pending.kind=='play' and current.hands_played==((pending.hands_played or -2)+1) and current.hands_left==((pending.hands_left or -2)-1) or
        pending.kind=='discard' and current.discards_used==((pending.discards_used or -2)+1) and current.discards_left==((pending.discards_left or -2)-1)
      if completed and context==pending.context and self.epoch==pending.epoch then
        pending.observed_complete=true
        local b=deps.belief and deps.belief.advance_public and deps.belief.advance_public(self.belief,pending)
        if b then self.belief=b else fail('Completed public action has no qualified ability transition.')end
        emit({kind='joker_public_action_complete',epoch=self.epoch,action=pending.kind,discarded_count=pending.discarded_count,
          discarded_jacks=pending.discarded_jacks})
        pending_action=nil;play=nil
      end
    end
  end
  local function visual_slot(g,major)
    if not major or shuffle_pending or drag or (g.jokers or {}).shuffle_amt and g.jokers.shuffle_amt~=0 then return nil end
    local last,slot
    for i,card in ipairs(row(g))do
      local visual=card.VT;local x=visual and visual.x
      if not finite(x) or last and x<=last or not settled_flip(card) or card.states and card.states.visible==false then return nil end
      last=x;if card==major then slot=i end
    end
    return slot
  end
  function T:display(g,args,kind)
    if not same_run(g) or not self.belief or self.belief.supported==false or not play then return end
    if g.STATE_COMPLETE and g.STATES and g.STATE==g.STATES.SELECTING_HAND and #(g.play and g.play.cards or {})==0 then return end
    args=args or {};local slot=visual_slot(g,args.major)
    if not slot then return end
    if self.event_count>=M.MAX_EVENTS then fail('Public Joker observation bound reached.');return end
    local numeric=kind~='juice' and M.rendered_number(args.text,args.backdrop_colour,g.C,deps.localize)
    local event={epoch=self.epoch,slot=slot,type=numeric and 'rendered_status' or kind=='juice' and 'juice' or 'unclassified_status',
      phase='play',text=type(args.text)=='string' and args.text:sub(1,256) or nil,color=copy(args.backdrop_colour),
      location={x=(args.major.VT or {}).x,y=(args.major.VT or {}).y,offset=copy(args.offset)},
      qualified_render=numeric~=nil,channel=numeric and numeric.channel,amount=numeric and numeric.amount}
    self.event_count=self.event_count+1;event.sequence=self.event_count
    self.events[#self.events+1]=event;emit({kind='joker_public_observation',observation=event})
    if numeric and deps.belief and type(deps.belief.observe)=='function' then
      local result=deps.belief.observe(self.belief,event,{render=function(channel,amount)
        return deps.localize({type='variable',key=({chips='a_chips',mult='a_mult',x_mult='a_xmult'})[channel],vars={amount}})
      end})
      if type(result)=='table'then self.belief=result end
    end
  end
  function T:capture(g,s)
    self:sync(g)
    if not s then return s end
    if concealed(g)then
      -- Do not even inspect hidden captured fields: replace the whole entry.
      for i,card in ipairs(row(g))do if hidden(card)then s.jokers[i]={face_down=true,identity_redacted=true,public_slot=i}end end
      s.public_joker_belief=copy(self.belief or {schema=1,supported=false,reason='No public Joker belief.'})
      s.public_joker_observations=copy(self.events)
    end
    return s
  end
  function T:public_held(g)
    self:sync(g)
    if not concealed(g)then return nil end
    local b=self.belief
    if not b or b.supported~=true or b.complete~=true or b.state_valid~=true or not b.inventory or #b.inventory~=#row(g)then
      return {schema=1,status='unavailable',scope='concealed_public_inventory_unavailable'}
    end
    local keys={};for i,joker in ipairs(b.inventory)do keys[i]=joker.key end;table.sort(keys)
    return {schema=1,status='complete',keys=keys,scope='remembered_public_unordered_inventory',epoch=b.epoch,revision=b.revision}
  end
  return T
end
M.copy=copy
return M
