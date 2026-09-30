-- The prepare step prepends exact stock and use snippets as source_stock and
-- source_use_booster. This harness is inert until the separately approved
-- one-use worker executes prepared_source_probe.lua.
local case_id, fixture, draw_count, construct_count, ui_count, materialize_count
local offer_count, open_count, open_seen, draw_card_count, delay_count
local source_trace_count = 0

local function shown(value)
    if value == nil then return '<nil>' end
    return tostring(value)
end

local function trace(kind, slot, key)
    source_trace_count = source_trace_count + 1
    assert(source_trace_count <= 80, 'source trace cap')
    print(table.concat({'TRACE', case_id, kind, shown(slot), shown(key)}, '|'))
end

local function copy_numeric(source)
    local target = {}
    for key, value in pairs(source) do target[key] = value end
    return target
end

Card = setmetatable({}, {__call = function(_, x, y, w, h, base, center, params)
    assert(center and center.key and base == G.P_CARDS.empty, 'invalid Card center/base')
    assert(x == G.shop_booster.T.x + G.shop_booster.T.w/2 and
           y == G.shop_booster.T.y and w == G.CARD_W*1.27 and
           h == G.CARD_H*1.27, 'unexpected booster geometry')
    assert(params and params.bypass_discovery_center and
           params.bypass_discovery_ui, 'unexpected Card params')
    construct_count = construct_count + 1
    assert(construct_count <= 16, 'Card construction cap')
    local card = {center_key = center.key, ability = {set = 'Booster'},
                  ui_seen = false, materialized = false}
    function card:start_materialize()
        assert(self.ui_seen and not self.materialized, 'materialize before UI/duplicate')
        self.materialized = true
        materialize_count = materialize_count + 1
        trace('MATERIALIZE', self.ability.booster_pos, self.center_key)
    end
    function card:open()
        open_count = open_count + 1
        assert(open_count <= 1, 'open cap')
        open_seen = G.GAME.current_round.used_packs[self.ability.booster_pos]
        trace('OPEN', self.ability.booster_pos, open_seen)
    end
    return card
end})

create_shop_card_ui = function(card, set_name, area)
    assert(set_name == 'Booster' and area == G.shop_booster, 'unexpected UI call')
    assert(card.ability.booster_pos == nil and not card.ui_seen,
           'source booster_pos order changed')
    card.ui_seen = true
    ui_count = ui_count + 1
    trace('UI', nil, card.center_key)
end

get_pack = function(key)
    assert(key == 'shop_pack', 'unexpected pack stream')
    local used = G.GAME.current_round.used_packs
    local slot = nil
    for i = 1, 2 do if not used[i] then slot = i; break end end
    assert(slot ~= nil, 'get_pack called for a stored/used slot')
    draw_count = draw_count + 1
    assert(draw_count <= 16 and draw_count <= #fixture.draws, 'extra get_pack call')
    local pack_key = fixture.draws[draw_count]
    local center = G.P_CENTERS[pack_key]
    assert(center and center.key == pack_key, 'unknown prescribed pack')
    trace('DRAW', slot, pack_key)
    return center
end

delay = function(amount)
    assert(amount == 0.1, 'unexpected use delay')
    delay_count = delay_count + 1
end
draw_card = function(from, to, count, direction, visible, card)
    assert(from == G.hand and to == G.play and count == 1 and
           direction == 'up' and visible == true and card, 'unexpected draw_card')
    draw_card_count = draw_card_count + 1
end

local function run_case(row)
    fixture, case_id = row, row.id
    draw_count, construct_count, ui_count, materialize_count = 0, 0, 0, 0
    offer_count, open_count, open_seen, draw_card_count, delay_count = 0, 0, nil, 0, 0
    local used = copy_numeric(row.used_packs)
    local area = {T = {x = 0, y = 0, w = 2}, cards = {}}
    function area:emplace(card)
        assert(card.materialized and card.ability.booster_pos and
               self == G.shop_booster, 'invalid booster emplace')
        assert(G.GAME.current_round.used_packs[card.ability.booster_pos] ==
               card.center_key, 'offer does not match persisted slot')
        self.cards[#self.cards + 1] = card
        offer_count = offer_count + 1
        trace('OFFER', card.ability.booster_pos, card.center_key)
    end
    local centers = {}
    for _, key in ipairs(row.draws) do centers[key] = {key = key} end
    for _, key in pairs(used) do
        if key ~= 'USED' then centers[key] = {key = key} end
    end
    G = {
        GAME = {current_round = {used_packs = used}, dollars = row.cash,
                round_scores = {cards_purchased = {amt = 0}}},
        shop_booster = area, CARD_W = 1, CARD_H = 1,
        P_CARDS = {empty = {}}, P_CENTERS = centers,
        hand = {}, play = {},
    }
    source_stock()
    assert(draw_count == #row.draws, 'missing prescribed get_pack call')
    assert(construct_count == #area.cards and ui_count == #area.cards and
           materialize_count == #area.cards and offer_count == #area.cards,
           'Card/UI/materialize/offer count mismatch')
    print(table.concat({'STOCK', case_id, 'used1=' .. shown(used[1]),
        'used2=' .. shown(used[2]), 'draws=' .. draw_count,
        'offers=' .. offer_count}, '|'))

    if row.id == 'used_first_stored_second' then
        assert(#area.cards == 1, 'opening fixture offer count')
        local opened = area.cards[1]
        source_use_booster(opened, {config = {ref_table = opened}})
        assert(open_count == 1 and draw_card_count == 1 and delay_count == 1 and
               G.GAME.round_scores.cards_purchased.amt == 1,
               'use-body stub call counts')
    else
        assert(open_count == 0, 'unexpected open')
    end
    print(table.concat({'CASE', case_id, 'used1=' .. shown(used[1]),
        'used2=' .. shown(used[2]), 'draws=' .. draw_count,
        'offers=' .. offer_count, 'open_seen=' .. shown(open_seen),
        'open_count=' .. open_count, 'cash=' .. G.GAME.dollars}, '|'))
end

assert(#PROBE_CASES == 8, 'exactly eight cases required')
for _, row in ipairs(PROBE_CASES) do run_case(row) end
