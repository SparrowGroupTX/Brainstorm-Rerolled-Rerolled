-- Loaded-state receipts around original callbacks. Never writes profile/save
-- data and never accepts GAME.won alone as completion. Arm an actual GAME
-- started by the controller or adopted after a verified user checkpoint load;
-- only later callbacks on that bound GAME/profile can establish completion.
local M={}
local function number(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function copy(v)
  if type(v)~='table' then return v end
  local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
end
local function packed(...)return {n=select('#',...),...}end
function M.attach(deps)
  deps=deps or {};local get=assert(deps.game);local globals=deps.globals or _G
  local card=deps.card or globals.Card;local game_class=deps.game_class or globals.Game
  local api={};local bound;local hooks={};local source_listener
  function api:subscribe_source(listener)
    assert(source_listener==nil and type(listener)=='function','A single passive terminal listener is required.')
    source_listener=listener
  end
  local function source(kind,g,details)
    if source_listener then
      local okay,why=pcall(source_listener,kind,g,details)
      if not okay then api.source_listener_error=tostring(why) end
    end
  end
  local function current()
    local g=get();return bound and g and g.GAME==bound.game and (g.SETTINGS or {}).profile==bound.profile and
      (g.PROFILES or {})[bound.profile]==bound.profile_table and g or nil
  end
  local function info(g)
    local game=g.GAME;local profile=(g.PROFILES or {})[(g.SETTINGS or {}).profile]
    if type(profile)~='table' then return nil end
    local stake=game.stake;local center=game.selected_back and game.selected_back.effect and game.selected_back.effect.center
    if not number(stake) or not center or type(center.key)~='string' then return nil end
    local function wins(kind,key)
      local value=((((profile[kind] or {})[key] or {}).wins or {})[stake])
      if value==nil then return 0 end
      return number(value) and value>=0 and value%1==0 and value or nil
    end
    local held={}
    for _,c in ipairs(g.jokers and g.jokers.cards or {})do
      local ccenter=c.config and c.config.center
      local key=c.config and c.config.center_key or ccenter and ccenter.key
      if not key or held[key]~=nil then
        -- Repeated physical copies can increment the same counter more than
        -- once. Track its initial number once; verify a positive increment.
        if not key then return nil end
      else held[key]=wins('joker_usage',key);if held[key]==nil then return nil end end
    end
    return {deck=center.key,stake=stake,deck_wins=wins('deck_usage',center.key),jokers=held,
      ante=(game.round_resets or {}).ante,round=game.round,win_ante=game.win_ante,
      chips=game.chips,target=(game.blind or {}).chips,boss=not not (game.blind or {}).boss,
      seeded=not not game.seeded,challenge=game.challenge,won=not not game.won,state=g.STATE}
  end
  function api:arm(run_id)
    local g=get()
    if not g or type(g.GAME)~='table' or type(run_id)~='string' or run_id=='' then return false end
    local profile=(g.SETTINGS or {}).profile
    if type((g.PROFILES or {})[profile])~='table' then return false end
    bound={game=g.GAME,profile=profile,profile_table=g.PROFILES[profile],run_id=run_id,callbacks={}}
    return true
  end
  function api:disarm()bound=nil end
  local function wrap(name,before,after)
    local original=globals[name]
    if type(original)~='function' or original==hooks[name] then return end
    local function wrapped(...)
      local g=current();local stamp=bound;local context=g and info(g);local previous_overlay=g and g.OVERLAY_MENU
      if name=='end_round' then source('end_round_entry',get()) end
      if context and before then before(context,g)end
      local source_win=context and name=='win_game' and bound.final~=nil
      if source_win then stamp.win_depth=(stamp.win_depth or 0)+1 end
      local result=packed(pcall(original,...))
      if source_win then stamp.win_depth=stamp.win_depth-1 end
      if result[1] and context and current()==g and bound==stamp and after then after(context,info(g),g,previous_overlay,result)end
      if result[1] and name=='win_game' then source('win_game_returned',get()) end
      if not result[1]then error(result[2],0)end
      return unpack(result,2,result.n)
    end
    hooks[name]=wrapped;globals[name]=wrapped
  end
  function api:install_hooks()
    wrap('end_round',function(context)
      if context.boss and context.ante==context.win_ante then bound.final=copy(context)end
    end)
    for _,name in ipairs({'set_joker_win','set_deck_win'})do
      local callback=name
      wrap(callback,nil,function(before,after)
        local final=bound.final
        if not final or not after or before.round~=final.round or after.round~=final.round or
          not before.won or not after.won or before.seeded or before.challenge or
          before.deck~=final.deck or before.stake~=final.stake or after.deck~=before.deck or after.stake~=before.stake then return end
        local expected=#bound.callbacks==0 and 'set_joker_win' or #bound.callbacks==1 and 'set_deck_win'
        if callback~=expected then bound.invalid=true;return end
        local valid=before.deck_wins~=nil and after.deck_wins~=nil
        if callback=='set_deck_win'then valid=valid and after.deck_wins>before.deck_wins
        else
          for key,n in pairs(before.jokers)do valid=valid and after.jokers[key]~=nil and after.jokers[key]>n end
          for key in pairs(after.jokers)do if before.jokers[key]==nil then valid=false end end
        end
        if #bound.callbacks>=8 then bound.invalid=true;return end
        bound.callbacks[#bound.callbacks+1]={name=callback,before=copy(before),after=copy(after),verified=not not valid}
        if valid then bound[callback]=true end
      end)
    end
    wrap('win_game',nil,function(_,_,g,previous_overlay)
      bound.win_called=true
      -- This exact overlay was created by the original win callback; an
      -- unrelated later menu must never inherit permission to be dismissed.
      if g.OVERLAY_MENU~=previous_overlay then bound.overlay=g.OVERLAY_MENU end
    end)
    wrap('create_UIBox_win',nil,function(_,_,g,_,result)
      -- The original win_game schedules this UI creation in a later event.
      -- Bind its actual definition object to the already observed original
      -- accounting, then consume that exact object at overlay creation.
      local ended=api:poll(bound.run_id)
      if bound.win_called and ended and ended.kind=='win' and not bound.overlay and
        not bound.win_definition and type(result[2])=='table' then bound.win_definition=result[2] end
    end)
    local g=get();local funcs=g and g.FUNCS
    if funcs and type(funcs.overlay_menu)=='function' and funcs.overlay_menu~=hooks.overlay_menu then
      local original=funcs.overlay_menu
      local function overlay_menu(args,...)
        local active=current();local stamp=bound
        local ended=active and api:poll(stamp.run_id)
        local owned=ended and ended.kind=='win' and stamp.win_definition and type(args)=='table' and
          args.definition==stamp.win_definition and not stamp.overlay
        if owned then stamp.win_definition=nil;stamp.win_depth=(stamp.win_depth or 0)+1 end
        local result=packed(pcall(original,args,...))
        if owned then stamp.win_depth=stamp.win_depth-1 end
        if result[1] and owned and current()==active and bound==stamp then stamp.overlay=active.OVERLAY_MENU end
        if not result[1]then error(result[2],0)end
        return unpack(result,2,result.n)
      end
      hooks.overlay_menu=overlay_menu;funcs.overlay_menu=overlay_menu
    end
    if game_class and type(game_class.update_game_over)=='function' and game_class.update_game_over~=hooks.game_over then
      local original=game_class.update_game_over
      local function update_game_over(self,...)
        local g=current();local stamp=bound;local previous_overlay=g and g.OVERLAY_MENU
        local owned=g and self==g and g.STATES and g.STATE==g.STATES.GAME_OVER
        if owned then stamp.result_depth=(stamp.result_depth or 0)+1 end
        local result=packed(pcall(original,self,...))
        if owned then stamp.result_depth=stamp.result_depth-1 end
        if result[1] and owned and current()==g and bound==stamp and g.OVERLAY_MENU~=previous_overlay then bound.loss_overlay=g.OVERLAY_MENU end
        if result[1] then source('game_over_returned',get()) end
        if not result[1]then error(result[2],0)end
        return unpack(result,2,result.n)
      end
      hooks.game_over=update_game_over;game_class.update_game_over=update_game_over
    end
    if card and type(card.calculate_joker)=='function' and card.calculate_joker~=hooks.calculate_joker then
      local original=card.calculate_joker
      local function calculate(self,context,...)
        local g=current();local stamp=bound
        local result=packed(original(self,context,...))
        if context and context.end_of_round and type(result[1])=='table' and result[1].saved==true then
          source('end_round_saved',get())
        end
        if g and current()==g and bound==stamp and context and context.end_of_round and
          type(result[1])=='table' and result[1].saved==true then bound.saved=info(g)end
        return unpack(result,1,result.n)
      end
      hooks.calculate_joker=calculate;card.calculate_joker=calculate
    end
  end
  function api:poll(run_id)
    local g=current();if not g or bound.run_id~=run_id then return nil end
    if g.STATES and g.STATE==g.STATES.GAME_OVER then
      return {kind='loss',verified=true,run_id=run_id,event_id='loss:'..run_id,source='GAME_OVER',
        source_won_field=not not g.GAME.won,result_surface_seen=bound.loss_overlay~=nil}
    end
    local final=bound.final;local now=info(g)
    if bound.invalid or not final or not now or not now.won or final.seeded or final.challenge or
      final.stake~=8 or now.stake~=final.stake or now.deck~=final.deck or not final.boss or
      final.ante~=final.win_ante or not bound.set_joker_win or not bound.set_deck_win then return nil end
    local threshold=number(final.chips) and number(final.target) and final.target>0 and final.chips>=final.target
    local saved=bound.saved and bound.saved.ante==final.ante and bound.saved.round==final.round
    if not threshold and not saved then return nil end
    return {kind='win',verified=true,run_id=run_id,event_id='win:'..run_id,source='original_win_callback',
      final_context=copy(final),callbacks=copy(bound.callbacks),threshold_met=not not threshold,
      source_saved=not not saved,game_over=false,result_surface_seen=bound.overlay~=nil}
  end
  function api:owned_overlay(run_id)
    local terminal=self:poll(run_id);local g=current()
    if terminal and terminal.kind=='win' and bound.overlay and g.OVERLAY_MENU==bound.overlay then return bound.overlay end
    if terminal and terminal.kind=='loss' and bound.loss_overlay and g.OVERLAY_MENU==bound.loss_overlay then return bound.loss_overlay end
  end
  function api:in_win_callback()
    return current()~=nil and ((bound.win_depth or 0)>0 or (bound.result_depth or 0)>0)
  end
  api:install_hooks();return api
end
return M
