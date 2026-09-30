-- M14 only: exercise the frozen facade with an explicitly injected OBSERVED
-- search receipt. Original Game.delete_run/start_run and Back do all run setup.
-- No native/thread work, blind selection, card action, win or progress injection.
return function(env)
  local g,modules,snapshot,trace=env.G,env.modules,env.snapshot,env.trace
  local observed=assert(PROBE_COLLECTION_OBSERVED_RECEIPT,'Missing frozen observed S05 receipt')
  local product=require('probe_collection_search_product')
  local query=require('probe_policy_collection_search')
  -- M13 proves boot_timer creates this persistent display-cache shape.
  -- Font rendering is represented by an inert table. boot_timer itself is
  -- not executed; no game/profile/terminal fields are changed by this setup.
  assert(g.LOADING==nil or g.LOADING==false,'M14 expected isolated probe without original boot display cache')
  local boot_cache={font={synthetic_display_font=true}}
  g.LOADING=boot_cache
  local old_game=g.GAME
  local profile=g.PROFILES[g.SETTINGS.profile]
  local usage_before=PROBE_SHA256(snapshot.fingerprint(profile.joker_usage))
  local before=snapshot.capture(g)
  assert(before.phase=='blind' and before.round==0 and before.ante==1 and #before.jokers==0,
      'M14 requires untouched ordinary preblind initialization')
  assert(g.GAME.seeded==true and g.GAME.used_filter~=true and g.GAME.pseudorandom.seed==PROBE_SEED and
      PROBE_SEED~=observed.result.seed,'M14 bootstrap must differ from the actual product start')
  local calls={search_stand_in=0,delete_run=0,start_run=0,back=0,settings_changed=0,advisor_actions=0,native_search=0}
  local active,completed,receipt
  local runtime={}
  function runtime.start(q,seed,token)
    assert(not active and not completed,'M14 search stand-in is one use')
    assert(q.native_api_version==9 and q.deck=='Red Deck' and q.stake_level==8 and
      q.target_jokers==table.concat(observed.request.targets,'\31') and
      q.target_locations==table.concat(observed.request.locations,'\31') and
      q.interchangeable_copies==true and q.minimum_distinct==0 and q.first_ante==1 and q.last_ante==8 and
      q.budget_ms==27000 and q.reject_perishable_targets==true and q.souls==2 and q.tag=='Charm Tag' and
      q.voucher=='' and q.pack=='' and q.custom_filter=='No Filter' and q.target_rank=='Kings' and
      q.target_suit=='Any Suit' and q.specific_rank_min==0 and q.any_rank_min==0,
      'M14 actual product query differs from the observed effective fixed-opening query')
    assert(seed==observed.request.seed and product.seed_id(seed)==observed.request.start_index,
      'M14 must explicitly bind the original observed request start index')
    calls.search_stand_in=calls.search_stand_in+1;active=true
    receipt={generation=1,status='found',profile_id=q.profile_id,profile_token=token,request=snapshot.copy(q),
      result=snapshot.copy(observed.result),raw_result=observed.raw_result,elapsed_wall_seconds=0,
      starts_run=false,mechanical_injection='already_observed_S05_no_search',evidence=snapshot.copy(observed.binding)}
    return 1
  end
  function runtime.busy()return active==true end
  function runtime.poll(token)
    assert(active and token==receipt.profile_token,'M14 stand-in received invalid ownership')
    active=false;completed=true;return receipt
  end
  function runtime.stop(reason)error('M14 unexpected cancellation: '..tostring(reason))end
  local real_delete,real_start,real_back=g.delete_run,g.start_run,Back
  local real_sources={delete_run=debug.getinfo(real_delete,'S').source,
      start_run=debug.getinfo(real_start,'S').source,back=debug.getinfo(Back.init,'S').source}
  assert(real_sources.delete_run:find('game.lua',1,true) and real_sources.start_run:find('game.lua',1,true)
      and real_sources.back:find('back.lua',1,true),'M14 requires original source method definitions')
  local B={collection_search_cursor=observed.request.start_index,CollectionSearch=query,
      CollectionSearchRuntime=runtime,Advisor={gold_search=modules.gold_search,gold_stickers=modules.gold_stickers,
        settings_changed=function()calls.settings_changed=calls.settings_changed+1 end}}
  local baseline=require('probe_baseline_collection_search_product').attach(B,{game=function()return g end})
  local old_ready,old_reason=baseline.can_begin()
  assert(not old_ready and old_reason=='A save or checkpoint operation is pending.',
      'M14 must reproduce frozen302 wrongly treating boot display cache as active loading')
  trace({type='engine_collection_startup_baseline',baseline_product_sha256=PROBE_BASELINE_PRODUCT_SHA256,
      ready=false,reason=old_reason,searches=0,launches=0,
      injected_scope='Only M13-proven G.LOADING font-only cache; inert font stand-in, no original boot_timer execution'})
  local api=product.attach(B,{game=function()return g end,
      back=function(center)calls.back=calls.back+1;return real_back(center)end,
      delete_run=function(game)calls.delete_run=calls.delete_run+1;return real_delete(game)end,
      start_run=function(game,args)calls.start_run=calls.start_run+1;return real_start(game,args)end,
      on_event=function(kind,data)trace({type='engine_collection_product_event',event=kind,data=data})end})
  local goal_before=modules.gold_stickers.capture(g,{enabled=true})
  assert(goal_before.counts.unknown==0 and goal_before.counts.missing==150 and goal_before.counts.complete==0,
      'M14 requires actual source-loaded fresh synthetic history, without fake Gold records')
  local ready,why=api.can_begin()
  trace({type='engine_collection_startup_preflight',ready=not not ready,reason=why,
      state=g.STATE,state_complete=g.STATE_COMPLETE,controller_locked=g.CONTROLLER.locked,
      controller_locks=snapshot.copy(g.CONTROLLER.locks),source_methods=real_sources,
      initial_seed=PROBE_SEED,requested_seed=observed.result.seed,initial_counts=goal_before.counts})
  assert(ready,'M14 product safety gate rejected original settled source: '..tostring(why))
  local request,reason=api.prepare({deck_name='Red Deck',interchangeable_copies=true,
      minimum_distinct=0,first_ante=1,last_ante=8,budget_ms=30000})
  assert(request,reason);assert(request.requested_budget_ms==30000 and request.query.budget_ms==27000)
  local owner='mechanical:M14:observed-S05'
  assert(api.begin(request,owner)==request.request_id,'M14 product search dispatch failed')
  assert(g.GAME==old_game and g.GAME.pseudorandom.seed==PROBE_SEED,'Search dispatch must not start a run')
  local result=assert(api.poll(owner));assert(result.status=='found' and result.exited and result.found)
  local started,start_reason=api.launch(result.found,owner)
  assert(started,'M14 authentic product run launch failed: '..tostring(start_reason))
  env.until_state(env.input_ready,1200)
  local after=snapshot.capture(g)
  local route,route_reason=modules.normal_opening.capture(g)
  local goal_after=modules.gold_stickers.capture(g,{enabled=true})
  assert(g.GAME~=old_game and g.GAME.pseudorandom.seed==observed.result.seed and g.GAME.challenge==nil,
      'Original delete/start must replace the run with the observed seed')
  assert(g.GAME.stake==8 and g.GAME.selected_back.effect.center.key=='b_red' and
      g.GAME.used_filter==true and g.GAME.seeded==false,'Actual product flags/deck/stake differ')
  assert(after.phase=='blind' and after.round==0 and after.ante==1 and #after.jokers==0 and
      after.blind_on_deck=='Small' and after.skips==0 and #g.playing_cards==52 and
      after.skip_tags.Small=='tag_charm' and g.LOADING==boot_cache,
      'M14 must stop before any blind, acquisition or gameplay progression')
  assert(route and route.bound_to_run and route.required_souls==2 and
      route.legendary_targets[1]=='j_yorick' and route.legendary_targets[2]=='j_perkeo' and
      route.multi_soul_pack_consumed==false,'Actual normal opening capture rejected product metadata: '..tostring(route_reason))
  local info=g.GAME.filter_info
  assert(info.native_api_version==9 and #info.filter_params==28 and info.filter_params[1]==observed.result.seed and
      info.filter_params[23]==true and info.collection_search.interchangeable_copies==true and
      info.collection_search.future_acquisition_verified==false,'Product must retain API9 OR metadata without acquisition claims')
  assert(profile==g.PROFILES[g.SETTINGS.profile] and usage_before==PROBE_SHA256(snapshot.fingerprint(profile.joker_usage))
      and goal_after.counts.complete==0 and goal_after.counts.missing==150 and goal_after.counts.unknown==0,
      'The synthetic profile history must remain unchanged')
  assert(env.score_calls()==0 and calls.search_stand_in==1 and calls.delete_run==1 and calls.start_run==1 and
      calls.back==1 and calls.settings_changed==1,'M14 scope exceeded or authentic startup call count differs')
  local second=api.launch(result.found,owner)
  assert(not second and calls.delete_run==1 and calls.start_run==1,'A consumed receipt must never restart twice')
  trace({type='engine_collection_startup_verified',scenario='collection_product_startup',calls=calls,
      source_methods=real_sources,old_game_replaced=true,initial_seed=PROBE_SEED,actual_seed=g.GAME.pseudorandom.seed,
      deck=after.deck_key,stake=after.stake,phase=after.phase,round=after.round,ante=after.ante,
      used_filter=g.GAME.used_filter,seeded=g.GAME.seeded,profile_unchanged=true,profile_counts=goal_after.counts,
      actual_small_tag=after.skip_tags.Small,boot_cache_preserved=g.LOADING==boot_cache,baseline_preflight_rejected=true,
      normal_opening=route,filter_info=snapshot.copy(info),snapshot=after,observed_receipt=observed.binding,
      score_calls=env.score_calls(),qualified_scope='Only observed-receipt product launch into original-source preblind state',
      full_autoplay_qualified=false,acquisition_retention_survival_verified=false})
  trace({type='engine_episode_stopped',outcome='censored',reason='development_collection_product_startup_boot_cache',decisions=0})
end
