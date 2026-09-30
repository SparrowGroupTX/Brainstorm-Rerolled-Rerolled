local Strategy = dofile('Brainstorm/Advisor/strategy.lua')
local checks = 0
local function check(condition, message)
    checks = checks + 1
    assert(condition, message)
end

local function card(key, cost, extras)
    local out = {key=key, name=key, cost=cost or 0, ability={}}
    for field, value in pairs(extras or {}) do out[field] = value end
    return out
end

local function snapshot(extras)
    local out = {phase='shop', dollars=25, bankrupt_at=0, joker_limit=5,
        consumable_limit=2, jokers={}, consumeables={}, playing_cards={},
        shop_jokers={}, shop_booster={}, shop_vouchers={}, hand={}, deck={},
        hands={Pair={level=2,played=8}, Flush={level=1,played=1}}, ante=2,
        interest_cap=25, modifiers={}, reroll_cost=5}
    for field, value in pairs(extras or {}) do out[field] = value end
    return out
end

local function text(result)
    return result.title .. ' ' .. table.concat(result.lines, ' ') .. ' ' .. table.concat(result.warnings, ' ')
end

local function contains(result, value)
    return text(result):find(value, 1, true) ~= nil
end

local function actionable(result)
    -- Purchase/selection regressions allow navigation or a shop refresh.
    return result.action and result.action.area ~= nil
end

local function serialize(value)
    if type(value) ~= 'table' then return type(value) .. ':' .. tostring(value) end
    local keys, out = {}, {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do out[#out + 1] = serialize(key) .. '=' .. serialize(value[key]) end
    return '{' .. table.concat(out, ',') .. '}'
end

-- No live game, RNG, or mutations should be needed to give advice.
local old_random = math.random
math.random = function() error('Advice must not advance RNG') end
local immutable = snapshot({shop_jokers={card('j_joker',2)}, challenge='c_golden_needle_1'})
local before = serialize(immutable)
local first = Strategy.advise(immutable)
check(serialize(immutable) == before, 'strategy mutated its snapshot')
check(serialize(first) == serialize(Strategy.advise(immutable)), 'strategy is nondeterministic')
check(first.action and first.action.index == 1, 'buy a cheap scoring Joker early')

local result = Strategy.advise(snapshot({dollars=1,shop_jokers={card('j_joker',5)}}))
check(not actionable(result), 'must not recommend an unaffordable card')
result = Strategy.advise(snapshot({dollars=1,bankrupt_at=-20,shop_jokers={card('j_joker',5)}}))
check(result.action and result.action.index == 1, 'Credit Card permits affordable borrowing')
check(contains(result, 'debt'), 'a purchase into debt must be disclosed')

local full = {card('j_joker'),card('j_abstract'),card('j_card_sharp'),card('j_blue_joker'),card('j_golden')}
result = Strategy.advise(snapshot({jokers=full,shop_jokers={card('j_blueprint',8)}}))
check(not actionable(result), 'cannot buy an ordinary Joker into full slots')
result = Strategy.advise(snapshot({jokers=full,shop_jokers={card('j_blueprint',8,{edition={negative=true}})}}))
check(result.action ~= nil, 'a negative edition supplies its own slot')
result = Strategy.advise(snapshot({jokers=full,joker_limit=0,challenge='c_typecast_1',shop_jokers={card('j_blueprint',0,{edition={negative=true}})}}))
check(not actionable(result), 'a negative shop Joker does not bypass Typecast being over capacity')

result = Strategy.advise(snapshot({consumeables={card('c_pluto'),card('c_earth')},shop_jokers={card('c_hermit',3)}}))
check(not actionable(result), 'buying a stored consumable needs space')
result = Strategy.advise(snapshot({challenge='c_jokerless_1',joker_limit=0,
    shop_jokers={card('j_blueprint',0,{edition='negative'}),card('c_mercury',3)},shop_booster={card('p_buffoon_normal_1',0)}}))
check(result.action and result.action.area == 'shop_jokers' and result.action.index == 2, 'Jokerless must choose a Planet over illegal Jokers')

result = Strategy.advise(snapshot({modifiers={no_shop_jokers=true},shop_jokers={card('j_joker',0)}}))
check(not actionable(result), 'no_shop_jokers excludes shop Jokers')
result = Strategy.advise(snapshot({phase='pack',modifiers={no_shop_jokers=true},pack_cards={card('j_joker',0)}}))
check(result.action and result.action.index == 1, 'Bram Poker still allows Buffoon pack Jokers')

result = Strategy.advise(snapshot({shop_jokers={card('j_joker',2,{ability={rental=true}}),card('j_joker',2)}}))
check(result.action and result.action.index == 2, 'prefer the equivalent Joker without rental drain')
result = Strategy.advise(snapshot({shop_jokers={card('j_joker',2,{ability={eternal=true}}),card('j_joker',2)}}))
check(result.action and result.action.index == 2, 'prefer the equivalent Joker without a permanent slot commitment')
result = Strategy.advise(snapshot({shop_jokers={card('j_joker',0,{ability={perishable=true,perish_tally=0}})}}))
check(not actionable(result), 'expired perishable Jokers cannot provide scoring value')
for _, key in ipairs({'j_trousers','j_stencil','j_ticket','j_onyx_agate'}) do
    result = Strategy.advise(snapshot({dollars=50,playing_cards={card('m_gold',0,{rank=2,suit='Clubs',enhancement='m_gold'})},shop_jokers={card(key,2)}}))
    check(result.action ~= nil, 'recognize actual vanilla key ' .. key)
    check(not contains(result, 'generic strategic rating'), 'known card should not be treated as unknown: ' .. key)
end
result = Strategy.advise(snapshot({shop_jokers={card('j_ticket',2)}}))
check(not actionable(result), 'Golden Ticket has no income without Gold cards')
result = Strategy.advise(snapshot({shop_jokers={card('j_stencil',8)}}))
check(result.action ~= nil, 'a mostly empty Joker row makes Stencil a strong multiplier')

result = Strategy.advise(snapshot({shop_jokers={card('c_hermit',3),card('j_joker',2)}}))
check(result.action and result.action.index == 1, 'a near-capped Hermit is a strong economic purchase')
result = Strategy.advise(snapshot({phase='pack',dollars=0,pack_cards={card('c_hermit'),card('c_mercury')}}))
check(result.action and result.action.index == 2, 'Hermit has no payout at zero dollars')
result = Strategy.advise(snapshot({phase='pack',pack_cards={card('c_jupiter'),card('c_mercury')}}))
check(result.action and result.action.index == 2, 'choose the Planet for the established hand')

result = Strategy.advise(snapshot({phase='pack',pack_cards={card('c_soul')},joker_limit=0,challenge='c_jokerless_1'}))
check(not actionable(result), 'Soul is unusable in Jokerless')
result = Strategy.advise(snapshot({phase='pack',pack_cards={card('c_fool')}}))
check(not actionable(result), 'Fool cannot copy a missing previous card')
result = Strategy.advise(snapshot({phase='pack',pack_cards={card('c_death')},hand={card('c_base',0,{rank=2})}}))
check(not actionable(result), 'Death requires two available cards')
result = Strategy.advise(snapshot({phase='pack',pack_cards={card('c_immolate')},hand={}}))
check(not actionable(result), 'hand-transforming Spectrals need available hand cards')
result = Strategy.advise(snapshot({phase='pack',pack_cards={card('c_hex')}}))
check(not actionable(result), 'Hex requires an eligible Joker')
result = Strategy.advise(snapshot({phase='pack',pack_cards={card('c_ankh')},jokers=full}))
check(not actionable(result), 'Ankh cannot be used with all Joker slots full')
do
    local vulnerable = card('j_yorick',0,{edition={foil=true}})
    local perkeo = card('j_perkeo')
    local eternal = card('j_banner',0,{ability={eternal=true}})
    local row = {vulnerable,perkeo,eternal}
    local state = snapshot({phase='pack',jokers=row,pack_cards={card('c_hex')}})
    local before = serialize(state)
    result = Strategy.advise(state)
    check(not actionable(result), 'Hex cannot sacrifice the visible Yorick and Perkeo engine')
    check(serialize(state)==before, 'destructive-pack guard leaves the public state unchanged')
    state.pack_cards={card('c_hex'),card('c_mercury')}
    result = Strategy.advise(state)
    check(result.action and result.action.index==2, 'choose a useful safe alternative to destructive Hex')
    state.jokers={card('j_yorick'),card('j_banner',0,{ability={eternal=true}})}
    state.pack_cards={card('c_hex')}
    check(not actionable(Strategy.advise(state)), 'Hex selecting an Eternal could destroy the sole vulnerable Joker')
    state.jokers={card('j_yorick'),card('j_banner',0,{ability={eternal=true},edition={foil=true}})}
    check(actionable(Strategy.advise(state)), 'only eligible Joker survives when companions are Eternal')
    state.jokers={card('j_yorick')}
    check(actionable(Strategy.advise(state)), 'Hex remains useful with a sole eligible Joker')
    state.jokers={card('j_yorick'),card('j_banner',0,{ability={eternal=true}})}
    state.modifiers={all_eternal=true}
    check(actionable(Strategy.advise(state)), 'all-eternal challenge protects the complete row')
    state.modifiers={};state.jokers={card('j_unknown',0,{unknown=true}),card('j_yorick')}
    check(not actionable(Strategy.advise(state)), 'concealed Joker row cannot certify destructive Hex')
    state.jokers={card('j_yorick'),card('j_perkeo')};state.pack_cards={card('c_ankh')}
    check(not actionable(Strategy.advise(state)), 'Ankh cannot randomly destroy one of two vulnerable Jokers')
    state.jokers={card('j_yorick')}
    check(actionable(Strategy.advise(state)), 'Ankh remains useful with a sole Joker and a free slot')
    state.jokers={card('j_yorick',0,{ability={eternal=true}}),card('j_perkeo',0,{ability={eternal=true}})}
    check(actionable(Strategy.advise(state)), 'Ankh retains its all-Eternal safe case')
end
result = Strategy.advise(snapshot({phase='pack',pack_cards={card('c_emperor')},consumeables={card('c_pluto'),card('c_mercury')}}))
check(not actionable(result), 'pack Emperor cannot create consumables with full inventory')

result = Strategy.advise(snapshot({phase='pack',pack_cards={card('c_base',0,{rank=5,suit='Clubs'})}}))
check(not actionable(result) and contains(result, 'Skip'), 'skip a plain Standard card that dilutes a normal deck')
result = Strategy.advise(snapshot({phase='pack',pack_cards={card('c_base',0,{rank=5,suit='Clubs'}),
    card('c_base',0,{rank=6,suit='Clubs',seal='Blue'})}}))
check(result.action and result.action.index == 2, 'a valuable Blue Seal can justify adding a card')
result = Strategy.advise(snapshot({phase='pack',jokers={card('j_hologram')},pack_cards={card('c_base',0,{rank=5,suit='Clubs'})}}))
check(result.action ~= nil, 'Hologram provides a reason to take an otherwise ordinary card')

result = Strategy.advise(snapshot({shop_jokers={card('j_credit_card',8)},reroll_cost=0}))
check(contains(result, 'free shop reroll'), 'a free shop refresh is useful when no current purchase is good')
result = Strategy.advise(snapshot({modifiers={no_interest=true},dollars=15}))
check(not contains(result, 'maximum interest'), 'do not recommend building interest in a no-interest challenge')
result = Strategy.advise(snapshot({modifiers={minus_hand_size_per_X_dollar=5},dollars=15}))
check(not contains(result, 'maximum interest'), 'Luxury Tax should not tell the user to hoard cash')

local challenge_ids = {'omelette','city','rich','knife','xray','mad_world','luxury','non_perishable',
    'medusa','double_nothing','typecast','inflation','bram_poker','fragile','monolith','blast_off',
    'five_card','golden_needle','cruelty','jokerless'}
for _, id in ipairs(challenge_ids) do
    result = Strategy.advise(snapshot({phase='hand',challenge='c_' .. id .. '_1'}))
    check(#result.lines > 0, 'missing challenge guidance for ' .. id)
end
result = Strategy.advise(snapshot({phase='hand',challenge='c_typecast_1'}))
check(contains(result, 'after the ante 4 boss'), 'Typecast locks after ante 4, not on entering ante 4')
result = Strategy.advise(snapshot({phase='hand',blind={key='bl_psychic'}}))
check(contains(result, 'exactly five cards'), 'Psychic legality should be prominent')
result = Strategy.advise(snapshot({phase='hand',blind={key='bl_psychic',disabled=true}}))
check(not contains(result, 'exactly five cards'), 'a disabled boss must not retain active-rule guidance')
result = Strategy.advise(snapshot({phase='shop',blind_choices={Boss='bl_final_leaf'}}))
check(contains(result, 'selling one non-eternal Joker'), 'prepare for Verdant Leaf before entering')

result = Strategy.advise(snapshot({phase='blind',blind_states={Small='Defeated',Big='Select',Boss='Upcoming'}}))
check(result.title == 'Play the Big Blind', 'recommend the currently selectable blind')
result = Strategy.advise(snapshot({phase='blind',ante=1,skip_tags={Small='tag_investment'}}))
check(contains(result, 'Consider skipping'), 'Investment can be a conditional early economy tradeoff')
check(result.title=='Play the Small Blind' and result.action.kind=='select_blind' and result.action.blind=='Small',
    'Investment default recommendation and executable action both select the current blind')
check(contains(result,'has not been simulated'), 'conditional skip discussion does not imply a verified safe future blind')
result = Strategy.advise(snapshot({phase='blind',blind_on_deck='Boss',skip_tags={Boss='tag_investment'}}))
check(result.title == 'Play the Boss Blind', 'bosses cannot be skipped for tags')

local function eggs(values)
    local out = {}
    for i, value in ipairs(values) do out[i] = card('j_egg', 0, {name='Egg', sell_cost=value, ability={extra=3}}) end
    return out
end
local function omelette(extras)
    local state = snapshot({challenge='c_omelette_1', dollars=4, jokers=eggs({5,5,5,5,5}),
        modifiers={no_interest=true,no_extra_hand_money=true,no_blind_reward={Small=true,Big=true,Boss=true}}})
    for key, value in pairs(extras or {}) do state[key] = value end
    return state
end

result = Strategy.advise(omelette())
check(not actionable(result) and not result.title:find('Sell', 1, true), 'full Egg row alone never justifies selling')
check(contains(result, 'Keep the Eggs growing'), 'no useful purchase preserves future Egg value')
result = Strategy.advise(omelette({reroll_cost=0}))
check(result.title == 'Use the free shop reroll', 'a free refresh does not require selling an Egg first')
result = Strategy.advise(omelette({shop_jokers={card('j_credit_card',8)}}))
check(not actionable(result), 'do not liquidate an Egg for a weak speculative purchase')

local varied_eggs = eggs({30,5,12,14,16})
local sale_state = omelette({jokers=varied_eggs,shop_jokers={card('j_joker',2,{name='Joker'})}})
before = serialize(sale_state)
result = Strategy.advise(sale_state)
check(serialize(sale_state) == before, 'Egg-sale planning never mutates Joker order or cash')
check(result.action and result.action.kind == 'sell' and result.action.area == 'jokers' and result.action.index == 2,
    'sell the smallest sufficient Egg instead of blindly choosing the first')
check(result.action.followup.kind == 'buy' and result.action.followup.area == 'shop_jokers' and result.action.followup.index == 1,
    'sale has an executable specific purchase follow-up')
check(contains(result, 'Then buy Joker ($2)'), 'explain what the Egg sale funds')
check(serialize(result) == serialize(Strategy.advise(sale_state)), 'sale plans are deterministic')

result = Strategy.advise(omelette({jokers=varied_eggs,shop_jokers={card('j_swashbuckler',4)}}))
check(result.action and result.action.kind == 'sell' and result.action.index == 2, 'keep the large Eggs for Swashbuckler')
check(contains(result, 'Adds +72 Mult'), 'Swashbuckler value excludes the Egg the plan must sell')
check(not contains(result, 'Adds +77 Mult'), 'do not advertise pre-sale Swashbuckler Mult')
local reduced = {varied_eggs[1],varied_eggs[3],varied_eggs[4],varied_eggs[5]}
result = Strategy.advise(omelette({dollars=9,jokers=reduced,shop_jokers={card('j_swashbuckler',4)}}))
check(result.action and result.action.kind == 'buy' and contains(result, 'Adds +72 Mult'),
    're-evaluating after the planned sale reaches the advertised buy')

result = Strategy.advise(omelette({dollars=0,shop_jokers={card('j_blueprint',40)}}))
check(not actionable(result), 'a sale plan must actually afford its follow-up')
result = Strategy.advise(omelette({dollars=0,jokers=eggs({2,10,3,3}),shop_jokers={card('j_joker',8)}}))
check(result.action and result.action.kind == 'sell' and result.action.index == 2,
    'sell an Egg for a specific unaffordable scoring purchase even when a slot is already open')

local eternal_eggs = eggs({5,5,5,5,5})
for _, egg in ipairs(eternal_eggs) do egg.ability.eternal = true end
result = Strategy.advise(omelette({jokers=eternal_eggs,shop_jokers={card('j_swashbuckler',4)}}))
check(not actionable(result), 'eternal Eggs cannot be sold for replacements')
local negative = card('j_egg',0,{sell_cost=1,edition={negative=true}})
eternal_eggs[#eternal_eggs + 1] = negative
result = Strategy.advise(omelette({jokers=eternal_eggs,joker_limit=6,shop_jokers={card('j_swashbuckler',4)}}))
check(not actionable(result), 'selling the sole sellable Negative Egg does not free a normal Joker slot')

local anchored = {card('j_swashbuckler',0,{sell_cost=2}),card('j_egg',0,{sell_cost=60}),
    card('j_blue_joker',0,{sell_cost=2,ability={eternal=true}}),card('j_card_sharp',0,{sell_cost=3,ability={eternal=true}}),
    card('j_gift',0,{sell_cost=2,ability={eternal=true}})}
result = Strategy.advise(omelette({jokers=anchored,shop_jokers={card('j_joker',2)}}))
check(not actionable(result), 'do not destroy most of Swashbuckler Mult for a weak replacement')
result = Strategy.advise(omelette({jokers=eggs({5,5,5,5,5}),shop_jokers={card('j_mail',4)}}))
check(result.action and result.action.kind == 'sell', 'five illiquid Eggs do not make actual cash income redundant')
check(contains(result, 'Generates cash for upgrades'), 'cash advice respects disabled interest')

local growing_engine = {card('j_swashbuckler',0,{sell_cost=2}),card('j_blue_joker',0,{sell_cost=3}),
    card('j_egg',0,{sell_cost=15}),card('j_egg',0,{sell_cost=15})}
result = Strategy.advise(omelette({dollars=10,jokers=growing_engine,shop_jokers={card('j_gift',6),card('j_egg',4)}}))
check(result.action and result.action.kind == 'buy' and result.action.index == 1, 'Gift Card supports an established Swashbuckler engine')
check(contains(result, 'no immediate cash') and contains(result, 'increases Swashbuckler Mult'), 'describe Gift Card as resale growth, not cash payout')
result = Strategy.advise(omelette({dollars=10,jokers=eggs({5,5,5,5}),shop_jokers={card('j_gift',6),card('j_joker',2)}}))
check(result.action and result.action.kind == 'buy' and result.action.index == 2, 'buy missing immediate scoring before more resale growth')

result = Strategy.advise(omelette({phase='pack',pack_cards={card('j_swashbuckler')}}))
check(result.action and result.action.kind == 'sell', 'full Omelette row can replace an Egg with a revealed Buffoon Joker')
check(result.action.followup.kind == 'choose' and result.action.followup.area == 'pack_cards' and result.action.followup.index == 1,
    'pack sale identifies the exact revealed choice')
result = Strategy.advise(omelette({phase='pack',pack_cards={card('j_egg')}}))
check(not actionable(result), 'do not replace a grown Egg with another plain Egg')
result = Strategy.advise(omelette({phase='pack',pack_cards={card('j_swashbuckler',0,{edition={negative=true}})}}))
check(result.action and result.action.kind == 'choose', 'take a Negative pack Joker without an unnecessary Egg sale')
result = Strategy.advise(omelette({shop_booster={card('p_buffoon_normal_1',4)}}))
check(result.action and result.action.kind == 'sell' and result.action.followup.kind == 'open',
    'an early scoring-less Egg row can make room for an affordable Buffoon pack')
check(contains(result, 'contents are unknown'), 'a planned pack purchase does not imply known contents')

result = Strategy.advise(omelette({consumeables={card('c_temperance')},shop_jokers={card('j_swashbuckler',4)}}))
check(result.action and result.action.kind == 'use' and result.action.area == 'consumeables' and result.action.index == 1,
    'cash owned Temperance before reducing its payout through an Egg sale')
check(contains(result, '+$25') and contains(result, 'before selling an Egg'), 'Temperance preserves the full pre-sale payout')
result = Strategy.advise(omelette({consumeables={card('c_temperance')},jokers=eggs({20,20,20})}))
check(result.action and result.action.kind == 'use' and contains(result, '+$50'), 'use capped Temperance without selling any Eggs')
result = Strategy.advise(omelette({dollars=0,jokers=eggs({10,10,10,10}),consumeables={card('c_temperance')},
    shop_jokers={card('j_joker',2)}}))
check(result.action and result.action.kind == 'use', 'owned Temperance funds the visible scoring upgrade without unnecessary sale')
result = Strategy.advise(omelette({phase='pack',pack_cards={card('c_temperance'),card('c_mercury')}}))
check(result.action and result.action.kind == 'choose' and result.action.index == 1, 'Temperance monetizes the Egg row while keeping future growth')

result = Strategy.advise(omelette({modifiers={},dollars=15,shop_jokers={card('j_to_the_moon',0)},shop_vouchers={card('v_seed_money',0)}}))
check(not actionable(result) and not contains(result, 'maximum interest'), 'Omelette identity itself disables interest advice even with sparse snapshots')
result = Strategy.advise(omelette({phase='blind',ante=1,skip_tags={Small='tag_investment'}}))
check(result.title == 'Play the Small Blind', 'Omelette Investment comparison accounts for lost Egg growth and shop access')
check(contains(result, '$15 in total resale value') and contains(result, 'no blind payout'), 'blind guidance distinguishes resale growth from missing cash income')

for _, plan in ipairs({{joker='j_trousers',planet='c_uranus'},{joker='j_shortcut',planet='c_saturn'},
    {joker='j_droll',planet='c_jupiter'}}) do
    result = Strategy.advise(snapshot({phase='pack',jokers={card(plan.joker)},pack_cards={card('c_mercury'),card(plan.planet)}}))
    check(result.action and result.action.index == 2, 'Planet priorities account for current hand-type Joker: ' .. plan.joker)
end
result = Strategy.advise(snapshot({phase='pack',jokers={card('j_droll',0,{debuff=true})},pack_cards={card('c_mercury'),card('c_jupiter')}}))
check(result.action and result.action.index == 1, 'a debuffed hand-type Joker does not redirect the hand plan')

local numbered_diamonds = {card('c_base',0,{rank=4,suit='Diamonds'}),card('c_base',0,{rank=10,suit='Diamonds'})}
for _, key in ipairs({'j_lusty_joker','j_scholar','j_fibonacci','j_odd_todd','j_business','j_smiley'}) do
    result = Strategy.advise(snapshot({playing_cards=numbered_diamonds,shop_jokers={card(key,0)}}))
    check(not actionable(result), 'do not buy an inactive suit/rank/face effect: ' .. key)
end
for _, key in ipairs({'j_even_steven','j_walkie_talkie'}) do
    result = Strategy.advise(snapshot({playing_cards=numbered_diamonds,shop_jokers={card(key,2)}}))
    check(result.action ~= nil, 'matching ranked cards activate strategic rating: ' .. key)
end
result = Strategy.advise(snapshot({playing_cards=numbered_diamonds,jokers={card('j_smeared')},shop_jokers={card('j_lusty_joker',2)}}))
check(result.action ~= nil, 'Smeared makes Diamonds eligible for Heart scoring Jokers')
result = Strategy.advise(snapshot({playing_cards={card('m_wild',0,{rank=4,suit='Clubs',enhancement='m_wild'})},
    shop_jokers={card('j_lusty_joker',2)}}))
check(result.action ~= nil, 'Wild cards satisfy suit-dependent Joker strategy')
result = Strategy.advise(snapshot({playing_cards=numbered_diamonds,jokers={card('j_pareidolia')},shop_jokers={card('j_business',2)}}))
check(result.action ~= nil, 'Pareidolia makes numbered cards eligible for Business Card income')
local aces = {card('c_base',0,{rank=14,suit='Spades'})}
result = Strategy.advise(snapshot({playing_cards=aces,shop_jokers={card('j_even_steven',0)}}))
check(not actionable(result), 'Ace is not an Even Steven trigger despite its internal rank being 14')
for _, key in ipairs({'j_odd_todd','j_fibonacci','j_scholar'}) do
    result = Strategy.advise(snapshot({playing_cards=aces,shop_jokers={card(key,2)}}))
    check(result.action ~= nil, 'Ace activates the actual vanilla rank condition: ' .. key)
end

local hand_with_planet = snapshot({phase='hand',consumeables={card('c_mercury')}})
check(contains(Strategy.advise(hand_with_planet), 'Use c_mercury'), 'standalone strategy retains ordinary consumable tips')
check(not contains(Strategy.advise(hand_with_planet,{tactical_consumables=true}), 'Use c_mercury'),
    'targeted tactical evaluation can suppress generic consumable tips')

-- Vary cash, inventory, and card costs together: every indexed buy must remain
-- affordable and fit the snapshot. This catches cross-rule regressions.
for dollars = -4, 24, 4 do
    for slots = 0, 5 do
        local owned = {}
        for index = 1, slots do owned[index] = card('j_joker') end
        local state = snapshot({dollars=dollars,bankrupt_at=-4,joker_limit=slots,
            jokers=owned,shop_jokers={card('j_blueprint',5),card('j_joker',2,{edition='negative'}),card('c_mercury',3)},
            shop_booster={card('p_arcana_normal_1',4)},shop_vouchers={card('v_paint_brush',10)}})
        local advice = Strategy.advise(state)
        if actionable(advice) then
            local chosen = state[advice.action.area][advice.action.index]
            check(chosen.cost <= 0 or chosen.cost <= dollars + 4, 'recommended purchase exceeds available credit')
            if chosen.key:sub(1,2) == 'j_' then check(chosen.edition == 'negative', 'full slots only allow a negative Joker purchase') end
        end
    end
end
math.random = old_random
Strategy.synergies = dofile('Brainstorm/Advisor/synergies.lua')
result = Strategy.advise(snapshot({dollars=10,jokers={card('j_hanging_chad')},
    playing_cards={card('c_base',0,{rank=13,suit='Spades'})},shop_jokers={card('j_photograph',5)}}))
check(result.action and result.action.kind=='buy', 'owned combo synergy changes an otherwise weak Photograph purchase decision')
check(result.forecast and result.forecast.existing[1]=='j_hanging_chad', 'chosen advice exposes structured synergy evidence')
check(contains(result,'Owned synergy') and not contains(result,'generic strategic rating'), 'known synergy reason is presented with the actual recommendation')
result = Strategy.advise(snapshot({shop_jokers={}}))
check(result.action and result.action.kind=='leave_shop' or result.action.kind=='reroll', 'shop navigation has executable action metadata')
result = Strategy.advise(snapshot({phase='pack',pack_cards={}}))
check(result.action.kind=='skip_pack', 'empty pack has executable skip action')
result = Strategy.advise(snapshot({phase='round'}))
check(result.action.kind=='cash_out', 'cash-out phase has executable action')
result = Strategy.advise(snapshot({phase='blind',blind_on_deck='Big'}))
check(result.action.kind=='select_blind' and result.action.blind=='Big', 'blind selection identifies the current blind')
do
    local weak=card('c_base',0,{rank=3,suit='Clubs',enhancement='c_base'})
    local strong=card('m_steel',0,{rank=13,suit='Spades',enhancement='m_steel',seal='Red'})
    local state=snapshot({phase='pack',hand={weak,strong},playing_cards={weak,strong},
        pack_cards={card('c_death')}})
    local original=serialize(state)
    result=Strategy.advise(state)
    check(result.action.kind=='choose' and serialize(result.action.targets)==serialize({1,2}), 'Death specifies legal left-to-right copy targets')
    check(contains(result,'RIGHT card onto the LEFT'), 'Death copy direction is explicit')
    check(serialize(state)==original, 'pack targeting leaves input unchanged')
    state.hand={strong,weak}
    original=serialize(state)
    result=Strategy.advise(state)
    check(result.action.kind=='reorder_hand' and result.action.area=='hand' and serialize(result.action.order)==serialize({2,1}),
        'move the valuable left Death source to the right before choosing it')
    check(result.action.targets==nil and result.action.index==nil and result.action.followup==nil,
        'Death reorder is only a manual first step, never a premature use or target selection')
    check(contains(result,'Close the panel') and contains(result,'refresh advice'), 'Death reorder explains the manual sequence')
    check(serialize(state)==original, 'Death reorder recommendation leaves card order and snapshot unchanged')
    state.hand={state.hand[result.action.order[1]],state.hand[result.action.order[2]]}
    result=Strategy.advise(state)
    check(result.action.kind=='choose' and serialize(result.action.targets)==serialize({1,2}),
        'after the manual move Death has stable legal left-to-right targets')
    check(serialize(result)==serialize(Strategy.advise(state)), 'Death follow-up stays stable across refreshes')
    state.hand={weak,strong}; state.pack_cards={card('c_medium')}
    result=Strategy.advise(state)
    check(result.action.kind=='choose' and result.action.targets[1]==1, 'Medium supplies one target and preserves an existing Red seal')
    state.pack_cards={card('c_aura')}; weak.edition={foil=true}
    result=Strategy.advise(state)
    check(result.action.kind=='choose' and result.action.targets[1]==2, 'Aura only selects an editionless card')
    strong.edition={polychrome=true}
    result=Strategy.advise(state)
    check(result.action.kind=='skip_pack', 'Aura with no legal target is skipped')
    weak.edition=nil; strong.edition=nil
    state.pack_cards={card('c_empress',0,{ability={consumeable={min_highlighted=1,max_highlighted=2,mod_num=2}}})}
    result=Strategy.advise(state)
    check(result.action.kind=='choose' and #result.action.targets==1 and result.action.targets[1]==1, 'enhancement targets preserve valuable Steel cards rather than forcing maximum targets')
    state.pack_cards={card('c_modded_target',0,{ability={consumeable={max_highlighted=1}}})}
    result=Strategy.advise(state)
    check(result.action.kind=='skip_pack', 'unknown targeting rules do not invent an executable choice')
end
do
    local deck={}
    for _,suit in ipairs({'Hearts','Diamonds','Clubs','Spades'}) do
        for rank=2,14 do deck[#deck+1]=card('c_base',0,{rank=rank,suit=suit}) end
    end
    local hand={deck[14],deck[27],deck[40],deck[1]}
    local state=snapshot({phase='pack',hand=hand,playing_cards=deck,pack_cards={card('c_sun')},
        hands={Flush={level=2,played=8},Pair={level=1,played=0}}})
    local original=serialize(state)
    result=Strategy.advise(state)
    check(result.action.kind=='choose' and serialize(result.action.targets)==serialize({1,2,3}),
        'a balanced Flush deck benefits from converting three different suits together')
    check(serialize(state)==original, 'batch suit targeting never edits the hand or deck')
    state.hands={Pair={level=2,played=8},Flush={level=1,played=0}}
    result=Strategy.advise(state)
    check(result.action.kind=='skip_pack', 'a balanced Pair deck has no invented suit-conversion benefit')
    state.jokers={card('j_bloodstone')}
    result=Strategy.advise(state)
    check(result.action.kind=='choose' and serialize(result.action.targets)==serialize({1,2,3}),
        'current Heart-triggered Jokers make suit conversion valuable without a Flush focus')
    state.jokers={card('j_ancient')}; state.current_round={ancient_card={suit='Hearts'}}
    check(Strategy.advise(state).action.kind=='choose', 'Ancient uses its current suit when choosing conversion targets')
    state.jokers={card('j_bloodstone',0,{debuff=true})}
    check(Strategy.advise(state).action.kind=='skip_pack', 'debuffed suit Jokers do not create conversion utility')
    state.jokers={card('j_smeared'),card('j_bloodstone')}; state.hand={deck[14]}
    state.hands={Flush={level=2,played=8},Pair={level=1,played=0}}
    check(Strategy.advise(state).action.kind=='skip_pack', 'Smeared already makes a Diamond satisfy Hearts and red Flushes')
end
do
    local king=card('m_steel',0,{rank=13,suit='Spades',enhancement='m_steel',seal='Blue'})
    local weak=card('c_base',0,{rank=3,suit='Clubs'})
    local state=snapshot({phase='pack',hand={king,weak},playing_cards={king,weak},jokers={card('j_baron')},
        pack_cards={card('c_deja_vu')}})
    local original=serialize(state)
    result=Strategy.advise(state)
    check(result.action.kind=='choose' and serialize(result.action.targets)==serialize({1}),
        'Red Seal can replace Blue on a Steel Baron King instead of defaulting to an unsealed weak card')
    check(serialize(state)==original, 'contextual seal utility leaves the existing Blue Seal unchanged')
    king.seal='Red'; state.hand={king}; state.pack_cards={card('c_trance')}
    check(Strategy.advise(state).action.kind=='skip_pack', 'Blue does not overwrite a more valuable Red Steel Baron King')
    state.pack_cards={card('c_deja_vu')}
    check(Strategy.advise(state).action.kind=='skip_pack', 'an identical seal is not an upgrade')
    local middle=card('m_mult',0,{rank=3,suit='Clubs',enhancement='m_mult'})
    state.hand={king,middle,weak}; state.playing_cards={king,middle,weak}; state.pack_cards={card('c_death')}
    result=Strategy.advise(state)
    check(result.action.kind=='reorder_hand' and serialize(result.action.order)==serialize({2,3,1}),
        'Death emits a full permutation with only the best source moved to the end')
    state.hand={weak,weak}
    check(Strategy.advise(state).action.kind=='skip_pack', 'equal-value Death targets do not cause pointless reordering')
end
do
    local function owned(key,extra)
        local c=card(key,0,{sell_cost=2,ability={}})
        for k,v in pairs(extra or {}) do c[k]=v end
        return c
    end
    local function remove_for_followup(state,index)
        local copy={}; for k,v in pairs(state) do copy[k]=v end
        copy.jokers={}; for i,c in ipairs(state.jokers) do if i~=index then copy.jokers[#copy.jokers+1]=c end end
        local sold=state.jokers[index]
        copy.dollars=state.dollars+(sold.sell_cost or 0)
        if sold.key=='j_credit_card' and not sold.debuff then copy.bankrupt_at=state.bankrupt_at+(sold.ability.extra or 20) end
        if sold.edition=='negative' or type(sold.edition)=='table' and sold.edition.negative then copy.joker_limit=state.joker_limit-1 end
        return copy
    end
    local core=owned('j_joker',{ability={mult=4,eternal=true}})
    local chips=owned('j_blue_joker',{ability={t_chips=80,eternal=true}})
    local filler=owned('j_credit_card',{ability={extra=20}})
    local state=snapshot({jokers={core,filler,chips},joker_limit=3,bankrupt_at=-20,dollars=10,
        shop_jokers={card('j_card_sharp',4,{name='Card Sharp',sell_cost=2,ability={extra={Xmult=3}}})}})
    local original=serialize(state)
    result=Strategy.advise(state)
    check(result.action.kind=='sell' and result.action.index==2, 'full rows can replace known filler with a substantial visible scoring upgrade')
    check(result.action.followup.kind=='buy' and result.action.followup.area=='shop_jokers' and result.action.followup.index==1,
        'replacement sale identifies one exact buy follow-up')
    check(contains(result,'Then buy Card Sharp ($4)') and contains(result,'borrowing allowance'), 'replacement explains the concrete purchase and Credit Card consequence')
    check(serialize(state)==original and serialize(result)==serialize(Strategy.advise(state)), 'replacement planning is immutable and deterministic')
    local after=remove_for_followup(state,2)
    local followup=Strategy.advise(after)
    check(followup.action.kind=='buy' and followup.action.index==result.action.followup.index, 'after the suggested sale the same shop purchase remains the next advice')
    state.dollars=-5
    check(Strategy.advise(state).action.kind~='sell', 'selling the only Credit Card cannot fund a purchase using the credit it removes')
    state.dollars=0; state.bankrupt_at=-40; state.jokers[3]=owned('j_credit_card',{ability={extra=20,eternal=true}})
    result=Strategy.advise(state)
    check(result.action.kind=='sell' and result.action.index==2 and result.replacement.cash_after_purchase==-2,
        'remaining Credit Card permits a concrete affordable replacement into debt')
    state.dollars=10; state.bankrupt_at=-20; state.jokers[3]=chips
    filler.ability.eternal=true
    check(Strategy.advise(state).action.kind~='sell', 'eternal filler cannot be sold for a replacement')
    filler.ability.eternal=nil; state.modifiers={all_eternal=true}
    check(Strategy.advise(state).action.kind~='sell', 'global eternal challenge rule prevents every replacement sale')
    state.modifiers={}; filler.edition={negative=true}
    check(Strategy.advise(state).action.kind~='sell', 'selling the only sellable Negative Joker removes its slot instead of freeing capacity')
    filler.edition=nil; state.shop_jokers[1].edition={negative=true}
    check(Strategy.advise(state).action.kind=='buy', 'a directly affordable Negative upgrade avoids an unnecessary sale')
    state.shop_jokers[1].edition=nil; state.shop_jokers={}
    check(Strategy.advise(state).action.kind~='sell', 'weak filler alone never justifies an unplanned cash sale')
    state.shop_booster={card('p_buffoon_normal_1',1)}
    check(Strategy.advise(state).action.kind~='sell', 'general replacement does not sell a Joker for an unrevealed Buffoon gamble')
    state.shop_booster={}; state.shop_jokers={card('j_modded_legendary',0,{rarity=4})}
    check(Strategy.advise(state).action.kind~='sell', 'unknown rarity alone is not evidence to replace a known build')
    state.phase='pack'; state.shop_jokers={}; state.pack_cards={card('j_card_sharp',4,{ability={extra={Xmult=3}}})}
    result=Strategy.advise(state)
    check(result.action.kind=='sell' and result.action.followup.kind=='choose' and result.action.followup.area=='pack_cards',
        'a revealed pack Joker can be taken after one concrete replacement sale')
    followup=Strategy.advise(remove_for_followup(state,result.action.index))
    check(followup.action.kind=='choose' and followup.action.index==result.action.followup.index, 'pack follow-up stays executable after the sale')
    state.phase='shop'; state.pack_cards={}; state.shop_jokers={card('j_card_sharp',4,{ability={extra={Xmult=3}}})}
    state.jokers[2]=owned('j_invisible',{ability={invis_rounds=2,extra=2}})
    check(Strategy.advise(state).action.kind~='sell', 'charged Invisible Joker cannot promise a slot that its random copy refills')
    state.jokers[2]=owned('j_diet_cola')
    result=Strategy.advise(state)
    check(result.action.kind=='sell' and contains(result,'Double Tag'), 'known Diet Cola sale effect does not block a legal concrete upgrade')
    state.jokers[2]=owned('j_joker',{debuff=true,ability={mult=4,perishable=true,perish_tally=0,rental=true}})
    result=Strategy.advise(state)
    check(result.action.kind=='sell' and contains(result,'no rounds left') and contains(result,'rental charge'),
        'expired rental filler is explicitly prioritized and its removed charge is explained')
    state.shop_jokers={card('j_joker',0,{ability={perishable=true,perish_tally=0}})}
    check(Strategy.advise(state).action.kind~='sell', 'an expired incoming perishable is never a replacement upgrade')
    state.jokers={owned('j_green_joker',{debuff=true,ability={mult=90}}),chips,
        owned('j_card_sharp',{ability={eternal=true,extra={Xmult=3}}})}
    state.shop_jokers={card('j_blueprint',4,{blueprint_compat=true})}
    check(Strategy.advise(state).action.kind~='sell', 'temporary debuffs do not turn a scaled base-Mult core into disposable filler')
    state.jokers={owned('j_photograph',{blueprint_compat=true}),owned('j_hanging_chad',{blueprint_compat=true}),owned('j_credit_card',{ability={extra=20}})}
    state.playing_cards={card('c_base',0,{rank=13,suit='Hearts'})}
    result=Strategy.advise(state)
    check(result.action.kind=='sell' and result.action.index==3, 'replacement preserves the owned Photograph and Chad engine while removing filler')
    state.jokers[3].ability.eternal=true
    check(Strategy.advise(state).action.kind~='sell', 'an unavailable filler slot does not justify dismantling the owned combo')
    state.jokers={core,owned('j_diet_cola'),owned('j_campfire',{ability={x_mult=1.5,extra=0.25,eternal=true}})}
    state.shop_jokers={card('j_blue_joker',3,{ability={t_chips=80}})}
    original=serialize(state)
    result=Strategy.advise(state)
    check(result.action.kind=='sell' and result.action.index==2 and contains(result,'Campfire grows'),
        'a retained Campfire sale trigger contributes to the replacement plan')
    check(serialize(state)==original and state.jokers[3].ability.x_mult==1.5, 'detached Campfire growth never edits the live snapshot ability')
    state.jokers={owned('j_swashbuckler',{ability={eternal=true}}),owned('j_egg',{sell_cost=60}),chips,
        owned('j_card_sharp',{ability={eternal=true,extra={Xmult=3}}})}
    state.joker_limit=4; state.shop_jokers={card('j_blueprint',4,{blueprint_compat=true})}
    check(Strategy.advise(state).action.kind~='sell', 'outside Omelette a large Egg remains protected when its resale value powers Swashbuckler')
end
print('advisor_strategy: ' .. checks .. ' checks passed')
