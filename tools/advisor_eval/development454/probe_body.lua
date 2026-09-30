-- Bounded original-source Golden/rental probe. PROBE_CASES and source methods
-- are prepended by prepare_source_probe.py. This file alone is never run.
local function noop() end
Event = function(event) return event end
localize = function() return '$' end
inc_career_stat = noop
check_and_set_high_score = noop
check_for_unlock = noop
attention_text = noop
play_sound = noop
delay = noop
ease_background_colour_blind = noop

local queue, rows, callback_statuses
card_eval_status_text = function(_, kind)
    if kind == 'jokers' then callback_statuses = callback_statuses + 1 end
end
add_round_eval_row = function(row) rows[row.name] = row.dollars end

local function flush_bounded()
    local index = 1
    while queue[index] do
        assert(index <= 32, 'event queue cap')
        assert(queue[index].func(), 'event did not settle')
        index = index + 1
    end
    return index - 1
end

local function run_case(fixture)
    queue, rows, callback_statuses = {}, {}, 0
    local opening_cash = fixture.cash
    G = {
        C = {MONEY = {}, RED = {}, FILTER = {}},
        FUNCS = {evaluate_round = source_evaluate_round},
        STATES = {ROUND_EVAL = 1},
        GAME = {
            dollars = opening_cash, rental_rate = 3, blind = nil,
            current_round = {hands_left = 0, discards_left = 0, discards_used = 0},
            modifiers = {}, interest_amount = 1, interest_cap = 25,
            chips = 1, tags = {}, challenge = true, seeded = true,
            selected_back = {trigger_effect = noop}
        },
        jokers = {cards = {}},
        hand = {change_size = noop},
        consumeables = {cards = {}, config = {card_limit = 2}},
        HUD = {
            get_UIE_by_ID = function()
                return {config = {object = {update = noop}}, parent = {}}
            end,
            recalculate = noop
        },
        E_MANAGER = {add_event = function(_, event)
            queue[#queue + 1] = event
            return event
        end}
    }
    for _, spec in ipairs(fixture.jokers) do
        assert(spec.edition == nil, 'plain edition only')
        local name = spec.center_key == 'j_golden' and 'Golden Joker' or 'Joker'
        assert(spec.center_key == 'j_golden' or spec.center_key == 'j_joker', 'unsupported Joker')
        local card = setmetatable({
            physical_id = spec.physical_id,
            ability = {set = 'Joker', name = name, extra = name == 'Golden Joker' and 4 or 0,
                       h_size = 0, d_size = 0, perishable = spec.perishable,
                       perish_tally = spec.tally, rental = spec.rental},
            debuff = spec.debuff, added_to_deck = true
        }, {__index = Card})
        card.area = G.jokers
        G.jokers.cards[#G.jokers.cards + 1] = card
    end
    source_round_end_loop() -- Exact row loop extracted from state_events.lua.
    local cash_before_flush = G.GAME.dollars
    local queued_after_round = #queue
    local flushed = flush_bounded() -- Executes original ease_dollars queued callbacks.
    local settled_cash = G.GAME.dollars
    assert(queued_after_round == flushed, 'unexpected queued effects')
    assert(callback_statuses == 0, 'unexpected end-of-round callback')
    G.GAME.blind = {chips = 1, dollars = 0, defeat = noop}
    G.FUNCS.evaluate_round() -- Exact original cash-out evaluation function.
    local tally = {}
    for _, card in ipairs(G.jokers.cards) do
        tally[#tally + 1] = card.physical_id .. ':' .. card.ability.perish_tally .. ':' ..
                            (card.debuff and '1' or '0')
    end
    local joker_bonus = 0
    for key, amount in pairs(rows) do
        if string.match(key, '^joker%d+$') then joker_bonus = joker_bonus + amount end
    end
    print('CASE|' .. fixture.id .. '|' .. cash_before_flush .. '|' ..
          queued_after_round .. '|' .. settled_cash .. '|' .. joker_bonus .. '|' ..
          (rows.interest or 0) .. '|' .. (rows.bottom or 0) .. '|' ..
          table.concat(tally, ','))
end

for _, fixture in ipairs(PROBE_CASES) do run_case(fixture) end
