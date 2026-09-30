local checks = 0
local function check(value, message)
  assert(value, message)
  checks = checks + 1
end
local function equal(actual, expected, message)
  check(actual == expected, (message or 'values differ') .. ': ' .. tostring(actual) .. ' ~= ' .. tostring(expected))
end

-- Use the real capture, search, runtime and UI with a simple deterministic score.
package.preload.nativefs = function()
  return {read = function(path)
    if path:match('/scoring.lua$') then
      return [[return {score = function(s, indices)
        local score = 0
        for _, i in ipairs(indices) do score = score + s.hand[i].rank end
        return {score = score, legal = true, hand = 'High Card', warnings = {}}
      end}]]
    elseif path:match('/strategy.lua$') then
      return [[return {advise = function(s) return {title = 'Strategy ' .. s.phase, lines = {'Current strategy'}, warnings = {}} end}]]
    end
    local file = assert(io.open(path, 'rb'))
    local contents = file:read('*a')
    file:close()
    return contents
  end}
end

local function setup(config)
  Brainstorm = {PATH = 'Brainstorm', config = config or {}}
  local now = 0
  local observed = {hud = {}, overlay_calls = 0,config_writes=0}
  Brainstorm.writeConfig=function()observed.config_writes=observed.config_writes+1 end
  local graphics = {}
  for _, name in ipairs({'push', 'pop', 'origin', 'setFont', 'setColor', 'rectangle'}) do graphics[name] = function() end end
  graphics.getDimensions = function() return 1600, 900 end
  graphics.newFont = function() return {getWidth = function(_, text) return #text * 5 end} end
  graphics.print = function(text) observed.hud[#observed.hud + 1] = text end
  graphics.printf = graphics.print
  love = {timer = {getTime = function() now = now + 0.005; return now end}, graphics = graphics}
  Game = {draw = function() end}
  G = {
    STAGES = {RUN = 1}, STAGE = 1,
    STATES = {SELECTING_HAND = 1, SHOP = 2, BLIND_SELECT = 3, ROUND_EVAL = 4}, STATE = 1,
    STATE_COMPLETE = true, SETTINGS = {},
    CONTROLLER = {locked = false, dragging = {}, locks = {}},
    hand = {cards = {}, highlighted = {}, config = {card_limit = 8, highlighted_limit = 5}},
    deck = {cards = {}, config = {}}, jokers = {cards = {}, config = {card_limit = 5}},
    consumeables = {cards = {}, config = {card_limit = 2}},
    GAME = {challenge = 'c_city_1', hands = {}, dollars = 4, chips = 0,
      blind = {name = 'Small Blind', chips = 12, config = {blind = {key = 'bl_small'}}},
      current_round = {hands_left = 4, discards_left = 2}, round_resets = {ante = 1}},
    FUNCS = {}, UIT = {R = 'R', T = 'T', C = 'C', O = 'O', ROOT = 'ROOT'},
    C = {WHITE = {}, GREEN = {}, ORANGE = {}, CLEAR = {}, UI = {TEXT_INACTIVE = {}}},
  }
  for i = 1, 8 do
    G.hand.cards[i] = {base = {id = i + 1, nominal = i + 1, suit = 'Hearts'},
      ability = {}, config = {center = {}}, facing = 'front'}
  end
  function G.hand:unhighlight_all() self.highlighted = {} end
  function G.hand:add_to_highlighted(card)
    check(card ~= nil, 'never highlight absent card')
    self.highlighted[#self.highlighted + 1] = card
  end
  Moveable = function() return {remove = function() end} end
  UIBox = function(args)
    local object = {definition = args.definition, elements = {}}
    function object:remove() self.removed = true end
    function object:recalculate() end
    function object:get_UIE_by_ID(id) return self.elements[id] end
    local function scan(definition)
      if definition.config and definition.config.id then
        object.elements[definition.config.id] = {config = definition.config, UIBox = object}
      end
      for _, child in ipairs(definition.nodes or definition.contents or {}) do scan(child) end
    end
    scan(args.definition)
    return object
  end
  G.FUNCS.overlay_menu = function(args)
    observed.overlay_calls = observed.overlay_calls + 1
    G.CONTROLLER.locks.frame, G.CONTROLLER.locks.frame_set = true, true
    G.CONTROLLER.locked = true
    G.OVERLAY_MENU = UIBox(args)
  end
  G.FUNCS.exit_overlay_menu = function()
    G.CONTROLLER.locks.frame, G.CONTROLLER.locks.frame_set = true, true
    G.CONTROLLER.locked = true
    G.OVERLAY_MENU = nil
    G.SETTINGS.paused = false
  end
  G.FUNCS.play_cards_from_highlighted = function() error('advisor played cards') end
  G.FUNCS.discard_cards_from_highlighted = function() error('advisor discarded cards') end
  create_UIBox_generic_options = function(args) return args end
  UIBox_button = function(args) return {n = 'BUTTON', config = args} end
  create_toggle = function(args) return args end
  local A = dofile('Brainstorm/Advisor/runtime.lua')
  check(A.gold_slot and A.strategy.gold_slot==A.gold_slot and A.shop_sequences.gold_slot==A.gold_slot,
    'runtime installs one shared collection-slot admission rule')
  check(A.gold_slot.gold_goal==A.gold_goal and A.gold_slot.gold_tarot_hold==A.gold_tarot_hold,
    'runtime binds supported opening and whole-inventory receipt validators')
  Brainstorm.Advisor = A
  dofile('Brainstorm/UI/advisor.lua')
  return A, observed
end
local function complete(A)
  for _ = 1, 60 do
    A.update(0.1)
    if A.result and not A.worker then return end
  end
  error('advisor did not finish within 60 update ticks')
end

local function menu_text_and_buttons()
  local content = G.OVERLAY_MENU:get_UIE_by_ID('brainstorm_advisor_contents').config.object
  local texts, buttons = {}, {}
  local function visit(node)
    if node.config and node.config.text then texts[node.config.text] = true end
    if node.config and node.config.button then buttons[node.config.button] = node.config end
    for _, child in ipairs(node.nodes or {}) do visit(child) end
  end
  visit(content.definition)
  return texts, buttons
end

do
  local A, observed = setup()
  local searches = 0
  -- The actual search mutates its initial result after sampling discards. This
  -- reproduces the reported play-in-badge/discard-in-panel transition exactly.
  A.search.run = function(_, _, _, progress)
    searches = searches + 1
    local result = {kind = 'play', evaluations = 32,
      play = {hand = 'High Card', score = 9, indices = {8}, warnings = {}}}
    progress(32, result)
    progress(64)
    result.kind, result.evaluations = 'discard', 96
    result.discard = {indices = {1, 2, 3}, mean = 90, probability = 0.75, count = 24}
    return result
  end
  A.update(0.01)
  local worker, key = A.worker, A.key
  check(worker ~= nil, 'partial play leaves search running')
  equal(A.result, nil, 'partial play is never a published result')
  equal(A.selection, nil, 'partial play cannot be selected')
  equal(A.display.title, 'Comparing moves...', 'badge waits for complete comparison')
  A.draw()
  equal(observed.hud[2], A.display.title, 'calculating badge uses shared title')
  equal(observed.hud[3], A.display.status, 'calculating badge uses shared status')
  A.open()
  equal(A.worker, worker, 'opening mid-search keeps the same worker')
  equal(A.key, key, 'opening mid-search keeps its snapshot')
  equal(searches, 1, 'opening mid-search does not restart sampling')
  local texts, buttons = menu_text_and_buttons()
  check(texts[A.display.title] and texts[A.display.status], 'mid-search panel agrees with badge')
  equal(buttons.brainstorm_advisor_select, nil, 'mid-search panel has no provisional action')
  A.select()
  equal(#G.hand.highlighted, 0, 'select during comparison cannot select partial play')
  equal(A.worker, worker, 'select during comparison does not restart sampling')
  A.update(0.01)
  equal(A.selection, nil, 'later sampling progress still offers no provisional action')
  A.update(0.01)
  equal(A.worker, nil, 'complete result finishes worker')
  equal(A.result.kind, 'discard', 'only final discard is published')
  equal(A.display.title, 'Discard 3 cards', 'final title matches result action')
  equal(A.selection.kind, 'discard', 'final selection matches result action')
  equal(observed.overlay_calls, 1, 'completion never reopens popup')
  texts, buttons = menu_text_and_buttons()
  check(texts[A.display.title] and texts[A.display.status], 'final panel matches published title and status')
  equal(buttons.brainstorm_advisor_select.label[1], 'Select cards to discard', 'panel button matches published action')
  local result, selection = A.result, A.selection
  G.FUNCS.brainstorm_advisor_close()
  A.update(0.31)
  equal(A.result, result, 'closing frame lock preserves final result')
  equal(A.selection, selection, 'closing frame lock preserves final action')
  A.draw()
  equal(observed.hud[#observed.hud - 3], A.display.title, 'ready badge matches final panel title')
  equal(observed.hud[#observed.hud - 2], A.display.status, 'ready badge matches final panel status')
  A.open()
  A.update(0.31)
  equal(searches, 1, 'reopening ready advice never restarts sampling')
  equal(A.result, result, 'reopening ready advice keeps published result identity')
  A.select()
  equal(#G.hand.highlighted, 3, 'select highlights the final discard despite own input locks')
  for i = 1, 3 do equal(G.hand.highlighted[i], G.hand.cards[i], 'selection uses final discard card') end
  A.update(0.31)
  equal(A.result, result, 'highlighting cards and closing preserves the same decision')
  equal(searches, 1, 'advisor clicks never reseed or restart search')
  equal(observed.overlay_calls, 2, 'only explicit opens create popups')
end

do
  local A = setup()
  local started, finished = {}, {}
  A.search.run = function(s, _, _, progress)
    started[#started + 1] = s.dollars
    progress(32)
    finished[#finished + 1] = s.dollars
    return {kind = 'play', evaluations = 32,
      play = {hand = 'High Card', score = s.dollars, indices = {1}, warnings = {}}}
  end
  A.update(0.01)
  local original = A.worker
  G.GAME.dollars = 7
  A.update(0.001)
  check(A.worker ~= original, 'real scoring change cancels worker before idle refresh interval')
  equal(#finished, 0, 'obsolete worker never completes or publishes')
  equal(A.selection, nil, 'state change keeps action unavailable until ready')
  A.update(0.001)
  equal(A.result.play.score, 7, 'only current state can publish')
  equal(#started, 2, 'changed state starts exactly one replacement search')
  equal(#finished, 1, 'only replacement search finishes')
  local published = A.result
  G.CONTROLLER.dragging.target = G.hand.cards[1]
  A.update(0.01)
  equal(A.result, published, 'drag without reorder preserves recommendation')
  A.select()
  equal(#G.hand.highlighted, 0, 'selection waits until drag is released')
  G.hand.cards[1], G.hand.cards[2] = G.hand.cards[2], G.hand.cards[1]
  A.update(0.01)
  equal(A.result, published, 'intermediate drag crossings keep the previous detached result paused')
  check(A.drag_pending and not A.can_execute(), 'intermediate drag crossings cannot execute old card indices')
  G.CONTROLLER.dragging.target = nil
  check(not A.can_execute(), 'release alone cannot re-enable advice before the final arrangement is checked')
  A.update(0.001)
  equal(A.result, nil, 'release immediately invalidates changed card indices before resuming work')
  complete(A)
  G.GAME.dollars = 11
  A.open()
  equal(A.result, nil, 'opening catches changes between idle update ticks')
  equal(A.selection, nil, 'opening never offers stale selection')
  equal(A.current.dollars, 11, 'opening compares the current snapshot')
end

do
  local A = setup()
  A.search.run = function()
    return {kind = 'play', evaluations = 50,
      play = {hand = 'High Card', score = 9, indices = {1, 2, 3, 8}, scoring_indices = {8},
        cycle_indices = {1, 2, 3}, cycle_note = 'Cycle low-value cards to draw replacements.', warnings = {}}}
  end
  complete(A)
  check(table.concat(A.lines, '\n'):find('Cycle with this play: #1 2H, #2 3H, #3 4H', 1, true), 'panel identifies non-scoring cards included for cycling')
  check(table.concat(A.lines, '\n'):find('Cycle low-value cards to draw replacements.', 1, true), 'panel explains the cycling choice')
  A.open()
  A.select()
  equal(#G.hand.highlighted, 4, 'high-card selection includes the entire recommended play')
  equal(G.hand.highlighted[4], G.hand.cards[8], 'scoring card is included alongside cycling cards')
end

do
  local A = setup()
  equal(Brainstorm.config.advisor.enabled, true, 'enabled by default')
  equal(Brainstorm.config.advisor.challenge_only, false, 'new settings include normal decks by default')
  check(A.active(), 'challenge advisor active')
  G.GAME.challenge = nil
  check(A.active(), 'normal deck advice is available with fresh defaults')
  complete(A)
  check(A.result and A.published_key,'normal deck follows the existing complete decision path')
  Brainstorm.config.advisor.challenge_only = true;A.defaults()
  check(not A.active(), 'saved challenge-only preference remains respected')
  G.GAME.challenge='c_city_1';check(A.active(),'saved challenge-only still permits challenges')
end

do
  local settings={advisor={enabled=false,challenge_only=true,hud=false,retry={persistent_count=5}},
    ar_filters={joker_targets={'Marble Joker'}},ar_prefs={native_cpu_mode='maximum'}}
  local A,observed=setup(settings);G.GAME.challenge=nil
  local old=A.snapshot.fingerprint(settings)
  A.defaults();Brainstorm.createAdvisorPage()
  equal(A.snapshot.fingerprint(settings),old,'loading defaults and rendering preserve existing preferences and retry metadata')
  equal(observed.config_writes,0,'defaults and rendering never write settings')
  check(not A.active(),'explicit disabled advisor is preserved')
  A.open()
  local texts,buttons=menu_text_and_buttons()
  check(buttons.brainstorm_advisor_enable_normal,'inactive advisor panel exposes the explicit normal-deck enable action')
  check(texts['Advice is available on normal decks and challenge runs.'],'inactive panel explains both supported run types')
  local game_before=A.snapshot.fingerprint(G.GAME)
  G.FUNCS.brainstorm_advisor_enable_normal()
  check(settings.advisor.enabled and settings.advisor.challenge_only==false,'explicit click enables normal and challenge advice')
  equal(observed.config_writes,1,'explicit enable action writes settings once')
  check(settings.advisor.hud==false and settings.advisor.retry.persistent_count==5,'HUD preference and persistent retry allowance are retained')
  equal(settings.ar_filters.joker_targets[1],'Marble Joker','normal advice does not change search filters')
  equal(settings.ar_prefs.native_cpu_mode,'maximum','normal advice does not change CPU preference')
  equal(A.snapshot.fingerprint(G.GAME),game_before,'enable action does not touch run state')
  check(not A.worker and not A.result,'enable action schedules no immediate score or gameplay work')
end

do
  local A,observed=setup();G.GAME.challenge=nil
  local calls=0
  A.decision.run=function(_,_,progress)
    calls=calls+1;progress()
    return {kind='play',evaluations=1,play={score=99,legal=true,hand='High Card',indices={1},warnings={}},
      action={kind='play',area='hand',indices={1}}}
  end
  A.refresh();local abandoned=A.worker;check(abandoned~=nil,'a real runtime worker is pending')
  check(coroutine.resume(abandoned),'old worker reaches a supported yield')
  local epoch,generation=A.state_epoch,A.retry_generation
  local retry_store={persistent_count=5};A.retry_store=retry_store
  local cache=A.score_cache
  A.hud_action_key=A.key;A.hud_retry_generation=generation
  Brainstorm.config.advisor.enabled=false;Brainstorm.config.advisor.challenge_only=true
  G.FUNCS.brainstorm_advisor_enable_normal()
  equal(calls,1,'settings click never resumes scoring')
  check(A.state_epoch>epoch and A.retry_generation>generation,'configuration invalidates worker epochs and old action tokens')
  check(not A.worker and not A.key and not A.published_key and not A.selection and not A.result,'all obsolete published work is cleared')
  check(not A.hud_action_key and not A.hud_retry_generation,'old HUD action tokens are cleared')
  check(A.retry_store==retry_store and retry_store.persistent_count==5 and A.score_cache==cache,'retry journal and scorer cache are preserved')
  A.refresh();local current=A.worker
  check(current and current~=abandoned,'ordinary refresh creates a separate fresh worker')
  check(coroutine.resume(abandoned),'previous coroutine may finish harmlessly after cancellation')
  check(not A.result and A.worker==current,'cancelled worker cannot publish even at the same public fingerprint')
  complete(A);check(A.result and A.published_key,'fresh normal-deck advice completes normally')
  A.execution_key=A.published_key
  local latched=A.execution_key;local before=calls
  G.FUNCS.brainstorm_advisor_enable_normal();A.refresh()
  check(A.execution_key==latched and not A.worker and not A.result,'changing settings never renews a pending execution at the same state')
  equal(calls,before,'preserved execution latch prevents duplicate computation/action')
  check(not A.can_execute(),'no stale recommendation can execute after configuration invalidation')
  Brainstorm.config.advisor.enabled=false;G.FUNCS.brainstorm_advisor_config()
  check(not Brainstorm.config.advisor.enabled,'ordinary toggle callback does not re-enable an explicitly disabled advisor')
end

do
  local A, observed = setup()
  G.GAME.blind.chips = 200 -- exercise the full tactical pass on a nonclear
  G.consumeables.cards = {{ability = {name = 'Strength', set = 'Tarot'},
    config = {center = {key = 'c_strength', name = 'Strength'}}, facing = 'front'}}
  local calls = 0
  A.consumables.suggest = function(s, _, result, progress)
    calls = calls + 1
    equal(#s.consumeables, 1, 'tactical check sees held inventory')
    progress()
    return {title = 'Use Strength', lines = {'Increase the target ranks before playing.'}, warnings = {},
      action = {kind = 'use', area = 'consumeables', index = 1, targets = {2, 4}},
      play = {hand = 'Four of a Kind', score = 200}}, 50
  end
  complete(A)
  equal(calls, 1, 'one completed tactical comparison per state')
  equal(A.display.title, 'Use Strength', 'consumable use precedes play advice')
  equal(A.selection.kind, 'use', 'selection is explicitly a consumable target action')
  check(table.concat(A.lines, '\n'):find('Target cards: #2 3H, #4 5H', 1, true), 'targets shown in panel')
  check(table.concat(A.lines, '\n'):find('Use consumable #1', 1, true), 'inventory slot shown in panel')
  A.open()
  equal(A.display.title, 'Use Strength', 'opening retains same consumable recommendation')
  A.select()
  equal(#G.hand.highlighted, 2, 'target selection highlights exact consumable targets')
  equal(G.hand.highlighted[1], G.hand.cards[2], 'first target correct')
  equal(G.hand.highlighted[2], G.hand.cards[4], 'second target correct')
  equal(#G.consumeables.cards, 1, 'highlighting never spends the consumable')
  G.consumeables.cards = {}
  A.select()
  equal(A.selection, nil, 'inventory change invalidates old target action')
end

do
  local A = setup()
  G.GAME.blind.chips = 200 -- nonclear exercises tactical presentation
  G.consumeables.cards = {{ability = {name = 'Pluto', set = 'Planet'},
    config = {center = {key = 'c_pluto', name = 'Pluto'}}, facing = 'front'}}
  A.consumables.suggest = function()
    return {title = 'Use Pluto', lines = {}, warnings = {},
      action = {kind = 'use', area = 'consumeables', index = 1, targets = {}},
      play = {hand = 'High Card', score = 100}}, 10
  end
  complete(A)
  equal(A.display.title, 'Use Pluto', 'untargeted consumable displayed as next step')
  equal(A.selection, nil, 'untargeted consumable never highlights play cards by mistake')
end

do
  local A = setup()
  G.GAME.blind.chips = 200 -- nonclear exercises ordering arbitration
  G.jokers.cards = {
    {sort_id = 1, ability = {name = 'Cavendish'}, config = {center = {key = 'j_cavendish', name = 'Cavendish'}}, facing = 'front'},
    {sort_id = 2, ability = {name = 'Joker'}, config = {center = {key = 'j_joker', name = 'Joker'}}, facing = 'front'},
  }
  G.consumeables.cards = {{ability = {name = 'Strength'}, config = {center = {key = 'c_strength'}}, facing = 'front'}}
  A.consumables.suggest = function()
    return {title = 'Use Strength', lines = {}, warnings = {},
      action = {kind = 'use', area = 'consumeables', index = 1, targets = {1}},
      play = {hand = 'Pair', score = 100}}, 5
  end
  local order_checks = 0
  A.ordering.suggest = function(s, _, result, progress, options)
    order_checks = order_checks + 1
    check(result.consumable ~= nil, 'order comparison sees the consumable alternative')
    equal(options.arm_cost, A.search.arm_cost, 'order comparison shares permanent boss cost')
    progress()
    return {title = 'Reorder Jokers before playing', lines = {'Apply flat Mult before XMult.'}, warnings = {},
      action = {kind = 'reorder_jokers', order = {2, 1}}, play = {hand = 'High Card', score = 200}}, 10
  end
  complete(A)
  equal(order_checks, 1, 'one completed ordering comparison per state')
  equal(A.result.action.kind, 'reorder_jokers', 'shared decision publishes reorder as the first action')
  equal(A.display.title, 'Reorder Jokers before playing', 'panel and badge expose the same ordering action')
  equal(A.selection, nil, 'ordering never exposes obsolete play or consumable selection')
  check(table.concat(A.lines, '\n'):find('Left to right: #2 Joker -> #1 Cavendish', 1, true), 'desired order uses current positions and names')
  A.open()
  equal(order_checks, 1, 'opening preserves completed Joker order recommendation')
  A.select()
  equal(#G.hand.highlighted, 0, 'reorder advice cannot select an unrelated hand')
  equal(G.jokers.cards[1].sort_id, 1, 'reading advice never rearranges live Jokers')
  G.jokers.cards[1], G.jokers.cards[2] = G.jokers.cards[2], G.jokers.cards[1]
  A.open()
  equal(A.result, nil, 'manual Joker reorder invalidates the previous plan')
  equal(A.selection, nil, 'recalculation does not reuse the old play selection')
end

do
  local A = setup()
  A.update(0.1)
  check(A.worker ~= nil, 'search runs incrementally')
  A.open()
  check(A.menu_open and G.SETTINGS.paused, 'panel opens and pauses')
  complete(A)
  check(A.result.play and A.selection, 'search completes while its own panel is open')
  local expected = {}
  for _, index in ipairs(A.selection.indices) do expected[#expected + 1] = G.hand.cards[index] end
  A.select()
  equal(#G.hand.highlighted, #expected, 'recommended cards highlighted')
  for i, selected in ipairs(expected) do equal(G.hand.highlighted[i], selected, 'correct live card highlighted') end
  equal(G.OVERLAY_MENU, nil, 'select closes panel')
  equal(G.SETTINGS.paused, false, 'select resumes game')
end

do
  local A = setup()
  complete(A)
  G.hand.cards[1], G.hand.cards[2] = G.hand.cards[2], G.hand.cards[1]
  A.select()
  equal(#G.hand.highlighted, 0, 'stale hand order cannot select wrong cards')
  equal(A.selection, nil, 'stale selection discarded')
  equal(A.key, nil, 'stale result scheduled for refresh')
end

do
  local A = setup()
  complete(A)
  G.GAME.dollars = G.GAME.dollars + 1
  A.select()
  equal(#G.hand.highlighted, 0, 'any scoring state change blocks old selection')
end

for _, lock in ipairs({'use', 'shop_reroll', 'toggle_shop'}) do
  local A = setup()
  complete(A)
  A.open()
  G.CONTROLLER.locks[lock] = true
  A.update(0.1)
  equal(A.worker, nil, lock .. ' stops worker')
  equal(A.selection, nil, lock .. ' clears card selection')
  equal(A.result, nil, lock .. ' clears obsolete result')
  equal(A.current, nil, lock .. ' clears obsolete snapshot')
  check(not table.concat(A.lines or {}, '\n'):find('Current strategy', 1, true), lock .. ' clears stale panel details')
end

do
  local A = setup()
  complete(A)
  G.GAME.blind.block_play = true
  A.select()
  equal(#G.hand.highlighted, 0, 'blocked blind cannot select')
  A.update(0.1)
  equal(A.selection, nil, 'blocked blind clears selection')
end

do
  local A = setup()
  complete(A)
  A.open()
  Brainstorm.config.advisor.challenge_only = true
  G.GAME.challenge = nil
  A.update(0.1)
  equal(A.worker, nil, 'deactivation clears worker')
  equal(A.result, nil, 'deactivation clears result')
  equal(A.selection, nil, 'deactivation clears selection')
  check(not table.concat(A.lines or {}, '\n'):find('Current strategy', 1, true), 'deactivation clears stale advice')
end

do
  local A = setup()
  A.scoring.score = function() error('synthetic scoring error') end
  local ok, failure = pcall(A.update, 0.1)
  check(ok, 'worker failure cannot crash game: ' .. tostring(failure))
  equal(A.worker, nil, 'failed worker stopped')
  equal(A.selection, nil, 'failure offers no card selection')
  check(table.concat(A.lines or {}, '\n'):find('synthetic scoring error', 1, true), 'failure exposed in panel')
end

do
  local A = setup()
  A.open()
  G.OVERLAY_MENU = nil
  A.update(0.1)
  equal(A.menu_open, false, 'escape closes advisor ownership')
end

do
  local A, observed = setup()
  G.STATES.SPECTRAL_PACK=5; G.STATE=5
  G.pack_cards={cards={{config={center={key='c_medium'}},ability={name='Medium'}}},config={}}
  A.strategy.advise=function() return {title='Choose Medium',lines={'Apply a Purple seal'},warnings={},
    action={kind='choose',area='pack_cards',index=1,targets={3}}} end
  complete(A)
  equal(A.display.title,'Choose Medium','pack badge publishes targeted choice')
  equal(A.selection.kind,'use','pack choice offers target selection')
  equal(A.selection.indices[1],3,'pack target selection uses the recommendation')
  check(table.concat(A.lines,' '):find('Target cards:',1,true),'pack target positions appear in the panel')
  A.open(); equal(observed.overlay_calls,1,'pack advice opens only on request')
  A.select()
  equal(#G.hand.highlighted,1,'pack selection highlights only the intended target')
  equal(G.hand.highlighted[1],G.hand.cards[3],'pack selection uses actual hand card')
  equal(#G.pack_cards.cards,1,'selecting targets does not use the pack card')
end
do
  local A=setup()
  G.STATES.TAROT_PACK=5; G.STATE=5
  G.pack_cards={cards={{config={center={key='c_death'}},ability={name='Death'}}},config={}}
  A.strategy.advise=function() return {title='Move Death source right',lines={},warnings={},
    action={kind='reorder_hand',area='hand',order={2,3,4,5,6,7,8,1}}} end
  complete(A)
  equal(A.result.action.kind,'reorder_hand','pack preparation retains its shared executable action')
  equal(A.selection,nil,'reorder preparation offers no obsolete play/use selection')
  check(table.concat(A.lines,' '):find('drag the cards',1,true),'hand reorder instruction is visible')
  local original=G.hand.cards[1]
  A.open(); A.select()
  equal(G.hand.cards[1],original,'opening/selecting advice never moves hand cards')
  equal(#G.hand.highlighted,0,'reorder preparation never highlights use targets prematurely')
end
do
  local A,observed=setup(); complete(A)
  local calls=0
  A.execution.execute=function(g,action)
    calls=calls+1
    check(action.kind=='play' and #action.indices>0,'execute forwards exactly the published play')
    return true
  end
  local shown=A.published_key
  check(A.can_execute(),'settled completed advice enables execution')
  check(A.execute(shown),'one explicit click executes')
  equal(calls,1,'one action dispatched')
  equal(observed.overlay_calls,0,'execute does not open the popup')
  check(not A.execute(shown),'same-frame second click cannot repeat an asynchronous action')
  A.update(0.4)
  equal(calls,1,'updates never auto-execute or repeat advice')
  equal(A.result,nil,'unchanged pre-action state cannot republish a duplicate action')
  G.GAME.dollars=G.GAME.dollars+1
  complete(A)
  check(A.can_execute(),'settled new state releases the execution latch')
  check(not A.execute(shown),'a click on a previously rendered recommendation cannot execute a newer one')
  equal(calls,1,'old rendered key causes no action')
end
do
  local A=setup(); complete(A)
  local calls=0; A.execution.execute=function() calls=calls+1; return true end
  G.GAME.dollars=G.GAME.dollars+1
  check(not A.execute(A.published_key),'changed live state refuses stale execution')
  equal(calls,0,'stale advice never reaches callbacks')
  complete(A); G.CONTROLLER.locks.frame=true
  check(not A.can_execute(),'even presentation frame locks block execution')
  G.CONTROLLER.locks.frame=nil; G.CONTROLLER.locked=true
  check(not A.can_execute(),'aggregate controller lock blocks execution')
  G.CONTROLLER.locked=false; G.SETTINGS.paused=true
  check(not A.can_execute(),'paused game blocks execution')
  G.SETTINGS.paused=false; G.GAME.STOP_USE=1
  check(not A.can_execute(),'transient consumable-use lock disables Execute before a failed attempt')
  G.GAME.STOP_USE=0; G.play={cards={{}}}
  check(not A.can_execute(),'unresolved played cards disable Execute')
  G.play=nil
  G.SETTINGS.paused=false; G.CONTROLLER.dragging.target={}
  check(not A.can_execute(),'dragging blocks execution')
end
do
  local A=setup(); complete(A)
  A.execution.execute=function() error('synthetic execution error') end
  local ok=pcall(A.execute,A.published_key)
  check(ok,'execution callback failures cannot crash the game')
  equal(A.display.title,'Action could not execute','failed action is disclosed')
  check(not A.can_execute(),'failed or partially queued action cannot repeat on the same state')
end
do
  local A=setup(); complete(A)
  local calls=0
  A.execution.execute=function() calls=calls+1; return false,'Button not ready',false end
  check(not A.execute(A.published_key),'known preflight rejection does not execute')
  check(not A.can_execute(),'rejected advice must be freshly published before retry')
  complete(A)
  check(A.can_execute(),'same gameplay state can recover after a temporary UI-only rejection')
  equal(calls,1,'recovering advice never retries the action automatically')
end
do
  local A,observed=setup()
  A.search.run=function()
    return {kind='discard',evaluations=1,
      play={hand='High Card',score=5,indices={8},warnings={}},
      discard={indices={1,2,4,7},mean=50,probability=0.5,count=4}}
  end
  complete(A)
  local discarded,calls=nil,0
  G.FUNCS.can_discard=function(e)
    if #G.hand.highlighted>0 and G.GAME.current_round.discards_left>0 then
      e.config.button='discard_cards_from_highlighted'
    end
  end
  G.FUNCS.discard_cards_from_highlighted=function()
    calls=calls+1; discarded={}
    for i,card in ipairs(G.hand.highlighted) do discarded[i]=card end
  end
  A.draw()
  local bounds=A.execute_bounds
  love.mousepressed(bounds.x+2,bounds.y+2,1)
  equal(calls,1,'HUD through real dispatcher invokes discard once')
  equal(#discarded,4,'Execute both selects and discards all four recommended cards')
  for i,index in ipairs({1,2,4,7}) do equal(discarded[i],G.hand.cards[index],'exact recommended discard target '..i) end
  equal(observed.overlay_calls,0,'full execution path never opens the popup')
  love.mousepressed(bounds.x+2,bounds.y+2,1)
  equal(calls,1,'rapid second HUD click cannot repeat the real dispatch')
end
do
  local A,observed=setup();G.STATE=G.STATES.SHOP
  A.shop_scoring.new=function() return {evaluations=64} end
  A.strategy.advise=function(s,options)
    if options and options.shop_scoring then coroutine.yield();coroutine.yield() end
    return {title='Shop with $'..s.dollars,lines={},warnings={},action={kind='leave_shop'}}
  end
  A.update(0.1)
  check(A.worker~=nil and A.result==nil,'shop scoring yields instead of blocking the game update')
  check(not A.can_execute(),'partial shop comparison cannot execute')
  A.open()
  equal(observed.overlay_calls,1,'shop details open only on explicit request')
  G.GAME.dollars=9
  complete(A)
  equal(A.display.title,'Shop with $9','shop worker restarts on a changed live economy')
  equal(A.result.evaluations,64,'shop score comparison count is retained')
  equal(A.published_key,A.key,'only fresh complete shop result is published')
  equal(observed.overlay_calls,1,'finishing shop comparison updates existing panel without reopening')
end
for _,feature in ipairs({'hand_ordering','boss_rescue','mixed_rescue'}) do
  local A,observed=setup()
  G.GAME.blind.chips=200 -- exercise full specialist publication
  local action=feature=='hand_ordering' and {kind='reorder_hand',area='hand',order={8,2,3,4,5,6,7,1}} or
    feature=='mixed_rescue' and {kind='reorder_jokers',area='jokers',order={}} or {kind='sell',area='jokers',index=1}
  local suggestion={title='Published '..feature,lines={'One reviewed action'},warnings={},action=action,
    play={hand='High Card',score=99,indices={8}}}
  A.hand_ordering.suggest=function() if feature=='hand_ordering' then return suggestion,1,{} end end
  A.boss_rescue.suggest=function() if feature=='boss_rescue' then return suggestion,1,{} end end
  A.mixed_rescue.suggest=function() if feature=='mixed_rescue' then return suggestion,1,{} end end
  complete(A)
  equal(A.display.title,suggestion.title,'HUD title matches '..feature..' action')
  equal(A.result.action.kind,action.kind,'decision action matches '..feature..' display priority')
  check(A.selection==nil,'new non-play advice cannot leave stale play highlights')
  local key=A.published_key;A.open()
  equal(A.display.title,suggestion.title,'opening details retains '..feature..' advice')
  equal(A.published_key,key,'details and HUD share the completed recommendation')
  G.FUNCS.brainstorm_advisor_close()
  check(not A.can_execute(),'closing-menu frame lock pauses '..feature..' execution')
  G.CONTROLLER.locks.frame,G.CONTROLLER.locks.frame_set,G.CONTROLLER.locked=nil,nil,false
  local calls=0
  A.execution.execute=function(_,chosen) calls=calls+1;equal(chosen.kind,action.kind,'Execute dispatches published '..feature);return true end
  check(A.execute(key),'published '..feature..' executes')
  check(not A.execute(key),'rapid duplicate '..feature..' is latched')
  equal(calls,1,'one action per displayed recommendation')
end
do
  local A=setup()
  local calls=0
  A.growth.suggest=function(_,_,known)
    calls=calls+1
    return {title='Discard two for lasting growth',lines={'Retain the clearing cards.'},warnings={},
      action={kind='discard',area='hand',indices={1,2}},play=known},2,{bounded_growth=true}
  end
  complete(A)
  equal(calls,1,'growth check runs once for a completed fast decision')
  equal(A.display.title,'Discard two for lasting growth','HUD displays investment purpose')
  equal(A.result.action.kind,'discard','Execute receives investment first action')
  equal(A.selection.kind,'discard','selection matches published investment action')
  equal(table.concat(A.selection.indices,','),'1,2','selection uses current setup indices rather than future finish indices')
  A.open()
  equal(calls,1,'opening keeps stable completed growth advice')
  G.GAME.chips=1
  A.select()
  equal(A.selection,nil,'changed state invalidates growth just like ordinary advice')
end

do
  local A=setup();G.GAME.blind.chips=200
  A.multi_discard.suggest=function()
    return {indices={1,2},action={kind='discard',area='hand',indices={1,2}},reason='Conditional two-discard plan'},5,{}
  end
  complete(A)
  equal(A.result.action.kind,'discard','nested plan publishes its first discard action')
  equal(table.concat(A.selection.indices,','),'1,2','nested plan highlights the same first discard')
  check(A.display.title:match('two%-discard')~=nil,'nested plan has corresponding HUD explanation')
  local key=A.published_key;local calls=0
  A.execution.execute=function(_,action) calls=calls+1;equal(table.concat(action.indices,','),'1,2','nested execution matches display');return true end
  check(A.execute(key),'nested first action can execute through existing guard')
  check(not A.execute(key),'nested plan does not queue or duplicate a second discard')
  equal(calls,1,'one user action per nested recommendation')
end
do
  local A=setup()
  local s=A.snapshot.capture(G)
  local result={kind='discard',evaluations=100,play={indices={1},hand='High Card',score=3},
    discard={indices={2},mean=3,probability=0,count=4},
    two_hand_finish={indices={1},action={kind='play',area='hand',indices={1}},reason='Conditional final-hand redraw.'},
    resource_comparison={samples=4,horizon=2}}
  A.present(s,result,true)
  check(A.display.title:find('two%-hand finish')~=nil,'Two-hand plan has its own displayed action')
  equal(A.selection.kind,'play','Displayed selection follows the specialist action instead of the old discard')
  check(not table.concat(A.lines,' '):find('later discards are not searched',1,true),'UI does not attach the superseded future-play-only scope')
  for hands,label in pairs({[4]='four',[5]='five'}) do
    result.two_hand_finish.horizon=hands
    result.two_hand_finish.reason='Observed-state resource comparison; only this first play is recommended.'
    result.two_hand_finish_diagnostics={complete=true}
    result.search_diagnostics={continuation_skipped='Base-search size limit.'}
    A.present(s,result,true)
    equal(A.display.title,'Play 1 cards for a '..label..'-hand finish','larger resource plan displays its actual horizon')
    equal(A.selection.kind,'play','larger resource plan retains its first-action selection')
    check(not table.concat(A.lines,' '):find('Remaining-blind comparison unavailable',1,true),
      'a complete specialist comparison supersedes the base-search unavailable warning')
  end
end
do
  local A=setup();local s=A.snapshot.capture(G)
  local action={kind='use',area='consumeables',index=2,targets={}}
  A.present(s,{kind='play',evaluations=100,action=action,
    play={indices={1},hand='High Card',score=3},
    two_hand_finish={action=action,consumable_name='Mercury',horizon=3,
      reason='Improve a later Pair before playing.'}},true)
  equal(A.display.title,'Use Mercury for a three-hand finish','owned-use finish names the inventory action and horizon')
  equal(A.selection,nil,'owned-use finish does not highlight a future hand action')
  check(table.concat(A.lines,' '):find('consumable #2',1,true)~=nil,'owned-use finish identifies the actual inventory slot')
  check(table.concat(A.lines,' '):find('recalculate',1,true)~=nil,'owned-use finish explains fresh advice after use')
end
do
  local A=setup();local s=A.snapshot.capture(G)
  s.hand[1].face_down=true;s.hand[1].rank=14;s.hand[1].suit='Spades'
  equal(A.card_names(s,{1}),'#1 Face-down card','public card label hides latent identity')
  A.strategy.advise=function() error('hidden strategy leakage') end
  A.present(s,{kind='play',evaluations=16,action={kind='play',area='hand',indices={1}},
    play={indices={1},hand='Concealed hand',score=50},concealed_belief={supported=true},
    strategy={title='Concealed choice',lines={'Conditioned observations'},warnings={}}},true)
  equal(A.selection.kind,'play','concealed estimate selects the executable observed slot')
  check(not table.concat(A.lines,' '):find('AS',1,true),'presentation never names hidden Ace of Spades')
  equal(A.display.status,'Concealed-card estimate','concealed result has qualified presentation')
  A.present(s,{kind='unsupported',evaluations=0,concealed_belief={supported=false},
    strategy={title='Unavailable',lines={'Unsupported concealed horizon'},warnings={}}},true)
  equal(A.selection,nil,'unsupported hidden state publishes no action')
end
do
  local A=setup();local s=A.snapshot.capture(G);s.phase='shop';s.round=1;s.skips=1
  s.jokers={{key='j_yorick',ability={}},{key='j_perkeo',ability={}}}
  s.filter_info={challenge_opening=true,challenge_id=s.challenge,legendary_jokers={'j_yorick','j_perkeo'},
    later={target_key='j_blueprint',found_ante=3,shop=1,slot=2}}
  A.opening={rare_names={j_blueprint='Blueprint'}}
  local result={kind='strategy',evaluations=0,action={kind='reroll'},
    strategy={title='Reroll to find immediate scoring',lines={},warnings={}}}
  A.present(s,result,true)
  equal(result.action.kind,'reroll','route hints never force an action over existing survival advice')
  check(result.challenge_route.proposed_action_changes_path,'actual result records the route consequence')
  check(table.concat(A.lines,' '):find('Conditional later offer: Blueprint',1,true)~=nil,'conditional target/location displayed in advisor')
  check(table.concat(A.lines,' '):find('may still be needed for survival',1,true)~=nil,'route conditions do not imply sacrificing survival to preserve a forecast')
  equal(A.selection,nil,'route forecast queues no action or highlight')
  s.jokers[3]={key='j_blueprint',ability={}};A.present(s,result,true)
  check(result.challenge_route.retention_verified and not result.challenge_route.acquisition_verified,
    'presentation distinguishes observed current retention from unverified acquisition path')
end
local function retry_complete(A) A.refresh();complete(A) end
-- Manual checkpoint controls use fake metadata IO and detached observations.
-- These tests never create, read, restore or play a real game save.
local function retry_setup(files)
  local A=setup();files=files or {}
  G.SETTINGS.profile=1;G.GAME.pseudorandom={seed='PUBLIC_TEST'};G.GAME.stake=1
  love.filesystem={
    getInfo=function(path)
      check(path:match('^advisor_retry_metadata_v1%.'),'metadata path never targets a save or configuration')
      if files[path] then return {type='file',size=#files[path]} end
    end,
    read=function(path) return files[path] end,
    write=function(path,bytes) files[path]=bytes;return true end,
  }
  local s={phase='hand',round=1,ante=1,challenge='test',deck_key='b_challenge',
    hand={},deck={},playing_cards={},jokers={},consumeables={},blind={key='bl_small',chips=800},
    chips=0,hands_left=4,discards_left=0,hands={},modifiers={},current_round={},hand_limit=5}
  for i=1,6 do
    local card={id='playing:'..i,key='c_base',rank=i+2,nominal=i+2,suit='Hearts',ability={}}
    s.hand[i]=card;s.playing_cards[i]=card
  end
  A.snapshot.capture=function() return A.snapshot.copy(s) end
  local D=dofile('Brainstorm/Advisor/decision.lua')
  A.decision={run=function(snapshot,_,progress,options)
    return D.run(snapshot,{scoring={},strategy=A.strategy,retry_memory=A.retry_memory,retry_policy=A.retry_policy,
      search={run=function(_,_,_,yield)
        if A.test_yield then yield() end
        local r={kind='play',evaluations=6,play_complete=true,alternatives={}}
        for i=1,6 do r.alternatives[i]={indices={i},hand='High Card',score=91-i,legal=true} end
        r.play=r.alternatives[1];return r
      end}},progress,options)
  end}
  A.execution={execute=function() A.test_executions=(A.test_executions or 0)+1;return true end}
  return A,s,files
end
do
  local A,s,files=retry_setup();retry_complete(A)
  local original_key=A.published_key;local original_generation=A.published_generation
  local status=A.retry_status();check(status.can_mark,'settled supported decision can be remembered')
  check(A.remember_checkpoint(status.token),'explicit remember persists metadata')
  check(not A.remember_checkpoint(status.token),'stale remember callback is rejected')
  retry_complete(A);equal(A.result.action.indices[1],1,'marking does not change original recommendation')
  check(A.execute(A.published_key,A.published_generation),'original action executes once')
  check(A.retry_status().can_report,'executed first action becomes reportable at a public match')
  -- Simulate a later state and return, not a filesystem save or live replay.
  for reload=1,5 do
    s.chips=7;retry_complete(A);s.chips=0;retry_complete(A)
    equal(A.result.action,nil,'unconfirmed restored state is review-only')
    equal(A.selection,nil,'pending retry never exposes old specialist/card selection')
    status=A.retry_status();check(status.can_report,'authorized restored report '..reload)
    local token=status.token
    check(A.report_checkpoint_loss(token),'report spends reload '..reload)
    check(not A.report_checkpoint_loss(token),'same click cannot spend twice '..reload)
    retry_complete(A)
    equal(A.result.action.indices[1],reload+1,'highest ranked untried first action '..reload)
    check(A.result.retry and not A.result.retry.review_only,'advice identifies its retry scope')
    equal(A.selection.indices[1],reload+1,'display and selection use the new first action')
    check(not A.execute(original_key,original_generation),'stale identical-state HUD generation cannot execute')
    check(A.execute(A.published_key,A.published_generation),'retry remains one user-clicked action '..reload)
  end
  equal(A.test_executions,6,'original plus five authorized reload lines')
  s.chips=7;retry_complete(A);s.chips=0;retry_complete(A)
  check(not A.retry_status().can_report,'sixth reload report is disabled')
  check(not A.report_checkpoint_loss(A.retry_status().token),'sixth reload cannot be registered')
  equal(A.result.action,nil,'exhausted pending checkpoint is review-only')
  local restarted=retry_setup(files);retry_complete(restarted)
  check(restarted.retry_status().text:find('5/5',1,true),'restart preserves the exhausted count')
  equal(restarted.result.action,nil,'restart cannot re-execute a pending checkpoint')
  local same_seed_new=retry_setup(files);retry_complete(same_seed_new)
  check(same_seed_new.retry_status().text:find('5/5',1,true),'ambiguous same-seed new lineage cannot renew cap')
end
do
  local A,s=retry_setup();retry_complete(A);A.open()
  local _,buttons=menu_text_and_buttons()
  check(buttons.brainstorm_advisor_checkpoint_mark,'panel exposes explicit metadata-only mark')
  G.FUNCS.brainstorm_advisor_checkpoint_mark({config=buttons.brainstorm_advisor_checkpoint_mark})
  retry_complete(A)
  check(A.retry_status().text:find('marked',1,true),'bound panel callback remembered the decision')
  local token=A.retry_status().token
  s.dollars=2
  check(not A.remember_checkpoint(token),'changed public state rejects old callback')
end
do
  local A,s=retry_setup();retry_complete(A)
  check(A.remember_checkpoint(A.retry_status().token),'mark before execution rejection')
  retry_complete(A)
  A.execution.execute=function() return false,'preflight rejected',false end
  check(not A.execute(A.published_key,A.published_generation),'preflight rejection stays rejected')
  retry_complete(A);check(not A.retry_status().can_report,'unexecuted action never becomes a failed line')
  A.execution.execute=function() error('ambiguous callback failure') end
  check(not A.execute(A.published_key,A.published_generation),'uncertain exception stays latched')
  check(not A.retry_status().can_report,'uncertain callback is not claimed as a recorded execution')
end
do
  local A,s=retry_setup();retry_complete(A)
  local old=A.retry_status().token
  A.test_yield=true;s.chips=1;A.refresh()
  local abandoned=A.worker;check(abandoned,'changed decision has a worker')
  check(not A.remember_checkpoint(old),'stale token cannot mark during a newer decision')
  s.chips=2;A.refresh();local current=A.worker
  check(coroutine.resume(abandoned),'abandoned worker can finish in test')
  check(coroutine.resume(abandoned),'abandoned worker completion is harmless')
  equal(A.worker,current,'old worker cannot replace new worker')
  equal(A.result,nil,'old worker cannot publish its result')
  retry_complete(A)
end
do
  local A,s=retry_setup();retry_complete(A)
  local token=A.retry_status().token;local key,generation=A.published_key,A.published_generation
  G.GAME=A.snapshot.copy(G.GAME)
  check(not A.can_execute(),'same-public-state replacement cannot reuse advice before refresh')
  check(not A.execute(key,generation),'replacement refuses an old execute click')
  check(not A.remember_checkpoint(token),'replacement refuses an old checkpoint callback')
  retry_complete(A)
  check(not A.execute(key,generation),'old HUD generation stays stale after replacement publishes')
  G.GAME.pseudorandom.seed='ANOTHER_PUBLIC_SEED'
  check(not A.execute(A.published_key,A.published_generation),'identity mutation between ticks refuses old advice')
end
do
  local A,s=retry_setup();retry_complete(A)
  check(A.remember_checkpoint(A.retry_status().token),'mark before storage failure')
  retry_complete(A);check(A.execute(A.published_key,A.published_generation),'record before failure report')
  s.chips=3;retry_complete(A);s.chips=0;retry_complete(A)
  love.filesystem.write=function() return nil,'Injected metadata failure' end
  check(not A.report_checkpoint_loss(A.retry_status().token),'failed write does not accept report')
  equal(A.result,nil,'failed metadata mutation invalidates old result')
  check(not A.can_execute(),'failed metadata mutation cannot execute stale advice')
  retry_complete(A);equal(A.result.action,nil,'corrupt or unverifiable journal keeps retry advice review-only')
  equal(A.result.retry.status,'unavailable','storage failure is explicit')
end
do
  local A=setup();local s=A.snapshot.capture(G)
  local original={title='Original immediate use',action={kind='use',area='consumeables',index=1,targets={1}},lines={}}
  local plan={action={kind='discard',area='hand',indices={2,3}},indices={2,3},horizon=3,
    replaces_consumable=true,reason='Complete remaining-resource comparison.'}
  local result={kind='play',evaluations=20,consumable=original,two_hand_finish=plan,action=plan.action}
  A.present(s,result,true)
  check(A.display.title:find('Discard 2 cards',1,true),'certified discard replacement is also the displayed recommendation')
  equal(A.selection.kind,'discard','display selects the published resource action')
  equal(A.selection.indices[1],2,'display never retains old consumable targets after replacement')
  plan.action={kind='use',area='consumeables',index=2,targets={3,4}};plan.indices=nil;result.action=plan.action
  A.present(s,result,true)
  equal(A.selection.kind,'use','targeted resource use exposes card selection')
  equal(A.selection.consumable_index,2,'targeted resource use exposes the correct owned index')
  equal(A.selection.indices[2],4,'targeted resource use displays exact target indices')
  check(table.concat(A.lines,'\n'):find('Target cards: #3 4H, #4 5H',1,true),'targeted resource use names current visible cards')
  plan.replaces_consumable=false;result.action=original.action;A.present(s,result,true)
  equal(A.display.title,original.title,'uncertified resource proposal preserves ordinary consumable display')
end
do
  local A=setup()
  equal(Brainstorm.config.advisor.gold_stickers,false,'collection objective is explicitly opt-in')
  equal(A.snapshot.capture(G).completionist_goal,nil,'ordinary source-like observation contains no profile context')
  G.GAME.challenge=nil;G.GAME.stake=8;G.GAME.win_ante=8;G.GAME.won=false;G.GAME.seeded=false
  G.SETTINGS.profile=1
  G.PROFILES={[1]={joker_usage={}},[2]={joker_usage={j_joker={count=1,order=1,wins={[8]=1},losses={}}}}}
  G.P_STAKES={};G.P_CENTERS={}
  G.sticker_map={'White','Red','Green','Black','Blue','Purple','Orange','Gold'}
  for _,key in ipairs(A.gold_stickers.target_keys()) do G.P_CENTERS[key]={key=key,set='Joker',name=key} end
  for i,color in ipairs({'white','red','green','black','blue','purple','orange','gold'}) do
    G.P_STAKES['stake_'..color]={set='Stake',order=i,stake_level=i}
  end
  local history=A.snapshot.fingerprint(G.PROFILES)
  complete(A)
  local ordinary_action=A.snapshot.fingerprint(A.result.action)
  Brainstorm.config.advisor.gold_stickers=true;A.settings_changed();complete(A)
  local live=A.snapshot.capture(G)
  equal(live.completionist_goal.profile_id,1,'runtime binds the current loaded public profile')
  equal(live.completionist_goal.counts.missing,150,'runtime carries complete missing history to publication')
  equal(A.snapshot.fingerprint(A.result.action),ordinary_action,'tracking alone does not change deterministic tactical action')
  check(table.concat(A.lines,'\n'):find('Completionist++: 0/150',1,true),'ordinary advice displays collection progress')
  local key=A.published_key;G.SETTINGS.profile=2
  check(A.snapshot.fingerprint(A.snapshot.capture(G))~=key,'profile change invalidates the full publication key')
  check(not A.execute(key,A.published_generation),'profile change rejects stale Execute before a game callback')
  equal(#G.hand.highlighted,0,'rejected stale objective action does not select cards')
  complete(A);key=A.published_key
  G.PROFILES[2].joker_usage.j_joker.wins[8]=2
  -- Completion status alone is unchanged by another win with an already-Gold
  -- Joker, so no irrelevant count enters the public decision key.
  equal(A.snapshot.fingerprint(A.snapshot.capture(G)),key,'irrelevant repeated win counts do not change objective decisions')
  G.PROFILES[2].joker_usage.j_perkeo={count=1,order=150,wins={[8]=1},losses={}}
  check(not A.execute(key,A.published_generation),'newly completed sticker rejects stale Execute')
  complete(A)
  local s=A.snapshot.capture(G);s.phase='shop';s.jokers={{key='j_joker',ability={name='Joker'}},{key='j_egg',ability={name='Egg'}}}
  s.completionist_goal.by_key.j_egg.status='missing'
  A.present(s,{strategy={title='Sell Egg',lines={},warnings={}},action={kind='sell',area='jokers',index=2}},true)
  check(table.concat(A.lines,'\n'):find('last Egg',1,true),'selling the last missing copy is disclosed')
  s.jokers[3]={key='j_egg',ability={name='Egg'}}
  A.present(s,{strategy={title='Sell Egg',lines={},warnings={}},action={kind='sell',area='jokers',index=2}},true)
  check(not table.concat(A.lines,'\n'):find('last Egg',1,true),'duplicate sale is not falsely described as losing the target')
  Brainstorm.config.advisor.gold_stickers=false;A.settings_changed()
  equal(A.snapshot.capture(G).completionist_goal,nil,'disabling collection tracking restores clean captures')
  G.PROFILES[2].joker_usage.j_joker.wins[8]=1;G.PROFILES[2].joker_usage.j_perkeo=nil
  equal(A.snapshot.fingerprint(G.PROFILES),history,'advisor never writes the synthetic profile histories')
end
do
  local A=setup()
  complete(A)
  local key,generation=A.published_key,A.published_generation
  Brainstorm.native_search_busy=true
  check(not A.can_execute(key,generation),'native search blocks a previously valid Execute')
  A.update(.2)
  check(not A.worker and not A.result,'native search suspends and invalidates advisor work')
  Brainstorm.native_search_busy=false
  complete(A)
  check(A.result~=nil,'fresh advice resumes after the native worker actually exits')
end
do
  local A,observed=setup()
  complete(A)
  local active,stops,executes=true,0,0
  Brainstorm.AutoRun={status_text='Playing run 1',status_report=function()return {busy=active,requested=true,phase=active and 'playing' or 'stopped',owner='auto',text='Playing run 1'}end,
    stop=function()active=false;stops=stops+1 end}
  A.execute=function()executes=executes+1 end
  A.draw()
  check(A.hud_auto_stop,'an active auto-run draws Stop in the existing HUD action area')
  local button=A.execute_bounds
  active=false -- Original physical input may stop before this custom handler.
  love.mousepressed(button.x+2,button.y+2,1)
  equal(stops,1,'the drawn Stop remains a stop after an earlier physical interruption')
  equal(executes,0,'a stale Stop never becomes a manual Execute')
  A.draw()
  check(not A.hud_auto_stop,'ordinary action button returns on the next stopped draw')
end
-- Append before advisor_runtime.lua's final print; uses its existing setup/complete helpers.
do
  local A=setup();G.STATE=G.STATES.ROUND_EVAL
  A.decision.run=function()return {kind='strategy',evaluations=0,
    strategy={title='Cash Out',lines={'Synthetic completed round.'}},action={kind='cash_out'}}end
  local root={elements={},states={visible=true},config={}}
  function root:get_UIE_by_ID(id)return self.elements[id]end
  G.round_eval=root
  local detached={elements={},config={major=root},states={visible=true}}
  function detached:get_UIE_by_ID(id)return self.elements[id]end
  detached.UIRoot={UIBox=detached,states={visible=true},config={}}
  local button={UIBox=detached,parent=detached.UIRoot,states={visible=true},config={id='cash_out_button'}}
  detached.elements.cash_out_button=button;G.I={UIBOX={detached}}
  local calls=0;G.FUNCS.cash_out=function(e)equal(e,button,'runtime passes original detached cash-out element');calls=calls+1 end
  complete(A)
  local key,generation,result=A.published_key,A.published_generation,A.result
  for _=1,5 do
    local ready,why=A.can_execute()
    check(ready==false and type(why)=='string' and #why>0,'runtime exposes an explicit cash-out wait reason')
    local accepted,reason=A.execute(key,generation)
    check(accepted==false and type(reason)=='string' and #reason>0,'early manual Execute returns its readiness reason')
    equal(A.result,result,'unready live button does not invalidate complete advice')
    equal(A.execution_key,nil,'unready live button does not consume the execution latch')
  end
  equal(calls,0,'nothing cashes out while detached button is still disabled')
  equal(A.published_key,key,'UI readiness does not change the public-state publication')
  button.config.button='cash_out'
  check(A.can_execute(),'the same public-state advice becomes executable when its button enables')
  check(A.execute(key,generation),'runtime dispatches once through original detached button')
  equal(calls,1,'exactly one cash-out callback')
  check(not A.execute(key,generation) and calls==1,'same-frame repeated click cannot cash out twice')
end
do
  local A=setup();G.STATE=G.STATES.ROUND_EVAL
  A.decision.run=function()return {kind='strategy',evaluations=0,
    strategy={title='Cash Out',lines={}},action={kind='cash_out'}}end
  local root={elements={},config={},states={visible=true}}
  function root:get_UIE_by_ID(id)return self.elements[id]end
  local button={config={button='cash_out'},states={visible=true},UIBox=root}
  root.elements.cash_out_button=button;G.round_eval=root
  G.FUNCS.cash_out=function()error('Original synthetic cash-out failure')end
  complete(A)
  local accepted,reason=A.execute(A.published_key,A.published_generation)
  check(accepted==false and type(reason)=='string' and reason:find('Original synthetic cash-out failure',1,true),
    'runtime preserves original callback error text rather than returning false as a reason')
  check(A.execution_key~=nil and not A.can_execute(),'an attempted failing callback retains the duplicate latch')
end

do
  -- Use the actual runtime and capture. The counter measures unnecessary work,
  -- not a game/CPU benchmark; no real callback or source state is executed.
  for _,phase in ipairs({'hand','shop','blind'}) do
    local A=setup();G.STATE=phase=='hand' and G.STATES.SELECTING_HAND or phase=='shop' and G.STATES.SHOP or G.STATES.BLIND_SELECT
    local captures,keys,decisions=0,0,0
    local capture,fingerprint=A.snapshot.capture,A.snapshot.fingerprint
    A.snapshot.capture=function(...) captures=captures+1;return capture(...) end
    A.snapshot.fingerprint=function(...) keys=keys+1;return fingerprint(...) end
    A.decision.run=function(s,_,yield_fn)
      decisions=decisions+1
      if yield_fn then yield_fn() end
      return {kind='strategy',evaluations=0,strategy={title='Test '..s.phase,lines={}},action={kind='select_blind',blind='Small'}}
    end
    complete(A)
    local result,oldkey=A.result,A.key
    local before_c,before_k,before_d=captures,keys,decisions
    G.CONTROLLER.dragging.target=G.hand.cards[1]
    for frame=1,120 do
      G.hand.cards[1],G.hand.cards[2]=G.hand.cards[2],G.hand.cards[1]
      A.update(1/60);A.refresh()
    end
    equal(captures,before_c,phase..': 120 drag frames and explicit refreshes capture no provisional state')
    equal(keys,before_k,phase..': drag crossings perform no full fingerprint')
    equal(decisions,before_d,phase..': drag crossings start no decision (including synchronous blind planning)')
    equal(A.result,result,phase..': unchanged private result is retained while blocked')
    check(A.drag_pending and not A.can_execute(),phase..': old action remains unusable')
    G.CONTROLLER.dragging.target=nil
    check(not A.can_execute(),phase..': no execution gap between release and refresh')
    A.update(0.001)
    equal(captures,before_c+1,phase..': release captures exactly once before the idle interval')
    equal(keys,before_k+1,phase..': release fingerprints exactly once')
    equal(A.result,result,phase..': returning to the same arrangement reuses the complete result')
    equal(A.key,oldkey,phase..': unchanged final arrangement retains deterministic key')
    equal(decisions,before_d,phase..': no repeat decision for the unchanged final arrangement')
    check(not A.drag_pending,phase..': successful final check releases the drag gate')
    G.CONTROLLER.dragging.target=G.hand.cards[1]
    G.hand.cards[1],G.hand.cards[2]=G.hand.cards[2],G.hand.cards[1]
    A.update(0.01)
    G.CONTROLLER.dragging.target=nil
    A.update(0.001)
    complete(A)
    equal(decisions,before_d+1,phase..': one completed rearrangement produces one new decision')
    check(A.key~=oldkey,phase..': changed final physical order receives a new key')
    local stable=decisions
    for frame=1,120 do A.update(1/60) end
    equal(decisions,stable,phase..': idle frames do not rerun the completed decision')
  end
end

do
  local A=setup();local started,finished=0,0
  A.decision.run=function(s,_,yield_fn)
    started=started+1;yield_fn();finished=finished+1
    return {kind='play',play={score=s.dollars,legal=true,hand='High Card',indices={1},warnings={}},evaluations=0}
  end
  A.update(0.001);local old=A.worker
  G.CONTROLLER.dragging.target=G.hand.cards[1]
  for frame=1,60 do A.update(1/60) end
  equal(A.worker,old,'drag pauses the original worker instead of restarting it')
  equal(started,1,'no new worker during drag')
  equal(finished,0,'paused worker performs no scoring/continuation during drag')
  G.CONTROLLER.dragging.target=nil;A.update(0.001)
  equal(started,1,'unchanged release resumes the original worker')
  equal(finished,1,'unchanged worker completes once after release')
  A.settings_changed();A.update(0.001);old=A.worker
  G.CONTROLLER.dragging.target=G.hand.cards[1];A.update(0.001)
  G.GAME.dollars=12;G.CONTROLLER.dragging.target=nil;A.update(0.001)
  check(A.worker~=old,'cash mutation during drag cancels obsolete work before resumption')
  equal(finished,1,'obsolete cash state never finishes or publishes')
  A.update(0.001)
  equal(A.result.play.score,12,'only the final released state publishes')
  G.CONTROLLER.dragging.target=G.hand.cards[1];A.update(0.001)
  G.GAME=A.snapshot.copy(G.GAME);G.CONTROLLER.dragging.target=nil
  check(not A.can_execute(),'same-public-state game replacement remains blocked across a drag')
  A.update(0.001)
  check(A.result==nil and A.worker,'replacement still creates fresh generation-bound work')
  G.CONTROLLER.locks.gameplay=true;A.update(0.001)
  check(not A.worker and not A.result,'hard gameplay locks retain their cancellation safeguard')
end

do
  local A=setup();local decisions=0
  A.decision.run=function(s,_,yield_fn)
    decisions=decisions+1;yield_fn()
    return {kind='play',play={score=100,legal=true,hand='High Card',indices={1},warnings={}},evaluations=1}
  end
  A.update(0.001)
  local worker,key=A.worker,A.key
  G.GAME.current_round.current_hand={chips=10,mult=2,handname='Pair',chip_total=20,hand_level=1}
  A.update(0.001)
  equal(decisions,1,'HUD hand-preview updates do not restart a yielded worker')
  check(worker~=nil and A.worker==nil and A.result,'original decision finishes despite display changes')
  local result=A.result
  for frame=1,120 do
    G.GAME.current_round.current_hand.chips=frame
    G.GAME.current_round.current_hand.mult=frame/2
    A.update(1/60)
  end
  equal(A.key,key,'animated preview numbers do not change the decision key')
  equal(A.result,result,'preview churn reuses completed advice')
  equal(decisions,1,'idle preview updates produce no extra move search')
  G.GAME.current_round.hands_left=3;A.update(0.31)
  equal(decisions,2,'actual remaining hands still trigger a fresh decision')
  check(A.result==nil,'actual resource change invalidates the displayed recommendation')
end

do
  for _,failure in ipairs({'missing','unsupported'}) do
    local A=setup();complete(A)
    G.CONTROLLER.dragging.target=G.hand.cards[1];A.update(0.001)
    local capture=A.snapshot.capture
    A.snapshot.capture=function(g)
      if failure=='missing' then return nil end
      local s=capture(g);s.phase='other';return s
    end
    G.CONTROLLER.dragging.target=nil;A.update(0.001)
    check(A.drag_pending and not A.can_execute(),failure..' release capture retains the execution gate')
    check(not A.worker and not A.result and not A.published_key,failure..' release cannot reuse stale work or advice')
    A.snapshot.capture=capture;A.update(0.001);complete(A)
    check(not A.drag_pending and A.result,failure..' capture recovery completes one fresh comparison')
  end
  local A=setup();complete(A)
  G.CONTROLLER.dragging.target=G.hand.cards[1];A.update(0.001)
  G.CONTROLLER.locks.gameplay=true;A.update(0.001)
  check(not A.result and not A.worker,'gameplay lock cancels existing work even while dragging')
  G.CONTROLLER.locks.gameplay=nil
  local generation=A.retry_generation
  A.settings_changed();A.update(0.001)
  check(A.retry_generation>generation and not A.worker and not A.result,'settings invalidate generation without calculating intermediate drag state')
  G.CONTROLLER.dragging.target=nil;A.update(0.001);complete(A)
  check(not A.drag_pending and A.published_generation==A.retry_generation,'release uses the new settings generation')
end

-- Timing is observational: yielded wall wait/drag is separate from active
-- resume work, unchanged inputs reuse the result, and stale work has no scores.
do
  local A=setup({advisor={player_logging=true}})
  local clock,decisions=0,0
  love.timer.getTime=function()return clock end
  A.decision.run=function(s,_,yield_fn)
    decisions=decisions+1;clock=clock+.010;yield_fn();clock=clock+.020
    return {kind='play',play={score=100,legal=true,hand='High Card',indices={1},warnings={}},
      action={kind='play',indices={1}},evaluations=17}
  end
  A.update(.001)
  check(A.worker and not A.last_decision_timing,'yielded worker has no invented completed timing')
  G.CONTROLLER.dragging.target=G.hand.cards[1];clock=10.010
  for i=1,60 do A.update(1/60) end
  equal(decisions,1,'timed drag starts no additional decisions')
  G.CONTROLLER.dragging.target=nil;A.update(.001)
  local t=A.last_decision_timing
  equal(t.status,'completed','current worker receipt completes')
  check(math.abs(t.elapsed_seconds-10.030)<.000001,'elapsed includes time waiting during drag')
  check(math.abs(t.active_seconds-.030)<.000001,'active excludes all drag/wait time')
  check(math.abs(t.max_resume_seconds-.020)<.000001,'long individual chunk is visible despite four-ms frame allowance')
  equal(t.resume_calls,2,'both actual resumes counted')
  equal(t.evaluations,17,'only completed result reports its score calls')
  equal(A.last_decision_result,A.result,'receipt belongs to the published result object')
  local key,result=A.key,A.result
  for i=1,120 do clock=clock+1/60;A.update(1/60) end
  equal(decisions,1,'timing does not create repeated idle decisions')
  equal(A.key,key,'timing never enters scoring fingerprint')
  equal(A.result,result,'timing preserves published result reuse')
  local events={}
  local J=dofile('Brainstorm/Advisor/player_journal.lua').attach(A,Brainstorm,{
    append=function(bytes)events[#events+1]=bytes;return true end,now=function()return 'test' end})
  check(J:event('test',{}),'manufactured journal writes current advice without filesystem access')
  check(events[1]:find('"decision_id":'..t.decision_id,1,true),'current advice includes matching decision receipt')
  A.last_decision_result={}
  check(J:event('test',{}),'second manufactured journal event')
  check(not events[2]:find('"decision_id"',1,true),'unrelated receipt is not attached to current advice')
  G.GAME.dollars=9;A.update(.31)
  check(A.worker and not A.last_decision_timing,'state change clears old receipt')
  local old=A.worker_perf
  G.CONTROLLER.locks.gameplay=true;A.update(.001)
  check(old.done and not A.worker,'hard lock finalizes cancelled timing and retains cancellation')
  local receipts=A.performance.window.decisions
  equal(receipts[#receipts].status,'cancelled','cancelled worker explicitly recorded')
  equal(receipts[#receipts].evaluations,nil,'partial scores are unknown, not imputed zero')
  G.CONTROLLER.locks.gameplay=nil
  A.decision.run=function()clock=clock+.025;error('timed fixture failure')end
  A.update(.001)
  equal(receipts[#receipts].status,'error','worker errors retain explicit outcome')
  equal(receipts[#receipts].evaluations,nil,'failed worker has no fabricated score count')
  check(not A.result and A.lines[1]:find('timed fixture failure',1,true),'existing safe error handling remains')
end

do
  local A=setup({advisor={player_logging=true}})
  local clock=0;love.timer.getTime=function()return clock end
  G.STATE=G.STATES.BLIND_SELECT
  A.decision.run=function()clock=clock+.012;return {kind='strategy',strategy={title='Fixture',lines={},warnings={}},
    action={kind='select_blind'},evaluations=3}end
  A.update(.001)
  equal(A.last_decision_timing.status,'completed','short blind strategy completes in its first worker resume')
  equal(A.last_decision_timing.evaluations,3,'short blind score counts are exact result field')
  check(math.abs(A.last_decision_timing.active_seconds-.012)<.000001,'short blind active time measured')
  check(not A.worker,'finished short blind worker is released immediately')
  Brainstorm.config.advisor.player_logging=false
  local capture=A.snapshot.capture(G);A.snapshot.fingerprint(capture)
  check(A.performance.window==nil,'disabled recording drops timing state without logging or capture changes')
end

do
  local A=setup({advisor={player_logging=true}})
  local clock,writes=0,0;love.timer.getTime=function()return clock end
  local P=A.performance;P:now();P:record('advisor_update',.2)
  local J=dofile('Brainstorm/Advisor/player_journal.lua').attach(A,Brainstorm,{
    append=function()writes=writes+1;return false,'manufactured unavailable storage' end,
    now=function()return 'test' end})
  local original=P.window;clock=5;P:flush(J,{})
  check(J.error and writes==1,'real journal failure stops recording once')
  equal(P.pending,original,'failed real journal summary is retained, never acknowledged or erased')
  check(P.window and P.window~=original,'write measurements keep their separate bounded window')
  clock=15;P:flush(J,{})
  equal(writes,1,'failed logger is not asked to append again')
  equal(P.pending,original,'stopped logger retains failed summary in memory')
  Brainstorm.config.advisor.player_logging=false;P:now()
  equal(P.pending,nil,'explicit recording opt-out drops the unflushed tail')
end

-- Packs and blind preparation can perform real scored comparisons. Their
-- existing yields now pause a detached worker instead of running synchronously
-- in refresh. No partially compared action is published or executable.
for _,phase in ipairs({'pack','blind'}) do
  local A=setup()
  G.STATES.PLANET_PACK=5
  G.STATE=phase=='pack' and G.STATES.PLANET_PACK or G.STATES.BLIND_SELECT
  local calls,completed=0,0
  local function decide(s,_,yield_fn)
    calls=calls+1
    if yield_fn then yield_fn();yield_fn() end
    completed=completed+1
    return {kind='strategy',evaluations=128,strategy={title=phase..' with $'..s.dollars,lines={},warnings={}},
      action=phase=='pack' and {kind='skip_pack'} or {kind='select_blind',blind='Small'}}
  end
  A.decision.run=decide
  local expected=decide(A.snapshot.capture(G),A,nil)
  calls,completed=0,0
  A.refresh()
  check(A.worker and not A.result,phase..': refresh creates a worker without doing the comparison')
  equal(calls,0,phase..': panel refresh cannot synchronously score a comparison')
  A.update(.001)
  check(A.worker and not A.result and not A.published_key,phase..': first yield publishes no partial result')
  check(not A.can_execute(),phase..': partial comparison is not executable')
  local original=A.worker
  G.CONTROLLER.dragging.target=G.hand.cards[1]
  A.update(.001)
  equal(A.worker,original,phase..': input drag pauses the exact worker')
  equal(completed,0,phase..': paused partial comparison stays incomplete')
  G.CONTROLLER.dragging.target=nil
  complete(A)
  equal(A.snapshot.fingerprint(A.result),A.snapshot.fingerprint(expected),phase..': yielded and synchronous complete results are identical')
  equal(calls,1,phase..': unchanged input does not restart comparison')
  A.settings_changed();A.update(.001);original=A.worker
  G.GAME.dollars=11
  A.update(.001)
  check(A.worker~=original and not A.result,phase..': changed cash cancels stale work before another resume')
  complete(A)
  equal(A.display.title,phase..' with $11',phase..': only the complete fresh economy result publishes')
  local key=A.published_key
  G.STATE=900
  A.refresh()
  check(not A.worker and not A.result and not A.key and not A.selection and not A.published_key,
    phase..': leaving the decision phase clears all old recommendation state')
  check(not A.execute(key),phase..': old advice cannot execute from another phase')
end

do
  local A=setup()
  local captures,decisions=0,0
  local capture=A.snapshot.capture
  A.snapshot.capture=function(g)captures=captures+1;return capture(g)end
  A.decision.run=function(s,_,yield_fn)
    decisions=decisions+1
    yield_fn()
    return {kind='play',evaluations=1,play={score=99,hand='High Card',indices={1},warnings={}},
      action={kind='play',indices={1}}}
  end
  A.update(.001)
  check(A.worker~=nil,'manufactured hand worker starts before transition')
  local worker=A.worker
  G.STATE=900
  A.update(.001)
  check(not A.worker and not A.result and not A.key and not A.published_key and not A.selection,
    'other-phase entry cancels detached work and every published action')
  local before=captures
  for frame=1,120 do A.update(1/60);A.refresh() end
  equal(captures,before,'120 other-phase frames and explicit refreshes need no full snapshots')
  equal(decisions,1,'other-phase waiting starts no repeated decision')
  local public=A.snapshot.capture(G)
  equal(public.phase,'other','full public capture remains available in other phases for observation/acknowledgment')
  check(public.hand and #public.hand==8,'other-phase public capture retains its complete card information')
  G.STATE=G.STATES.SELECTING_HAND
  A.update(.001)
  check(A.worker and A.worker~=worker,'returning to the hand starts a new worker immediately')
  equal(decisions,2,'cancelled hand continuation never resumes after phase transition')
  complete(A)
  check(A.result and A.published_key==A.key,'fresh hand comparison publishes after phase transition')
  A.settings_changed();A.update(.001)
  G.CONTROLLER.dragging.target=G.hand.cards[1];A.update(.001)
  G.STATE=900;G.CONTROLLER.dragging.target=nil;A.update(.001)
  check(not A.worker and not A.result and not A.published_key,'drag ending in another phase cancels obsolete work')
  G.STATE=G.STATES.SELECTING_HAND;A.update(.001);complete(A)
  check(A.result and not A.drag_pending,'return from other phase satisfies the final post-drag full comparison')
end

print('advisor_runtime: ' .. checks .. ' checks passed')

-- Public Joker belief UI regression.
do
  local A=setup();local s=A.snapshot.capture(G)
  A.joker_names=function()error('Hidden Joker name formatter must not be called')end
  A.present(s,{strategy={title='Public order',lines={},warnings={}},
    public_joker_belief={supported=true,worlds=2},action={kind='reorder_jokers',order={3,1,2}},
    play={score=500},evaluations=20},true)
  equal(A.display.status,'Public Joker score floor','Concealed row receives explicit conservative UI status')
  local lines=table.concat(A.lines,'\n')
  check(lines:find('#3, #1, #2',1,true),'Display references current physical slots without guessed names')
  check(lines:find('Lowest supported score across 2 possible rows: 500 chips.',1,true),'UI presents minimum over public worlds')
  A.present(s,{strategy={title='Unavailable',lines={'Unsupported public state'},warnings={}},
    public_joker_belief={supported=false},action=nil},true)
  equal(A.display.status,'Public Joker advice unavailable','No unsupported fallback masquerades as exact advice')
end
do
  local A=setup();Brainstorm.config.advisor.gold_stickers=true
  A.gold_stickers.capture=function()return {schema=1,by_key={j_yorick={status='complete'},j_joker={status='missing'}}}end
  A.teacher_profile='perkeo_yorick_win_v1'
  local s=A.snapshot.capture(G)
  check(not s.completionist_goal and s.collection_progress.by_key.j_joker.status=='missing',
    'teacher preserves actual public sticker metadata without enabling collection trades')
  equal(s.teacher_profile,'perkeo_yorick_win_v1','teacher objective has explicit provenance')
  A.teacher_profile=nil;s=A.snapshot.capture(G)
  check(s.completionist_goal and not s.collection_progress and not s.teacher_profile,
    'normal policy retains its original collection objective')
end
print('advisor_public_runtime_total: '..checks..' checks passed')

--404: settled playing-card presentation is part of runtime admission.
do
 local A=setup();local c=G.hand.cards[1]
 c.facing='front';c.sprite_facing='back';c.flipping='b2f';c.pinch={x=true}
 A.update(.1)
 check(not A.worker and not A.result,'unsettled card blocks scoring/advice publication')
 c.sprite_facing='front';c.pinch.x=false
 complete(A)
 check(A.result~=nil,'settled front releases normal advice')
end
print('advisor_runtime_total404: '..checks..' checks passed')

--404: final arbitration's play must replace a stale discard presentation.
do
 local A=setup();local s=A.snapshot.capture(G);s.phase='hand'
 local D=dofile('Brainstorm/Advisor/decision.lua')
 local result=D.run(s,{scoring={},strategy={},search={run=function()
  return {kind='discard',evaluations=1,clear_shortcut={},
   play={indices={1},score=1000000,hand='High Card',warnings={},legal=true,uncertain=false},
   discard={indices={2},mean=1,probability=0,count=1}}
 end}})
 check(result.search_kind=='discard' and result.kind=='play' and result.action.kind=='play','final public kind follows selected action and preserves original search kind')
 A.present(s,result,true)
 check(A.display.title:find('Play ',1,true)==1 and A.selection.kind=='play' and A.selection.indices[1]==1,'rendered verb and selected indices match final encoded play')
end
print('advisor_presentation_total404: '..checks..' checks passed')

--408: actual Execute binds continuation only after accepted callbacks, scoped to GAME.
for _,accepted in ipairs({false,true}) do
 local A=setup();G.STATE=G.STATES.SHOP
 local lease={schema=1,id='invented-runtime408'};local callbacks=0
 A.shop_sequences.prepare_commitment=function()return lease end
 A.shop_sequences.observe_commitment=function(_,x)return {schema=1,id=x.id,status='matched'}end
 A.execution.button_ready=function()return true end
 A.execution.execute=function()callbacks=callbacks+1;return accepted,'invented callback',false end
 A.decision.run=function()local action={kind='sell',area='jokers',index=1}
  return {kind='strategy',action=action,evaluations=0,strategy={title='Invented sale',lines={},warnings={},action=action,shop_sequence={complete=true}}}end
 complete(A);check(not A.shop_sequence_pending,'Publication alone creates no commitment')
 equal(A.execute(),accepted,'Real Execute returns callback acceptance')
 equal(callbacks,1,'One callback only')
 equal(A.shop_sequence_pending,accepted and lease or nil,'Only accepted callback records continuation')
 if accepted then
  check(not A.execute(),'Duplicate execute remains latched')
  check(A.snapshot.capture(G).shop_sequence_commitment,'Fresh same-game snapshot carries public disposition')
  G.GAME=A.snapshot.copy(G.GAME)
  check(not A.snapshot.capture(G).shop_sequence_commitment,'New game object cannot inherit funded plan')
 end
end
print('advisor_continuation_runtime408: '..checks..' checks passed')

--408 real snapshot wrapper, public deck backs and regenerated Gold held lists.
do
 local A=setup();G.STATE=G.STATES.SHOP;Brainstorm.config.advisor.gold_stickers=true
 A.teacher_profile='perkeo_yorick_win_v1'
 A.strategy=dofile('Brainstorm/Advisor/strategy.lua');A.scoring=dofile('Brainstorm/Advisor/scoring.lua')
 A.shop_scoring.strategy=A.strategy;A.blind_finishing.strategy=A.strategy
 G.GAME.challenge=nil;G.GAME.round=4;G.GAME.dollars=0;G.GAME.win_ante=8
 G.GAME.round_resets={ante=2,hands=4,discards=3};G.GAME.current_round.jokers_purchased=0
 G.P_BLINDS={bl_small={name='Small Blind',mult=1,dollars=3}}
 G.playing_cards=G.hand.cards;G.hand.cards={};G.deck.cards=G.playing_cards
 for i,c in ipairs(G.playing_cards) do c.playing_card=i;c.facing='back';c.sprite_facing='back' end
 local function live(id,key,name,mult,cost)
  return {sort_id=id,facing='front',sprite_facing='front',base={},debuff=false,
    config={center_key=key,center={key=key,name=name,set='Joker',blueprint_compat=true}},
    ability={name=name,set='Joker',mult=mult},cost=cost,base_cost=cost,sell_cost=5}
 end
 G.jokers.cards={live(31,'j_popcorn','Popcorn',0,10)}
 G.shop_jokers={cards={live(32,'j_joker','Joker',4,2),live(33,'j_joker','Joker',4,2)}}
 G.shop_vouchers={cards={}};G.shop_booster={cards={}}
 local source=A.snapshot.capture(G)
 check(source.playing_cards[1].face_down and #source.collection_progress.held_unknown_keys==1,'Real wrapper captures ordinary deck backs and Gold held inventory')
 local actions={{kind='sell',area='jokers',index=1},{kind='buy',area='shop_jokers',index=1},{kind='buy',area='shop_jokers',index=1}}
 local result={title='Invented complete plan',lines={},warnings={},action=actions[1],shop_sequence={complete=true,actions=actions}}
 check(A.shop_sequences.qualify_sale(source,result,A,A.shop_scoring.new(source,A.scoring)),'Source-shaped pre-sale prefixes receive complete production certificates')
 local real_decision=A.decision.run
 A.decision.run=function()return {kind='strategy',action=result.action,strategy=result,evaluations=0}end
 A.execution.button_ready=function()return true end
 A.execution.execute=function()return true end -- queued callback, deliberately unsettled
 complete(A);local published=A.published_key
 check(A.execute(),'Accepted asynchronous sale')
 equal(A.snapshot.fingerprint(A.snapshot.capture(G)),published,'Pending metadata alone cannot unlock duplicate execution')
 check(not A.execute(),'No duplicate callback before physical sale settles')
 G.jokers.cards={};G.GAME.dollars=5
 local sold=A.snapshot.capture(G)
 equal(#sold.collection_progress.held_unknown_keys,0,'Actual wrapper regenerates held list after sale')
 equal(sold.shop_sequence_commitment.status,'matched','Fresh physical sale matches projected state despite regenerated held metadata')
 A.decision.run=real_decision
 local next_result=A.decision.run(sold,A)
 check(next_result.action and next_result.action.kind=='buy','Real wrapper snapshot resumes through production decision')
 local next_lease=A.shop_sequences.prepare_commitment(sold,next_result.strategy,A)
 check(next_lease~=nil,'Next purchase gets another exact continuation')
 local item=table.remove(G.shop_jokers.cards,1);G.jokers.cards={item};G.GAME.dollars=3;G.GAME.current_round.jokers_purchased=1
 A.shop_sequence_pending=next_lease
 local bought=A.snapshot.capture(G)
 equal(bought.shop_sequence_commitment.status,'matched','Fresh acquired physical Joker and refreshed Gold held list match next lease')
 G.GAME.dollars=2
 equal(A.snapshot.capture(G).shop_sequence_commitment.status,'public_context_changed','Unplanned cash change invalidates the exact public match')
end
print('advisor_capture_continuation408: '..checks..' checks passed')

--410: real capture/decision/presentation/Execute agree on the selected discard.
do
 local A=setup();A.teacher_profile='perkeo_yorick_win_v1'
 Brainstorm.config.advisor.gold_stickers=true
 A.strategy=dofile('Brainstorm/Advisor/strategy.lua');A.scoring=dofile('Brainstorm/Advisor/scoring.lua')
 G.GAME.challenge=nil;G.GAME.blind.chips=100;G.GAME.win_ante=8
 G.GAME.round_resets={ante=8,hands=4,discards=3};G.GAME.current_round.discards_left=3
 for i,c in ipairs(G.hand.cards) do c.playing_card=i;c.config.center={key='c_base',set='Default'} end
 G.playing_cards=G.hand.cards
 G.jokers.cards={{sort_id=99,facing='front',base={},debuff=false,
  config={center_key='j_joker',center={key='j_joker',name='Joker',set='Joker',blueprint_compat=true}},
  ability={name='Joker',set='Joker',mult=100},sell_cost=2}}
 local callbacks=0;local executed
 A.execution.button_ready=function()return true end
 A.execution.execute=function(_,action)callbacks=callbacks+1;executed=action;return true end
 complete(A)
 check(A.result.action.kind=='discard' and A.result.discard_before_clear.selected,'actual captured teacher state selects discard')
 equal(A.selection.kind,'discard','presented selection is discard')
 check(A.display.title:find('Discard ',1,true)==1,'presented title is discard')
 local expected_action=A.result.action
 check(A.execute(),'Execute accepts the selected discard')
 equal(executed.kind,'discard','callback receives discard, not stored clearing play')
 for i,index in ipairs(executed.indices) do equal(index,expected_action.indices[i],'callback uses final physical indices') end
 check(not A.execute() and callbacks==1,'asynchronous duplicate protection retained')
end
print('advisor_discard_runtime410: '..checks..' checks passed')

--414: actual capture -> phase arbitration -> presentation -> Execute reorders
-- the physical mock row first, then fresh advice invokes the shop exit callback.
-- The empty-shop incumbent is fixed to isolate this gate from stock liquidation.
for _,inventory_case in ipairs({'mixed','saturated'}) do
 local A=setup();A.teacher_profile='perkeo_yorick_win_v1';G.STATE=G.STATES.SHOP
 Brainstorm.config.advisor.gold_stickers=true
 A.strategy=dofile('Brainstorm/Advisor/strategy.lua')
 A.strategy.advise=function()return {title='Leave shop',lines={},warnings={},action={kind='leave_shop'}}end
 A.shop_scoring=nil;A.economy=nil;A.gold_retention=nil
 G.GAME.challenge=nil;G.GAME.round=4;G.GAME.dollars=20;G.GAME.win_ante=8
 G.GAME.round_resets={ante=3,hands=4,discards=3}
 G.playing_cards=G.hand.cards;G.deck.cards=G.playing_cards;G.hand.cards={}
 for i,c in ipairs(G.playing_cards) do c.playing_card=i;c.config.center={key='c_base',set='Default'} end
 local function live(id,key,name,set)
  return {sort_id=id,facing='front',sprite_facing='front',base={},debuff=false,
   config={center_key=key,center={key=key,name=name,set=set,blueprint_compat=true}},
   ability={name=name,set=set},states={drag={can=true,is=false}},cost=3,base_cost=3,sell_cost=4}
 end
 G.jokers.cards={live(41,'j_yorick','Yorick','Joker'),live(42,'j_brainstorm','Brainstorm','Joker'),live(43,'j_perkeo','Perkeo','Joker')}
 G.jokers.cards[1].ability.x_mult=4
 G.jokers.align_cards=function()end;G.jokers.set_ranks=function()end
 G.consumeables.cards={};G.consumeables.config.card_limit=11
 local keys={'c_death','c_strength','c_hanged_man','c_empress','c_heirophant','c_chariot','c_justice','c_devil','c_temperance'}
 if inventory_case=='saturated' then keys={'c_mercury','c_saturn'};G.GAME.hands.Flush={played=17,level=5,chips=95,mult=12} end
 for i,key in ipairs(keys) do
  local c=live(50+i,key,key,'Tarot');c.edition={negative=true,type='negative'};G.consumeables.cards[i]=c
 end
 G.shop_jokers={cards={}};G.shop_vouchers={cards={}};G.shop_booster={cards={}}
 local exits=0;local button={config={button='toggle_shop'}}
 G.shop={get_UIE_by_ID=function(_,id)if id=='next_round_button' then return button end end}
 G.FUNCS.toggle_shop=function()exits=exits+1 end
 local inventory=A.snapshot.fingerprint(A.snapshot.capture(G).consumeables)
 complete(A)
 check(A.result.action.kind=='reorder_jokers','large physical inventory selects Perkeo reorder in runtime')
 check(A.display.title:find('Copy Perkeo',1,true),'runtime displays the Perkeo preparation')
 local observed=A.player_log_observe()
 check(observed.advice.phase_copy_review.selected,'current public advice carries selected Perkeo setup receipt')
 equal(observed.advice.phase_copy_review.inventory_value_tie,inventory_case=='saturated','public receipt distinguishes utility tie from useful mixed-stock gain')
 local order=A.snapshot.copy(A.result.action.order);local row={};for i,c in ipairs(G.jokers.cards) do row[i]=c end
 check(A.execute(),'real execution adapter accepts the separate reorder')
 for i,source in ipairs(order) do equal(G.jokers.cards[i],row[source],'adapter physically applies published Joker permutation') end
 equal(exits,0,'reorder never calls the irreversible shop exit')
 check(not A.execute(),'old reorder publication cannot be executed again')
 complete(A)
 equal(A.result.action.kind,'leave_shop','fresh runtime advice exits the arranged shop')
 equal(A.phase_copy.copy_effects(A.snapshot.capture(G),'j_perkeo'),2,'actual fresh row resolves Brainstorm to Perkeo')
 equal(A.snapshot.fingerprint(A.snapshot.capture(G).consumeables),inventory,'all held physical consumables preserved')
 equal(G.GAME.dollars,20,'setup preserves actual cash')
 check(A.execute(),'fresh exit executes through the same production adapter')
 equal(exits,1,'shop callback receives exactly one exit')
 check(not A.execute(),'pending exit duplicate remains latched')
end
print('advisor_perkeo_exit_runtime414: '..checks..' checks passed')

--416: real public capture, advice, rendering and execution adapter retain the
-- same winning card through all three actual mocked discard/draw settlements.
do
 local F=dofile('tests/fixtures/repair416.lua');local s=F.state()
 s.jokers={F.joker('j_yorick','Yorick',{x_mult=4,yorick_discards=20,extra={discards=23,xmult=1}}),
  F.joker('j_shoot_the_moon','Shoot the Moon',{extra=13})}
 local A=setup();A.teacher_profile='perkeo_yorick_win_v1';Brainstorm.config.advisor.gold_stickers=true
 A.strategy=dofile('Brainstorm/Advisor/strategy.lua');A.scoring=dofile('Brainstorm/Advisor/scoring.lua')
 G.GAME.challenge=nil;G.GAME.win_ante=8;G.GAME.dollars=30;G.GAME.probabilities={normal=1}
 G.GAME.round_resets={ante=3,hands=3,discards=3};G.GAME.current_round.hands_left=3;G.GAME.current_round.discards_left=3
 G.GAME.blind={name='The Wheel',chips=500,config={blind={key='bl_wheel'}}}
 G.hand.cards={};G.hand.config.card_limit=7;G.deck.cards={};G.playing_cards={};G.jokers.cards={}
 local function live(c,id,joker)
  local v=F.copy(c);v.playing_card=not joker and id or nil;v.sort_id=id
  v.facing='front';v.sprite_facing='front';v.base=v.base or {};v.base.suit=v.suit
  v.config={center_key=v.key,center={key=v.key,name=v.ability.name,set= joker and 'Joker' or v.ability.set,blueprint_compat=true}}
  return v
 end
 for i,c in ipairs(s.hand) do local v=live(c,i);G.hand.cards[i]=v;G.playing_cards[#G.playing_cards+1]=v end
 G.hand.cards[7].facing='back';G.hand.cards[7].sprite_facing='back'
 for i,c in ipairs(s.deck) do local v=live(c,7+i);v.facing='back';v.sprite_facing='back';G.deck.cards[i]=v;G.playing_cards[#G.playing_cards+1]=v end
 for i,c in ipairs(s.jokers) do G.jokers.cards[i]=live(c,30+i,true) end
 local ace=G.hand.cards[1];local queen=G.hand.cards[2];local callbacks=0;local pending
 G.FUNCS.can_discard=function(e)e.config.button='discard_cards_from_highlighted'end
 G.FUNCS.discard_cards_from_highlighted=function()
  callbacks=callbacks+1;pending={};for _,c in ipairs(G.hand.highlighted) do pending[c]=true end
 end
 for remaining=3,1,-1 do
  complete(A)
  check(A.result.action.kind=='discard' and A.result.concealed_belief.scope=='visible_retained_floor','captured hidden-hand runtime selects proved discard')
  check(A.selection.kind=='discard' and A.display.title:find('Discard ',1,true)==1,'rendered action agrees with final advice: '..tostring(A.selection.kind)..' / '..tostring(A.display.title))
  check(A.execute(),'production adapter accepts actual physical discard selection')
  check(not pending[ace] and not pending[queen],'execution retains the exact winning Ace and Queen objects')
  check(not A.execute() and callbacks==4-remaining,'no duplicate callback before settlement')
  local retained={};local count=0
  for _,c in ipairs(G.hand.cards) do if pending[c] then count=count+1 else retained[#retained+1]=c end end
  G.hand.cards=retained;G.hand.highlighted={}
  while #G.hand.cards<7 and #G.deck.cards>0 do local c=table.remove(G.deck.cards,1);c.facing='front';c.sprite_facing='front';G.hand.cards[#G.hand.cards+1]=c end
  G.GAME.current_round.discards_left=remaining-1;G.GAME.current_round.discards_used=4-remaining
  G.jokers.cards[1].ability.yorick_discards=G.jokers.cards[1].ability.yorick_discards-count
 end
 complete(A)
 check(A.result.action.kind=='play' and A.snapshot.capture(G).discards_left==0,'fresh runtime finishes only after all three discards settled')
end
print('advisor_visible_discard_runtime416: '..checks..' checks passed')

--417: observed-shape passive income and fixed main-stage Mult cannot block
-- a safe five-card Psychic anchor. Real adapter callbacks settle between advice.
do
 local F=dofile('tests/fixtures/repair416.lua');local A=setup()
 local function complete417()
  -- This harness advances its clock by5ms on every timer read, allowing only
  -- one coroutine yield per update. Give the full production ordering modules
  -- enough synthetic frames; their actual score budget remains unchanged.
  for _=1,5000 do A.update(0.1);if A.result and not A.worker then
   check(A.result.evaluations<=140000,'full runtime comparison retains the ordinary score cap');return
  end end
  error('417 runtime did not finish: '..table.concat(A.lines or {},' | ')..' / worker='..tostring(A.worker))
 end
 A.teacher_profile='perkeo_yorick_win_v1';Brainstorm.config.advisor.gold_stickers=true
 A.strategy=dofile('Brainstorm/Advisor/strategy.lua');A.scoring=dofile('Brainstorm/Advisor/scoring.lua')
 G.GAME.challenge=nil;G.GAME.win_ante=8;G.GAME.dollars=35;G.GAME.probabilities={normal=1}
 G.GAME.round_resets={ante=4,hands=4,discards=3};G.GAME.current_round.discards_left=3
 G.GAME.blind={name='The Psychic',chips=1000,config={blind={key='bl_psychic'}}}
 G.hand.cards={};G.deck.cards={};G.playing_cards={};G.jokers.cards={}
 local function live(c,id,joker)
  local v=F.copy(c);v.playing_card=not joker and id or nil;v.sort_id=id
  v.facing='front';v.sprite_facing='front';v.base=v.base or {};v.base.suit=v.suit
  v.config={center_key=v.key,center={key=v.key,name=v.ability.name,set=joker and 'Joker' or v.ability.set,blueprint_compat=v.blueprint_compat}}
  return v
 end
 for i,r in ipairs({13,12,11,7,3,4,6,8}) do
  local v=live(F.card('made'..i,r,({'Clubs','Spades','Diamonds','Hearts'})[(i-1)%4+1],i<=3 and 'm_mult' or 'c_base'),i)
  G.hand.cards[i]=v;G.playing_cards[#G.playing_cards+1]=v
 end
 for i=1,15 do local v=live(F.card('draw'..i,2+i%6,'Clubs'),8+i);v.facing='back';v.sprite_facing='back';G.deck.cards[i]=v;G.playing_cards[#G.playing_cards+1]=v end
 local row={F.joker('j_cloud_9','Cloud 9',{extra=1,nine_tally=3}),F.joker('j_popcorn','Popcorn',{extra=4,mult=20}),
  F.joker('j_yorick','Yorick',{x_mult=3,yorick_discards=23,extra={discards=23,xmult=1}}),F.joker('j_perkeo','Perkeo')}
 row[1].ability.effect=nil;row[1].blueprint_compat=false;row[2].ability.effect=nil
 for i,c in ipairs(row) do G.jokers.cards[i]=live(c,30+i,true) end
 local captured=A.snapshot.capture(G);captured.teacher_profile=A.teacher_profile
 local anchor=A.scoring.score(captured,{1,2,3,4,5});anchor.indices={1,2,3,4,5}
 local retained,proof_work=A.growth.suggest(captured,A,anchor,{exhaust_discards=true,max_evaluations=12})
 check(retained and #retained.action.indices==3 and proof_work<=12,'actual capture qualifies the five-card retained floor')
 local callbacks=0;local pending
 G.FUNCS.can_discard=function(e)e.config.button='discard_cards_from_highlighted'end
 G.FUNCS.discard_cards_from_highlighted=function()
  callbacks=callbacks+1;pending={};for _,c in ipairs(G.hand.highlighted) do pending[c]=true end
 end
 for remaining=3,1,-1 do
  complete417()
  check(A.result.action.kind=='discard' and A.result.discard_before_clear.selected,'real captured Cloud9/Popcorn Psychic selects discard')
  local advised=F.copy(A.result.action.indices);local reason=A.result.discard_before_clear.reason
  check(A.selection.kind=='discard','presentation highlights discard rather than clearing play')
  check(A.execute(),'real adapter accepts the selected physical discard')
  check(not A.execute() and callbacks==4-remaining,'pending callback cannot execute twice')
  local held={};local n=0;for _,c in ipairs(G.hand.cards) do if pending[c] then n=n+1 else held[#held+1]=c end end
  check(n==#advised,'physical callback discards exactly the published cards')
  if reason=='supported_retained_clear' then check(#held>=5,'retained proof keeps five legal Psychic cards') end
  G.hand.cards=held;G.hand.highlighted={}
  while #G.hand.cards<8 and #G.deck.cards>0 do local c=table.remove(G.deck.cards,1);c.facing='front';c.sprite_facing='front';G.hand.cards[#G.hand.cards+1]=c end
  G.GAME.current_round.discards_left=remaining-1;G.GAME.current_round.discards_used=4-remaining
  G.jokers.cards[3].ability.yorick_discards=G.jokers.cards[3].ability.yorick_discards-n
 end
 complete417();check(A.result.action.kind=='play' and #A.result.action.indices==5,'fresh final advice plays a legal five-card Psychic hand after exhausting discards')
 check(A.scoring.score(A.snapshot.capture(G),A.result.action.indices).score>=1000,'fresh physical final hand actually clears the manufactured target')
end
print('advisor_retained_scope_runtime417: '..checks..' checks passed')

--418: actual captured hidden spare slots can be discarded only through the
-- qualified public projection. Physical objects, settlement and callbacks stay real.
do
 local F=dofile('tests/fixtures/retained418.lua');local s=F.state(false);local A=setup()
 A.teacher_profile='perkeo_yorick_win_v1';Brainstorm.config.advisor.gold_stickers=true
 A.strategy=dofile('Brainstorm/Advisor/strategy.lua');A.scoring=dofile('Brainstorm/Advisor/scoring.lua')
 G.GAME.challenge=nil;G.GAME.win_ante=8;G.GAME.dollars=30;G.GAME.probabilities={normal=1}
 G.GAME.round_resets={ante=4,hands=4,discards=3};G.GAME.current_round.discards_left=3
 G.GAME.blind={name='The House',chips=2000,config={blind={key='bl_house'}}}
 G.hand.cards={};G.deck.cards={};G.playing_cards={};G.jokers.cards={};G.discard={cards={}}
 local function live(c,id,joker)
  local v=F.copy(c);v.playing_card=not joker and id or nil;v.sort_id=id
  v.facing='front';v.sprite_facing='front';v.base=v.base or {};v.base.suit=v.suit
  v.config={center_key=v.key,center={key=v.key,name=v.ability.name,set=joker and 'Joker' or v.ability.set,blueprint_compat=v.blueprint_compat}}
  return v
 end
 for i,c in ipairs(s.hand) do local v=live(c,i);if i>=6 then v.facing='back';v.sprite_facing='back' end
  G.hand.cards[i]=v;G.playing_cards[#G.playing_cards+1]=v
 end
 for i,c in ipairs(s.deck) do local v=live(c,8+i);v.facing='back';v.sprite_facing='back';G.deck.cards[i]=v;G.playing_cards[#G.playing_cards+1]=v end
 for i,c in ipairs(s.jokers) do G.jokers.cards[i]=live(c,30+i,true) end
 local callbacks=0;local pending;local original_anchor={}
 for i=1,5 do original_anchor[G.hand.cards[i]]=true end
 G.FUNCS.can_discard=function(e)e.config.button='discard_cards_from_highlighted'end
 G.FUNCS.discard_cards_from_highlighted=function()
  callbacks=callbacks+1;pending={};for _,c in ipairs(G.hand.highlighted) do pending[c]=true end
 end
 local function finish()
  for _=1,5000 do A.update(0.1);if A.result and not A.worker then return end end
  error('418 runtime did not complete: '..table.concat(A.lines or {},' | '))
 end
 for remaining=3,1,-1 do
  finish();check(A.result.action.kind=='discard','full captured public decision spends the available discard')
  check(A.result.evaluations<=140000 and A.result.discard_before_clear.evaluations<=12,'runtime public work stays bounded')
  if remaining==3 then
   check(A.result.concealed_belief.retained.hidden_discard_scope=='canonical_identity_independent_no_hidden_rewards','initial advice certifies hidden discard independence')
   check(#A.result.action.indices==3,'initial advice spends every safe spare slot')
   for _,i in ipairs(A.result.action.indices) do check(G.hand.cards[i].facing=='back','advised indices are actual concealed spares') end
  end
  check(A.execute(),'real Execute accepts the physically legal public discard')
  check(not A.execute() and callbacks==4-remaining,'pending action cannot dispatch twice')
  local retained={};local count=0
  for _,c in ipairs(G.hand.cards) do
   if pending[c] then
    if remaining==3 then check(not original_anchor[c] and c.facing=='back','callback selects only hidden spares on first discard') end
    count=count+1;c.ability.discarded=true;G.discard.cards[#G.discard.cards+1]=c
   else retained[#retained+1]=c end
  end
  G.hand.cards=retained;G.hand.highlighted={}
  while #G.hand.cards<8 and #G.deck.cards>0 do local c=table.remove(G.deck.cards,1);c.facing='front';c.sprite_facing='front';G.hand.cards[#G.hand.cards+1]=c end
  G.GAME.current_round.discards_left=remaining-1;G.GAME.current_round.discards_used=4-remaining
  G.jokers.cards[1].ability.yorick_discards=G.jokers.cards[1].ability.yorick_discards-count
 end
 finish();check(A.result.action.kind=='play' and G.GAME.current_round.discards_left==0,'fresh runtime plays after all three physical settlements')
 check(A.scoring.score(A.snapshot.capture(G),A.result.action.indices).score>=2000,'actual final physical hand clears')
 check(#G.playing_cards==#s.playing_cards,'public population includes unknown discarded cards after every settlement')
end
print('advisor_retained_families_runtime418: '..checks..' checks passed')
