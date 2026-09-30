-- M16 main_menu plus M13 update/Controller source determines this boundary.
-- Original main_menu, menu update, EventManager, CardArea/Card updates and full
-- Controller:update run. Full Game:update's sound, HTTP, rendering and Steam
-- services are omitted. Mouse/keyboard reads are deterministic no-input stubs;
-- they never access the user's actual devices. UI trees reuse the declared
-- source adapter's display model. Unknown surfaces remain explicit errors.
return function(context)
  local g,env,snapshot,trace,case=context.G,context.env,context.snapshot,context.trace,context.case
  assert(g.LOADING==nil or g.LOADING==false,'M17 requires isolated initialization without boot display cache')
  local cache={font={synthetic_display_font=true}}
  g.LOADING=cache
  love.mouse={getPosition=function()return -10000,-10000 end,getX=function()return -10000 end,
    getY=function()return -10000 end,isDown=function()return false end,
    setVisible=function()end,getRelativeMode=function()return false end}
  love.keyboard={isDown=function()return false end,hasTextInput=function()return false end}
  local count={ticks=0,controller_update=0,menu_update=0,main_menu=0}
  local function tick()
    count.ticks=count.ticks+1;assert(count.ticks<=1800,'HEADLESS_BOUNDARY M17 menu tick cap')
    env.tick()
    if g.STATE==g.STATES.MENU then count.menu_update=count.menu_update+1;g:update_menu(1/60)end
    count.controller_update=count.controller_update+1;g.CONTROLLER:update(1/60)
  end
  local main_menu=g.main_menu
  assert(debug.getinfo(main_menu,'S').source:find('@installed/game.lua',1,true),
    'HEADLESS_BOUNDARY M17 main_menu must remain original')
  count.main_menu=count.main_menu+1;g:main_menu('game')
  -- M16 source queues the final menu UI at 3 seconds for this exact context.
  -- Four simulated seconds cover its presentation queue without wall sleeping.
  for _=1,240 do tick()end
  assert(g.LOADING==cache and g.STAGE==g.STAGES.MAIN_MENU and g.STATE==g.STATES.MENU and g.STATE_COMPLETE==false,
    'HEADLESS_BOUNDARY original main-menu/cache state differs')
  assert(not g.screenwipe and not g.CONTROLLER.locked and not g.CONTROLLER.lock_input,
    'HEADLESS_BOUNDARY original main menu did not settle')
  trace({type='engine_collection_original_menu_ready',case=case,calls=snapshot.copy(count),
    stage=g.STAGE,state=g.STATE,state_complete=g.STATE_COMPLETE,controller_locks=snapshot.copy(g.CONTROLLER.locks),
    boot_cache_scope='Injected M13 source-proven font-only cache; boot_timer not executed',
    update_scope='Original EventManager/CardArea/Card updates, update_menu and Controller:update; full Game:update omitted'})
  return {tick=tick,evidence=function()return {calls=snapshot.copy(count),boot_cache_preserved=g.LOADING==cache,
    original_main_menu=true,original_options=true,original_overlay_callbacks=true,original_controller_update=true,
    original_menu_update=true,full_game_update=false,source_menu_ui_tree_standin=true,synthetic_no_input=true,
    injected_boot_cache=true,original_boot_timer=false,physical_input_or_window_access=false}end}
end
