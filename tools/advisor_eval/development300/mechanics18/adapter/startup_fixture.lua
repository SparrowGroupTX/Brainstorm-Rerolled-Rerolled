-- M18 prospective mechanic: actual frozen UI Start callbacks, original menu
-- lifecycle and source normal startup. The search answer is explicitly injected
-- from already observed S05; no native work, advisor action or terminal mutation.
return function(env)
  local g,modules,snapshot,trace=env.G,env.modules,env.snapshot,env.trace
  local observed=assert(PROBE_COLLECTION_OBSERVED_RECEIPT)
  local case=assert(PROBE_STARTUP_CASE)
  assert(case=='manual' or case=='auto','HEADLESS_BOUNDARY unknown M18 case')
  local product=require('probe_collection_search_product')
  local query=require('probe_policy_collection_search')
  local calls={search_stand_in=0,delete_run=0,start_run=0,back=0,settings_changed=0,
    advisor_actions=0,native_search=0,ui_button=0,config_writes=0,overlay_close=0}
  local active,completed,receipt
  local runtime={}
  function runtime.start(q,seed,token)
    assert(not active and not completed,'M18 stand-in is one use per fresh source state')
    assert(q.native_api_version==9 and q.deck=='Red Deck' and q.stake_level==8 and
      q.target_jokers==table.concat(observed.request.targets,'\31') and
      q.target_locations==table.concat(observed.request.locations,'\31') and
      q.interchangeable_copies==true and q.minimum_distinct==0 and q.quota_mode=='strict' and
      q.first_ante==1 and q.last_ante==8 and q.burnt_fallback==false and
      q.budget_ms==27000 and q.reject_perishable_targets==true and q.souls==2 and q.tag=='Charm Tag' and
      q.voucher=='' and q.pack=='' and q.custom_filter=='No Filter' and q.target_rank=='Kings' and
      q.target_suit=='Any Suit' and q.specific_rank_min==0 and q.any_rank_min==0,
      'M18 requested query must match observed effective S05 criteria')
    assert(seed==observed.request.seed and product.seed_id(seed)==observed.request.start_index,
      'M18 observed receipt must retain its original start cursor')
    assert(g.STAGE==g.STAGES.MAIN_MENU and g.STATE==g.STATES.MENU and g.STATE_COMPLETE==false,
      'M18 search must begin from actual source main MENU without a forced completion latch')
    assert(not g.OVERLAY_MENU and not g.SETTINGS.paused and not g.CONTROLLER.locked and
      not g.CONTROLLER.locks.frame and not g.CONTROLLER.locks.frame_set,
      'M18 dispatch must wait for original overlay/controller settlement')
    calls.search_stand_in=calls.search_stand_in+1;active=true
    receipt={generation=1,status='found',profile_id=q.profile_id,profile_token=token,request=snapshot.copy(q),
      result=snapshot.copy(observed.result),raw_result=observed.raw_result,elapsed_wall_seconds=0,
      starts_run=false,mechanical_injection='already_observed_S05_no_search',evidence=snapshot.copy(observed.binding)}
    return 1
  end
  function runtime.busy()return active==true end
  function runtime.poll(token)
    assert(active and token==receipt.profile_token,'M18 invalid observed receipt ownership')
    active=false;completed=true;return receipt
  end
  function runtime.stop(reason)
    assert(not active,'M18 unexpected active search cancellation: '..tostring(reason))
    return false
  end
  local profile=g.PROFILES[g.SETTINGS.profile]
  local history_before=PROBE_SHA256(snapshot.fingerprint(profile.joker_usage))
  local real_delete,real_start,real_back,real_close=g.delete_run,g.start_run,Back,g.FUNCS.exit_overlay_menu
  local source_methods={delete_run=debug.getinfo(real_delete,'S').source,
    start_run=debug.getinfo(real_start,'S').source,back=debug.getinfo(Back.init,'S').source,
    main_menu=debug.getinfo(g.main_menu,'S').source,exit_overlay=debug.getinfo(real_close,'S').source,
    controller_update=debug.getinfo(g.CONTROLLER.update,'S').source,update_menu=debug.getinfo(g.update_menu,'S').source}
  for _,source in pairs(source_methods)do assert(source:find('@installed/',1,true),'M18 requires original source method')end
  local B={VERSION='M18-frozen-policy',collection_search_cursor=observed.request.start_index,
    CollectionSearch=query,CollectionSearchRuntime=runtime,
    config={advisor={enabled=false,challenge_only=true,gold_stickers=false,player_logging=false,
      gold_run={deck_name='Red Deck',interchangeable_copies=true,quota_mode='strict',minimum_distinct=0,
        first_ante=1,last_ante=8,budget_ms=30000,max_runs=5,burnt_fallback=false}}}}
  Brainstorm=B
  local A={snapshot=snapshot,gold_search=modules.gold_search,gold_stickers=modules.gold_stickers,
    retry_generation=0,lines={}};B.Advisor=A
  A.player_log={status='M18 memory-only declared logger stand-in'}
  function A.player_log:enabled()return B.config.advisor.player_logging==true end
  function A.player_log:event(kind,data)
    trace({type='engine_collection_memory_log',case=case,kind=kind,data=data});return true
  end
  function A.execute()calls.advisor_actions=calls.advisor_actions+1;error('HEADLESS_BOUNDARY M18 forbids advisor actions')end
  function A.can_execute()return false end
  function A.settings_changed()
    calls.settings_changed=calls.settings_changed+1;A.retry_generation=A.retry_generation+1
    if B.AutoRun then B.AutoRun:manual('Advisor settings changed.','settings')end
    if B.CollectionSearchProduct then B.CollectionSearchProduct.stop('Advisor settings changed.')end
  end
  function B.writeConfig()calls.config_writes=calls.config_writes+1 end
  local function close_overlay()
    calls.overlay_close=calls.overlay_close+1;return real_close()
  end
  local now=function()return g.TIMERS.UPTIME end
  local api=product.attach(B,{game=function()return g end,now=now,input_token=function()return 0 end,
    exit_overlay=close_overlay,
    back=function(center)calls.back=calls.back+1;return real_back(center)end,
    delete_run=function(game)calls.delete_run=calls.delete_run+1;return real_delete(game)end,
    start_run=function(game,args)calls.start_run=calls.start_run+1;return real_start(game,args)end,
    on_event=function(kind,data)trace({type='engine_collection_product_event',case=case,event=kind,data=data})end})
  local auto=require('probe_auto_run_product').attach(B,{game=function()return g end,advisor=A,search=api,
    controller=require('probe_policy_auto_run'),terminal=require('probe_auto_terminal'),now=now,exit_overlay=close_overlay})
  require('probe_collection_run_ui')
  -- This support function is frozen after M16 inspection. It runs original
  -- main_menu and source lock/phase callbacks; unsupported display surfaces fail.
  local lifecycle=require('probe_startup_menu_support')({G=g,env=env,snapshot=snapshot,trace=trace,case=case})
  assert(g.STAGE==g.STAGES.MAIN_MENU and g.STATE==g.STATES.MENU and g.STATE_COMPLETE==false,
    'Original menu initialization must establish the actual false completion latch')
  local menu_game=g.GAME
  local goal_before=modules.gold_stickers.capture(g,{enabled=true})
  assert(goal_before.counts.missing==150 and goal_before.counts.complete==0 and goal_before.counts.unknown==0,
    'M18 requires unchanged actual source-loaded synthetic missing history')
  assert(type(g.FUNCS.options)=='function','HEADLESS_BOUNDARY original options callback unavailable')
  source_methods.options=debug.getinfo(g.FUNCS.options,'S').source
  assert(source_methods.options:find('@installed/',1,true),'M18 requires original options callback')
  g.FUNCS.options()
  assert(g.OVERLAY_MENU and g.SETTINGS.paused,'Original options callback must establish its paused overlay')
  g.FUNCS.overlay_menu({definition=B.createCollectionRunPage()})
  assert(g.OVERLAY_MENU and g.SETTINGS.paused,'Original overlay callback must open the actual product page')
  local callback=case=='manual' and 'brainstorm_collection_search_start' or 'brainstorm_collection_auto_start'
  calls.ui_button=calls.ui_button+1;g.FUNCS[callback]()
  assert(calls.search_stand_in==0 and calls.start_run==0 and g.GAME==menu_game,
    'UI Start must only arm ownership before original controller settlement')
  assert(not g.OVERLAY_MENU and g.CONTROLLER.locks.frame and g.CONTROLLER.locks.frame_set,
    'Original menu close must establish its real frame locks')
  api.update();if case=='auto'then auto:update()end
  assert(calls.search_stand_in==0,'The pending frame lock must actually block dispatch')
  trace({type='engine_collection_button_armed',case=case,state=g.STATE,stage=g.STAGE,
    state_complete=g.STATE_COMPLETE,controller_locks=snapshot.copy(g.CONTROLLER.locks),
    manual_status=api.status,auto_status=auto.status_text,calls=snapshot.copy(calls)})
  for frame=1,600 do
    lifecycle.tick()
    api.update();if case=='auto'then auto:update()end
    if calls.start_run==1 then break end
  end
  assert(calls.start_run==1,'HEADLESS_BOUNDARY M18 product button remained blocked: '..
    tostring(case=='manual' and api.status or auto.status_text))
  if case=='auto'then auto:stop('M18 censored preblind boundary')end
  env.until_state(env.input_ready,1200)
  local after=snapshot.capture(g)
  local route,route_reason=modules.normal_opening.capture(g)
  local goal_after=modules.gold_stickers.capture(g,{enabled=true})
  assert(g.GAME~=menu_game and g.GAME.pseudorandom.seed==observed.result.seed and g.GAME.challenge==nil,
    'Original product startup must replace the menu game with observed S05')
  assert(g.GAME.stake==8 and g.GAME.selected_back.effect.center.key=='b_red' and
    g.GAME.used_filter and not g.GAME.seeded,'Actual source run settings differ')
  assert(after.phase=='blind' and after.round==0 and after.ante==1 and #after.jokers==0 and after.skips==0 and
    after.blind_on_deck=='Small' and after.skip_tags.Small=='tag_charm' and #g.playing_cards==52,
    'M18 must stop with actual Small Charm before blind play or acquisition')
  assert(route and route.bound_to_run and route.required_souls==2 and
    route.legendary_targets[1]=='j_yorick' and route.legendary_targets[2]=='j_perkeo' and
    not route.multi_soul_pack_consumed,'Actual opening recipe failed: '..tostring(route_reason))
  assert(profile==g.PROFILES[g.SETTINGS.profile] and history_before==PROBE_SHA256(snapshot.fingerprint(profile.joker_usage)) and
    goal_after.counts.complete==0 and goal_after.counts.missing==150 and goal_after.counts.unknown==0,
    'Actual loaded synthetic history must remain unchanged')
  assert(calls.search_stand_in==1 and calls.start_run==1 and calls.delete_run==1 and calls.back==1 and
    calls.overlay_close==1 and calls.ui_button==1 and calls.advisor_actions==0 and calls.native_search==0 and env.score_calls()==0,
    'M18 exceeded registered startup-only scope')
  if case=='manual'then assert(api.status=='Gold run started. Advisor play remains user-controlled.',
    'Manual settings invalidation must preserve successful-start status')end
  trace({type='engine_collection_button_startup_verified',case=case,calls=calls,source_methods=source_methods,
    snapshot=after,normal_opening=route,filter_info=snapshot.copy(g.GAME.filter_info),lifecycle=lifecycle.evidence(),
    profile_unchanged=true,profile_counts=goal_after.counts,score_calls=0,observed_receipt=observed.binding,
    qualified_scope='Only observed-receipt original-source UI-start lifecycle',full_autoplay_qualified=false,
    acquisition_retention_survival_verified=false})
  trace({type='engine_episode_stopped',case=case,outcome='censored',reason='M18_preblind_ui_startup',decisions=0})
end
