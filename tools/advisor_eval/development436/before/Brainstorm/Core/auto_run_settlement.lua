-- Observe settlement of an auto-run shop transaction without advancing the
-- game's event queue. A callback can accept an action before its debit and
-- card transfer finish; retain the exact pre-dispatch objects until both do.
local M={}

local function finite(value)
  return type(value)=='number' and value==value and math.abs(value)<math.huge
end

local function contains_card(area,card)
  if type(area)~='table' or type(area.cards)~='table' then return false end
  for _,value in ipairs(area.cards) do if value==card then return true end end
  return false
end

local function shop_events_pending(g)
  local manager=g.E_MANAGER
  if manager==nil then return false end
  if type(manager)~='table' or type(manager.queues)~='table' or type(manager.queues.base)~='table' then
    return true,'Shop event completion is unavailable.'
  end
  local count=0
  for index,event in pairs(manager.queues.base) do
    count=count+1
    if count>2048 or type(index)~='number' or index<1 or index%1~=0 or type(event)~='table' then
      return true,'The shop event queue cannot be verified.'
    end
    if event.blocking~=false then return true,'Shop actions are still settling.' end
  end
  return false
end

function M.new()
  local pending
  local api={}

  function api:clear() pending=nil end

  function api:capture(g,action)
    if not action or (action.kind~='buy' and action.kind~='open') then return nil end
    local source=g[action.area];local card=source and source.cards and source.cards[action.index]
    if not card or not finite(card.cost) or card.cost<0 or not finite(g.GAME.dollars) then
      return false,'The exact purchase cost is unavailable.'
    end
    local key=card.config and (card.config.center_key or card.config.center and card.config.center.key)
    if action.area=='shop_vouchers' and type(key)~='string' then return false,'The voucher identity is unavailable.' end
    return {game=g.GAME,kind=action.kind,area=action.area,source=source,card=card,key=key,
      expected_dollars=g.GAME.dollars-card.cost}
  end

  function api:bind(receipt) pending=receipt end

  function api:release_on_rejection(accepted,execution_key)
    if accepted~=true and not execution_key then pending=nil end
  end

  function api:check(g)
    if pending or g.STATES and g.STATES.SHOP~=nil and g.STATE==g.STATES.SHOP then
      local queued,reason=shop_events_pending(g);if queued then return true,reason end
    end
    local receipt=pending
    if not receipt then return false end
    if g.GAME~=receipt.game then pending=nil;return false end
    if not finite(g.GAME.dollars) or g.GAME.dollars>receipt.expected_dollars then
      return true,'Waiting for the purchase cost to settle.'
    end
    if contains_card(receipt.source,receipt.card) then
      return true,'Waiting for the purchased card to leave the shop.'
    end
    if receipt.kind=='buy' and receipt.area=='shop_jokers' then
      local owned=contains_card(g.jokers,receipt.card) or contains_card(g.consumeables,receipt.card) or contains_card(g.deck,receipt.card)
      if not owned then return true,'Waiting for the purchased card to enter the owned inventory.' end
    elseif receipt.area=='shop_vouchers' then
      if not (g.GAME.used_vouchers or {})[receipt.key] then return true,'Waiting for the voucher to be redeemed.' end
    elseif receipt.kind=='open' then
      local pack=false
      for _,name in ipairs({'TAROT_PACK','PLANET_PACK','SPECTRAL_PACK','STANDARD_PACK','BUFFOON_PACK'}) do
        if g.STATES and g.STATES[name]~=nil and g.STATE==g.STATES[name] then pack=true;break end
      end
      if not pack or not g.pack_cards or not g.pack_cards.cards or #g.pack_cards.cards==0 then
        return true,'Waiting for the opened pack to become available.'
      end
    end
    pending=nil
    return false
  end

  return api
end

return M
