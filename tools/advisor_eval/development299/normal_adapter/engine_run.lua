-- Experimental dispatcher around original game rules. Rendering is replaced by
-- a tree carrying original UI definitions/configs/IDs. Game rule callbacks,
-- Card/CardArea/Blind state and EventManager execution are retained.
local snapshot=require('probe_policy_snapshot')
-- Fingerprint source state in the trace producer's schema. Candidate snapshot
-- improvements may change derived observations without changing original rules.
local replay_snapshot=PROBE_VERIFIED_REPLAY and require('probe_replay_snapshot') or snapshot
local contract=require('probe_engine_contract')
local scoring=require('probe_policy_scoring')
local clock=assert(PROBE_MONOTONIC_SECONDS,'Missing host monotonic profiler')
local score_calls=0
local raw_score=scoring.score
scoring.score=function(...)
    score_calls=score_calls+1
    return raw_score(...)
end
local search=require('probe_policy_search')
local strategy=require('probe_policy_strategy')
strategy.synergies=require('probe_policy_synergies')
local decision=require('probe_policy_decision')
local consumables_ok,consumables=pcall(require,'probe_policy_consumables')
if not consumables_ok then consumables={suggest=function() error('HEADLESS_BOUNDARY tactical consumable policy unavailable') end} end
local modules={snapshot=snapshot,scoring=scoring,search=search,strategy=strategy,consumables=consumables}
if package.preload.probe_jokerless_opening then modules.jokerless_opening=require('probe_jokerless_opening') end
strategy.consumables=consumables
if package.preload.probe_policy_conditional_value then strategy.conditional_value=require('probe_policy_conditional_value') end
if package.preload.probe_policy_deck_development then
  modules.deck_development=require('probe_policy_deck_development')
  if package.preload.probe_policy_spectral_development then
    modules.deck_development.spectral=require('probe_policy_spectral_development')
  end
  consumables.deck_development=modules.deck_development
  strategy.deck_development=modules.deck_development
end
if package.preload.probe_policy_ordering then modules.ordering=require('probe_policy_ordering') end
if package.preload.probe_policy_economy then modules.economy=require('probe_policy_economy') end
if package.preload.probe_policy_shop_scoring then modules.shop_scoring=require('probe_policy_shop_scoring') end
if modules.shop_scoring then
  modules.shop_scoring.strategy=strategy
  if package.preload.probe_policy_blind_prep then modules.shop_scoring.blind_prep=require('probe_policy_blind_prep') end
end
if modules.shop_scoring and package.preload.probe_policy_paired_deck then modules.shop_scoring.paired_deck=require('probe_policy_paired_deck') end
if modules.shop_scoring and package.preload.probe_policy_blind_start then modules.shop_scoring.blind_start=require('probe_policy_blind_start') end
if package.preload.probe_policy_shop_sequences then modules.shop_sequences=require('probe_policy_shop_sequences') end
if package.preload.probe_policy_pack_scoring then modules.pack_scoring=require('probe_policy_pack_scoring');strategy.pack_scoring=modules.pack_scoring end
if package.preload.probe_policy_hand_ordering then modules.hand_ordering=require('probe_policy_hand_ordering') end
if package.preload.probe_policy_boss_rescue then modules.boss_rescue=require('probe_policy_boss_rescue') end
if package.preload.probe_policy_mixed_rescue then modules.mixed_rescue=require('probe_policy_mixed_rescue') end
if package.preload.probe_policy_growth then modules.growth=require('probe_policy_growth') end
if package.preload.probe_policy_phase_copy then modules.phase_copy=require('probe_policy_phase_copy') end
if package.preload.probe_policy_gold_stickers then modules.gold_stickers=require('probe_policy_gold_stickers') end
if package.preload.probe_policy_gold_search then modules.gold_search=require('probe_policy_gold_search') end
if package.preload.probe_policy_normal_opening then modules.normal_opening=require('probe_policy_normal_opening') end
if modules.normal_opening then
  modules.normal_opening.gold_stickers=modules.gold_stickers
  modules.normal_opening.gold_search=modules.gold_search
  snapshot.normal_opening=modules.normal_opening
end
if package.preload.probe_policy_finish_rewards then modules.finish_rewards=require('probe_policy_finish_rewards') end
if package.preload.probe_policy_score_cache then modules.score_cache=require('probe_policy_score_cache') end
if package.preload.probe_policy_blind_routing then modules.blind_routing=require('probe_policy_blind_routing') end
if package.preload.probe_policy_draws then modules.draws=require('probe_policy_draws') end
if package.preload.probe_policy_sampled_outcomes then modules.sampled_outcomes=require('probe_policy_sampled_outcomes') end
if package.preload.probe_policy_multi_discard then modules.multi_discard=require('probe_policy_multi_discard') end
if package.preload.probe_policy_two_hand_finish then modules.two_hand_finish=require('probe_policy_two_hand_finish') end
if package.preload.probe_policy_resource_finish then modules.resource_finish=require('probe_policy_resource_finish') end
if package.preload.probe_policy_concealed_belief then modules.concealed_belief=require('probe_policy_concealed_belief') end
if package.preload.probe_policy_policy_weights then
  modules.policy_weights=require('probe_policy_policy_weights')
  search.policy_weights=modules.policy_weights
  if modules.growth then modules.growth.policy_weights=modules.policy_weights end
  if modules.shop_scoring then modules.shop_scoring.policy_weights=modules.policy_weights end
end
if modules.shop_scoring and package.preload.probe_policy_work_cost then modules.shop_scoring.work_cost=require('probe_policy_work_cost') end
if PROBE_OPENING_RAW or PROBE_NORMAL_FILTER_RECIPE then
  modules.opening=require('probe_challenge_opening')
  Brainstorm={ChallengeOpening=modules.opening}
  assert(loadstring(PROBE_CHARM_HOOK,'@frozen_charm_hook.lua'))()
end
if package.preload.probe_policy_blind_prep then modules.blind_prep=require('probe_policy_blind_prep') end
if modules.blind_prep and modules.shop_scoring then modules.blind_prep.blind_start=modules.shop_scoring.blind_start end
if package.preload.probe_policy_paid_reroll then strategy.paid_reroll=require('probe_policy_paid_reroll') end
if strategy.paid_reroll and package.preload.probe_policy_catalog_joker then strategy.paid_reroll.catalog=require('probe_policy_catalog_joker') end
if strategy.paid_reroll then strategy.paid_reroll.policy_weights=modules.policy_weights end
if package.preload.probe_policy_liquidity then
  modules.liquidity=require('probe_policy_liquidity');strategy.liquidity=modules.liquidity
  modules.liquidity.snapshot=snapshot
  if modules.shop_scoring then modules.shop_scoring.liquidity=modules.liquidity end
  if strategy.paid_reroll then strategy.paid_reroll.liquidity=modules.liquidity end
  if strategy.conditional_value then strategy.conditional_value.liquidity=modules.liquidity end
end
if package.preload.probe_policy_blind_finishing then
  modules.blind_finishing=require('probe_policy_blind_finishing')
  for _,key in ipairs({'draws','sampled_outcomes','search','finish_rewards','strategy','multi_discard'}) do
    modules.blind_finishing[key]=modules[key]
  end
  if modules.shop_scoring then modules.shop_scoring.blind_finishing=modules.blind_finishing end
end
local function json(value)
    if value==nil then return 'null' end
    if type(value)=='boolean' then return tostring(value) end
    if type(value)=='number' then return contract.trace_number(value) end
    if type(value)=='string' then
        return '"'..value:gsub('[%z\1-\31\\"]',function(c)
            local escape={['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
            return escape[c] or string.format('\\u%04x',string.byte(c))
        end)..'"'
    end
    assert(type(value)=='table','Unsupported trace value')
    local parts={}
    if #value>0 then for _,item in ipairs(value) do parts[#parts+1]=json(item) end;return '['..table.concat(parts,',')..']' end
    local keys={};for key in pairs(value) do keys[#keys+1]=key end;table.sort(keys)
    for _,key in ipairs(keys) do parts[#parts+1]=json(key)..':'..json(value[key]) end
    return '{'..table.concat(parts,',')..'}'
end
local function trace(value) print(json(value)) end
-- This dispatcher never loads runtime.lua/UI, external retry journals or manual
-- SaveManager checkpoints. Product files being frozen does not exercise those
-- integrations. Keep this actual-context receipt independent of policy presence.
local clean_retry_context={schema=1,mode='disabled_clean_attempt_v1',journal_access='none',
    checkpoint_restore='unsupported',initial_memory='empty',max_checkpoint_reloads=0,retry_advice_evaluated=false}
trace({type='engine_probe_retry_context',retry_context_spec=clean_retry_context,
    retry_context_spec_digest=PROBE_SHA256(json(clean_retry_context)),checkpoint_reloads_observed=0,
    initialized_before_decision=true,qualification_compatible=false})
local function state_fingerprint(s)
    -- Include source randomness and progression alongside the detached policy
    -- observation. This is a replay invariant, never an advisor RNG input.
    local canonical=replay_snapshot~=snapshot and replay_snapshot.capture(G) or s
    return PROBE_SHA256(replay_snapshot.fingerprint({snapshot=canonical,state=G.STATE,
        pseudorandom=replay_snapshot.copy(G.GAME.pseudorandom),pool_flags=replay_snapshot.copy(G.GAME.pool_flags),
        used_jokers=replay_snapshot.copy(G.GAME.used_jokers),round=replay_snapshot.copy(G.GAME.current_round),
        round_resets=replay_snapshot.copy(G.GAME.round_resets),source_game_won=not not G.GAME.won}))
end
local function score_prediction(choice)
    if not choice then return nil end
    return {score=choice.score,uncertain=not not choice.uncertain,
        reliable_bound=not not choice.reliable_bound,bound_kind=choice.bound_kind}
end
local active_decision
PROBE_EXPORT_FAILURE_CONTEXT=function()
    return json({type='engine_episode_failure_context',last_decision=active_decision,snapshot=snapshot.capture(G)})
end
local normal_terminal=PROBE_DECK and require('probe_normal_terminal').attach(G,trace,snapshot.copy)
if PROBE_DECK and PROBE_TEST_SCENARIO then
    G.GAME.seeded=false -- Declared synthetic progress-callback fixture only.
    trace({type='engine_normal_synthetic_progress_enabled',scenario=PROBE_TEST_SCENARIO,qualification=false})
end
local function completed()
    if normal_terminal then return normal_terminal:completed() end
    return G.PROFILES[G.SETTINGS.profile].challenge_progress.completed[G.GAME.challenge]==true
end
local function terminal(decisions)
    -- Original final-boss processing can set GAME.won before the loss check.
    -- Only successful completion of the in-memory profile is a win, and an
    -- actual loss wins precedence, including at development stop boundaries.
    local outcome=G.STATE==G.STATES.GAME_OVER and 'loss' or (completed() and 'win' or nil)
    if not outcome then return false end
    trace({type='engine_episode_terminal',outcome=outcome,challenge=G.GAME.challenge,seed=PROBE_SEED,
        ante=G.GAME.round_resets.ante,round=G.GAME.round,decisions=decisions,game_won=outcome=='win',
        source_game_won=not not G.GAME.won,source_profile_completed=completed(),
        state=G.STATE,game_over=G.STATE==G.STATES.GAME_OVER,
        normal_progress=normal_terminal and normal_terminal:evidence() or nil})
    trace({type='engine_episode_terminal_context',outcome=outcome,step=decisions,
        last_decision=active_decision,snapshot=snapshot.capture(G)})
    return true
end
local presentation_attention=attention_text
require('functions/UI_definitions')
attention_text=presentation_attention

DynaText=Moveable:extend()
function DynaText:init(config)
    Moveable.init(self,0,0,1,1)
    self.config=config or {};self.scale=self.config.scale or 1
    self.string=self.config.string;self.strings={{W=1,H=1,letters={}}}
end
function DynaText:update() end
function DynaText:update_text() end
function DynaText:pulse() end
function DynaText:pop_in() end
function DynaText:pop_out() end
function DynaText:align_letters() end
G.LANG={font={DESCSCALE=1,FONTSCALE=1,TEXT_HEIGHT_SCALE=1}}
G.LANGUAGES={['en-us']=G.LANG}
G.SPEEDFACTOR=1

local cashout_ready=false
require('engine/ui') -- Original method definitions only; no UI construction/rendering.
local source_ui_element_remove=assert(UIElement.remove,'Missing original UIElement removal')
local source_ui_box_remove=assert(UIBox.remove,'Missing original UIBox removal')
local function tree(def,parent,box)
    assert(type(def)=='table','HEADLESS_BOUNDARY invalid UI definition')
    local node=Moveable(0,0,(def.config or {}).minw or 1,(def.config or {}).minh or 1)
    node.config=def.config or {};node.parent=parent;node.UIBox=box
    node.children={};node.n=def.n
    -- Original UIElement removal owns config.object cleanup. These objects
    -- include shop/pack CardAreas: merely removing a Moveable leaves their
    -- unselected cards in the source used_jokers duplicate-exclusion pool.
    node.remove=source_ui_element_remove
    if node.config.object then node.config.object.parent=node end
    if node.config.id then box.ids[node.config.id]=node end
    for _,child in ipairs(def.nodes or {}) do node.children[#node.children+1]=tree(child,node,box) end
    return node
end
UIBox=Moveable:extend()
function UIBox:init(args)
    Moveable.init(self,0,0,8,8)
    self.config=args.config or {};self.ids={}
    self.alignment={offset=self.config.offset or {x=0,y=0}}
    self.UIRoot=tree(args.definition,self,self);self.children={self.UIRoot}
    if self.ids.cash_out_button then cashout_ready=true end
    table.insert(G.I[self.config.instance_type or 'UIBOX'],self)
end
function UIBox:get_UIE_by_ID(id) return self.ids[id] end
function UIBox:recalculate() end
function UIBox:align_to_major() end
function UIBox:add_child(def,parent)
    assert(parent,'HEADLESS_BOUNDARY missing UI parent')
    local node=tree(def,parent,self);parent.children[#parent.children+1]=node;return node
end
function UIBox:remove()
    return source_ui_box_remove(self)
end

-- The source itself disables run persistence through F_NO_SAVING. Settings and
-- progress retain an in-memory profile; never start the save thread.
Game.save_progress=function() end
local tick_count=0
local function tick()
    tick_count=tick_count+1
    assert(tick_count<1000000,'HEADLESS_BOUNDARY episode tick budget')
    for _,key in ipairs({'REAL','TOTAL','UPTIME'}) do G.TIMERS[key]=G.TIMERS[key]+1/60 end
    G.real_dt=1/60
    G.E_MANAGER:update(1/60)
    -- Match the original Game:update phase order, including SELECTING_HAND's
    -- STATE_COMPLETE latch; omitting it can schedule the same redraw twice.
    if G.STATE==G.STATES.SELECTING_HAND then
        -- Original Game:update handles an entirely destroyed held hand before
        -- update_selecting_hand. Omitting this guard falsely strands the run.
        if not G.hand.cards[1] and G.deck.cards[1] then
            G.STATE=G.STATES.DRAW_TO_HAND;G.STATE_COMPLETE=false
        else G:update_selecting_hand(1/60) end
    end
    if G.STATE==G.STATES.SHOP then G:update_shop(1/60) end
    if G.STATE==G.STATES.HAND_PLAYED then G:update_hand_played(1/60) end
    if G.STATE==G.STATES.DRAW_TO_HAND then G:update_draw_to_hand(1/60) end
    if G.STATE==G.STATES.NEW_ROUND then G:update_new_round(1/60) end
    if G.STATE==G.STATES.BLIND_SELECT then G:update_blind_select(1/60) end
    if G.STATE==G.STATES.ROUND_EVAL then G:update_round_eval(1/60) end
    if G.STATE==G.STATES.TAROT_PACK then G:update_arcana_pack(1/60) end
    if G.STATE==G.STATES.SPECTRAL_PACK then G:update_spectral_pack(1/60) end
    if G.STATE==G.STATES.STANDARD_PACK then G:update_standard_pack(1/60) end
    if G.STATE==G.STATES.BUFFOON_PACK then G:update_buffoon_pack(1/60) end
    if G.STATE==G.STATES.PLANET_PACK then G:update_celestial_pack(1/60) end
    -- Layout owns gameplay-relevant left/right coordinates (notably Death and
    -- ordered hand triggers). Normal CardArea:move calls this after array sorts.
    for _,area in ipairs(G.I.CARDAREA) do area:update(1/60);area:align_cards() end
    for _,card in ipairs(G.I.CARD) do if card:is(Card) then card:update(1/60) end end
end
local function until_state(predicate,max_frames)
    for _=1,max_frames or 10000 do tick();if predicate() then return end end
    error('HEADLESS_BOUNDARY unsettled phase '..tostring(G.STATE))
end
local function queue_busy()
    for _,events in pairs(G.E_MANAGER.queues) do
        for _,event in ipairs(events) do if event.blocking and not event.complete then return true end end
    end
    return (G.GAME.STOP_USE or 0)>0 or (G.GAME.blind and G.GAME.blind.block_play)
end
local function input_ready()
    if G.STATE==G.STATES.GAME_OVER then return true end
    if completed() then return true end
    if G.STATE==G.STATES.ROUND_EVAL then return cashout_ready and not queue_busy() end
    local phase=snapshot.capture(G).phase
    return (phase=='hand' or phase=='shop' or phase=='pack' or phase=='blind') and G.STATE_COMPLETE and not queue_busy()
end
local function selected(indices)
    return contract.select_cards(G.hand,indices,1,math.min(5,G.hand.config.highlighted_limit or 5),false)
end
local function selected_targets(card,indices)
    local config=card.ability and card.ability.consumeable
    assert(type(config)=='table','HEADLESS_BOUNDARY card is not a usable consumable')
    local maximum=config.max_highlighted or (card.ability.name=='Aura' and 1 or 0)
    local minimum=maximum>0 and (config.min_highlighted or 1) or 0
    if type(card.check_use)=='function' then
        assert(not card:check_use(),'HEADLESS_BOUNDARY source consumable preflight rejected use')
    end
    return contract.select_cards(G.hand,indices or {},minimum,math.min(5,maximum),maximum==0)
end
local function invoke(check,callback,e)
    e=e or {config={}}
    if check then
        assert(G.FUNCS[check],'HEADLESS_BOUNDARY missing legality check '..check)
        G.FUNCS[check](e)
        if not e.config.button then
            trace({type='engine_episode_illegal_action',check=check,decision=active_decision,
                controller_locked=not not G.CONTROLLER.locked,controller_locks=snapshot.copy(G.CONTROLLER.locks),
                hand_highlighted=#G.hand.highlighted})
        end
        assert(e.config.button,'HEADLESS_BOUNDARY policy action rejected by '..check)
        callback=e.config.button
    end
    assert(G.FUNCS[callback],'HEADLESS_BOUNDARY missing action callback '..tostring(callback))
    return G.FUNCS[callback](e)
end

if PROBE_JOKERLESS_RECIPE then
    -- The product admits search only at the settled, untouched Small Blind.
    -- Advance original initialization events before validating that same gate.
    until_state(input_ready)
    assert(modules.jokerless_opening and G.GAME.challenge=='c_jokerless_1' and PROBE_JOKERLESS_RECIPE.seed==PROBE_SEED,
        'HEADLESS_BOUNDARY declared Jokerless opening cannot be activated')
    local catalog,reason=modules.jokerless_opening.catalog(G)
    assert(catalog,'HEADLESS_BOUNDARY Jokerless source catalog: '..tostring(reason))
    local prediction_options
    if PROBE_JOKERLESS_RECIPE.target_planet~=nil or PROBE_JOKERLESS_RECIPE.target_hand~=nil then
        prediction_options={require_planet=PROBE_JOKERLESS_RECIPE.target_planet,target_hand=PROBE_JOKERLESS_RECIPE.target_hand}
    end
    local predicted;predicted,reason=modules.jokerless_opening.predict(PROBE_SEED,catalog,prediction_options)
    assert(predicted and modules.jokerless_opening.validate_result(predicted),
        'HEADLESS_BOUNDARY Jokerless initial prediction: '..tostring(reason))
    assert(snapshot.fingerprint(predicted)==snapshot.fingerprint(PROBE_JOKERLESS_RECIPE),
        'HEADLESS_BOUNDARY source catalog prediction differs from the frozen declared recipe')
    G.GAME.used_filter=true
    G.GAME.seeded=false -- Same explicitly filtered challenge-progress route as the product.
    G.GAME.filter_info={jokerless_opening=predicted,jokerless_catalog_signature=predicted.catalog_signature}
    trace({type='engine_jokerless_opening_initialized',recipe_digest=PROBE_JOKERLESS_RECIPE_DIGEST,
        mode='jokerless_coupon_blue_v1',source_seed=PROBE_SEED,policy_module_loaded=true,
        policy_module_digest=PROBE_JOKERLESS_MODULE_DIGEST,source_catalog_prediction_matched=true,
        filtered_challenge_progress=true,source_state=snapshot.capture(G),
        action_selection='frozen_product_advice',hand_policy='unchanged_autonomous_advisor',qualification=false})
end

local opening_result,opening_complete,opening_retained_signature
if PROBE_NORMAL_FILTER_RECIPE then
    until_state(input_ready)
    assert(G.GAME.challenge==nil and PROBE_NORMAL_FILTER_RECIPE.seed==PROBE_SEED and
      G.GAME.stake==PROBE_NORMAL_FILTER_RECIPE.stake and
      G.GAME.selected_back.effect.center.key==PROBE_NORMAL_FILTER_RECIPE.deck,
      'HEADLESS_BOUNDARY normal filter recipe differs from the source run')
    G.GAME.used_filter=true;G.GAME.seeded=false
    G.GAME.filter_info=snapshot.copy(PROBE_NORMAL_FILTER_RECIPE.filter_info)
    opening_result={legendary_jokers=snapshot.copy(PROBE_NORMAL_FILTER_RECIPE.expected_opening_jokers),required_sales=0}
    trace({type='engine_normal_opening_initialized',run_seed=PROBE_SEED,recipe_digest=PROBE_NORMAL_FILTER_DIGEST,
      filter_info=snapshot.copy(G.GAME.filter_info),source_state=snapshot.capture(G),
      action_selection='frozen_product_advice',native_search_executed=false,qualification=false})
end
if PROBE_OPENING_RAW then
    until_state(input_ready)
    local targets={};for key in PROBE_OPENING_TARGETS:gmatch('[^,]+') do targets[#targets+1]=key end
    local valid,reason=modules.opening.validate(G,{enabled=true,targets=targets})
    assert(valid,'HEADLESS_BOUNDARY filtered opening validation: '..tostring(reason))
    opening_result,reason=modules.opening.result(PROBE_OPENING_RAW,G.GAME.challenge,PROBE_OPENING_TARGETS)
    assert(opening_result and opening_result.status=='found','HEADLESS_BOUNDARY filtered native result: '..tostring(reason))
    assert(opening_result.seed==PROBE_SEED,'HEADLESS_BOUNDARY native seed differs from actual source run')
    G.GAME.used_filter=true
    G.GAME.filter_info={challenge_opening=true,challenge_id=opening_result.challenge_id,native_api_version='challenge_opening_v1',
      required_soul_count=2,soul_count=opening_result.soul_count,legendary_jokers=opening_result.legendary_jokers,
      required_sales=opening_result.required_sales,multi_soul_pack_consumed=false}
    G.GAME.seeded=false
    trace({type='engine_opening_initialized',run_seed=PROBE_SEED,required_sales=opening_result.required_sales,
        expected_pair=opening_result.legendary_jokers,source_state=snapshot.capture(G)})
end
local function check_opening_complete(step)
    if not opening_result or opening_complete then return false end
    local s=snapshot.capture(G)
    if s.phase~='blind' or s.blind_on_deck~='Big' or not G.GAME.filter_info.multi_soul_pack_consumed then return false end
    local pair={}
    for _,card in ipairs(s.jokers) do if modules.opening.legendary[card.key] then pair[#pair+1]=card.key end end
    local actual,expected=snapshot.copy(pair),snapshot.copy(opening_result.legendary_jokers)
    if PROBE_NORMAL_FILTER_RECIPE then table.sort(actual);table.sort(expected) end
    assert(#pair==2 and actual[1]==expected[1] and actual[2]==expected[2],
        'HEADLESS_BOUNDARY filtered source setup did not produce native Legendary pair')
    opening_complete=true
    opening_retained_signature=table.concat(pair,',')
    local elapsed=clock()-PROBE_HOST_STARTED
    trace({type='engine_opening_setup_complete',run_seed=PROBE_SEED,actual_pair=pair,decisions=step,
        required_sales=opening_result.required_sales,search_seconds=PROBE_OPENING_SEARCH_SECONDS,
        setup_seconds=elapsed-(PROBE_OPENING_SEARCH_SECONDS or 0),search_and_setup_seconds=elapsed,
        snapshot=s})
    if PROBE_STOP_ON_OPENING_COMPLETE then
        trace({type='engine_episode_stopped',outcome='censored',reason='development_opening_setup_complete',decisions=step})
        return true
    end
    return false
end
local function trace_opening_retention(step,action)
    if not opening_complete then return end
    local held={};for _,card in ipairs(G.jokers.cards) do held[card.config.center.key]=true end
    local retained,missing={},{}
    for _,key in ipairs(opening_result.legendary_jokers) do
        local list=held[key] and retained or missing;list[#list+1]=key
    end
    local signature=table.concat(retained,',')
    if signature~=opening_retained_signature then
        trace({type='engine_opening_pair_changed',step=step,action=action,retained=retained,missing=missing,
            ante=G.GAME.round_resets.ante,round=G.GAME.round,scope='observed_inventory_change_after_source_action'})
        opening_retained_signature=signature
    end
end

-- Explicit in-memory source fixtures. They remain tagged counterfactual in
-- provenance and can never enter the ordinary/filtered policy denominators.
if PROBE_TEST_SCENARIO then
    until_state(input_ready)
    if PROBE_TEST_SCENARIO=='ui_object_lifecycle' then
        local population_before=#G.playing_cards
        local function area_with(keys)
            local area=CardArea(0,0,4,2,{card_limit=5,type='shop',highlighted_limit=1})
            for _,key in ipairs(keys) do local card=create_card('Planet',area,nil,nil,nil,nil,key);area:emplace(card) end
            local box=UIBox{definition={n=G.UIT.ROOT,config={},nodes={{n=G.UIT.O,config={id='probe_area',object=area}}}},config={}}
            return area,box
        end
        local function available(key)
            local pool=get_current_pool('Planet')
            for _,value in ipairs(pool) do if value==key then return true end end
            return false
        end
        local legacy_area,legacy_box=area_with({'c_saturn'})
        assert(not available('c_saturn'),'Shown source Planet must be excluded')
        legacy_box:get_UIE_by_ID('probe_area').remove=Moveable.remove
        legacy_box:remove()
        local legacy_leak=legacy_area.cards and #legacy_area.cards==1 and G.GAME.used_jokers.c_saturn==true
        assert(legacy_leak,'Legacy Moveable-only node must reproduce live card/pool leakage')
        legacy_area:remove()
        assert(available('c_saturn'),'Original CardArea removal must release an unowned Planet')
        local owned=create_card('Planet',G.consumeables,nil,nil,nil,nil,'c_mercury')
        owned:add_to_deck();G.consumeables:emplace(owned)
        local initial_cards=#G.I.CARD
        local area,box=area_with({'c_saturn','c_mercury'})
        local before={saturn=available('c_saturn'),mercury=available('c_mercury'),cards=#G.I.CARD}
        box:remove()
        local after={saturn=available('c_saturn'),mercury=available('c_mercury'),cards=#G.I.CARD}
        assert(area.cards==nil and after.cards==initial_cards,'UI removal must retire original CardArea and both offered cards')
        assert(not before.saturn and not before.mercury and after.saturn and not after.mercury,
            'Removed offers must release unused keys while owned duplicate remains excluded')
        assert(#G.consumeables.cards==1 and G.consumeables.cards[1]==owned and not owned.removed,
            'UI cleanup must preserve actual owned inventory')
        owned:remove()
        assert(available('c_mercury') and #G.playing_cards==population_before,'Final owned removal releases its key without changing the playing population')
        trace({type='engine_source_ui_lifecycle_verified',scenario=PROBE_TEST_SCENARIO,
            legacy_leak_reproduced=legacy_leak,source_ui_element_remove=true,source_ui_box_remove=true,
            before=before,after=after,cardarea_removed=area.cards==nil,owned_duplicate_preserved=true,
            population_before=population_before,population_after=#G.playing_cards})
        trace({type='engine_episode_stopped',outcome='censored',reason='development_ui_object_lifecycle',decisions=0})
        return
    elseif PROBE_TEST_SCENARIO=='dagger_preblind' then
        assert(G.GAME.challenge=='c_knife_1','Dagger source fixture requires Knife challenge')
        local strong=create_card('Joker',G.jokers,nil,nil,nil,nil,'j_joker');strong.ability.mult=80
        strong:add_to_deck();G.jokers:emplace(strong)
        local fodder=create_card('Joker',G.jokers,nil,nil,nil,nil,'j_egg')
        fodder:add_to_deck();G.jokers:emplace(fodder)
        G.jokers:align_cards();G.jokers:set_ranks()
        trace({type='engine_source_scenario',scenario=PROBE_TEST_SCENARIO,jokers=snapshot.capture(G).jokers})
    elseif PROBE_TEST_SCENARIO=='empty_hand_refill' or PROBE_TEST_SCENARIO=='empty_hand_zero_limit' then
        invoke(nil,'select_blind',{config={ref_table=G.P_BLINDS.bl_small}})
        until_state(function() return G.STATE==G.STATES.SELECTING_HAND and not queue_busy() end)
        local deck_before=#G.deck.cards
        assert(deck_before>0,'Empty-hand fixture requires a nonempty draw population')
        -- Explicit fixture mutation, using original removals. This tests the
        -- Game:update boundary after destruction, not a particular Tarot's law.
        while #G.hand.cards>0 do G.hand.cards[#G.hand.cards]:remove() end
        if PROBE_TEST_SCENARIO=='empty_hand_zero_limit' then G.hand.config.card_limit=0 end
        assert(#G.hand.cards==0,'Fixture must start with an empty held hand')
        tick();until_state(input_ready)
        trace({type='engine_source_phase_verified',scenario=PROBE_TEST_SCENARIO,deck_before=deck_before,
            deck_after=#G.deck.cards,held_after=#G.hand.cards,state=G.STATE,game_over=G.STATE==G.STATES.GAME_OVER})
        if PROBE_TEST_SCENARIO=='empty_hand_zero_limit' then
            assert(G.STATE==G.STATES.GAME_OVER,'Original zero hand-size draw must lose');assert(terminal(0))
        else
            assert(G.STATE==G.STATES.SELECTING_HAND and #G.hand.cards>0,'Empty hand did not refill')
            assert(deck_before-#G.deck.cards==#G.hand.cards,'Refill did not conserve the draw population')
            trace({type='engine_episode_stopped',outcome='censored',reason='development_empty_hand_refill',decisions=0})
        end
        return
    elseif PROBE_TEST_SCENARIO=='forced_selection' then
        -- Synthetic boundary: original blind callback supplies a real forced
        -- object; every following selection and discard uses original CardArea.
        invoke(nil,'select_blind',{config={ref_table=G.P_BLINDS.bl_final_bell}})
        until_state(input_ready)
        local forced,index,other
        for i,card in ipairs(G.hand.cards) do
            if card.ability.forced_selection then forced=card;index=i else other=i end
        end
        assert(forced and other and #G.hand.highlighted==1,'Original Bell must force exactly one held card')
        -- Retain direct proof of why the old adapter changes the requested set.
        G.hand:unhighlight_all();G.hand:add_to_highlighted(forced,true)
        local legacy_duplicate=#G.hand.highlighted==2 and G.hand.highlighted[1]==G.hand.highlighted[2]
        assert(legacy_duplicate,'Original highlight methods must reproduce duplicate forced selection')
        G.hand.highlighted={forced}
        local omitted=not pcall(selected,{other})
        assert(omitted and #G.hand.highlighted==1 and G.hand.highlighted[1]==forced,'Omitted forced card must reject before mutation')
        selected({index,other})
        assert(#G.hand.highlighted==2 and G.hand.highlighted[1]~=G.hand.highlighted[2],'Exact selected set must remain unique')
        local planet=create_card('Planet',G.consumeables,nil,nil,nil,nil,'c_pluto')
        selected_targets(planet,{})
        local zero_target=#G.hand.highlighted==1 and G.hand.highlighted[1]==forced
        local strength=create_card('Tarot',G.consumeables,nil,nil,nil,nil,'c_strength')
        local targeted_rejected=not pcall(selected_targets,strength,{other})
        selected_targets(strength,{index,other})
        local targeted_exact=#G.hand.highlighted==2 and G.hand.highlighted[1]~=G.hand.highlighted[2]
        planet:remove();strength:remove()
        local population_before=#G.playing_cards
        local discarded_before=#G.discard.cards
        selected({index});invoke('can_discard',nil)
        for _=1,12 do tick() end
        until_state(input_ready)
        assert(#G.discard.cards==discarded_before+1 and G.discard.cards[#G.discard.cards]==forced,
            'Original discard must remove exactly the selected forced object')
        local population_seen,total={},0
        for _,area in ipairs({G.hand,G.deck,G.discard,G.play}) do for _,card in ipairs(area.cards) do
            assert(not population_seen[card],'Original source areas contain a duplicate playing object')
            population_seen[card]=true;total=total+1
        end end
        assert(total==population_before and #G.playing_cards==population_before,'Forced discard must conserve playing population')
        while #G.jokers.cards<G.jokers.config.card_limit do
            local joker=create_card('Joker',G.jokers,nil,nil,nil,nil,'j_joker');joker:add_to_deck();G.jokers:emplace(joker)
        end
        local ankh=create_card('Spectral',G.consumeables,nil,nil,nil,nil,'c_ankh')
        local ankh_rejected,ankh_reason=pcall(selected_targets,ankh,{})
        ankh_rejected=not ankh_rejected and tostring(ankh_reason):find('source consumable preflight rejected use',1,true)~=nil
        assert(ankh_rejected,'Original full-row Ankh no-op must fail adapter preflight')
        trace({type='engine_source_selection_verified',scenario=PROBE_TEST_SCENARIO,
            legacy_duplicate_reproduced=legacy_duplicate,omitted_forced_rejected=omitted,
            zero_target_preserves_forced=zero_target,targeted_omission_rejected=targeted_rejected,
            targeted_exact=targeted_exact,ankh_noop_rejected=ankh_rejected,discarded_count=#G.discard.cards-discarded_before,
            population_before=population_before,population_after=total,unique_population=true})
        assert(zero_target and targeted_rejected and targeted_exact,'Consumable target selection differs from product Execute')
        trace({type='engine_episode_stopped',outcome='censored',reason='development_forced_selection',decisions=1})
        return
    elseif PROBE_TEST_SCENARIO=='score_floor_play' or PROBE_TEST_SCENARIO=='selected_action_play' then
        invoke(nil,'select_blind',{config={ref_table=G.P_BLINDS.bl_small}})
        until_state(function() return G.STATE==G.STATES.SELECTING_HAND and not queue_busy() end)
        local keys=PROBE_TEST_SCENARIO=='score_floor_play' and {'j_joker','j_misprint'} or {'j_joker'}
        for _,key in ipairs(keys) do
            local card=create_card('Joker',G.jokers,nil,nil,nil,nil,key)
            if key=='j_joker' then card.ability.mult=80 end
            card:add_to_deck();G.jokers:emplace(card)
        end
        G.jokers:align_cards();G.jokers:set_ranks()
        local before=snapshot.capture(G)
        local floor,prediction_source
        if PROBE_TEST_SCENARIO=='score_floor_play' then
            floor=scoring.lower_bound(before,{1})
            assert(floor.reliable_bound and floor.bound_kind=='supported_random_floor','Missing supported Misprint floor')
        else
            floor,prediction_source=contract.selected_prediction(before,{kind='play',indices={1}},
                scoring.score(before,{1,2,3,4,5}),scoring)
            assert(prediction_source=='selected_action_rescore','Different specialist play must rescore selected indices')
        end
        local chips=G.GAME.chips;selected({1});invoke('can_play',nil)
        for _=1,12 do tick() end
        until_state(input_ready)
        local actual=G.GAME.chips-chips
        local verified,scope=contract.score_check(floor,actual)
        assert(verified,'HEADLESS_BOUNDARY score disagreement with supported random floor')
        trace({type='engine_episode_score_verified',scope=scope,predicted=floor.score,actual=actual,prediction_source=prediction_source})
        trace({type='engine_episode_stopped',outcome='censored',reason='development_source_score_floor',decisions=1})
        return
    elseif PROBE_TEST_SCENARIO=='failure_context' then
        active_decision={step=0,snapshot=snapshot.capture(G),action={kind='select_blind',blind=G.GAME.blind_on_deck}}
        error('HEADLESS_BOUNDARY synthetic failure context qualification')
    else
        G.GAME.round_resets.ante=G.GAME.win_ante
        G.GAME.round_resets.blind_choices.Boss='bl_wall'
        G.GAME.round_resets.blind_states={Small='Skipped',Big='Skipped',Boss='Select'}
        G.GAME.blind_on_deck='Boss'
        invoke(nil,'select_blind',{config={ref_table=G.P_BLINDS.bl_wall}})
        until_state(function() return G.STATE==G.STATES.SELECTING_HAND and not queue_busy() end)
        if PROBE_TEST_SCENARIO=='terminal_saved_final' or PROBE_TEST_SCENARIO=='terminal_unsaved_final' then
            local bones=create_card('Joker',G.jokers,nil,nil,nil,nil,'j_mr_bones');bones:add_to_deck();G.jokers:emplace(bones)
            G.GAME.chips=G.GAME.blind.chips/4-(PROBE_TEST_SCENARIO=='terminal_unsaved_final' and 1 or 0)
        else G.GAME.chips=PROBE_TEST_SCENARIO=='terminal_win_final' and G.GAME.blind.chips or 0 end
        G.GAME.current_round.hands_left=0
        G.STATE=G.STATES.NEW_ROUND;G.STATE_COMPLETE=false
        until_state(function() return G.STATE==G.STATES.GAME_OVER or completed() end)
        assert(terminal(0),'Original terminal fixture never resolved')
        return
    end
end
if PROBE_VERIFIED_REPLAY then
    assert(PROBE_SHA256(PROBE_UNLOCK_PROFILE_TEXT)==PROBE_VERIFIED_REPLAY.unlock_profile_digest,
        'REPLAY_MISMATCH source unlock profile')
end
local matching_decisions=0
for step=1,500 do
    until_state(input_ready)
    if terminal(step-1) then return end
    local capture_started=clock()
    local s=snapshot.capture(G)
    local capture_seconds=clock()-capture_started
    local fingerprint=state_fingerprint(s)
    local replay=PROBE_VERIFIED_REPLAY and PROBE_VERIFIED_REPLAY.prefix[step]
    local boundary=PROBE_VERIFIED_REPLAY and step==PROBE_REPLAY_BOUNDARY
    if replay or boundary then
        local expected=replay and replay.before or PROBE_VERIFIED_REPLAY.checkpoint
        assert(expected.state_fingerprint==fingerprint,'REPLAY_MISMATCH before decision '..step)
        assert(expected.phase==s.phase,'REPLAY_MISMATCH decision phase '..step)
    end
    active_decision={step=step,snapshot=s}
    trace({type='engine_episode_decision_started',step=step,phase=s.phase,snapshot=s,
        state_fingerprint=fingerprint,fingerprint_schema='source_decision_v1',
        ante=G.GAME.round_resets.ante,round=G.GAME.round})
    local decision_started,score_before=clock(),score_calls
    local skipped=replay and not PROBE_REPLAY_EVALUATE_PREFIX
    local result=not skipped and decision.run(s,modules) or nil
    local advisor_seconds=not skipped and clock()-decision_started or 0
    trace({type='engine_episode_profile',step=step,phase=s.phase,advisor_seconds=advisor_seconds,
        snapshot_seconds=capture_seconds,score_calls=score_calls-score_before,evaluations=result and result.evaluations,
        advisor_skipped=not not skipped,work_scope=skipped and 'verified_replay_prefix' or 'advisor_decision'})
    if PROBE_DEBUG_DECISIONS and result then trace({type='engine_episode_decision',step=step,snapshot=s,
        result=contract.trace_projection(result,PROBE_SHA256),diagnostics_projection='cache_keys_sha256_v1'}) end
    if replay and result then
        assert(snapshot.fingerprint(result.action)==snapshot.fingerprint(replay.before.action),
            'REPLAY_MISMATCH reevaluated policy action '..step)
    end
    local action=replay and replay.before.action or (boundary and PROBE_ACTION_OVERRIDE) or result and result.action
    active_decision={step=step,snapshot=s,action=action,pack_diagnostics=result and result.pack_diagnostics}
    assert(action,'HEADLESS_BOUNDARY advisor returned no machine action: '..s.phase..' '..tostring(result and result.strategy and result.strategy.title))
    local kind=action.kind
    if PROBE_OPENING_ONLY_ACTIONS then
      local allowed=kind=='skip_blind' and s.phase=='blind' and action.blind=='Small' and s.round==0 or
        kind=='choose' and s.phase=='pack' and action.area=='pack_cards' and
        s.pack_cards[action.index] and s.pack_cards[action.index].key=='c_soul'
      assert(allowed,'HEADLESS_BOUNDARY opening-only qualification refused non-opening action '..tostring(kind))
    end
    assert(contract.phase_allowed(kind,s.phase),'HEADLESS_BOUNDARY action is outside its executable phase')
    local choice=result and (kind=='discard' and result.discard or result.play)
    local prediction_source
    if kind=='play' and not (replay or boundary and PROBE_ACTION_OVERRIDE) then
        choice,prediction_source=contract.selected_prediction(s,action,choice,scoring)
    end
    if (replay or (boundary and PROBE_ACTION_OVERRIDE)) and kind=='play' then
        local expected=replay and replay.before.score_prediction
        choice=expected and expected.reliable_bound and scoring.lower_bound(s,action.indices) or scoring.score(s,action.indices)
        prediction_source='verified_replay_selected_action'
        if expected then
            assert(snapshot.fingerprint(score_prediction(choice))==snapshot.fingerprint(expected),
                'REPLAY_MISMATCH score prediction '..step)
        end
    end
    local match=result and not replay and (PROBE_STOP_AT_DECISION==s.phase or
        (PROBE_STOP_AT_DECISION=='tactical_shop' and s.phase=='shop' and result.shop_diagnostics and
            not result.shop_diagnostics.truncated and ((result.shop_diagnostics.metrics or {}).paired_comparisons or 0)>0) or
        (PROBE_STOP_AT_DECISION=='growth' and (result.growth or result.growth_diagnostics)) or
        (PROBE_STOP_AT_DECISION=='reroll' and kind=='reroll'))
    if match then matching_decisions=matching_decisions+1 end
    if boundary or (match and matching_decisions>=PROBE_DECISION_OCCURRENCE) then
        trace({type='engine_episode_checkpoint',step=step,phase=s.phase,snapshot=s,result=result,action=action,
            state_fingerprint=fingerprint,fingerprint_schema='source_decision_v1',replay_boundary=not not boundary})
        if (boundary and PROBE_STOP_AT_REPLAY_DECISION) or
            (PROBE_STOP_AT_DECISION and match and matching_decisions>=PROBE_DECISION_OCCURRENCE) then
            trace({type='engine_episode_stopped',outcome='censored',reason='development_decision_checkpoint',decisions=step-1,
                checkpoint_step=step,decision_class=PROBE_STOP_AT_DECISION})
            return
        end
    end
    local initial_chips=G.GAME.chips
    local initial_dollars=G.GAME.dollars
    local area=action.area and G[action.area]
    local card=area and area.cards[action.index]
    local e={config={ref_table=card}}
    local death_left,death_right
    if (kind=='use' or kind=='choose') and card and card.config.center.key=='c_death' then
        assert(action.targets and #action.targets==2,'HEADLESS_BOUNDARY Death requires two targets')
        death_left=G.hand.cards[math.min(action.targets[1],action.targets[2])]
        death_right=G.hand.cards[math.max(action.targets[1],action.targets[2])]
        assert(death_left and death_right and death_left.T.x<death_right.T.x,
            'HEADLESS_BOUNDARY Death target coordinates disagree with hand order')
    end
    print('EPISODE action',step,s.phase,kind,action.indices and table.concat(action.indices,',') or (card and card.config.center.key or ''),
        choice and (choice.score or choice.mean),G.GAME.dollars)
    trace({type='engine_episode_action',step=step,phase=s.phase,action=action,
        expected_score=kind=='play' and choice and choice.score or nil,dollars=G.GAME.dollars,
        score_bound=kind=='play' and choice and choice.bound_kind or nil,
        blind=G.GAME.blind.config.blind.key,ante=G.GAME.round_resets.ante,round=G.GAME.round,
        evaluations=result and result.evaluations,card_key=card and card.config.center.key,
        state_fingerprint=fingerprint,fingerprint_schema='source_decision_v1',
        score_prediction=kind=='play' and score_prediction(choice) or nil,
        prediction_source=prediction_source,
        advisor_skipped=not not skipped,offered_cards=s.phase=='pack' and s.pack_cards or nil,
        pack_diagnostics=result and result.pack_diagnostics,shop_diagnostics=result and result.shop_diagnostics})
    local engine_started,ticks_before=clock(),tick_count
    if kind=='reorder_jokers' or kind=='reorder_hand' then
        local reorder_area=kind=='reorder_hand' and G.hand or G.jokers
        assert(not queue_busy() and (not reorder_area.shuffle_amt or reorder_area.shuffle_amt==0),
            'HEADLESS_BOUNDARY reorder during unfinished movement')
        assert(not action.area or action.area==(kind=='reorder_hand' and 'hand' or 'jokers'),
            'HEADLESS_BOUNDARY reorder card area mismatch')
        assert(type(action.order)=='table' and #action.order==#reorder_area.cards,'HEADLESS_BOUNDARY incomplete card order')
        local ordered,expected,seen={},{},{}
        for position,index in ipairs(action.order) do
            local moved=reorder_area.cards[index]
            assert(moved and not seen[index] and moved.states.drag.can and not moved.states.drag.is and
                (kind=='reorder_hand' or moved.facing=='front'),'HEADLESS_BOUNDARY illegal card reorder')
            assert(not moved.pinned or position==index,'HEADLESS_BOUNDARY pinned card moved')
            seen[index]=true;ordered[position]=moved;expected[position]=moved
        end
        -- Manual dragging changes the CardArea's x-sorted array. Preserve the
        -- same objects and run the original layout/rank update after reordering.
        reorder_area.cards=ordered;reorder_area:align_cards();reorder_area:set_ranks()
        for position,moved in ipairs(expected) do
            assert(moved==reorder_area.cards[position],'HEADLESS_BOUNDARY source rejected card order')
        end
    elseif kind=='discard' then selected(action.indices);invoke('can_discard',nil)
    elseif kind=='play' then selected(action.indices);invoke('can_play',nil)
    elseif kind=='sell' then assert(card,'HEADLESS_BOUNDARY missing sale card');invoke('can_sell_card',nil,e)
    elseif kind=='buy' then
        assert(card,'HEADLESS_BOUNDARY missing purchase card')
        if action.area=='shop_vouchers' then invoke('can_redeem',nil,e) else
            assert(G.FUNCS.check_for_buy_space(card),'HEADLESS_BOUNDARY no space for purchase');invoke('can_buy',nil,e)
        end
    elseif kind=='buy_and_use' then
        assert(card and action.area=='shop_jokers','HEADLESS_BOUNDARY missing buy-and-use card')
        local box=card.children and card.children.buy_and_use_button
        e=box and (box:get_UIE_by_ID('buy_and_use') or box.UIRoot)
        assert(e and e.config.id=='buy_and_use' and e.config.ref_table==card,'HEADLESS_BOUNDARY missing buy-and-use UI')
        selected_targets(card,action.targets);invoke('can_buy_and_use',nil,e)
    elseif kind=='open' then assert(card,'HEADLESS_BOUNDARY missing booster');invoke('can_open',nil,e)
    elseif kind=='choose' then
        assert(card,'HEADLESS_BOUNDARY missing pack card')
        if card.ability.consumeable then selected_targets(card,action.targets)
        else assert(not action.targets or #action.targets==0,'HEADLESS_BOUNDARY pack card cannot accept targets') end
        invoke(card.ability.consumeable and 'can_use_consumeable' or 'can_select_card',nil,e)
    elseif kind=='use' then assert(card,'HEADLESS_BOUNDARY missing consumable');selected_targets(card,action.targets);invoke('can_use_consumeable',nil,e)
    elseif kind=='cash_out' then
        print('EPISODE round payout',G.GAME.current_round.dollars)
        cashout_ready=false;invoke(nil,'cash_out')
    elseif kind=='leave_shop' then invoke(nil,'toggle_shop')
    elseif kind=='reroll' then invoke('can_reroll',nil)
    elseif kind=='skip_pack' then invoke('can_skip_booster',nil)
    elseif kind=='select_blind' then
        assert(action.blind==G.GAME.blind_on_deck,'HEADLESS_BOUNDARY wrong selected blind')
        local key=G.GAME.round_resets.blind_choices[G.GAME.blind_on_deck]
        invoke(nil,'select_blind',{config={ref_table=assert(G.P_BLINDS[key],'HEADLESS_BOUNDARY invalid blind key')}})
    elseif kind=='skip_blind' then
        local blind=action.blind or G.GAME.blind_on_deck
        assert(blind==G.GAME.blind_on_deck and blind~='Boss' and G.GAME.round_resets.blind_states[blind]=='Select',
            'HEADLESS_BOUNDARY illegal blind skip')
        local box=(G.blind_select_opts or {})[string.lower(blind)]
        local tag=box and box:get_UIE_by_ID('tag_'..blind)
        local container=box and box:get_UIE_by_ID('tag_container')
        local button=tag and tag.children[2]
        assert(container and container.config.ref_table and container.states.visible~=false and button and
            button.UIBox==box and button.config.button=='skip_blind','HEADLESS_BOUNDARY missing enabled blind skip button')
        invoke(nil,'skip_blind',button)
    else error('HEADLESS_BOUNDARY unsupported action '..tostring(kind)) end
    -- Let the source action enter its transition before checking input again.
    for _=1,12 do tick() end
    until_state(input_ready)
    print('EPISODE action resolved',G.STATE,G.GAME.chips-initial_chips,G.GAME.dollars-initial_dollars,G.GAME.current_round.hands_left,G.GAME.current_round.discards_left)
    local after_fingerprint=state_fingerprint(snapshot.capture(G))
    if replay then
        local after=replay.after
        assert(after.state_fingerprint==after_fingerprint,'REPLAY_MISMATCH after action '..step)
        assert(after.state==G.STATE and after.chips_delta==G.GAME.chips-initial_chips and
            after.dollars_delta==G.GAME.dollars-initial_dollars and after.hands_left==G.GAME.current_round.hands_left and
            after.discards_left==G.GAME.current_round.discards_left,'REPLAY_MISMATCH resolved effects '..step)
        trace({type='engine_episode_replay_verified',step=step,advisor_skipped=not not skipped,
            before_fingerprint=fingerprint,after_fingerprint=after_fingerprint,
            checks={'source_state','phase','source_legality','score_prediction','resolved_effects'}})
    end
    trace({type='engine_episode_resolved',step=step,state=G.STATE,chips_delta=G.GAME.chips-initial_chips,
        state_fingerprint=after_fingerprint,fingerprint_schema='source_decision_v1',
        engine_seconds=clock()-engine_started,engine_ticks=tick_count-ticks_before,
        dollars_delta=G.GAME.dollars-initial_dollars,hands_left=G.GAME.current_round.hands_left,
        discards_left=G.GAME.current_round.discards_left,
        joker_order=(kind=='reorder_jokers' or kind=='select_blind') and snapshot.capture(G).jokers or nil,
        hand_order=kind=='reorder_hand' and snapshot.capture(G).hand or nil})
    if kind=='play' and choice and not choice.uncertain then
        local actual=G.GAME.chips-initial_chips
        local verified,scope=contract.score_check(choice,actual)
        if not verified then
            trace({type='engine_episode_score_mismatch',step=step,snapshot=s,action=action,
                predicted=choice.score,actual=actual,scope=scope,choice=choice})
        end
        assert(verified,'HEADLESS_BOUNDARY score disagreement: '..scope)
        trace({type='engine_episode_score_verified',step=step,scope=scope,predicted=choice.score,actual=actual})
    elseif kind=='play' then
        trace({type='engine_episode_score_unverified',step=step,scope='unverified_random_or_unknown_prediction',
            predicted=choice and choice.score,actual=G.GAME.chips-initial_chips,prediction_source=prediction_source,
            reason='The original source resolves the play, but this forecast is not an exact score or supported floor'})
    end
    if death_left then
        local function copied_fields(c)
            return {rank=c.base.id,suit=c.base.suit,enhancement=c.config.center.key,
                edition=snapshot.copy(c.edition),seal=c.seal,perma_bonus=c.ability.perma_bonus}
        end
        assert(snapshot.fingerprint(copied_fields(death_left))==snapshot.fingerprint(copied_fields(death_right)),
            'HEADLESS_BOUNDARY Death did not copy right target into left')
        trace({type='engine_episode_effect_verified',effect='Death',step=step,
            left=snapshot.card(death_left),right=snapshot.card(death_right)})
    end
    if terminal(step) then return end
    if check_opening_complete(step) then return end
    trace_opening_retention(step,action)
    if PROBE_STOP_AFTER_STEP and step>=PROBE_STOP_AFTER_STEP then
        trace({type='engine_episode_stopped',outcome='censored',reason='development_action_limit',decisions=step})
        return
    end
    if PROBE_STOP_ON_ROUND_END and G.GAME.round==PROBE_STOP_ON_ROUND_END and G.STATE==G.STATES.ROUND_EVAL then
        trace({type='engine_episode_stopped',outcome='censored',reason='development_round_boundary',
            decisions=step,round=G.GAME.round,chips=G.GAME.chips,blind_chips=s.blind.chips,
            hands_left=G.GAME.current_round.hands_left})
        return
    end
end
trace({type='engine_episode_stopped',outcome='censored',reason='development_action_budget',decisions=500})
