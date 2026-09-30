-- Passive presentation hooks. Displayed text is observed after attention_text
-- receives its final redirected major; raw Joker results are never inspected.
local M={}
local function packed(...)return {n=select('#',...),...}end
local callbacks={play_cards_from_highlighted='play',discard_cards_from_highlighted='discard',
  sell_card='sell',use_card='use',buy_from_shop='buy',select_blind='select_blind',
  cash_out='cash_out',toggle_shop='leave_shop'}
function M.attach(tracker,deps)
  deps=deps or {};local env=deps.env or _G;local hooks={};local H={}
  local callback_hooks=deps.callback_hooks
  local function game()return deps.game and deps.game() or env.G end
  local function safely(method,...)
    local ok=pcall(method,tracker,...)
    if not ok then tracker:reset('Public observation hook failed; prior inference discarded.')end
  end
  local function wrap(owner,name,before,after)
    if type(owner)~='table' or type(owner[name])~='function' then return end
    hooks[owner]=hooks[owner] or {}
    if owner[name]==hooks[owner][name] or callback_hooks and callback_hooks:contains(owner[name],hooks[owner][name])then return end
    local original=owner[name]
    local function wrapped(...)
      if before then before(...)end
      local result=packed(pcall(original,...))
      if not result[1]then
        safely(tracker.reset,'Source callback failed; pending public observations discarded.')
        error(result[2],0)
      end
      if result.n>=2 and result[2]==false and before then
        safely(tracker.invalidate,'Source callback explicitly rejected its pending public action.')
      end
      if after then after(...)end
      return unpack(result,2,result.n)
    end
    if callback_hooks then callback_hooks:record(wrapped,original)end
    hooks[owner][name]=wrapped;owner[name]=wrapped
  end
  local function in_jokers(g,card)
    for _,item in ipairs(g and g.jokers and g.jokers.cards or {})do if item==card then return true end end
    return false
  end
  function H:install()
    local g=game()
    wrap(env,'attention_text',nil,function(args)safely(tracker.display,game(),args,'status')end)
    wrap(env.Card,'juice_up',nil,function(card)
      safely(tracker.display,game(),{major=card},'juice')
    end)
    wrap(env.Card,'flip',function(card)
      local now=game()
      if in_jokers(now,card) and card.facing=='front'then safely(tracker.before_hide,now)end
    end)
    wrap(env.Card,'drag',function(card)safely(tracker.drag_start,game(),card)end)
    wrap(env.CardArea,'shuffle',function(area)
      local now=game()
      if now and area==now.jokers then
        safely(tracker.remember,now);safely(tracker.shuffle,now,'Joker shuffle observed; slot knowledge discarded.')
      end
    end)
    for _,name in ipairs({'start_run','delete_run'})do
      wrap(env.Game,name,function()safely(tracker.reset,'New or restored run requested.')end)
    end
    if g and g.FUNCS then
      for name,kind in pairs(callbacks)do
        wrap(g.FUNCS,name,function()safely(tracker.begin_action,kind,game())end)
      end
    end
  end
  function H:update()
    self:install();local g=game()
    if not g then return end
    safely(tracker.sync,g)
    local target=g.CONTROLLER and g.CONTROLLER.dragging and g.CONTROLLER.dragging.target
    if target and tracker.belief and in_jokers(g,target) and not tracker:drag_active()then
      safely(tracker.invalidate,'The origin of this public Joker drag was not observed.')
    end
    if not target then safely(tracker.drag_finish,g)end
  end
  H:install()
  return H
end
return M
