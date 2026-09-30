-- Execute one explicitly accepted, current recommendation through vanilla actions.
-- The caller owns snapshot freshness and its pending-click latch. Success means
-- the source callback accepted the action; its normal events may still be running.
-- Failure returns false, reason, may_have_started. Only false in the third slot
-- permits retrying the same recommendation after a safe preflight rejection.
local M = {}

local function reject(reason) error(reason, 0) end
local function require_value(value, reason) if not value then reject(reason) end; return value end
local function copy_list(values) local out={}; for i,v in ipairs(values or {}) do out[i]=v end; return out end
local function contains(values, card) for _,v in ipairs(values or {}) do if v==card then return true end end end
local function phase(g)
  for _,entry in ipairs({{'SELECTING_HAND','hand'},{'SHOP','shop'},{'BLIND_SELECT','blind'},
    {'ROUND_EVAL','round'},{'TAROT_PACK','pack'},{'PLANET_PACK','pack'},
    {'SPECTRAL_PACK','pack'},{'STANDARD_PACK','pack'},{'BUFFOON_PACK','pack'}}) do
    if g.STATES[entry[1]] and g.STATE==g.STATES[entry[1]] then return entry[2] end
  end
end
local function indices(values, cards, minimum, maximum)
  require_value(type(values)=='table', 'This action has no card indices.')
  local n,seen,out=#values,{},{}
  require_value(n>=minimum and n<=maximum, 'The number of selected cards is invalid.')
  for key in pairs(values) do
    require_value(type(key)=='number' and key%1==0 and key>=1 and key<=n, 'Card indices must be a dense list.')
  end
  for i,index in ipairs(values) do
    require_value(type(index)=='number' and index%1==0 and cards[index] and not seen[index],
      'A card index is missing, repeated, or no longer present.')
    seen[index]=true;out[i]=cards[index]
  end
  return out
end
local function ui(box, id)
  if box and type(box.get_UIE_by_ID)=='function' then return box:get_UIE_by_ID(id) end
end
local function enabled(element, callback)
  if not element or not element.config or element.config.button~=callback or element.disable_button then return false end
  local seen={}
  while element and not seen[element] do
    if element.states and element.states.visible==false then return false end
    seen[element]=true;element=element.parent
  end
  return true
end
local function visible_owner(element)
  local seen={}
  for _=1,64 do
    if element==nil then return true end
    if type(element)~='table' or seen[element] or element.REMOVED or element.removed or
      element.states and element.states.visible==false then return false end
    seen[element]=true;element=element.parent
  end
  return false
end
local function action_button(g,kind)
  if kind=='leave_shop' then
    local box=g.shop;local e=ui(box,'next_round_button')
    -- Preserve the existing shop subtree lookup, including nested UIBoxes.
    if not box or not visible_owner(box) or not e or not visible_owner(e) then
      return nil,'Waiting for the shop exit button.'
    end
    return e
  end
  local anchor=g.round_eval
  if not anchor or not visible_owner(anchor) then return nil,'Waiting for the round results panel.' end
  local found,seen_boxes,seen_elements=nil,{},{}
  local function add(box)
    if not box or seen_boxes[box] then return end
    seen_boxes[box]=true
    if not visible_owner(box) then return end
    local e=ui(box,'cash_out_button')
    if not e or e.UIBox~=box or not visible_owner(e) or seen_elements[e] then return end
    seen_elements[e]=true
    require_value(not found,'More than one current Cash Out button is present.')
    found=e
  end
  -- Retain compatible direct children, but vanilla creates a separate UIBox
  -- after the payout animation. Its config.major is the current round_eval.
  add(anchor)
  local boxes=g.I and g.I.UIBOX
  if boxes~=nil then
    require_value(type(boxes)=='table','The UI registry is unavailable.')
    local count=0
    for _,box in pairs(boxes) do
      count=count+1;require_value(count<=512,'The UI registry exceeds the Cash Out lookup bound.')
      if type(box)=='table' and box.config and box.config.major==anchor then add(box) end
    end
  end
  return found,not found and 'Cash Out is not ready: waiting for its button to appear.' or nil
end
-- Pure readiness for existing phase-transition buttons only. It performs no
-- callback, selection, latch or UI mutation. All other legality stays in execute.
function M.button_ready(g,action)
  if type(action)~='table' then return false,'No current action is available.' end
  local kind=action.kind
  if kind~='cash_out' and kind~='leave_shop' then return true end
  local ok,ready,reason=pcall(function()
    require_value(type(g)=='table' and type(g.STATES)=='table' and type(g.FUNCS)=='table','The game is not ready.')
    require_value(phase(g)==(kind=='cash_out' and 'round' or 'shop'),'The recommendation belongs to a different game phase.')
    local e,why=action_button(g,kind)
    if not e then return false,why end
    local callback=kind=='cash_out' and 'cash_out' or 'toggle_shop'
    if not enabled(e,callback) or type(g.FUNCS[callback])~='function' then
      return false,kind=='cash_out' and 'Waiting for the Cash Out button to be ready.' or 'Waiting for the shop exit button to be ready.'
    end
    return true
  end)
  if not ok then return false,tostring(ready) end
  return ready,reason
end
local function selection(hand, wanted, allow_forced)
  require_value(hand and hand.cards and hand.highlighted and type(hand.unhighlight_all)=='function' and
    type(hand.add_to_highlighted)=='function', 'The hand cannot be selected right now.')
  local expected=copy_list(wanted)
  for _,card in ipairs(hand.cards) do
    if card.ability and card.ability.forced_selection and not contains(expected,card) then
      require_value(allow_forced, 'The recommendation omits a card forced by the blind.')
      expected[#expected+1]=card
    end
  end
  require_value(#expected<=(hand.config.highlighted_limit or 5), 'The selection exceeds the hand highlight limit.')
  hand:unhighlight_all()
  for _,card in ipairs(expected) do if not contains(hand.highlighted,card) then hand:add_to_highlighted(card,true) end end
  require_value(#hand.highlighted==#expected, 'The game did not accept the complete selection.')
  for _,card in ipairs(expected) do require_value(contains(hand.highlighted,card), 'The game selected different cards.') end
end
local function check_callback(g, check, callback, element)
  require_value(type(g.FUNCS[callback])=='function', 'The game action '..callback..' is unavailable.')
  if check then
    require_value(type(g.FUNCS[check])=='function', 'The game legality check '..check..' is unavailable.')
    element.config.button=nil
    g.FUNCS[check](element)
    require_value(element.config.button==callback, 'The game currently disallows this action ('..check..').')
  end
end

function M.execute(g, action)
  local old_selection, selection_changed, callback_started, reorder_started, changed_area, old_order
  local ok,reason=pcall(function()
    require_value(type(g)=='table' and type(g.GAME)=='table' and type(g.STATES)=='table' and type(g.FUNCS)=='table',
      'The game is not ready.')
    require_value(type(action)=='table' and type(action.kind)=='string', 'There is no executable recommendation.')
    require_value(not g.OVERLAY_MENU and not (g.SETTINGS and g.SETTINGS.paused), 'Close the menu before executing a move.')
    require_value(not (g.CONTROLLER and g.CONTROLLER.locked) and (g.GAME.STOP_USE or 0)<=0,
      'Wait for the current game action to finish.')
    for _,locked in pairs(g.CONTROLLER and g.CONTROLLER.locks or {}) do
      require_value(not locked, 'Wait for the current game action to finish.')
    end
    require_value(not (g.play and g.play.cards and #g.play.cards>0), 'Wait for the played cards to resolve.')
    local current=require_value(phase(g), 'This game phase has no executable recommendation.')
    local kind=action.kind
    local e={config={}}
    local check,callback,targets,allow_forced
    local function at(...)
      for _,wanted in ipairs({...}) do if current==wanted then return end end
      reject('The recommendation belongs to a different game phase.')
    end
    local function get_card(...)
      local valid=false
      for _,name in ipairs({...}) do if action.area==name then valid=true end end
      require_value(valid, 'This action names an invalid card area.')
      local area=require_value(g[action.area], 'The recommended card area is no longer present.')
      local cards=indices({action.index},area.cards or {},1,1)
      local card=cards[1]
      require_value(card.area==area and not card.removed and not card.getting_sliced, 'The recommended card is no longer available.')
      e.config.ref_table=card
      return card
    end
    local function target_cards(card)
      local config=card.ability and card.ability.consumeable
      require_value(type(config)=='table', 'This card is not a usable consumable.')
      local aura=card.ability.name=='Aura'
      local maximum=config.max_highlighted or (aura and 1 or 0)
      local minimum=maximum>0 and (config.min_highlighted or 1) or 0
      local hand=g.hand
      targets=indices(action.targets or {},hand and hand.cards or {},minimum,math.min(5,maximum))
      allow_forced=maximum==0
      -- The original use callback also calls check_use. Check before beginning
      -- so an Ankh blocked by the Joker limit is not reported as executed.
      if type(card.check_use)=='function' then require_value(not card:check_use(), 'The game cannot use this card right now.') end
    end
    if kind=='play' or kind=='discard' then
      at('hand')
      require_value(action.area==nil or action.area=='hand', 'This move must select the hand.')
      require_value(g.hand and g.hand.cards and g.hand.config, 'The hand is unavailable.')
      targets=indices(action.indices,g.hand.cards,1,math.min(5,g.hand.config.highlighted_limit or 5))
      check=kind=='play' and 'can_play' or 'can_discard'
      callback=kind=='play' and 'play_cards_from_highlighted' or 'discard_cards_from_highlighted'
      if kind=='play' then require_value((g.GAME.current_round.hands_left or 0)>0, 'There are no hands left.') end
    elseif kind=='use' or kind=='choose' or kind=='buy_and_use' then
      if kind=='choose' then at('pack') elseif kind=='buy_and_use' then at('shop') else at('hand','shop','blind','pack','round') end
      local card=get_card(kind=='choose' and 'pack_cards' or kind=='buy_and_use' and 'shop_jokers' or 'consumeables')
      if kind=='choose' then require_value((g.GAME.pack_choices or 0)>0, 'There are no pack choices left.') end
      if card.ability and card.ability.consumeable then
        target_cards(card);check='can_use_consumeable'
        if kind=='buy_and_use' then
          check='can_buy_and_use'
          local box=card.children and card.children.buy_and_use_button
          e=ui(box,'buy_and_use') or (box and box.UIRoot)
          require_value(e and e.config and e.config.id=='buy_and_use' and e.config.ref_table==card and e.UIBox,
            'The game buy-and-use button is unavailable.')
        end
      else
        require_value(kind=='choose' and card.ability and
          (card.ability.set=='Joker' or card.ability.set=='Default' or card.ability.set=='Enhanced'),
          'This card has no supported use action.')
        require_value(not action.targets or #action.targets==0, 'This pack card does not accept hand targets.')
        check='can_select_card'
      end
      callback=kind=='buy_and_use' and 'buy_from_shop' or 'use_card'
    elseif kind=='buy' or kind=='open' then
      at('shop')
      local card
      if kind=='open' then
        card=get_card('shop_booster');require_value(card.ability and card.ability.set=='Booster', 'This card is not a booster pack.')
        check,callback='can_open','use_card'
      else
        card=get_card('shop_jokers','shop_vouchers')
        if action.area=='shop_vouchers' then
          require_value(card.ability and card.ability.set=='Voucher', 'This card is not a voucher.')
          check,callback='can_redeem','use_card'
        else
          check,callback='can_buy','buy_from_shop'
          require_value(type(g.FUNCS.check_for_buy_space)=='function', 'The purchase capacity check is unavailable.')
          require_value(g.FUNCS.check_for_buy_space(card), 'There is no room for this purchase.')
        end
      end
    elseif kind=='sell' then
      at('hand','shop','blind','pack','round')
      local card=get_card('jokers','consumeables')
      require_value(not (card.ability and card.ability.eternal), 'Eternal cards cannot be sold.')
      check,callback='can_sell_card','sell_card'
    elseif kind=='reroll' then at('shop');check,callback='can_reroll','reroll_shop'
    elseif kind=='skip_pack' then at('pack');check,callback='can_skip_booster','skip_booster'
    elseif kind=='leave_shop' or kind=='cash_out' then
      at(kind=='leave_shop' and 'shop' or 'round')
      callback=kind=='leave_shop' and 'toggle_shop' or 'cash_out'
      local why;e,why=action_button(g,kind)
      require_value(enabled(e,callback), why or 'The game button for this action is not ready.')
    elseif kind=='select_blind' or kind=='skip_blind' then
      at('blind')
      require_value(g.blind_select, 'The blind selection screen is no longer present.')
      local blind=action.blind or g.GAME.blind_on_deck
      require_value((blind=='Small' or blind=='Big' or blind=='Boss') and blind==g.GAME.blind_on_deck,
        'The recommended blind is no longer the current blind.')
      local resets=g.GAME.round_resets or {}
      require_value((resets.blind_states or {})[blind]=='Select', 'This blind cannot be selected now.')
      local box=(g.blind_select_opts or {})[string.lower(blind)]
      callback=kind
      if kind=='select_blind' then
        e=ui(box,'select_blind_button')
        local definition=(g.P_BLINDS or {})[(resets.blind_choices or {})[blind]]
        require_value(definition and e and e.config and e.config.ref_table==definition, 'The displayed blind has changed.')
      else
        require_value(blind~='Boss', 'Boss blinds cannot be skipped.')
        local tag,container=ui(box,'tag_'..blind),ui(box,'tag_container')
        require_value(container and container.config and container.config.ref_table and
          not (container.states and container.states.visible==false), 'There is no available blind-skip reward.')
        e=tag and tag.children and tag.children[2]
        require_value(e and e.UIBox==box, 'The blind-skip button is unavailable.')
      end
      require_value(enabled(e,callback), 'The blind button is not ready.')
    elseif kind=='reorder_jokers' or kind=='reorder_hand' then
      if kind=='reorder_hand' then at('hand','pack') else at('hand','shop','blind','pack','round') end
      local name=kind=='reorder_hand' and 'hand' or 'jokers'
      require_value(action.area==nil or action.area==name, 'The ordering names a different card area.')
      local area=require_value(g[name], 'The card area is no longer present.')
      local ordered=indices(action.order,area.cards,#area.cards,#area.cards)
      require_value(type(area.align_cards)=='function' and type(area.set_ranks)=='function', 'Card ordering is unavailable.')
      require_value(not area.shuffle_amt or area.shuffle_amt==0, 'Wait for the cards to finish shuffling.')
      for position,card in ipairs(ordered) do
        require_value(card.states and card.states.drag and card.states.drag.can and not card.states.drag.is,
          'A card cannot be moved right now.')
        require_value(not card.pinned or area.cards[position]==card, 'A pinned card cannot be moved.')
        require_value(kind=='reorder_hand' or card.facing=='front', 'Face-down Jokers cannot be reordered by the advisor.')
      end
      old_order=copy_list(area.cards);changed_area=area
      reorder_started=true
      area.cards=copy_list(ordered);area:align_cards();area:set_ranks()
      for i,card in ipairs(ordered) do require_value(area.cards[i]==card, 'The game did not accept the requested card order.') end
      changed_area=nil
      return
    else reject('Unsupported advisor action: '..kind) end

    -- Validate callback availability before changing the player's selection.
    require_value(type(g.FUNCS[callback])=='function' and (not check or type(g.FUNCS[check])=='function'),
      'The required game action is unavailable.')
    if targets then
      old_selection=copy_list(g.hand and g.hand.highlighted)
      selection_changed=true;selection(g.hand,targets,allow_forced)
    end
    check_callback(g,check,callback,e)
    callback_started=true
    require_value(g.FUNCS[callback](e)~=false, 'The game rejected this action; refresh the recommendation.')
  end)
  if not ok then
    local may_have_started=not not (callback_started or reorder_started)
    if changed_area and old_order then local restored=pcall(function()
      changed_area.cards=old_order;changed_area:align_cards();changed_area:set_ranks()
    end);if not restored then may_have_started=true end end
    if selection_changed and not callback_started then
      if not g.hand then may_have_started=true
      else local restored=pcall(function()
        local surviving={}
        for _,card in ipairs(old_selection) do if contains(g.hand.cards,card) then surviving[#surviving+1]=card end end
        if #surviving~=#old_selection then may_have_started=true end
        selection(g.hand,surviving,true)
      end);if not restored then may_have_started=true end end
    end
    return false,(may_have_started and 'The game action did not finish normally; refresh the recommendation. ' or '')..tostring(reason),may_have_started
  end
  return true
end

return M
