-- Integration deliberately keeps the advisor out of saves and run RNG state.
local A = {display = {title = 'Run Advisor', status = 'Waiting for a decision'}, elapsed = 0, page = 1}
local function module(name)
  local nfs = require('nativefs')
  return assert(load(nfs.read(Brainstorm.PATH .. '/Advisor/' .. name .. '.lua'), '@Advisor/' .. name .. '.lua'))()
end
A.snapshot, A.scoring, A.search, A.strategy = module('snapshot'), module('scoring'), module('search'), module('strategy')
A.gold_stickers = module('gold_stickers')
A.gold_perkeo = module('gold_perkeo')
A.perkeo_inventory = module('perkeo_inventory')
A.gold_planet_policy = module('gold_planet_policy')
A.snapshot.perkeo_inventory = A.perkeo_inventory
A.bell_opening = module('bell_opening')
A.certificate=module('certificate')
A.snapshot.certificate=A.certificate
A.gold_goal = module('gold_goal')
A.gold_slot = module('gold_slot')
A.gold_slot.gold_goal = A.gold_goal
A.gold_slot.gold_perkeo = A.gold_perkeo
A.gold_slot.bell_opening = A.bell_opening
A.strategy.gold_slot = A.gold_slot
A.joker_retirement = module('joker_retirement')
A.strategy.joker_retirement = A.joker_retirement
A.gold_goal.gold_slot = A.gold_slot
A.gold_tarot_hold = module('gold_tarot_hold')
A.gold_slot.gold_tarot_hold = A.gold_tarot_hold
A.snapshot.gold_tarot_hold = A.gold_tarot_hold
A.gold_acquisition = module('gold_acquisition')
A.gold_order = module('gold_order')
A.gold_retention = module('gold_retention')
A.gold_search = module('gold_search')
A.normal_opening=module('normal_opening')
A.normal_opening.gold_stickers=A.gold_stickers
A.normal_opening.gold_search=A.gold_search
A.snapshot.normal_opening=A.normal_opening
A.consumables = module('consumables')
A.strategy.consumables = A.consumables
A.strategy.conditional_value = module('conditional_value')
A.deck_development = module('deck_development')
A.spectral_development = module('spectral_development')
A.deck_development.spectral = A.spectral_development
A.consumables.deck_development = A.deck_development
A.strategy.deck_development = A.deck_development
A.economy = module('economy')
A.shop_scoring = module('shop_scoring')
A.shop_scoring.gold_goal=A.gold_goal
A.shop_scoring.bell_opening=A.bell_opening
A.shop_scoring.certificate=A.certificate
A.shop_scoring.paired_deck = module('paired_deck')
A.shop_scoring.blind_start = module('blind_start')
A.shop_sequences = module('shop_sequences')
A.shop_sequences.gold_slot = A.gold_slot
A.pack_scoring = module('pack_scoring')
A.strategy.pack_scoring = A.pack_scoring
A.pack_survival = module('pack_survival')
A.strategy.pack_survival = A.pack_survival
A.execution = module('execution')
A.ordering = module('ordering')
A.phase_copy = module('phase_copy')
A.hand_copy_preflight = module('hand_copy_preflight')
A.hand_ordering = module('hand_ordering')
A.boss_rescue = module('boss_rescue')
A.mixed_rescue = module('mixed_rescue')
A.multi_discard = module('multi_discard')
A.two_hand_finish = module('two_hand_finish')
A.resource_finish = module('resource_finish')
A.concealed_belief = module('concealed_belief')
A.acorn_belief=module('acorn_belief')
A.acorn_ordering=module('acorn_ordering')
A.acorn_discard=module('acorn_discard')
A.acorn_public=module('acorn_public')
A.acorn_public_hooks=module('acorn_public_hooks')
A.growth = module('growth')
A.finish_rewards = module('finish_rewards')
A.score_cache = module('score_cache')
A.draws = module('draws')
A.sampled_outcomes = module('sampled_outcomes')
A.policy_weights = module('policy_weights')
A.work_cost = module('work_cost')
A.shop_scoring.work_cost=A.work_cost
A.shop_scoring.policy_weights=A.policy_weights
A.search.policy_weights=A.policy_weights
A.growth.policy_weights=A.policy_weights
A.blind_prep = module('blind_prep')
A.blind_prep.blind_start=A.shop_scoring.blind_start
A.shop_scoring.blind_prep = A.blind_prep
A.shop_scoring.strategy = A.strategy
A.blind_routing = module('blind_routing')
A.opening = Brainstorm.ChallengeOpening
A.jokerless_opening = Brainstorm.JokerlessOpening
A.challenge_route = module('challenge_route')
A.decision = module('decision')
A.retry_memory, A.retry_policy, A.retry_journal = module('retry_memory'), module('retry_policy'), module('retry_journal')
A.retry_generation, A.state_epoch = 0, 0
A.strategy.synergies = module('synergies')
A.strategy.paid_reroll = module('paid_reroll')
A.strategy.paid_reroll.catalog = module('catalog_joker')
A.strategy.paid_reroll.policy_weights=A.policy_weights
A.liquidity=module('liquidity')
A.liquidity.snapshot=A.snapshot
A.shop_scoring.liquidity=A.liquidity
A.strategy.liquidity=A.liquidity
A.strategy.paid_reroll.liquidity=A.liquidity
A.strategy.conditional_value.liquidity=A.liquidity
A.blind_finishing=module('blind_finishing')
A.blind_finishing.pack_survival=A.pack_survival
for _,key in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards','strategy'}) do
  A.blind_finishing[key]=A[key]
end
A.shop_scoring.blind_finishing=A.blind_finishing

function A.defaults()
  local config = Brainstorm.config
  if type(config.advisor) ~= 'table' then config.advisor = {} end
  if config.advisor.enabled == nil then config.advisor.enabled = true end
  if config.advisor.challenge_only == nil then config.advisor.challenge_only = false end
  if config.advisor.hud == nil then config.advisor.hud = true end
  if config.advisor.gold_stickers == nil then config.advisor.gold_stickers = false end
  if config.advisor.player_logging == nil then config.advisor.player_logging = false end
  if config.advisor.manual_logging == nil then config.advisor.manual_logging = true end
end
A.defaults()

A.performance=module('performance').new({enabled=function()
  return Brainstorm.config.advisor.player_logging==true or A.manual_log and A.manual_log:is_active(G)==true
end})
local P=A.performance

function A.gold_status()
  return A.gold_stickers.capture(G,{enabled=Brainstorm.config.advisor.gold_stickers==true,
    public_held=A.public_joker_tracker and A.public_joker_tracker:public_held(G)})
end
-- Collection history is public objective context, never draw order or run RNG.
-- The runtime alone opts in; detached/source evaluation captures stay unchanged.
-- Every existing capture, publication and execution check sees the same context,
-- so a profile switch or newly awarded sticker makes old advice stale.
local capture_without_gold=A.snapshot.capture
A.snapshot.capture=function(g)
  local started=P:now()
  local snapshot=capture_without_gold(g)
  if snapshot and Brainstorm.config.advisor.gold_stickers==true then
    snapshot.completionist_goal=A.gold_stickers.capture(g,{enabled=true,
      public_held=A.public_joker_tracker and A.public_joker_tracker:public_held(g)})
    if A.teacher_profile=='perkeo_yorick_win_v1' then
      -- Keep the observed ledger for imitation context, while suppressing
      -- optional collection cargo trades during the win-first teacher pilot.
      snapshot.collection_progress=snapshot.completionist_goal
      snapshot.completionist_goal=nil
      snapshot.teacher_profile=A.teacher_profile
    end
  end
  if snapshot and A.shop_sequence_game==g.GAME and A.shop_sequence_pending then
    snapshot.shop_sequence_commitment=A.shop_sequences.observe_commitment(snapshot,A.shop_sequence_pending,A)
  end
  P:finish('snapshot.capture',started)
  return snapshot
end
local fingerprint_without_timing=A.snapshot.fingerprint
A.snapshot.fingerprint=function(value)
  local started=P:now()
  local key=fingerprint_without_timing(value)
  P:finish('snapshot.fingerprint',started)
  return key
end

function A.active()
  A.defaults()
  return G and G.GAME and G.STAGE == G.STAGES.RUN and Brainstorm.config.advisor.enabled
    and (not Brainstorm.config.advisor.challenge_only or G.GAME.challenge)
end

local function ready()
  if not A.active() or Brainstorm.ar_active or Brainstorm.native_search_busy or G.screenwipe then return false end
  local controller = G.CONTROLLER
  -- Opening AND closing overlays introduces presentation locks. The aggregate
  -- controller.locked can also remain true for a frame after its locks clear.
  -- Neither changes scoring inputs; gameplay locks below still cancel advice.
  local locks = controller and controller.locks or {}
  for name, locked in pairs(locks) do
    if locked and name ~= 'frame' and name ~= 'frame_set' then return false end
  end
  for _,area in ipairs({G.hand or {},G.pack_cards or {}}) do
    for _,card in ipairs(area.cards or {}) do
      if not A.snapshot.presentation_settled(card) then return false end
    end
  end
  return G.STATE_COMPLETE and not (G.GAME.blind and G.GAME.blind.block_play)
end

local function dragging()
  return G.CONTROLLER and G.CONTROLLER.dragging and G.CONTROLLER.dragging.target
end

local function invalidate(status)
  P:finish_decision(A.worker_perf,'cancelled')
  A.worker_perf,A.last_decision_timing,A.last_decision_result=nil,nil,nil
  A.state_epoch = A.state_epoch + 1
  local changed = A.display.title ~= 'Run Advisor' or A.display.status ~= status
    or A.selection or A.result or A.worker or A.current
  A.worker, A.key, A.selection, A.current, A.result = nil, nil, nil, nil, nil
  A.published_key = nil
  A.display.title, A.display.status, A.lines = 'Run Advisor', status, {status}
  if changed and A.menu_open and G.OVERLAY_MENU and A.render_menu then A.render_menu() end
end

-- Configuration changes invalidate published work and old UI tokens, while the
-- persistent retry count and any already-queued action's duplicate latch remain.
-- Recalculation waits for the ordinary update path and its existing ready checks.
function A.settings_changed()
  if Brainstorm.AutoRun then Brainstorm.AutoRun:manual('Advisor settings changed.','settings') end
  if Brainstorm.CollectionSearchProduct and not (Brainstorm.AutoRun and
    (Brainstorm.AutoRun:owned() or Brainstorm.AutoRun.engaged and Brainstorm.AutoRun:engaged())) then
    Brainstorm.CollectionSearchProduct.stop('Advisor settings changed.')
  end
  A.retry_generation=A.retry_generation+1
  A.published_generation,A.published_game,A.published_identity=nil,nil,nil
  A.hud_action_key,A.hud_retry_generation=nil,nil
  A.elapsed=0
  invalidate('Settings changed; waiting for fresh advice.')
end

-- Seed/profile identity is used only for an external metadata ledger, never
-- inserted into scoring snapshots or deterministic sample keys. Ambiguous new
-- runs with the same identity inherit the old cap instead of renewing it.
local function retry_identity(s)
  local game=G and G.GAME or {};local values={
    (G.SETTINGS or {}).profile,(game.pseudorandom or {}).seed,
    s.challenge or 'normal',s.deck_key,game.stake}
  local parts={}
  for i=1,5 do
    local value=values[i]
    if type(value)~='string' and type(value)~='number' then return nil end
    value=tostring(value);if #value==0 or #value>96 or value:find('%c') then return nil end
    parts[#parts+1]=#value..':'..value
  end
  local id=table.concat(parts,'|');if #id>256 then return nil end;return id
end
local function retry_store()
  if A.retry_store then return A.retry_store end
  local fs=love and love.filesystem
  if not fs or not fs.getInfo or not fs.read or not fs.write then return nil,'Retry metadata storage is unavailable.' end
  local names={data='advisor_retry_metadata_v1.dat',guard='advisor_retry_metadata_v1.guard'}
  A.retry_store=A.retry_journal.new({
    read=function(which,limit)
      local info=fs.getInfo(names[which])
      if not info then return nil,'missing' end
      if info.type~='file' or not info.size or info.size>limit then return nil,'Invalid retry metadata file.' end
      return fs.read(names[which])
    end,
    write=function(which,bytes) return fs.write(names[which],bytes) end,
  },A.retry_memory)
  return A.retry_store
end
local function retry_context(s)
  local id=retry_identity(s)
  if not id then return {active=false,reason='Stable profile, seed, deck and stake identity is unavailable.'} end
  local store,reason=retry_store();if not store then return {active=false,reason=reason},id end
  local ledger;ledger,reason=store:get(id)
  if not ledger then return {active=false,unavailable=true,reason=reason},id end
  if not ledger.checkpoint then return {active=false,valid=true,reloads_used=ledger.reloads_used,reloads_remaining=5-ledger.reloads_used},id,ledger end
  return A.retry_memory.context(ledger,id,s),id,ledger
end
local function metadata_ready()
  return ready() and not dragging() and (not G.OVERLAY_MENU or A.menu_open)
    and (G.GAME.STOP_USE or 0)<=0 and not (G.play and G.play.cards and #G.play.cards>0)
end
function A.retry_status()
  local s=A.snapshot.capture(G)
  if not metadata_ready() or not s or s.phase=='other' then return {text='Checkpoint controls wait for a settled decision.'} end
  local context,id,ledger=retry_context(s)
  if not ledger then return {text=context.reason or 'Retry memory unavailable.'} end
  local public=A.retry_memory.public_key(s)
  local current_key=A.snapshot.fingerprint(s)
  local action=A.result and current_key==A.published_key and A.result.action
  local can_mark=public~=nil and action and A.retry_memory.action_key(s,action)~=nil and not A.worker and not A.execution_key
  local can_report=context.matched and context.pending~=nil and context.reloads_remaining>0
  local text='Manual reloads reported: '..context.reloads_used..'/5.'
  if context.matched and context.pending then text=text..' Recorded line: confirm only after restoring from a loss.'
  elseif context.matched then text=text..' This decision is marked.'
  elseif ledger.checkpoint then text=text..' Waiting for the marked public state.' end
  return {text=A.retry_notice or text,can_mark=can_mark,can_report=can_report,
    token={key=current_key,generation=A.retry_generation,epoch=A.state_epoch,id=id,game=G.GAME}}
end
local function retry_mutation(method,token)
  if Brainstorm.AutoRun then Brainstorm.AutoRun:manual('Manual checkpoint advice changed.','checkpoint') end
  if not metadata_ready() or type(token)~='table' or token.generation~=A.retry_generation or token.epoch~=A.state_epoch or token.game~=G.GAME then return false end
  local s=A.snapshot.capture(G)
  if not s or A.snapshot.fingerprint(s)~=token.key or retry_identity(s)~=token.id then return false end
  local context,id,ledger=retry_context(s)
  if not ledger then A.retry_notice=context.reason;return false end
  if method=='mark' then
    local status=A.retry_status();if not status.can_mark then return false end
  elseif not context.matched or not context.pending or context.reloads_remaining<=0 then return false end
  local next_ledger,reason=A.retry_memory[method](ledger,id,s)
  if next_ledger then next_ledger,reason=A.retry_store:put(next_ledger) end
  if not next_ledger then
    A.retry_notice=tostring(reason)
    A.retry_generation=A.retry_generation+1
    invalidate('Retry metadata could not be verified')
    if A.menu_open and A.render_menu then A.render_menu() end
    return false
  end
  A.retry_generation=A.retry_generation+1;A.retry_notice=nil
  -- Only a verified explicit restored-after-loss report may release an
  -- identical-state execution latch. Marking is not a restore operation.
  if method=='failed' then A.execution_key=nil end
  invalidate('Refreshing checkpoint advice...');A.refresh();return true
end
function A.remember_checkpoint(token) return retry_mutation('mark',token) end
function A.report_checkpoint_loss(token) return retry_mutation('failed',token) end

local ranks = {[11] = 'J', [12] = 'Q', [13] = 'K', [14] = 'A'}
function A.card_names(s, indices)
  local result = {}
  for _, i in ipairs(indices or {}) do
    local c = s.hand[i]
    if c then
      result[#result + 1] = '#' .. i .. ' ' .. ((c.face_down or c.facing=='back' or not c.rank or not c.suit) and 'Face-down card' or c.enhancement == 'm_stone' and 'Stone'
        or ((ranks[c.rank] or tostring(c.rank or '?')) .. string.sub(c.suit or '?', 1, 1)))
    end
  end
  return table.concat(result, ', ')
end
function A.joker_names(s, indices)
  local result = {}
  for _, i in ipairs(indices or {}) do
    local joker = s.jokers[i]
    if joker then result[#result + 1] = '#' .. i .. ' ' .. (joker.name or (joker.ability or {}).name or joker.key or 'Joker') end
  end
  return table.concat(result, ' -> ')
end
local function number(value)
  if type(value) ~= 'number' then return '?' end
  if value >= 1000000 then return string.format('%.2g', value) end
  return tostring(math.floor(value + 0.5))
end
local function append(lines, extras) for _, v in ipairs(extras or {}) do lines[#lines + 1] = v end end

function A.present(s, result, final)
  -- Search reports its best immediate play before comparing discard draws.
  -- Publish only a completed decision so the badge and selection never expose
  -- a provisional play that later turns into a different action.
  if not final then return end
  local strategy = result and result.strategy or A.strategy.advise(s, {tactical_consumables = s.phase == 'hand'})
  local lines, warnings = {}, {}
  local title = strategy.title or 'Review the current decision'
  local selection, status
  if result and result.retry then
    title=result.retry.review_only and 'Checkpoint retry needs review' or 'Try another checkpoint line'
    status='Manual reloads reported: '..tostring(result.retry.reloads_used or 0)..'/5'
    append(lines,result.retry.lines)
    local action=result.action
    if action and (action.kind=='play' or action.kind=='discard') then
      lines[#lines+1]=action.kind..': '..A.card_names(s,action.indices)
      selection={kind=action.kind,indices=action.indices}
      if action.kind=='play' and result.play then lines[#lines+1]=tostring(result.play.hand)..' ~'..number(result.play.score)..' chips.' end
    elseif action then
      lines[#lines+1]=strategy.title or 'Review the selected alternative.'
      lines[#lines+1]='Action: '..action.kind..' in '..tostring(action.area)..', position '..tostring(action.index or '?')..'.'
    end
  elseif result and result.public_joker_belief then
    local belief=result.public_joker_belief
    status=belief.supported and (result.action and result.action.kind=='discard' and
      'Public Joker sampled redraw' or 'Public Joker score floor') or 'Public Joker advice unavailable'
    if belief.bound_kind=='public_retained_clear_floor' then status='Public Joker retained clearing floor' end
    local action=result.action
    if action and action.kind=='reorder_jokers' then
      local slots={};for _,slot in ipairs(action.order or {})do slots[#slots+1]='#'..tostring(slot)end
      lines[#lines+1]='Move the current Joker slots left to right: '..table.concat(slots,', ')
      lines[#lines+1]='Execute rearranges the visible backs; wait for fresh advice before playing.'
    elseif action and (action.kind=='play' or action.kind=='discard') then
      lines[#lines+1]=A.card_names(s,action.indices)
      selection={indices=action.indices,kind=action.kind}
    end
    if result.play and result.play.score then
      lines[#lines+1]='Lowest supported score across '..tostring(belief.worlds or '?')..' possible rows: '..number(result.play.score)..' chips.'
    end
  elseif result and result.concealed_belief then
    if result.action then
      lines[#lines+1]=A.card_names(s,result.action.indices)
      selection={indices=result.action.indices,kind=result.action.kind}
    end
    status=result.concealed_belief.supported and 'Concealed-card estimate' or 'Concealed-card advice unavailable'
    if result.concealed_belief.scope=='visible_retained_floor' then status='Visible retained clearing floor' end
  elseif s.phase == 'hand' and result then
    local play, discard = result.play, result.discard
    if result.mixed_rescue then
      title=result.mixed_rescue.title
      lines[#lines+1]='Left to right: '..A.joker_names(s,result.mixed_rescue.action.order)
      append(lines,result.mixed_rescue.lines);append(warnings,result.mixed_rescue.warnings)
    elseif result.boss_rescue then
      title=result.boss_rescue.title
      append(lines,result.boss_rescue.lines);append(warnings,result.boss_rescue.warnings)
    elseif result.hand_ordering then
      local reorder=result.hand_ordering
      title=reorder.title
      lines[#lines+1]='Left to right: '..A.card_names(s,reorder.action.order)
      lines[#lines+1]='Click Execute to reorder, then wait for fresh advice before playing.'
      append(lines,reorder.lines);append(warnings,reorder.warnings)
      if reorder.play then lines[#lines+1]='After reordering: '..reorder.play.hand..' ~'..number(reorder.play.score)..' chips.' end
    elseif result.ordering then
      local reorder = result.ordering
      title = reorder.title
      lines[#lines + 1] = 'Left to right: ' .. A.joker_names(s, reorder.action.order)
      lines[#lines + 1] = 'Numbers refer to the current Joker positions. Close this panel and click Execute, or drag them into that order, then wait for fresh advice.'
      -- The module keeps an order line for headless traces; the panel uses its
      -- own card-name formatter above, so avoid showing the same order twice.
      for i,line in ipairs(reorder.lines or {}) do
        if i~=1 or line:sub(1,1)~='#' then lines[#lines+1]=line end
      end
      append(warnings, reorder.warnings)
      if reorder.play then
        lines[#lines + 1] = 'After reordering: best estimated ' .. reorder.play.hand .. ' ~' .. number(reorder.play.score) .. ' chips.'
      end
    elseif result.growth then
      local growth=result.growth
      title=growth.title
      lines[#lines+1]=A.card_names(s,growth.action.indices)
      append(lines,growth.lines);append(warnings,growth.warnings)
      selection={indices=growth.action.indices,kind=growth.action.kind}
    elseif result.consumable and not (result.two_hand_finish and result.two_hand_finish.replaces_consumable) then
      local use = result.consumable
      title = use.title
      local targets = use.action.targets or {}
      if #targets > 0 then
        lines[#lines + 1] = 'Target cards: ' .. A.card_names(s, targets)
        selection = {indices = targets, kind = 'use', consumable_index = use.action.index}
      end
      lines[#lines + 1] = 'Use consumable #' .. tostring(use.action.index) .. ' in your inventory, then let the advisor recalculate.'
      append(lines, use.lines)
      append(warnings, use.warnings)
      if use.play then
        lines[#lines + 1] = 'After use: best estimated ' .. use.play.hand .. ' ~' .. number(use.play.score) .. ' chips.'
      end
    elseif result.multi_discard then
      local plan=result.multi_discard
      title='Discard '..#plan.indices..' cards for a two-discard plan'
      lines[#lines+1]=A.card_names(s,plan.indices)
      lines[#lines+1]=plan.reason
      lines[#lines+1]='The estimate is a small simulation; it is not a calibrated win probability.'
      selection={indices=plan.indices,kind='discard'}
    elseif result.two_hand_finish then
      local plan=result.two_hand_finish
      local horizon=(({[2]='two',[3]='three',[4]='four',[5]='five'})[plan.horizon or 2] or tostring(plan.horizon))..'-hand finish'
      if plan.action.kind=='use' then
        title='Use '..tostring(plan.consumable_name or 'consumable')..' for a '..horizon
        local targets=plan.action.targets or {}
        if #targets>0 then
          lines[#lines+1]='Target cards: '..A.card_names(s,targets)
          selection={indices=targets,kind='use',consumable_index=plan.action.index}
        end
        lines[#lines+1]='Use consumable #'..tostring(plan.action.index)..' in your inventory, then let the advisor recalculate.'
      else
        title=(plan.action.kind=='play' and 'Play ' or 'Discard ')..#plan.indices..' cards for a '..horizon
        lines[#lines+1]=A.card_names(s,plan.indices)
        selection={indices=plan.indices,kind=plan.action.kind}
      end
      lines[#lines+1]=plan.reason
    elseif result.kind == 'discard' and discard then
      title = 'Discard ' .. #discard.indices .. ' card' .. (#discard.indices == 1 and '' or 's')
      lines[#lines + 1] = A.card_names(s, discard.indices)
      lines[#lines + 1] = 'Next hand: mean ~' .. number(discard.mean) .. ' chips; ' .. math.floor(discard.probability * 100 + 0.5) .. '% sampled clear'
      lines[#lines + 1] = tostring(discard.count) .. ' samples for this discard; clear = finish this blind in one hand.'
      if result.risky_yorick_clear and result.risky_yorick_clear.selected and
        result.risky_yorick_clear.final_action_matches_search then
        lines[#lines+1]='An available clear is being traded for Yorick growth. The exact discard transition includes its new X-Mult before each sampled next play.'
        warnings[#warnings+1]='The sampled redraw can fail even though playing now clears; these samples are not a calibrated win probability.'
      end
      if (result.search_diagnostics or {}).sampled_clear_scope then lines[#lines+1]=result.search_diagnostics.sampled_clear_scope end
      selection = {indices = discard.indices, kind = 'discard'}
    elseif play then
      title = 'Play ' .. play.hand .. ' (~' .. number(play.score) .. ')'
      lines[#lines + 1] = A.card_names(s, play.indices)
      lines[#lines + 1] = 'Need ' .. number(math.max(0, s.blind.chips - s.chips)) .. ' more chips; ' .. s.hands_left .. ' hands left.'
      lines[#lines + 1] = play.hand .. ' level ' .. tostring(((s.hands or {})[play.hand] or {}).level or 1) .. '.'
      if play.future_note then lines[#lines + 1] = play.future_note end
      if play.reliable_bound then lines[#lines+1]='Conservative score estimate: random bonus triggers are excluded unless guaranteed.' end
      if play.cycle_indices and #play.cycle_indices > 0 then
        lines[#lines + 1] = 'Cycle with this play: ' .. A.card_names(s, play.cycle_indices)
      end
      if play.cycle_note then lines[#lines + 1] = play.cycle_note end
      selection = {indices = play.indices, kind = 'play'}
    else
      title = result.title or 'No scoring play found'
      append(lines, result.lines or {'Try discarding or using a consumable to change this hand.'})
    end
    local retention=(result.consumable_diagnostics or {}).retention_reasons or {}
    for i=1,math.min(2,#retention) do lines[#lines+1]=retention[i] end
    append(warnings,(result.search_diagnostics or {}).discard_transition_warnings)
    if play and not result.two_hand_finish and not result.multi_discard and not result.mixed_rescue and not result.growth and not result.consumable and not result.ordering and not result.hand_ordering and not result.boss_rescue then
      if result.kind == 'discard' then lines[#lines + 1] = 'Play now alternative: ' .. play.hand .. ' ~' .. number(play.score) end
      append(warnings, play.warnings)
    end
    local shown, alternatives_seen = 0, {}
    local function alternative_key(candidate)
      return candidate.hand .. ':' .. tostring(candidate.score) .. ':' .. table.concat(candidate.scoring_indices or candidate.indices, ',')
    end
    if play then alternatives_seen[alternative_key(play)] = true end
    for _, alternative in ipairs(not result.two_hand_finish and not result.multi_discard and not result.mixed_rescue and not result.consumable and not result.ordering and not result.hand_ordering and not result.boss_rescue and result.alternatives or {}) do
      local key = alternative_key(alternative)
      if not alternatives_seen[key] and shown < 2 then
        lines[#lines + 1] = 'Alternative: ' .. alternative.hand .. ' ~' .. number(alternative.score) .. ' (' .. A.card_names(s, alternative.indices) .. ')'
        shown = shown + 1
        alternatives_seen[key] = true
      end
    end
    if result.truncated then warnings[#warnings + 1] = 'Search limits reached; only completed comparisons are used.' end
    if result.search_diagnostics and result.search_diagnostics.discard_skipped then
      warnings[#warnings + 1] = result.search_diagnostics.discard_skipped
    end
    if result.search_diagnostics and result.search_diagnostics.continuation_skipped and
      not (result.two_hand_finish_diagnostics and result.two_hand_finish_diagnostics.complete) then
      warnings[#warnings + 1] = 'Remaining-blind comparison unavailable: '..result.search_diagnostics.continuation_skipped
    end
    if result.consumable_diagnostics then
      append(warnings, result.consumable_diagnostics.warnings)
      if result.consumable_diagnostics.truncated then
        warnings[#warnings + 1] = 'Consumable comparison budget reached; only completed comparisons are used.'
      end
    end
    if result.ordering_diagnostics then
      append(warnings, result.ordering_diagnostics.warnings)
      if result.ordering_diagnostics.truncated then
        warnings[#warnings + 1] = 'Joker order comparison budget reached; only completed comparisons are used.'
      end
    end
    if result.resource_comparison and not result.two_hand_finish and not result.ordering and not result.consumable then
      local comparison=result.resource_comparison
      lines[#lines+1]='Remaining-blind check: '..tostring(comparison.samples)..' paired draw samples across up to '..
        tostring(comparison.horizon)..' hands; later discards are not searched.'
    end
    if discard and not result.two_hand_finish and not (result.risky_yorick_clear and
      result.risky_yorick_clear.selected and result.risky_yorick_clear.final_action_matches_search) then
      warnings[#warnings + 1] = 'One-discard lookahead; discard-trigger Joker effects and later draws are approximate.'
    end
    status = 'Estimated | ' .. tostring(result.evaluations) .. ' scores compared'
  else
    status = (result and (result.evaluations or 0)>0) and
      ('Strategy estimate | '..tostring(result.evaluations)..' scores compared') or 'Strategy estimate | Ctrl+H for details'
    local action = strategy.action
    if result and result.shop_diagnostics and result.shop_diagnostics.unavailable_reason and (result.evaluations or 0)==0 then
      warnings[#warnings+1]='Shop scoring preview unavailable: '..result.shop_diagnostics.unavailable_reason..' Using strategy estimates.'
    end
    if action and action.kind == 'reorder_jokers' then
      lines[#lines+1]='Left to right: '..A.joker_names(s,action.order)
    elseif action and action.kind == 'reorder_hand' then
      lines[#lines+1]='Left to right: '..A.card_names(s,action.order)
      lines[#lines+1]='Numbers refer to the current hand positions. Close this panel and click Execute, or drag the cards into that order, then wait for fresh advice.'
    elseif action and action.kind == 'choose' and #(action.targets or {}) > 0 then
      lines[#lines + 1] = 'Target cards: ' .. A.card_names(s, action.targets)
      lines[#lines + 1] = 'Select these targets, then use the suggested card from the pack.'
      selection = {indices=action.targets,kind='use'}
    end
  end
  if not (result and result.retry) then
    append(lines, strategy.lines)
    append(warnings, strategy.warnings)
  end
  local goal=s.completionist_goal
  if goal then
    local counts=goal.counts or {}
    local held=goal.held_status=='complete' and
      ('carrying '..tostring(goal.held_target_count or 0)..' distinct missing Jokers.') or 'held Joker progress is unavailable.'
    table.insert(lines,1,'Completionist++: '..tostring(counts.complete or 0)..'/'..tostring(counts.total or 150)..' Gold stickers; '..held)
    if (counts.unknown or 0)>0 then
      warnings[#warnings+1]=tostring(counts.unknown)..' Joker sticker records are unknown; they are not counted as missing.'
    end
    if not (goal.eligibility and goal.eligibility.eligible) then
      warnings[#warnings+1]='Sticker tracking is informational here. Collection planning requires a supported normal Gold Stake run before its first win.'
    end
    local action=result and result.action or strategy.action
    local area=action and s[action.area or '']
    local card=type(area)=='table' and area[action.index or 0]
    local entry=card and goal.by_key and goal.by_key[card.key]
    if entry and entry.status=='missing' then
      local label=(card.ability or {}).name or card.key
      if action.kind=='buy' or action.kind=='choose' then
        lines[#lines+1]=label..' still needs Gold. Acquisition is not completion; keep it through a qualifying win.'
      elseif action.kind=='sell' and action.area=='jokers' then
        local copies=0;for _,owned in ipairs(s.jokers or {}) do if owned.key==card.key then copies=copies+1 end end
        if copies==1 then warnings[#warnings+1]='This sells your last '..label..', which still needs Gold. Review the scoring or survival reason before executing.' end
      end
    end
  end
  if s.phase~='hand' and A.challenge_route and not (result and result.retry and result.retry.review_only) then
    local route=A.challenge_route.inspect(s,result and result.action or strategy.action,A.opening)
    if route then
      append(lines,route.lines);append(warnings,route.warnings)
      if result then result.challenge_route=route end
    end
  end
  local discard_review=result and result.discard_before_clear
  if discard_review and discard_review.status=='exception' and result.action and result.action.kind=='play' then
    lines[#lines+1]='Remaining discards: '..tostring(discard_review.remaining_discards)..'. '..tostring(discard_review.reason)
  end
  local seen = {}
  for _, warning in ipairs(warnings) do
    if not seen[warning] then lines[#lines + 1] = 'Note: ' .. warning; seen[warning] = true end
  end
  lines[#lines + 1] = 'Heuristic advice, not a guaranteed win. Card numbers follow left-to-right hand order.'
  A.display.title, A.display.status, A.lines, A.result = title, status, lines, result
  A.selection, A.published_key = selection, A.key
  A.published_generation=A.retry_generation
  A.published_game,A.published_identity=G.GAME,retry_identity(s)
  if A.player_log and A.player_log.collection_mode and A.player_log.collection_observe then
    A.player_log:collection_observe({reason='advice_published',teacher_profile=A.teacher_profile})
  end
  if A.manual_log then
    local manual=A.manual_log:journal_for(G)
    if manual then manual:collection_observe({reason='advice_published'})end
  end
  A.page = 1
  if A.menu_open and G.OVERLAY_MENU then A.render_menu() end
end

-- Reuse the existing worker/result whenever the actual decision is unchanged.
-- The panel invokes this before showing advice, including between update ticks.
local present_without_timing=A.present
function A.present(...)
  local started=P:now()
  present_without_timing(...)
  P:finish('advisor.present',started)
end
function A.refresh()
  if A.menu_open and (not G.OVERLAY_MENU or (A.menu_overlay and A.menu_overlay ~= G.OVERLAY_MENU)) then
    A.menu_open, A.menu_overlay = false, nil
  end
  if not A.active() then
    invalidate('Enable the advisor and start a supported run.')
    return
  end
  if not ready() then
    invalidate('Waiting for the game...')
    return
  end
  -- Card crossings during one drag are provisional. Keep the detached work
  -- paused and compare the final physical arrangement once the drag ends.
  -- Execution stays blocked until that fresh comparison has actually run.
  if dragging() then A.drag_pending=true;return end
  if A.snapshot.phase(G)=='other' then
    invalidate('Waiting for a decision...')
    return
  end
  local s = A.snapshot.capture(G)
  if not s or s.phase == 'other' then
    invalidate('Waiting for a decision...')
    return
  end
  local key = A.snapshot.fingerprint(s)
  local context,run_id=retry_context(s)
  A.drag_pending=nil
  if run_id~=A.run_identity or A.game_instance~=G.GAME then
    A.run_identity,A.game_instance=run_id,G.GAME
    A.retry_generation=A.retry_generation+1
    A.execution_key=nil;invalidate('Run changed; refreshing advice...')
  end
  if A.execution_key then
    if key==A.execution_key then return end
    A.execution_key=nil
  end
  if key ~= A.key then
    P:finish_decision(A.worker_perf,'cancelled')
    A.worker_perf,A.last_decision_timing,A.last_decision_result=nil,nil,nil
    A.state_epoch=A.state_epoch+1
    local epoch,generation,game_instance=A.state_epoch,A.retry_generation,G.GAME
    A.key, A.current, A.selection, A.result, A.worker, A.published_key = key, s, nil, nil, nil, nil
    A.display.title, A.display.status = 'Comparing moves...', 'Calculating the complete recommendation'
    A.lines = {'Comparing plays, discard draws, held consumables, and Joker orders. Recommended actions will appear when the comparison is complete.'}
    A.page = 1
    if A.menu_open and G.OVERLAY_MENU then A.render_menu() end
    if s.phase == 'hand' and #s.hand > 0 or s.phase=='shop' or s.phase=='pack' or s.phase=='blind' then
      A.worker_perf=P:begin_decision(s)
      A.worker = coroutine.create(function()
        local result = A.decision.run(s, A, function() coroutine.yield() end,{retry=context})
        if A.key == key and A.state_epoch==epoch and A.retry_generation==generation and G.GAME==game_instance then A.present(s, result, true) end
      end)
    else
      local token=P:begin_decision(s);local started=P:now()
      local result=A.decision.run(s,A,nil,{retry=context})
      A.present(s,result,true)
      P:resume_finished(token,started)
      A.last_decision_timing=P:finish_decision(token,'completed',result)
      A.last_decision_result=result
    end
  end
end

local refresh_without_timing=A.refresh
function A.refresh(...)
  local started=P:now()
  refresh_without_timing(...)
  P:finish('advisor.refresh',started)
end

function A.update(dt)
  if A.public_joker_hooks then A.public_joker_hooks:update() end
  if A.menu_open and (not G.OVERLAY_MENU or (A.menu_overlay and A.menu_overlay ~= G.OVERLAY_MENU)) then
    A.menu_open, A.menu_overlay = false, nil
  end
  if not A.active() then
    invalidate('Enable the advisor and start a supported run.')
    return
  end
  if not ready() then
    invalidate('Waiting for the game...')
    return
  end
  if dragging() then A.drag_pending=true;return end
  if G.OVERLAY_MENU and not A.menu_open then return end
  A.elapsed = A.elapsed + dt
  -- Check every worker slice: a gameplay change must not publish an old result
  -- during the normal idle refresh interval. A released drag gets an immediate
  -- complete check even if less than one idle interval has elapsed.
  if A.drag_pending or A.worker or A.elapsed >= 0.3 or not A.key then
    A.elapsed = 0
    A.refresh()
  end
  if dragging() then return end
  if A.worker then
    local started = love.timer.getTime()
    repeat
      local resume_started=P:now()
      local ok, err = coroutine.resume(A.worker)
      P:resume_finished(A.worker_perf,resume_started)
      if not ok then
        P:finish_decision(A.worker_perf,'error')
        A.worker_perf,A.last_decision_timing,A.last_decision_result=nil,nil,nil
        A.worker, A.selection, A.result, A.published_key = nil, nil, nil, nil
        A.display.title, A.display.status = 'Advisor unavailable for this state', 'See the advisor panel for details'
        A.lines = {'The advisor stopped safely: ' .. tostring(err)}
        if A.menu_open and G.OVERLAY_MENU then A.render_menu() end
        break
      elseif coroutine.status(A.worker) == 'dead' then
        local current=A.result and A.published_key==A.key
        local receipt=P:finish_decision(A.worker_perf,current and 'completed' or 'cancelled',current and A.result)
        if current then A.last_decision_timing,A.last_decision_result=receipt,A.result end
        A.worker,A.worker_perf=nil,nil
        break
      end
    until love.timer.getTime() - started > 0.004
  end
end

function A.select()
  if dragging() or A.drag_pending then return end
  -- Check all scoring inputs immediately, including order, before changing selection.
  local live = A.snapshot.capture(G)
  if not ready() or not live or A.snapshot.fingerprint(live) ~= A.published_key or
    G.GAME~=A.published_game or retry_identity(live)~=A.published_identity then
    if A.selection then
      invalidate('State changed; recalculating')
    end
    return
  end
  if not A.selection or dragging() then return end
  local indices = A.selection.indices
  if #indices > (G.hand.config.highlighted_limit or 5) then return end
  G.FUNCS.exit_overlay_menu()
  A.menu_open, A.menu_overlay = false, nil
  G.hand:unhighlight_all()
  for _, i in ipairs(indices) do G.hand:add_to_highlighted(G.hand.cards[i], true) end
end

function A.can_execute()
  if not ready() or dragging() or A.drag_pending or A.worker or A.execution_key or
    not A.result or not A.result.action or not A.published_key or A.published_key~=A.key or A.published_generation~=A.retry_generation or
    G.OVERLAY_MENU or G.SETTINGS.paused or G.GAME~=A.published_game then return false end
  local controller=G.CONTROLLER or {}
  if controller.locked or (G.GAME.STOP_USE or 0)>0 or (G.play and G.play.cards and #G.play.cards>0) then return false end
  for _,locked in pairs(controller.locks or {}) do if locked then return false end end
  if A.execution and A.execution.button_ready then
    return A.execution.button_ready(G,A.result.action)
  end
  return true
end

function A.execute(shown_key,shown_generation)
  if Brainstorm.AutoRun then Brainstorm.AutoRun:manual('Manual Execute requested.') end
  local executable,wait_reason=A.can_execute()
  if not executable then return false,wait_reason end
  if shown_key and shown_key~=A.published_key then return false end
  if shown_generation and shown_generation~=A.retry_generation then return false end
  local live=A.snapshot.capture(G)
  if not live or A.snapshot.fingerprint(live)~=A.published_key or retry_identity(live)~=A.published_identity then
    invalidate('State changed; recalculating')
    return false
  end
  local action=A.snapshot.copy(A.result.action)
  local shop_commitment=A.shop_sequences.prepare_commitment(live,A.result.strategy,A)
  if A.result.strategy and A.snapshot.fingerprint(action)~=A.snapshot.fingerprint(A.result.strategy.action) then shop_commitment=nil end
  if action.kind=='sell' and A.result.strategy and A.result.strategy.shop_sequence and not shop_commitment then
    invalidate('Sale-funded continuation could not be bound to the public shop')
    return false,'The sale needs fresh identifiable continuation evidence.'
  end
  local context,id,ledger=retry_context(live)
  local pending,record_reason
  if context.matched then
    pending,record_reason=A.retry_memory.record(ledger,id,live,action)
    if not pending then A.retry_notice=record_reason;invalidate('Checkpoint line needs review');return false end
  end
  local action_log=A.manual_log and A.manual_log:journal_for(G) or A.player_log
  local log_sequence=action_log and action_log:before('advisor_execute',{action=action})
  A.execution_key=A.published_key
  -- Latch before the callback: even a second click in this same frame cannot
  -- repeat an asynchronously queued purchase/play. A new state releases it.
  invalidate('Executing recommendation...')
  if action_log then action_log.suppressed=action_log.suppressed+1 end
  local public_reorder=action.kind=='reorder_jokers' and A.public_joker_tracker and
    A.public_joker_tracker:prepare_reorder(G,action.order)
  local ok,success,reason,may_have_started=pcall(A.execution.execute,G,action)
  if A.public_joker_tracker and action.kind=='reorder_jokers' then
    A.public_joker_tracker:finish_reorder(G,public_reorder,ok and success==true,may_have_started)
  end
  if action_log then
    action_log.suppressed=action_log.suppressed-1
    action_log:after(log_sequence,ok and success==true,tostring(reason or (not ok and success) or ''))
  end
  if not ok or not success then
    -- A live UI button may not be ready yet even with unchanged scoring data.
    -- A confirmed preflight rejection permits fresh advice and another click;
    -- a callback that might have queued events must retain the duplicate latch.
    if ok and may_have_started==false then A.execution_key=nil end
    A.display.title='Action could not execute'
    A.display.status='See advisor details'
    A.lines={tostring(ok and reason or success),ok and may_have_started==false
      and 'The game did not accept an action. Wait for fresh advice, then try again.'
      or 'No further action is queued. Take a manual action to refresh this state.'}
    return false,tostring(ok and reason or success)
  end
  if pending then
    local saved,reason=A.retry_store:put(pending)
    if not saved then A.retry_notice=tostring(reason) end
    A.retry_generation=A.retry_generation+1
  end
  A.shop_sequence_pending=shop_commitment
  A.shop_sequence_game=G.GAME
  return true
end

A.player_log_archive=module('player_log_archive')
A.player_journal=module('player_journal')
A.callback_hooks=module('callback_hooks').new()
A.player_journal.attach(A,Brainstorm)
function A.recording_journal(g)
  return A.manual_log and A.manual_log:journal_for(g or G) or A.player_log
end
A.public_joker_tracker=A.acorn_public.new({belief=A.acorn_belief,card=A.snapshot.card,
  localize=function(...)return localize(...)end,
  emit=function(event)local log=A.recording_journal();if log then log:timing(event.kind,event)end end})
A.public_joker_hooks=A.acorn_public_hooks.attach(A.public_joker_tracker,{callback_hooks=A.callback_hooks})
A.execution.public_joker_reorder_check=function(g,proof)
  return A.public_joker_tracker:authorize_reorder(g,proof)
end
local capture_without_public_jokers=A.snapshot.capture
A.snapshot.capture=function(g)
  return A.public_joker_tracker:capture(g,capture_without_public_jokers(g))
end
return A
