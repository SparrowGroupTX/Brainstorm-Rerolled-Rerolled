G = {FUNCS = {}}
G.FUNCS.cash_out = function(e)
    stop_use()
      if G.round_eval then  
        e.config.button = nil
        G.round_eval.alignment.offset.y = G.ROOM.T.y + 15
        G.round_eval.alignment.offset.x = 0
        G.deck:shuffle('cashout'..G.GAME.round_resets.ante)
        G.deck:hard_set_T()
        delay(0.3)
        G.E_MANAGER:add_event(Event({
          trigger = 'immediate',
          func = function()
              if G.round_eval then 
                G.round_eval:remove()
                G.round_eval = nil
              end
              G.GAME.current_round.jokers_purchased = 0
              G.GAME.current_round.discards_left = math.max(0, G.GAME.round_resets.discards + G.GAME.round_bonus.discards)
              G.GAME.current_round.hands_left = (math.max(1, G.GAME.round_resets.hands + G.GAME.round_bonus.next_hands))
              G.STATE = G.STATES.SHOP
              G.GAME.shop_free = nil
              G.GAME.shop_d6ed = nil
              G.STATE_COMPLETE = false
            return true
          end
        }))
        ease_dollars(G.GAME.current_round.dollars)
        G.E_MANAGER:add_event(Event({
          func = function()
              G.GAME.previous_round.dollars = G.GAME.dollars
            return true
          end
        }))
        play_sound("coin7")
        G.VIBRATION = G.VIBRATION + 1
      end
      ease_chips(0)
      if G.GAME.round_resets.blind_states.Boss == 'Defeated' then 
        G.GAME.round_resets.blind_ante = G.GAME.round_resets.ante
        G.GAME.round_resets.blind_tags.Small = get_next_tag_key()
        G.GAME.round_resets.blind_tags.Big = get_next_tag_key()
      end
      reset_blinds()
      delay(0.6)
end

source_cash_out = G.FUNCS.cash_out
function ease_dollars(mod, instant)
    local function _mod(mod)
        local dollar_UI = G.HUD:get_UIE_by_ID('dollar_text_UI')
        mod = mod or 0
        local text = '+'..localize('$')
        local col = G.C.MONEY
        if mod < 0 then
            text = '-'..localize('$')
            col = G.C.RED              
        else
          inc_career_stat('c_dollars_earned', mod)
        end
        --Ease from current chips to the new number of chips
        G.GAME.dollars = G.GAME.dollars + mod
        check_and_set_high_score('most_money', G.GAME.dollars)
        check_for_unlock({type = 'money'})
        dollar_UI.config.object:update()
        G.HUD:recalculate()
        --Popup text next to the chips in UI showing number of chips gained/lost
        attention_text({
          text = text..tostring(math.abs(mod)),
          scale = 0.8, 
          hold = 0.7,
          cover = dollar_UI.parent,
          cover_colour = col,
          align = 'cm',
          })
        --Play a chip sound
        play_sound('coin1')
    end
    if instant then
        _mod(mod)
    else
        G.E_MANAGER:add_event(Event({
        trigger = 'immediate',
        func = function()
            _mod(mod)
            return true
        end
        }))
    end
end

function reset_blinds()
    G.GAME.round_resets.blind_states = G.GAME.round_resets.blind_states or {Small = 'Select', Big = 'Upcoming', Boss = 'Upcoming'}
    if G.GAME.round_resets.blind_states.Boss == 'Defeated' then
        G.GAME.round_resets.blind_states.Small = 'Upcoming'
        G.GAME.round_resets.blind_states.Big = 'Upcoming'
        G.GAME.round_resets.blind_states.Boss = 'Upcoming'
        G.GAME.blind_on_deck = 'Small'
        G.GAME.round_resets.blind_choices.Boss = get_new_boss()
        G.GAME.round_resets.boss_rerolled = false
    end
end

PROBE_CASES = {{["id"]="minimal_stale_resources",["cash"]=7,["earnings_total"]=1,["current_round"]={["hands_left"]=0,["discards_left"]=0,["jokers_purchased"]=2,["hands_played"]=3,["discards_used"]=1},["round_resets"]={["hands"]=4,["discards"]=3},["round_bonus"]={["next_hands"]=0,["discards"]=0},["previous_round"]={["dollars"]=4},["flags"]={["shop_free"]=true,["shop_d6ed"]=true}},{["id"]="already_correct_resources",["cash"]=8,["earnings_total"]=2,["current_round"]={["hands_left"]=4,["discards_left"]=3,["jokers_purchased"]=0,["hands_played"]=2,["discards_used"]=0},["round_resets"]={["hands"]=4,["discards"]=3},["round_bonus"]={["next_hands"]=0,["discards"]=0},["previous_round"]={["dollars"]=5},["flags"]={}},{["id"]="shop_entry_bonus_composition",["cash"]=2,["earnings_total"]=4,["current_round"]={["hands_left"]=0,["discards_left"]=1,["jokers_purchased"]=1,["hands_played"]=4,["discards_used"]=2},["round_resets"]={["hands"]=4,["discards"]=3},["round_bonus"]={["next_hands"]=2,["discards"]=1},["previous_round"]={["dollars"]=1},["flags"]={}},{["id"]="shop_entry_lower_bounds",["cash"]=0,["earnings_total"]=0,["current_round"]={["hands_left"]=0,["discards_left"]=0,["jokers_purchased"]=3,["hands_played"]=1,["discards_used"]=0},["round_resets"]={["hands"]=0,["discards"]=0},["round_bonus"]={["next_hands"]=-2,["discards"]=-1},["previous_round"]={["dollars"]=9},["flags"]={}},{["id"]="heldout_zero_payment_with_carry",["cash"]=12,["earnings_total"]=0,["current_round"]={["hands_left"]=3,["discards_left"]=2,["jokers_purchased"]=4,["hands_played"]=2,["discards_used"]=1},["round_resets"]={["hands"]=5,["discards"]=2},["round_bonus"]={["next_hands"]=0,["discards"]=0},["previous_round"]={["dollars"]=5,["carry_marker"]="retain"},["flags"]={["shop_free"]=true,["shop_d6ed"]=true}},{["id"]="negative_payment_control",["cash"]=2,["earnings_total"]=-3,["current_round"]={["hands_left"]=1,["discards_left"]=0,["jokers_purchased"]=0,["hands_played"]=3,["discards_used"]=2},["round_resets"]={["hands"]=4,["discards"]=3},["round_bonus"]={["next_hands"]=0,["discards"]=0},["previous_round"]={["dollars"]=2},["flags"]={}}}
-- Exact source functions and six fixture literals are prepended at prepare time.
-- This file is never run by itself. UI/animation and ease_chips(0) are excluded.
local function noop() end
local queue, delay_calls, chip_calls, stop_calls, shuffle_calls, hard_set_calls
local shuffle_key, round_eval_removals
local total_event_executions = 0

Event = function(config)
    assert(type(config.func) == 'function', 'event callback required')
    assert(config.trigger == nil or config.trigger == 'immediate', 'unexpected event trigger')
    assert(config.queue == nil and config.front == nil, 'unexpected event queue/front')
    assert(config.delay == nil, 'unexpected event delay')
    return {trigger = config.trigger or 'immediate', func = config.func}
end
stop_use = function() stop_calls = stop_calls + 1 end
delay = function(_) delay_calls = delay_calls + 1 end
ease_chips = function(amount)
    assert(amount == 0, 'unexpected chip mutation')
    chip_calls = chip_calls + 1
end
get_next_tag_key = function() error('Boss tag branch unsupported') end
get_new_boss = function() error('Boss reset branch unsupported') end
localize = function() return '$' end
inc_career_stat = noop
check_and_set_high_score = noop
check_for_unlock = noop
attention_text = noop
play_sound = noop

local function copy_table(source)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    return result
end

local function bit(value) return value and 1 or 0 end
local function fields(kind, fixture_id, data)
    local parts = {kind, fixture_id}
    for _, row in ipairs(data) do parts[#parts + 1] = row[1] .. '=' .. tostring(row[2]) end
    print(table.concat(parts, '|'))
end

local function snapshot()
    local cr = G.GAME.current_round
    return {
        phase = G.STATE, cash = G.GAME.dollars,
        hands = cr.hands_left, discards = cr.discards_left,
        purchases = cr.jokers_purchased,
        previous_dollars = G.GAME.previous_round.dollars,
        shop_free_present = bit(G.GAME.shop_free ~= nil),
        shop_d6ed_present = bit(G.GAME.shop_d6ed ~= nil),
        eval_removed = bit(G.round_eval == nil),
    }
end

local function print_frame(id, index, state)
    fields('FRAME', id, {
        {'index', index}, {'phase', state.phase}, {'cash', state.cash},
        {'hands', state.hands}, {'discards', state.discards},
        {'purchases', state.purchases}, {'previous_dollars', state.previous_dollars},
        {'shop_free_present', state.shop_free_present},
        {'shop_d6ed_present', state.shop_d6ed_present},
        {'eval_removed', state.eval_removed},
    })
end

local function run_case(fixture)
    queue, delay_calls, chip_calls, stop_calls = {}, 0, 0, 0
    shuffle_calls, hard_set_calls, shuffle_key, round_eval_removals = 0, 0, nil, 0
    local cr = copy_table(fixture.current_round)
    cr.dollars = fixture.earnings_total
    local rr = copy_table(fixture.round_resets)
    rr.ante = 1
    rr.blind_states = {Small = 'Defeated', Big = 'Upcoming', Boss = 'Upcoming'}
    rr.blind_tags = {}
    local rb = copy_table(fixture.round_bonus)
    local previous = copy_table(fixture.previous_round)
    local opening_cash = fixture.cash
    G = {
        FUNCS = {cash_out = source_cash_out},
        STATES = {ROUND_EVAL = 'round_eval', SHOP = 'shop'},
        STATE = 'round_eval', STATE_COMPLETE = true,
        GAME = {
            dollars = opening_cash, current_round = cr,
            round_resets = rr, round_bonus = rb, previous_round = previous,
            shop_free = fixture.flags.shop_free,
            shop_d6ed = fixture.flags.shop_d6ed,
        },
        deck = {
            shuffle = function(_, key)
                shuffle_calls = shuffle_calls + 1
                shuffle_key = key
            end,
            hard_set_T = function(_) hard_set_calls = hard_set_calls + 1 end,
        },
        ROOM = {T = {y = 0}}, VIBRATION = 0,
        C = {MONEY = {}, RED = {}},
        HUD = {
            get_UIE_by_ID = function(_)
                return {config = {object = {update = noop}}, parent = {}}
            end,
            recalculate = noop,
        },
        E_MANAGER = {
            add_event = function(_, event, queue_name, front)
                assert(queue_name == nil and front == nil, 'unexpected queue/front insertion')
                assert(#queue < 3, 'unexpected appended event')
                queue[#queue + 1] = event
                return event
            end,
        },
        round_eval = {
            alignment = {offset = {x = 9, y = 9}},
            remove = function(_) round_eval_removals = round_eval_removals + 1 end,
        },
    }
    local button = {config = {button = 'cash_out'}}
    G.FUNCS.cash_out(button)
    assert(button.config.button == nil, 'button not disabled')
    assert(G.round_eval.alignment.offset.x == 0 and
           G.round_eval.alignment.offset.y == 15, 'eval animation target')
    assert(shuffle_calls == 1 and shuffle_key == 'cashout1', 'shuffle key/call')
    assert(hard_set_calls == 1, 'hard_set_T call')
    assert(delay_calls == 2 and chip_calls == 1 and stop_calls == 1, 'excluded calls')
    assert(G.VIBRATION == 1, 'vibration call')
    assert(#queue == 3, 'exactly three queued callbacks required')
    assert(G.GAME.dollars == opening_cash and G.STATE == 'round_eval',
           'cash or phase mutated before queue drain')
    assert(G.GAME.previous_round.dollars == fixture.previous_round.dollars,
           'previous dollars mutated before queue drain')

    local queued = #queue
    local index = 1
    while queue[index] do
        assert(total_event_executions < 18, 'total event execution cap')
        total_event_executions = total_event_executions + 1
        assert(queue[index].trigger == 'immediate', 'non-immediate callback')
        assert(queue[index].func() == true, 'event did not settle')
        local state = snapshot()
        print_frame(fixture.id, index, state)
        if index == 1 then
            assert(state.phase == 'shop' and state.cash == opening_cash and
                   state.eval_removed == 1 and G.STATE_COMPLETE == false,
                   'shop-entry callback state')
        elseif index == 2 then
            assert(state.cash == opening_cash + fixture.earnings_total and
                   state.previous_dollars == fixture.previous_round.dollars,
                   'queued payment state')
        elseif index == 3 then
            assert(state.previous_dollars == state.cash, 'previous-round capture')
        end
        index = index + 1
    end
    assert(index - 1 == queued and queued == 3, 'unexpected appended event')
    assert(round_eval_removals == 1, 'round eval removal count')
    assert(G.GAME.previous_round == previous, 'previous_round table replaced')
    assert(cr.hands_played == fixture.current_round.hands_played and
           cr.discards_used == fixture.current_round.discards_used,
           'unrelated current_round fields changed')
    assert(rr.hands == fixture.round_resets.hands and
           rr.discards == fixture.round_resets.discards and
           rb.next_hands == fixture.round_bonus.next_hands and
           rb.discards == fixture.round_bonus.discards, 'resets/bonuses changed')

    local settled = snapshot()
    local repeat_button = {config = {button = 'repeat'}}
    G.FUNCS.cash_out(repeat_button)
    assert(#queue == queued and G.GAME.dollars == settled.cash and
           G.GAME.previous_round.dollars == settled.previous_dollars,
           'repeat cash-out changed settlement')
    assert(stop_calls == 2 and chip_calls == 2 and delay_calls == 3,
           'repeat excluded call count')
    fields('CASE', fixture.id, {
        {'pre_cash', opening_cash}, {'queued', queued},
        {'settled_cash', settled.cash}, {'hands', settled.hands},
        {'discards', settled.discards}, {'purchases', settled.purchases},
        {'previous_dollars', settled.previous_dollars},
        {'carry_marker', previous.carry_marker or '<none>'},
        {'shop_free_present', settled.shop_free_present},
        {'shop_d6ed_present', settled.shop_d6ed_present},
        {'phase', settled.phase}, {'previous_identity', bit(G.GAME.previous_round == previous)},
        {'shuffle_key', shuffle_key}, {'repeat_queued', #queue - queued},
        {'hands_played', cr.hands_played}, {'discards_used', cr.discards_used},
        {'reset_hands', rr.hands}, {'reset_discards', rr.discards},
        {'bonus_hands', rb.next_hands}, {'bonus_discards', rb.discards},
    })
end

for _, fixture in ipairs(PROBE_CASES) do run_case(fixture) end

