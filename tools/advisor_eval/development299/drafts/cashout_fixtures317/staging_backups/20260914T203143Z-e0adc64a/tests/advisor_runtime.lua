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
  equal(A.result, nil, 'hand reorder during drag invalidates old result')
  equal(A.selection, nil, 'hand reorder removes old card indices')
  G.CONTROLLER.dragging.target = nil
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
    manual=function()active=false;stops=stops+1 end}
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
print('advisor_runtime: ' .. checks .. ' checks passed')
