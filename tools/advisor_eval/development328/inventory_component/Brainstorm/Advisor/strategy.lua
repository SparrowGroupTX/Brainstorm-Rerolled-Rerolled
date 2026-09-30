-- Pure, deterministic run advice. Scores below are strategic priorities, not
-- simulated win probabilities. Only detached snapshot tables may enter here.
local Strategy = {}
local inventory_value, inventory_marginal, preservation_cost

local function num(value, fallback)
    return type(value) == 'number' and value or (fallback or 0)
end

local function ability(card)
    return type(card.ability) == 'table' and card.ability or {}
end

local function name(card)
    return card.name or ability(card).name or card.key or 'card'
end

local function has(snapshot, key)
    for _, card in ipairs(snapshot.jokers or {}) do
        if card.key == key and not card.debuff then return card end
    end
end

local function edition(card, key)
    return card.edition == key or
        (type(card.edition) == 'table' and card.edition[key])
end

local function challenge(snapshot)
    local value = snapshot.challenge
    if type(value) == 'table' then return value.id or value.key end
    return value
end

local function modifiers(snapshot)
    return snapshot.modifiers or {}
end

local function omelette(snapshot)
    return challenge(snapshot) == 'c_omelette_1'
end

local function no_interest(snapshot)
    return omelette(snapshot) or modifiers(snapshot).no_interest
end

local function joker_sell_value(snapshot, except)
    local value = 0
    for _, owned in ipairs(snapshot.jokers or {}) do
        if owned ~= except and not (except and except.id and owned.id == except.id) then
            value = value + num(owned.sell_cost)
        end
    end
    return value
end

local function jokerless(snapshot)
    return challenge(snapshot) == 'c_jokerless_1'
end

local function kind(card)
    local key = card.key or ''
    local set = ability(card).set
    if set == 'Joker' or key:sub(1, 2) == 'j_' then return 'joker' end
    if set == 'Voucher' or key:sub(1, 2) == 'v_' then return 'voucher' end
    if set == 'Booster' or key:sub(1, 2) == 'p_' then return 'booster' end
    if card.rank or card.base and card.base.id then return 'playing' end
    return 'consumable'
end

local planet_hands = {
    c_mercury = 'Pair', c_venus = 'Three of a Kind', c_earth = 'Full House',
    c_mars = 'Four of a Kind', c_jupiter = 'Flush', c_saturn = 'Straight',
    c_uranus = 'Two Pair', c_neptune = 'Straight Flush', c_pluto = 'High Card',
    c_planet_x = 'Five of a Kind', c_ceres = 'Flush House', c_eris = 'Flush Five',
}

local function hand_type(card)
    local consumeable = ability(card).consumeable
    return planet_hands[card.key] or
        (type(consumeable) == 'table' and consumeable.hand_type)
end

local hand_order = {'High Card', 'Pair', 'Two Pair', 'Three of a Kind',
    'Straight', 'Flush', 'Full House', 'Four of a Kind', 'Straight Flush',
    'Five of a Kind', 'Flush House', 'Flush Five'}

local hand_affinity = {
    j_jolly={Pair=30,['Two Pair']=20,['Three of a Kind']=18,['Full House']=22},
    j_sly={Pair=30,['Two Pair']=20,['Three of a Kind']=18,['Full House']=22},
    j_zany={['Three of a Kind']=35,['Full House']=24,['Four of a Kind']=22},
    j_wily={['Three of a Kind']=35,['Full House']=24,['Four of a Kind']=22},
    j_mad={['Two Pair']=35,['Full House']=24}, j_clever={['Two Pair']=35,['Full House']=24},
    j_trousers={['Two Pair']=40,['Full House']=26},
    j_crazy={Straight=35,['Straight Flush']=22}, j_devious={Straight=35,['Straight Flush']=22},
    j_shortcut={Straight=30,['Straight Flush']=15},
    j_droll={Flush=35,['Straight Flush']=22}, j_crafty={Flush=35,['Straight Flush']=22},
    j_half={['High Card']=12,Pair=18,['Three of a Kind']=16},
    j_four_fingers={Straight=15,Flush=15,['Straight Flush']=12}, j_smeared={Flush=18},
}

local function favored_hand(snapshot)
    local best, merit, played = 'Pair', -1, 0
    local affinity = {}
    for _, joker in ipairs(snapshot.jokers or {}) do
        if not joker.debuff then
            for hand, weight in pairs(hand_affinity[joker.key] or {}) do affinity[hand] = (affinity[hand] or 0) + weight end
        end
    end
    for _, hand in ipairs(hand_order) do
        local state = (snapshot.hands or {})[hand] or (affinity[hand] and {})
        if state then
            local count = num(state.played)
            local score = count * 3 + math.max(0, num(state.level, 1) - 1) * 2 + (affinity[hand] or 0)
            if score > merit and (count > 0 or num(state.level, 1) > 1 or affinity[hand]) then
                best, merit, played = hand, score, count
            end
        end
    end
    return best, played
end

local function deck_stats(snapshot)
    local out = {size = 0, stone = 0, glass = 0, enhanced = 0, face = 0,
        steel = 0, gold = 0, ranks = {}, suits = {}}
    for _, card in ipairs(snapshot.playing_cards or snapshot.deck or {}) do
        out.size = out.size + 1
        local enhancement = card.enhancement or ''
        if enhancement == 'm_stone' or enhancement == 'Stone Card' then
            out.stone = out.stone + 1
        else
            local rank = num(card.rank, num(card.base and card.base.id))
            out.ranks[rank] = (out.ranks[rank] or 0) + 1
            if rank >= 11 and rank <= 13 then out.face = out.face + 1 end
            if enhancement == 'm_wild' then
                for _, suit in ipairs({'Hearts','Diamonds','Clubs','Spades'}) do out.suits[suit] = (out.suits[suit] or 0) + 1 end
            elseif card.suit then out.suits[card.suit] = (out.suits[card.suit] or 0) + 1 end
        end
        if enhancement ~= '' and enhancement ~= 'c_base' and enhancement ~= 'Base' then
            out.enhanced = out.enhanced + 1
        end
        if enhancement == 'm_glass' or enhancement == 'Glass Card' then out.glass = out.glass + 1 end
        if enhancement == 'm_steel' or enhancement == 'Steel Card' then out.steel = out.steel + 1 end
        if enhancement == 'm_gold' or enhancement == 'Gold Card' then out.gold = out.gold + 1 end
    end
    out.known = out.size > 0
    out.size = math.max(1, out.size)
    return out
end

-- A deck commitment requires evidence from the full deck, not an incidental
-- dealt hand. This small profile is shared by targets and copy-pool valuation.
local function build_profile(snapshot, stats)
    stats=stats or deck_stats(snapshot)
    local preferred,played=favored_hand(snapshot)
    local rank,count,second=nil,0,0
    for r=2,14 do
        local n=stats.ranks[r] or 0
        if n>count then second=count;rank,count=r,n elseif n>second then second=n end
    end
    local rank_hands={Pair=true,['Two Pair']=true,['Three of a Kind']=true,['Full House']=true,
        ['Four of a Kind']=true,['Five of a Kind']=true,['Flush House']=true,['Flush Five']=true}
    local committed=stats.known and rank_hands[preferred] and count>=5 and count>=second*1.4 and count/stats.size>=0.20
    if not committed then rank=nil end
    local ante=num(snapshot.ante,1)
    local final=ante>=num(snapshot.win_ante,8) and
        ((snapshot.blind or {}).boss or snapshot.blind_on_deck=='Boss' or
        ((snapshot.blind or {}).key or ''):find('bl_final_',1,true)) and snapshot.phase=='hand'
    local horizon=final and 0 or math.max(0,math.min(6,(num(snapshot.win_ante,8)-ante)*3+2))
    return {stats=stats,hand=preferred,played=played,rank=rank,rank_count=count,
        predecessor=rank and (rank==2 and 14 or rank-1),horizon=horizon,final=not not final}
end

local function participation(snapshot,card,profile)
    local r=num(card.rank,num((card.base or {}).id))
    local value=1
    if profile.rank then value=r==profile.rank and 2.5 or 0.45 end
    if r==13 and has(snapshot,'j_baron') then value=math.max(value,2.8) end
    if card.enhancement=='m_steel' or card.enhancement=='m_gold' then value=math.max(value,1.3) end
    if card.seal=='Red' then value=value*1.5 end
    return value
end

-- All twenty vanilla challenges: the comments/guidance are original summaries
-- of the installed game's rules, including the post-ante-4 Typecast lock.
local challenge_tips = {
    c_omelette_1 = 'Omelette: sell Eggs only for a useful upgrade or needed cash; keep the others growing. There is no blind, unused-hand, or interest income.',
    c_city_1 = '15 Minute City: Shortcut allows rank gaps in straights. Scoring a face card resets Ride the Bus.',
    c_rich_1 = 'Rich get Richer: your dollars cap Chips. Prioritize Mult and income, and avoid spending your scoring ceiling.',
    c_knife_1 = 'Knife\'s Edge: Dagger is pinned first and destroys the Joker immediately to its right when a blind begins. Put disposable fodder in that slot.',
    c_xray_1 = 'X-ray Vision: some draws are face down. The advisor uses their internal identities; select by card position.',
    c_mad_world_1 = 'Mad World: Pareidolia makes every card a face card; score several for Business Card income. There is no interest or unused-hand income.',
    c_luxury_1 = 'Luxury Tax: every $5 reduces hand size by one. Buy useful upgrades before entering a blind; hoarding makes draws worse.',
    c_non_perishable_1 = 'Non-Perishable: every Joker is eternal. Commit slots to a coherent scoring engine; weak filler cannot be sold later.',
    c_medusa_1 = 'Medusa: Stone cards always score but have no rank or suit. Add them to small hands; Stone Joker and Hologram benefit from Marble.',
    c_double_nothing_1 = 'Double or Nothing: played cards become debuffed permanently. Favor fresh Red Seal cards and avoid wasting extras in a winning play.',
    c_typecast_1 = 'Typecast: after the ante 4 boss, all owned Jokers become eternal and Joker slots drop to zero. Finish your engine before that boss.',
    c_inflation_1 = 'Inflation: each purchase raises later prices. Favor major upgrades and income over filler; preserve Credit Card until debt is cleared.',
    c_bram_poker_1 = 'Bram Poker: feed enhancements to Vampire for scaling. Shop slots contain no Jokers; use Buffoon packs to find supporting Jokers.',
    c_fragile_1 = 'Fragile: the two Oops! Jokers make played Glass cards break with certainty. Play only what you need and preserve enough cards to finish.',
    c_monolith_1 = 'Monolith: build a lead in one hand type, then pivot. Playing any tied most-used hand resets Obelisk; Stone cards support small hands.',
    c_blast_off_1 = 'Blast Off: only two hands and four Joker slots. Planets grow Constellation; Rocket supplies income. Prioritize immediate Chips and Mult.',
    c_five_card_1 = 'Five-Card Draw: use the six discards to find repeatable hands. Repeating a hand type within the round activates Card Sharp.',
    c_golden_needle_1 = 'Golden Needle: your single hand must clear the blind. Discards cost $1; use them to assemble a winning hand and budget for the next blind.',
    c_cruelty_1 = 'Cruelty: Small and Big blinds pay no blind reward, but interest and unused hands still pay. Three Joker slots demand efficient scoring.',
    c_jokerless_1 = 'Jokerless: focus levels on a repeatable hand, shape the deck with Tarot, and use Glass/Steel plus Red/Blue seals for scaling.',
}

local boss_tips = {
    bl_hook = 'Hook: two random held cards are discarded after each play; do not depend on saving a fragile second hand.',
    bl_ox = 'Ox: playing its named hand sets money to $0. Check the blind text before committing your usual hand.',
    bl_house = 'House: the first draw is face down; discarding reveals fresh cards.',
    bl_wall = 'Wall: the larger target needs a strong scoring hand; reserve score-boosting consumables.',
    bl_wheel = 'Wheel: face-down draws make estimates uncertain.',
    bl_arm = 'Arm: the played hand loses a level before scoring, down to level 1.',
    bl_club = 'Club: Clubs are debuffed; their ranks still help form hands, but their scoring effects do not trigger.',
    bl_fish = 'Fish: draws after playing are face down; use discards to find visible cards.',
    bl_psychic = 'Psychic: you must play exactly five cards, even for Pair or High Card.',
    bl_goad = 'Goad: Spades are debuffed. Favor other suits for scoring cards.',
    bl_water = 'Water: there are no discards; use consumables and spare hands to improve draws.',
    bl_window = 'Window: Diamonds are debuffed. Favor other suits for scoring cards.',
    bl_manacle = 'Manacle: reduced hand size favors small, repeatable hand types.',
    bl_eye = 'Eye: each hand type can score only once this round.',
    bl_mouth = 'Mouth: the first played hand locks your hand type for this round.',
    bl_plant = 'Plant: face cards are debuffed, so face-card scoring engines can fail.',
    bl_serpent = 'Serpent: every play/discard draws exactly three cards. Small discards can increase cards held.',
    bl_pillar = 'Pillar: cards played earlier this ante are debuffed. Build the scoring hand from fresh cards.',
    bl_needle = 'Needle: only one hand. Use available discards and consumables before committing.',
    bl_head = 'Head: Hearts are debuffed. Favor other suits for scoring cards.',
    bl_tooth = 'Tooth: every card played costs $1, including non-scoring cards.',
    bl_flint = 'Flint: base hand Chips and Mult are halved; Joker and card bonuses matter more.',
    bl_mark = 'Mark: face cards are drawn face down.',
    bl_final_acorn = 'Amber Acorn: Jokers are shuffled and face down. Check order after reveals, especially copy Jokers.',
    bl_final_leaf = 'Verdant Leaf: selling one non-eternal Joker disables all playing-card debuffs.',
    bl_final_vessel = 'Violet Vessel: an exceptionally high target; use your strongest upgrades before committing.',
    bl_final_heart = 'Crimson Heart: one Joker is disabled each hand; check the new scoring estimate after every play.',
    bl_final_bell = 'Cerulean Bell: the forced card must be included in the play or discarded.',
}

local flat_mult = {
    j_joker = 4, j_greedy_joker = 6, j_lusty_joker = 6, j_wrathful_joker = 6,
    j_gluttenous_joker = 6, j_jolly = 8, j_zany = 12, j_mad = 10, j_crazy = 12,
    j_droll = 10, j_half = 20, j_fibonacci = 12, j_even_steven = 8,
    j_abstract = 12, j_scholar = 8, j_supernova = 8, j_mystic_summit = 15,
    j_popcorn = 20, j_gros_michel = 15, j_smiley = 10, j_raised_fist = 12,
    j_misprint = 11, j_fortune_teller = 8, j_bootstraps = 10,
    j_shoot_the_moon = 13, j_onyx_agate = 7, j_swashbuckler = 10, j_walkie_talkie = 10,
}

local flat_chips = {
    j_sly = 50, j_wily = 100, j_clever = 80, j_devious = 100, j_crafty = 80,
    j_banner = 60, j_scary_face = 60, j_odd_todd = 62, j_ice_cream = 100,
    j_blue_joker = 80, j_arrowhead = 75, j_stone = 75, j_stuntman = 250,
    j_bull = 70, j_runner = 40, j_square = 32, j_wee = 40,
}

local scaling = {
    j_ride_the_bus = true, j_green_joker = true, j_red_card = true,
    j_ceremonial = true, j_trousers = true, j_supernova = true,
    j_fortune_teller = true, j_runner = true, j_square = true, j_wee = true,
    j_hologram = true, j_constellation = true, j_vampire = true,
    j_lucky_cat = true, j_glass = true, j_obelisk = true, j_madness = true,
    j_hit_the_road = true, j_campfire = true, j_todo_list = false,
}

local xmult = {
    j_blackboard = true, j_card_sharp = true, j_acrobat = true, j_ramen = true,
    j_cavendish = true, j_loyalty_card = true, j_drivers_license = true,
    j_steel_joker = true, j_baron = true, j_ancient = true, j_flower_pot = true,
    j_seeing_double = true, j_duo = true, j_trio = true, j_family = true,
    j_order = true, j_tribe = true, j_idol = true, j_baseball = true,
    j_stencil = true, j_throwback = true, j_bloodstone = true,
}

local economy = {
    j_golden = true, j_rocket = true, j_egg = true, j_delayed_grat = true,
    j_business = true, j_faceless = true, j_todo_list = true, j_cloud_9 = true,
    j_to_the_moon = true, j_satellite = true, j_reserved_parking = true,
    j_mail = true, j_rough_gem = true, j_gift = true, j_ticket = true,
}

-- Typecast's slot lock happens after its named boss, not when the ante begins.
-- Apply this to the rule as well as the vanilla challenge identity. It changes
-- the value of real visible rows; it never assumes another shop will supply a
-- missing partner before the deadline.
local function commitment(snapshot)
    local lock=num(modifiers(snapshot).set_joker_slots_ante,
        challenge(snapshot)=='c_typecast_1' and 4 or 0)
    local ante=num(snapshot.ante,1)
    if lock<=0 or ante>lock or num(snapshot.joker_limit,5)<=0 or ante<lock-1 then return end
    return {lock=lock,pressure=ante==lock and 1 or 0.5,
        rounds=math.max(1,(num(snapshot.win_ante,8)-lock)*3+1)}
end

local function commitment_factor(snapshot,card)
    local plan=commitment(snapshot)
    if not plan then return 1 end
    local key,a=card.key,ability(card)
    local remaining=plan.rounds
    if a.perishable then remaining=math.max(0,num(a.perish_tally,5))
    elseif key=='j_popcorn' then remaining=math.max(0,num(a.mult,20))/math.max(1,num(a.extra,4))
    elseif key=='j_ice_cream' then local e=type(a.extra)=='table' and a.extra or {}; remaining=math.max(0,num(e.chips,100))/math.max(1,num(e.chip_mod,5))/2
    elseif key=='j_turtle_bean' then local e=type(a.extra)=='table' and a.extra or {}; remaining=math.max(0,num(e.h_size,5))/math.max(1,num(e.h_mod,1))
    elseif key=='j_selzer' then remaining=math.max(0,num(a.extra,10))/2
    elseif key=='j_diet_cola' or key=='j_luchador' or key=='j_invisible' then remaining=0
    elseif key=='j_egg' or key=='j_gift' then
        -- Resale growth still feeds Swashbuckler and repeatable Temperance.
        local useful=has(snapshot,'j_swashbuckler')
        for _,c in ipairs(snapshot.consumeables or {}) do if c.key=='c_temperance' then useful=true end end
        if not useful then remaining=0 end
    end
    return 1-plan.pressure*(1-math.max(0,math.min(1,remaining/plan.rounds)))*0.85
end

local suit_jokers = {
    j_greedy_joker = 'Diamonds', j_lusty_joker = 'Hearts', j_wrathful_joker = 'Spades',
    j_gluttenous_joker = 'Clubs', j_rough_gem = 'Diamonds', j_bloodstone = 'Hearts',
    j_arrowhead = 'Spades', j_onyx_agate = 'Clubs',
}

local function components(snapshot)
    local out = {mult = 0, chips = 0, xmult = 0, economy = 0, scaling = 0}
    for _, card in ipairs(snapshot.jokers or {}) do
        if not card.debuff then
            local key = card.key
            if flat_mult[key] or num(ability(card).mult) > 3 then out.mult = out.mult + 1 end
            if flat_chips[key] or num(ability(card).t_chips) > 20 then out.chips = out.chips + 1 end
            if xmult[key] or num(ability(card).x_mult) > 1 then out.xmult = out.xmult + 1 end
            -- Eggs and Gift Card grow resale value; five Eggs do not provide
            -- five sources of spendable cash or make cash Jokers redundant.
            if economy[key] and key ~= 'j_egg' and key ~= 'j_gift' then out.economy = out.economy + 1 end
            if scaling[key] then out.scaling = out.scaling + 1 end
        end
    end
    return out
end

local function joker_value(snapshot, card, stats, engine)
    local key, a = card.key, ability(card)
    local ante = num(snapshot.ante, 1)
    local score, reason, known = 22, 'Check its condition against your scoring hand.', false
    if flat_mult[key] then
        score = 32 + math.min(22, flat_mult[key]) + (engine.mult == 0 and 22 or 0)
        reason, known = 'Adds base Mult, which makes later XMult effects stronger.', true
    end
    if flat_chips[key] then
        score = 34 + math.min(25, flat_chips[key] / 4) + (engine.chips == 0 and 16 or 0)
        reason, known = 'Adds Chips to support your hand levels and Mult.', true
        if modifiers(snapshot).chips_dollar_cap then score = score - 30 end
    end
    if scaling[key] then
        score = math.max(score, 58 - math.max(0, ante - 3) * 6)
        reason, known = 'Can grow across played rounds; buy early enough to scale it.', true
    end
    if xmult[key] then
        score = 50 + (engine.mult > 0 and 19 or -12) + math.min(10, ante * 2)
        reason, known = 'Multiplicative scoring helps once you have reliable base Mult.', true
    end
    if economy[key] then
        score = 55 - math.max(0, ante - 3) * 5 - engine.economy * 12
        reason, known = no_interest(snapshot) and 'Generates cash for upgrades; interest is disabled.' or
            'Generates income for upgrades and interest over later rounds.', true
    end
    if key == 'j_blueprint' or key == 'j_brainstorm' then
        local compatible = false
        for _, owned in ipairs(snapshot.jokers or {}) do
            if owned.blueprint_compat == true or owned.blueprint_compat == nil and
                (flat_mult[owned.key] or flat_chips[owned.key] or xmult[owned.key]) then compatible = true end
        end
        score, reason, known = compatible and 84 or 26,
            'Copy your strongest compatible Joker; placement determines the target.', true
    elseif key == 'j_dna' then
        score, reason, known = 45 + (not Strategy.synergies and has(snapshot, 'j_hologram') and 30 or 0),
            'Copies a single-card first play; strongest with valuable cards or Hologram.', true
    elseif key == 'j_burglar' then
        score, reason, known = 72, 'Extra hands help survival; discards are removed when the blind starts.', true
    elseif key == 'j_hack' or key == 'j_sock_and_buskin' or key == 'j_dusk' or key == 'j_selzer' then
        score, reason, known = 49 + (stats.enhanced / stats.size > 0.2 and 20 or 0),
            'Retriggers multiply scoring-card effects; check the ranks or timing it requires.', true
    elseif key == 'j_trading' then
        score, reason, known = 64 - math.max(0, ante - 4) * 5,
            'Use a single-card first discard to remove a weak card and earn money.', true
    elseif key == 'j_cartomancer' or key == 'j_vagabond' or key == 'j_perkeo' or key == 'j_certificate' then
        score, reason, known = 65, 'Creates resources that improve the deck over later rounds.', true
    elseif key == 'j_shortcut' or key == 'j_four_fingers' or key == 'j_smeared' then
        local favored = favored_hand(snapshot)
        score = (favored == 'Straight' or favored == 'Flush' or favored == 'Straight Flush') and 62 or 27
        reason, known = 'Improves consistency for straights or flushes; needs a matching hand plan.', true
    elseif key == 'j_juggler' or key == 'j_troubadour' or key == 'j_turtle_bean' then
        score, reason, known = 52, 'More cards held improves hand selection; check any hand-count penalty.', true
    elseif key == 'j_credit_card' then
        score, reason, known = 10, 'Borrowing creates no income or scoring; buy only for a specific urgent purchase.', true
    elseif key == 'j_luchador' then
        score, reason, known = 30, 'Keep available to sell against a boss that disables your scoring engine.', true
    elseif key == 'j_mr_bones' then
        score, reason, known = 37, 'One-time survival insurance when the score reaches its requirement.', true
    elseif key == 'j_invisible' then
        score, reason, known = 30, 'Needs time and a strong copy target; it does not score immediately.', true
    elseif key == 'j_pareidolia' then
        score, reason, known = has(snapshot, 'j_business') and 52 or 12,
            'All cards count as faces; buy only for face-card synergies and check The Plant.', true
    elseif key == 'j_chicot' then
        score, reason, known = 42, 'Disables boss restrictions; compare the actual upcoming boss before committing a slot.', true
    end
    if key == 'j_abstract' then score = score + (#(snapshot.jokers or {}) - 3) * 4 end
    if key == 'j_egg' then score = 19; reason = 'Resale value grows slowly and occupies a scoring slot.' end
    if key == 'j_swashbuckler' then
        local value = joker_sell_value(snapshot, card)
        score = value > 0 and 36 + math.min(55, value * 2) or 0
        reason = 'Adds +' .. tostring(value) .. ' Mult from the other Jokers\' sell value; retained Eggs keep growing this bonus.'
    end
    if key == 'j_gift' then
        local growth = (#(snapshot.jokers or {}) + #(snapshot.consumeables or {}) + 1) * num(a.extra, 1)
        score = 24 + math.min(22, growth * 3) - math.max(0, ante - 4) * 7
        if has(snapshot, 'j_swashbuckler') then score = score + 28 end
        if engine.mult == 0 then score = score - 16 end
        reason = 'Grows Joker and consumable sell values each completed round; it gives no immediate cash.'
        if has(snapshot, 'j_swashbuckler') then
            reason = reason .. ' Other Jokers\' growth also increases Swashbuckler Mult; Temperance can cash out the value without selling them.'
        end
    end
    if key == 'j_bull' then score = 30 + math.min(50, num(snapshot.dollars)) end
    if key == 'j_bootstraps' then score = 32 + math.min(45, num(snapshot.dollars)) end
    if key == 'j_ticket' then
        score = stats.gold > 0 and 33 + math.min(45, stats.gold * 5) or 0
        reason = 'Pays only when Gold cards score; it needs Gold cards in the deck.'
    end
    if key == 'j_stencil' then
        local other_stencils = 0
        for _, owned in ipairs(snapshot.jokers or {}) do if owned.key == 'j_stencil' then other_stencils = other_stencils + 1 end end
        local factor = num(snapshot.joker_limit, 5) - #(snapshot.jokers or {}) + other_stencils
        if edition(card, 'negative') then factor = factor + 1 end
        score = factor > 1 and 35 + math.min(55, factor * 10) or 8
        reason = 'Scales with empty Joker slots; each non-Stencil Joker reduces that multiplier.'
    end
    if key == 'j_stone' then score = 25 + math.min(60, stats.stone * 5) end
    if key == 'j_steel_joker' then score = 25 + math.min(60, stats.steel * 7) end
    if key == 'j_drivers_license' and stats.enhanced < 16 then score = 20 end
    if key == 'j_glass' then score = 20 + math.min(55, stats.glass * 3) end
    if key == 'j_hologram' and (has(snapshot, 'j_marble') or not Strategy.synergies and (has(snapshot, 'j_certificate') or has(snapshot, 'j_dna'))) then
        score = score + 25
    end
    if key == 'j_constellation' and challenge(snapshot) == 'c_blast_off_1' then score = score + 10 end
    if key == 'j_ride_the_bus' and has(snapshot, 'j_pareidolia') then score = 0 end
    if key == 'j_to_the_moon' and no_interest(snapshot) then score = 0 end
    if key == 'j_baron' and (stats.ranks[13] or 0) < 5 then score = score - 26 end
    if key == 'j_obelisk' then
        local _, plays = favored_hand(snapshot)
        if plays < 8 then score = score - 24 end
    end
    if key == 'j_madness' or key == 'j_ceremonial' then
        score = score - 12
        reason = 'Destroys other Jokers; check the sacrifice and eternal interactions before buying.'
    end
    if suit_jokers[key] then
        local matches = stats.suits[suit_jokers[key]] or 0
        if has(snapshot, 'j_smeared') then
            local other = ({Hearts='Diamonds',Diamonds='Hearts',Clubs='Spades',Spades='Clubs'})[suit_jokers[key]]
            matches = math.min(stats.size, matches + (stats.suits[other] or 0))
        end
        score = score + (matches / stats.size - 0.25) * 65
        if stats.known and matches == 0 then score = 0; reason = 'No cards currently match the suit this Joker needs.' end
    end
    local eligible_ranks = ({j_fibonacci={2,3,5,8,14},j_even_steven={2,4,6,8,10},
        j_odd_todd={3,5,7,9,14},j_scholar={14},j_walkie_talkie={4,10},j_hack={2,3,4,5}})[key]
    if eligible_ranks and stats.known then
        local matches = 0
        for _, rank in ipairs(eligible_ranks) do matches = matches + (stats.ranks[rank] or 0) end
        if matches == 0 then score = 0; reason = 'No cards currently match the ranks this Joker needs.'
        else score = score + math.min(20, matches / stats.size * 35) - 7 end
    end
    if key == 'j_smiley' or key == 'j_scary_face' or key == 'j_sock_and_buskin' or key == 'j_business' or key == 'j_faceless' then
        if has(snapshot, 'j_pareidolia') then score = score + 23
        elseif stats.known and stats.face == 0 then score = 0; reason = 'There are no face cards for this Joker\'s condition.'
        elseif stats.face / stats.size < 0.15 then score = score - 25 end
    end
    local target = ({j_jolly='Pair',j_sly='Pair',j_zany='Three of a Kind',j_wily='Three of a Kind',
        j_mad='Two Pair',j_clever='Two Pair',j_crazy='Straight',j_devious='Straight',
        j_droll='Flush',j_crafty='Flush',j_order='Straight',j_tribe='Flush'})[key]
    if target then
        local preferred, plays = favored_hand(snapshot)
        if target == preferred then score = score + 12
        elseif plays > 3 then score = score - 15 end
    end
    if Strategy.conditional_value then
        local value=Strategy.conditional_value.assess(snapshot,card,{base_value=score,readiness=snapshot._readiness,no_interest=no_interest(snapshot)})
        if value then score=score+value.adjustment;reason=reason..' '..value.reason end
    end
    if edition(card, 'foil') then score = score + (engine.chips == 0 and 16 or 8) end
    if edition(card, 'holo') then score = score + (engine.mult == 0 and 23 or 13) end
    if edition(card, 'polychrome') then score = score + 21 end
    if edition(card, 'negative') then score = score + 12 end
    if a.eternal or modifiers(snapshot).all_eternal then
        score = score - (known and 8 or 20)
        reason = reason .. ' Eternal: this slot is permanent.'
    end
    if a.perishable then
        score = score - 13
        reason = reason .. ' Perishable: only ' .. tostring(a.perish_tally or 5) .. ' rounds remain.'
        if num(a.perish_tally, 5) <= 0 then score = 0 end
    end
    if a.rental then
        score = score - (num(snapshot.dollars) < 25 and 28 or 13)
        reason = reason .. ' Rental drains $3 every round.'
    end
    if card.debuff then score = score - 35 end
    local plan=commitment(snapshot)
    if plan then
        local factor=commitment_factor(snapshot,card)
        score=score*factor
        if factor<1 then reason=reason..' The approaching Joker-slot lock limits its lasting value.'
        elseif known and score>0 then
            score=score+10*plan.pressure
            reason=reason..' A durable contribution to the row retained after the Joker-slot lock.'
        end
        if a.rental then
            score=score-math.max(0,math.min(30,plan.rounds*3-num(snapshot.dollars)/3))*plan.pressure
            reason=reason..' Its rental charge continues after the slot lock.'
        end
    end
    return score, reason, known
end

local function base_consumable_value(snapshot, card, stats, already_owned)
    local key, preferred = card.key, favored_hand(snapshot)
    local hand = hand_type(card)
    if hand then
        local points = hand == preferred and 69 or 22
        if has(snapshot, 'j_constellation') then points = points + 23 end
        return points, hand == preferred and ('Levels your main hand: ' .. hand .. '.') or
            ('Levels ' .. hand .. (has(snapshot, 'j_constellation') and ' and grows Constellation.' or '.'))
    end
    local values = {
        c_fool=35,c_magician=40,c_high_priestess=38,c_empress=52,c_emperor=43,
        c_heirophant=51,c_lovers=17,c_chariot=58,c_justice=61,c_strength=48,
        c_hanged_man=53,c_death=68,c_devil=35,c_tower=22,c_star=38,c_moon=38,
        c_sun=38,c_judgement=58,c_world=38,c_aura=54,c_talisman=39,c_deja_vu=67,
        c_trance=70,c_medium=57,c_cryptid=71,c_soul=85,c_black_hole=91,
        c_familiar=19,c_grim=23,c_incantation=23,c_sigil=18,c_ouija=12,
        c_immolate=48,c_ankh=13,c_hex=15,c_ectoplasm=23,c_wraith=30,
        c_wheel_of_fortune=20,
    }
    local score, reason = values[key] or 12, 'Improves the deck; choose targets that support your main hand.'
    if key == 'c_hermit' then
        local gain = math.max(0, math.min(20, num(snapshot.dollars) -
            (snapshot.phase == 'shop' and not already_owned and num(card.cost) or 0)))
        return gain > 0 and 42 + gain * 2 or 0, 'Doubles current cash, up to $20; use before spending further.'
    elseif key == 'c_temperance' then
        local gain = joker_sell_value(snapshot)
        local priority = omelette(snapshot) and num(snapshot.dollars) < 15 and gain >= 10 and 16 or 0
        return gain > 0 and 40 + math.min(50, gain) + priority or 0,
            'Pays $' .. tostring(math.min(50, gain)) .. ' from the total Joker sell value, up to $50; keep the Jokers.'
    elseif key == 'c_death' then reason = 'Copy your best card: the selected LEFT card becomes the RIGHT card.'
    elseif key == 'c_justice' then reason = 'Glass gives X2 Mult when scored; target a card you can reliably play.'
    elseif key == 'c_chariot' then reason = 'Steel gives X1.5 Mult while held; target a card you can leave unplayed.'
    elseif key == 'c_trance' then reason = 'Blue Seal creates the winning hand\'s Planet if held with consumable space.'
    elseif key == 'c_deja_vu' then reason = 'Red Seal repeats card effects; prioritize Glass, Steel, or other strong scoring cards.'
    elseif key == 'c_hanged_man' then reason = 'Remove off-plan cards, improving future draws; protect scarce deck resources.'
    elseif key == 'c_cryptid' then reason = 'Copy an enhanced or sealed card that supports your main hand.'
    elseif key == 'c_black_hole' then reason = 'Levels every hand, with no Joker-space requirement.'
    elseif key == 'c_immolate' then reason = 'Destroys five random held cards for $20; inspect the hand before using.'
    elseif key == 'c_ankh' or key == 'c_hex' then
        reason = 'May destroy valuable Jokers; compare the whole engine before using.'
    elseif key == 'c_wraith' then reason = 'Creates a Rare Joker but sets money to $0; needs a free Joker slot.'
    elseif key == 'c_ectoplasm' then reason = 'Adds a negative edition but reduces hand size; inspect the tradeoff.'
    end
    if key == 'c_judgement' or key == 'c_wraith' or key == 'c_soul' then
        if jokerless(snapshot) or #(snapshot.jokers or {}) >= num(snapshot.joker_limit, 5) then return 0, 'No Joker space.' end
    end
    if key == 'c_fool' and (not snapshot.last_tarot_planet or snapshot.last_tarot_planet == 'c_fool') then
        return 0, 'There is no previous Tarot or Planet to copy.'
    end
    if key == 'c_high_priestess' or key == 'c_emperor' or key == 'c_fool' then
        if #(snapshot.consumeables or {}) >= num(snapshot.consumable_limit, 2) and snapshot.phase == 'pack' then
            return 0, 'Use a stored consumable first to make space.'
        end
    end
    if key == 'c_wheel_of_fortune' or key == 'c_ectoplasm' or key == 'c_hex' then
        local eligible = false
        for _, joker in ipairs(snapshot.jokers or {}) do
            if not joker.edition then eligible = true end
        end
        if not eligible then return 0, 'Needs an eligible Joker without an edition.' end
    end
    if key == 'c_ankh' and (#(snapshot.jokers or {}) == 0 or
        #(snapshot.jokers or {}) >= num(snapshot.joker_limit, 5) or num(snapshot.joker_limit, 5) <= 1) then
        return 0, 'Needs a Joker and an open Joker slot.'
    end
    if modifiers(snapshot).chips_dollar_cap and (key == 'c_wraith' or key == 'c_ouija') then score = 0 end
    if challenge(snapshot) == 'c_fragile_1' and (key == 'c_hanged_man' or key == 'c_immolate') then score = score - 50 end
    if has(snapshot, 'j_vampire') and (key == 'c_empress' or key == 'c_heirophant' or key == 'c_magician' or key == 'c_lovers') then
        score = score + 20
        reason = reason .. ' These enhancements also feed Vampire.'
    end
    if jokerless(snapshot) and (key == 'c_chariot' or key == 'c_justice' or key == 'c_death' or key == 'c_cryptid') then score = score + 15 end
    if has(snapshot, 'j_constellation') and key == 'c_high_priestess' then score = score + 15 end
    return score, reason
end

local function perkeo_effects(snapshot)
    local jokers=snapshot.jokers or {}
    local function source(index,seen)
        local card=jokers[index]
        if not card or card.debuff or seen[index] then return false end
        seen[index]=true
        local key=card.key
        local n=ability(card).name or card.name
        if key=='j_perkeo' or n=='Perkeo' then return true end
        local target=(key=='j_blueprint' or n=='Blueprint') and index+1 or
            (key=='j_brainstorm' or n=='Brainstorm') and 1
        if target and jokers[target] and jokers[target].blueprint_compat~=false then return source(target,seen) end
        return false
    end
    local count=0
    for i=1,#jokers do if source(i,{}) then count=count+1 end end
    return count
end

local function copy_utility(snapshot,card,profile)
    if card.debuff then return 0 end
    -- This inventory is already held, and Perkeo's new copies are free. The
    -- card's recorded shop price must not be charged again to its cash payout.
    local value=base_consumable_value(snapshot,card,profile.stats,true)
    local hand=hand_type(card)
    if hand then
        local h=(snapshot.hands or {})[hand] or {}
        local level=num(h.level,1)
        local relative=(num(h.l_chips,15)/math.max(10,num(h.chips,10+15*(level-1)))+
            num(h.l_mult,1)/math.max(2,num(h.mult,2+level-1)))
        return (hand==profile.hand and 1 or 0.18)*(8+math.min(100,65*relative))
    elseif card.key=='c_strength' then
        if profile.rank then
            local available=profile.stats.ranks[profile.predecessor] or 0
            return available>0 and math.min(120,40+available*12) or 0
        end
        return 18
    elseif card.key=='c_death' or card.key=='c_cryptid' then
        if profile.rank then return math.min(120,35+math.max(0,profile.stats.size-profile.rank_count)*6) end
    elseif card.key=='c_heirophant' or card.key=='c_empress' then
        local h=(snapshot.hands or {})[profile.hand] or {}
        local increase=card.key=='c_heirophant' and 60/math.max(20,num(h.chips,20)) or 8/math.max(4,num(h.mult,4))
        return math.min(100,12+45*increase)
    end
    return math.max(0,value)
end

-- Uniform sequential copying is a Polya urn: new Negative copies enter the
-- next draw's pool. Enumerate at most four events/eight equivalent types. The
-- larger-pool fallback retains exact additive means and labels its nonlinear
-- Observatory approximation; neither branch is a survival forecast.
inventory_value=function(snapshot,inventory,options)
    options=options or {}
    inventory=inventory or snapshot.consumeables or {}
    local profile=options.profile or build_profile(snapshot)
    local effects=perkeo_effects(snapshot)
    local events=math.min(4,math.max(0,math.floor(num(options.events,effects*math.min(2,profile.horizon)))))
    if effects==0 or profile.horizon==0 then events=0 end
    local groups,by_key={},{}
    local observatory=(snapshot.used_vouchers or {}).v_observatory or (snapshot.vouchers or {}).v_observatory
    for _,card in ipairs(inventory) do
        local key=tostring(card.key or name(card))..(card.debuff and ':debuff' or ':active')
        local group=by_key[key]
        if not group then
            group={key=key,card=card,count=0,utility=copy_utility(snapshot,card,profile),
                matching=not card.debuff and hand_type(card)==profile.hand}
            by_key[key]=group;groups[#groups+1]=group
        end
        group.count=group.count+1
    end
    table.sort(groups,function(a,b) return a.key<b.key end)
    local counts,total={},#inventory
    for i,g in ipairs(groups) do counts[i]=g.count end
    local function held_value(stock)
        if not observatory then return 0 end
        local count=0
        for i,g in ipairs(groups) do if g.matching then count=count+stock[i] end end
        -- Cap strategic utility, never the game's actual score multiplier.
        return 24*(math.min(32,1.5^count)-1)
    end
    local direct=0
    for _,g in ipairs(groups) do direct=direct+g.count*g.utility end
    local held=held_value(counts)
    local memo={}
    local function recurse(left,size)
        local key=left..':'..table.concat(counts,',')
        if memo[key] then return memo[key] end
        if left==0 then return held_value(counts) end
        local value=0
        for i=1,#groups do
            local p=counts[i]/size
            counts[i]=counts[i]+1
            value=value+p*recurse(left-1,size+1)
            counts[i]=counts[i]-1
        end
        memo[key]=value;return value
    end
    local mean=total>0 and direct/total or 0
    local projected_held=held
    local approximate=false
    if events>0 and total>0 and observatory then
        if #groups<=8 then projected_held=recurse(events,total)
        else
            -- Explicitly bounded approximation only for the strategic premium.
            approximate=true
            local matching=0;for _,g in ipairs(groups) do if g.matching then matching=matching+g.count end end
            projected_held=24*(math.min(32,1.5^(matching+events*matching/total))-1)
        end
    end
    local future=events*mean+projected_held-held
    local probabilities={}
    for _,g in ipairs(groups) do probabilities[g.card.key or name(g.card)]=(probabilities[g.card.key or name(g.card)] or 0)+g.count/math.max(1,total) end
    return direct+held+future,{direct=direct,held=held,future=future,events=events,
        effects=effects,probabilities=probabilities,approximate=approximate,profile=profile}
end

inventory_marginal=function(before,after,options)
    local old,old_info=inventory_value(before,nil,options)
    local new,new_info=inventory_value(after,nil,options)
    return new-old,{before=old_info,after=new_info,future=new_info.future-old_info.future,
        held=new_info.held-old_info.held}
end

preservation_cost=function(before,after,index)
    local profile=build_profile(before)
    local _,old=inventory_value(before,nil,{profile=profile})
    local _,new=inventory_value(before,after.consumeables or {},{profile=profile})
    local info={before=old,after=new,future=new.future-old.future,held=new.held-old.held}
    local card=(before.consumeables or {})[index]
    local last=false
    if card and info.before.events>0 and copy_utility(before,card,info.before.profile)>0 then
        last=true
        for _,other in ipairs(after.consumeables or {}) do
            if not other.debuff and other.key==card.key then last=false end
        end
    end
    local loss=math.max(0,-info.future)+math.max(0,-info.held)
    -- A weaker last-of-type card can be worth using to improve the pool.
    -- Preserve a source only when removing it actually loses future utility.
    last=last and loss>0.000001
    local reason=last and ('Keep the last '..name(card)..' for Perkeo copies.') or
        (loss>0 and 'Keeping this inventory preserves more valuable Perkeo copies or Observatory multipliers.' or nil)
    return loss,reason,last
end

local function consumable_value(snapshot,card,stats)
    local value,reason=base_consumable_value(snapshot,card,stats)
    if value<=0 then return value,reason end
    local profile=build_profile(snapshot,stats)
    local _,before=inventory_value(snapshot,nil,{profile=profile})
    if before.events==0 and before.held==0 and not ((snapshot.used_vouchers or {}).v_observatory or (snapshot.vouchers or {}).v_observatory) then return value,reason end
    -- A pack consumable is used immediately. A shop purchase remains in inventory;
    -- no illegal target use is invented to hide its copy-pool dilution.
    if snapshot.phase=='pack' then return copy_utility(snapshot,card,profile),reason end
    local inventory={};for i,c in ipairs(snapshot.consumeables or {}) do inventory[i]=c end
    inventory[#inventory+1]=card
    -- The offered card is paid for once. Existing cash-copy sources must also
    -- be valued at that resulting cash, rather than their historical prices.
    local purchased=snapshot
    if snapshot.phase=='shop' then
        purchased={};for k,v in pairs(snapshot) do purchased[k]=v end
        purchased.dollars=num(snapshot.dollars)-num(card.cost)
    end
    local _,after=inventory_value(purchased,inventory,{profile=profile})
    local delta=after.future-before.future+after.held-before.held
    if delta<-1 then reason=reason..' Its weaker copying pool dilutes the current Perkeo engine.'
    elseif delta>1 then reason=reason..' Holding it strengthens the copying pool or matching Observatory engine.' end
    return copy_utility(purchased,card,profile)+delta,reason
end

local function playing_value(snapshot, card, stats)
    local score = -7 -- Deck dilution is a real cost: ordinary cards can be skipped.
    local enhancement = card.enhancement
    local reasons = {}
    if enhancement and enhancement ~= 'c_base' and enhancement ~= 'Base' then
        score = score + 18
        reasons[#reasons + 1] = 'enhanced card'
    end
    if enhancement == 'm_glass' or enhancement == 'm_steel' then score = score + 12 end
    if edition(card, 'polychrome') then score = score + 30 end
    if edition(card, 'holo') then score = score + 22 end
    if edition(card, 'foil') then score = score + 18 end
    if card.seal == 'Blue' or card.seal == 'Purple' or card.seal == 'Red' then
        score = score + 33
        reasons[#reasons + 1] = card.seal .. ' Seal'
    elseif card.seal == 'Gold' then score = score + 16 end
    if has(snapshot, 'j_hologram') then score = score + 22; reasons[#reasons + 1] = 'grows Hologram' end
    if has(snapshot, 'j_vampire') and enhancement then score = score + 8 end
    local rank = card.rank or card.base and card.base.id
    if (stats.ranks[rank] or 0) / stats.size > 0.18 then score = score + 12 end
    if card.suit and (stats.suits[card.suit] or 0) / stats.size > 0.45 then score = score + 9 end
    if #reasons == 0 then return score, 'A plain extra card dilutes the deck unless its rank/suit advances your plan.' end
    return score, 'Useful addition: ' .. table.concat(reasons, ', ') .. '.'
end

local function voucher_value(snapshot, card)
    local scores = {
        v_grabber=76,v_nacho_tong=79,v_wasteful=59,v_recyclomancy=57,
        v_paint_brush=78,v_palette=79,v_antimatter=87,v_blank=15,
        v_seed_money=37,v_money_tree=35,v_clearance_sale=60,v_liquidation=66,
        v_overstock_norm=48,v_overstock_plus=49,v_reroll_surplus=28,v_reroll_glut=25,
        v_crystal_ball=50,v_omen_globe=32,v_telescope=74,v_observatory=32,
        v_tarot_merchant=40,v_tarot_tycoon=43,v_planet_merchant=39,v_planet_tycoon=40,
        v_magic_trick=12,v_illusion=26,v_directors_cut=32,v_retcon=34,
        v_hieroglyph=35,v_petroglyph=45,v_hone=41,v_glow_up=48,
    }
    local key, score = card.key, scores[card.key] or 15
    if (key == 'v_grabber' or key == 'v_nacho_tong') and num(snapshot.round_resets and snapshot.round_resets.hands, 4) <= 2 then score = score + 15 end
    if key == 'v_seed_money' or key == 'v_money_tree' then
        if no_interest(snapshot) then score = 0
        elseif num(snapshot.dollars) < num(snapshot.interest_cap, 25) + num(card.cost) then score = score - 25 end
    end
    if key == 'v_hieroglyph' and num(snapshot.round_resets and snapshot.round_resets.hands, 4) <= 2 then score = 0 end
    if key == 'v_antimatter' and jokerless(snapshot) then score = 0 end
    if (key == 'v_planet_merchant' or key == 'v_planet_tycoon' or key == 'v_telescope') and has(snapshot, 'j_constellation') then score = score + 18 end
    local reason = 'Permanent run upgrade; buy if it supports your current scoring plan.'
    if key=='v_observatory' and not (snapshot.used_vouchers or {}).v_observatory then
        local after={};for k,v in pairs(snapshot) do after[k]=v end
        after.used_vouchers={};for k,v in pairs(snapshot.used_vouchers or {}) do after.used_vouchers[k]=v end
        after.used_vouchers.v_observatory=true
        local gain=inventory_marginal(snapshot,after)
        score=score+math.min(150,math.max(0,gain))
        reason='Matching held Planets gain X1.5 each; this valuation includes the current inventory and bounded Perkeo copying opportunities.'
    end
    if key == 'v_telescope' then reason = 'Celestial packs will include the Planet for your most-played hand.' end
    if key == 'v_hieroglyph' then reason = 'One ante of extra growth costs one hand every round.' end
    if key == 'v_petroglyph' then reason = 'One ante of extra growth costs one discard every round.' end
    return score, reason
end

local function booster_value(snapshot, card, engine)
    local key = card.key or ''
    if key:find('buffoon', 1, true) then
        if jokerless(snapshot) or #(snapshot.jokers or {}) >= num(snapshot.joker_limit, 5) then return 0, 'No free Joker space.' end
        return engine.mult == 0 and 68 or 46, 'Find a scoring Joker; the contents are unknown until opened.'
    elseif key:find('celestial', 1, true) then
        return 45 + (has(snapshot, 'j_constellation') and 22 or 0) + (jokerless(snapshot) and 15 or 0),
            'Look for the Planet for your main hand; contents are unknown.'
    elseif key:find('arcana', 1, true) then
        return 43 + (jokerless(snapshot) and 14 or 0) + (has(snapshot, 'j_vampire') and 15 or 0),
            'Look for money, deck shaping, or enhancements; contents are unknown.'
    elseif key:find('spectral', 1, true) then return 40, 'Look for seals or strong deck upgrades; several Spectral choices have major costs.'
    elseif key:find('standard', 1, true) then
        return has(snapshot, 'j_hologram') and 51 or 23, 'Take a useful seal or enhancement; skip ordinary cards that dilute your deck.'
    end
    return 15, 'Pack contents are unknown; inspect the pack description.'
end

local purchase_liquidity
local function purchase_penalty(snapshot, cost, card, after, after_readiness, omit_liquidity)
    local dollars = num(snapshot.dollars)
    local remaining = dollars - cost
    local penalty = cost * 2.3
    if remaining < 0 then penalty = penalty + 14 end
    if not no_interest(snapshot) and not modifiers(snapshot).minus_hand_size_per_X_dollar then
        local cap = num(snapshot.interest_cap, 25)
        local before = math.min(math.floor(math.max(0, dollars) / 5), cap / 5)
        local after = math.min(math.floor(math.max(0, remaining) / 5), cap / 5)
        penalty = penalty + (before - after) * 4 * num(snapshot.interest_amount, 1)
    end
    if modifiers(snapshot).chips_dollar_cap and kind(card) ~= 'consumable' then penalty = penalty + cost * 2 end
    if modifiers(snapshot).minus_hand_size_per_X_dollar then penalty = penalty - math.min(15, math.floor(cost / 5) * 6) end
    if modifiers(snapshot).inflation then penalty = penalty + 6 end
    if cost == 0 then penalty = 0 end
    if Strategy.liquidity and purchase_liquidity then
        if not omit_liquidity then penalty=penalty+purchase_liquidity(snapshot,cost,card,after,after_readiness) end
    elseif modifiers(snapshot).discard_cost and remaining < 6 and cost~=0 then penalty = penalty + 10 end
    return penalty
end

local function capacity(snapshot, card, in_pack)
    local category = kind(card)
    if category == 'joker' then
        if jokerless(snapshot) then return false end
        local limit = num(snapshot.joker_limit, 5)
        if in_pack and edition(card, 'negative') then return true end
        return #(snapshot.jokers or {}) < limit + (edition(card, 'negative') and 1 or 0)
    elseif category == 'consumable' and not in_pack then
        return #(snapshot.consumeables or {}) < num(snapshot.consumable_limit, 2) + (edition(card, 'negative') and 1 or 0)
    end
    return true
end

local function copy_table(value)
    local out={}; for k,v in pairs(value or {}) do out[k]=v end; return out
end

-- Detached equivalents of the resource changes in Card:add/remove_from_deck.
-- Scoring previews must include their draw-size, resource and probability costs.
local function adjust_joker_resources(state,card,direction)
    if card.debuff then return end
    local a=ability(card); local extra=type(a.extra)=='table' and a.extra or {}
    local hand_delta=num(a.h_size)
    if card.key=='j_turtle_bean' or card.key=='j_troubadour' then hand_delta=hand_delta+num(extra.h_size) end
    if card.key=='j_stuntman' then hand_delta=hand_delta-num(extra.h_size,2) end
    state.hand_size=num(state.hand_size,8)+direction*hand_delta
    state.round_resets=copy_table(state.round_resets)
    state.round_resets.discards=num(state.round_resets.discards,3)+direction*math.max(0,num(a.d_size))
    state.round_resets.hands=num(state.round_resets.hands,4)+direction*(card.key=='j_troubadour' and num(extra.h_plays,-1) or 0)
    if card.key=='j_oops' then
        state.probabilities=copy_table(state.probabilities or {normal=1})
        for key,value in pairs(state.probabilities) do state.probabilities[key]=value*(direction==1 and 2 or 0.5) end
    end
end

local function change_preview_cash(state,amount)
    local tax=num(modifiers(state).minus_hand_size_per_X_dollar)
    local before=num(state.dollars)
    state.dollars=before+amount
    if tax>0 then state.hand_size=num(state.hand_size,8)+math.floor(before/tax)-math.floor(state.dollars/tax) end
end

local function after_joker_purchase(snapshot,card)
    local after=copy_table(snapshot); after.jokers=copy_table(snapshot.jokers)
    after.jokers[#after.jokers+1]=card
    if edition(card,'negative') then after.joker_limit=num(after.joker_limit,5)+1 end
    change_preview_cash(after,snapshot.phase=='shop' and -num(card.cost) or 0)
    adjust_joker_resources(after,card,1)
    if not card.debuff then
        if card.key=='j_credit_card' then after.bankrupt_at=num(after.bankrupt_at)-num(ability(card).extra,20) end
        if card.key=='j_to_the_moon' then after.interest_amount=num(after.interest_amount,1)+num(ability(card).extra,1) end
    end
    return after
end

purchase_liquidity=function(snapshot,cost,card,after,after_readiness)
    if not after then
        if kind(card)=='joker' then after=after_joker_purchase(snapshot,card)
        else after=copy_table(snapshot);change_preview_cash(after,-cost) end
    end
    return Strategy.liquidity.incremental(snapshot,after,snapshot._readiness,after_readiness or {supported=false})
end

local function survival_dominated(evidence)
    if not evidence or not evidence.complete_finishing then return false end
    local a,b=evidence.before_finishing,evidence.after_finishing
    if not a or not b or not a.complete or not b.complete or not a.supported or not b.supported or
        not a.known_mechanics or not b.known_mechanics or not a.selected or not b.selected or
        num(a.samples)<4 or a.samples~=b.samples then return false end
    -- The baseline already clears every common world. A final endpoint that
    -- loses any of them is dominated on this supported survival comparison;
    -- delayed utility cannot compensate by making an existing clear clearer.
    return a.selected.clearing_samples==a.samples and num(b.selected.clearing_samples,a.samples)<a.samples
end
Strategy.survival_dominated=survival_dominated

local function shop_score_evidence(snapshot,after,card,whole_row)
    local ctx=snapshot._shop_scoring
    -- Income and prospective growth keep their strategic value. This pass only
    -- changes tactical ratings when the current scoring effect is understood.
    local key=card.key
    local support={j_hack=true,j_sock_and_buskin=true,j_dusk=true,j_selzer=true,j_hanging_chad=true,
        j_photograph=true,j_mime=true,j_four_fingers=true,j_shortcut=true,j_smeared=true,j_splash=true,
        j_chicot=true,j_pareidolia=true,j_juggler=true,j_turtle_bean=true,j_troubadour=true}
    local tactical=flat_mult[key] or flat_chips[key] or xmult[key] or key=='j_blueprint' or key=='j_brainstorm'
        or support[key] or num(ability(card).mult)>0 or num(ability(card).x_mult)>1
    if not ctx or not (tactical or whole_row or ctx.readiness and (economy[key] or scaling[key])) then return end
    local evidence=ctx:compare(snapshot,after)
    if evidence then
        if survival_dominated(evidence) then
            evidence.survival_dominated=true
            evidence.reason=evidence.reason..' This final build loses a supported sampled finish that saving preserves; a complete rescuing continuation is required.'
        end
        local delta=(tactical or whole_row) and num(evidence.adjustment) or 0
        if scaling[key] then delta=math.max(-8,delta) end
        local before_ready,after_ready=evidence.before_readiness,evidence.after_readiness
        if before_ready and after_ready and before_ready.status=='sampled_deficit' and after_ready.supported then
            local gain=(after_ready.opening_mean-before_ready.opening_mean)/math.max(1,before_ready.target)
            if evidence.complete_finishing then
                local left=evidence.before_finishing and evidence.before_finishing.selected
                local right=evidence.after_finishing and evidence.after_finishing.selected
                if left and right then
                    gain=right.mean_progress-left.mean_progress
                    evidence.timely_scoring_basis='complete_paired_blind_progress'
                end
            end
            -- Only an actual, affordable resulting build earns emergency value.
            -- Growth counts only when exact transitions carried it through a
            -- complete paired blind policy. Unseen shop offers earn no credit.
            if gain>0.02 then
                delta=delta+math.min(36,12+48*gain)
                evidence.timely_scoring=true
            elseif snapshot.phase=='shop' and num(card.cost)>0 and after_ready.status=='sampled_deficit' then
                delta=delta-30
                evidence.delayed_spending=true
            end
            evidence.reason=evidence.reason..' '..before_ready.reason
        end
        return delta,evidence
    end
end

local function planet_purchase_evidence(snapshot,card)
    if not snapshot._shop_scoring or not Strategy.consumables or not hand_type(card) then return end
    local held=copy_table(snapshot);held.consumeables=copy_table(snapshot.consumeables)
    held.consumeables[#held.consumeables+1]=card
    if edition(card,'negative') then held.consumable_limit=num(held.consumable_limit,2)+1 end
    change_preview_cash(held,-num(card.cost))
    -- Preserve the whole copying inventory and Observatory choice. A new Planet
    -- is not silently assumed consumed when keeping it has an engine role.
    local index=#held.consumeables
    local clean=copy_table(held);clean._shop_scoring=nil
    local used=Strategy.consumables.apply(clean,index,{})
    if not used then return end
    local loss,_,last=preservation_cost(held,used,index)
    if last or loss>0 then return shop_score_evidence(snapshot,held,card,true) end
    local adjustment,evidence=shop_score_evidence(snapshot,used,card,true)
    if evidence then evidence.planet_use=true;evidence.reason=evidence.reason..' Includes using this Planet before the next blind.' end
    return adjustment,evidence,used
end

local function card_value(snapshot, card, stats, engine)
    local category = kind(card)
    if category == 'joker' then
        local score, reason, known = joker_value(snapshot, card, stats, engine)
        local forecast = Strategy.synergies and Strategy.synergies.forecast(snapshot, card)
        if forecast and commitment(snapshot) and forecast.mode=='speculative' then
            forecast=nil -- No credit for partners that may only appear after the row locks.
        end
        if forecast then
            if score > 0 then score = score + num(forecast.bonus) end
            if #forecast.lines > 0 then reason = reason .. ' ' .. table.concat(forecast.lines, ' ') end
            if #(forecast.existing or {}) > 0 or forecast.available then known = true end
        end
        return score, reason, known, forecast
    elseif category == 'consumable' then return consumable_value(snapshot, card, stats)
    elseif category == 'playing' then return playing_value(snapshot, card, stats)
    elseif category == 'voucher' then return voucher_value(snapshot, card)
    else return booster_value(snapshot, card, engine) end
end

local planet_shop_dominance,planet_shop_commitment
local function best_shop_purchase(snapshot, stats, engine, final_endpoint)
    local candidates,planet_candidates = {},{}
    for _, area in ipairs({'shop_jokers', 'shop_vouchers', 'shop_booster'}) do
        for index, card in ipairs(snapshot[area] or {}) do
            local cost = num(card.cost)
            if (cost <= 0 or cost <= num(snapshot.dollars) - num(snapshot.bankrupt_at)) and capacity(snapshot, card, false)
                and not (modifiers(snapshot).no_shop_jokers and kind(card) == 'joker') then
                local score, reason, known, forecast = card_value(snapshot, card, stats, engine)
                local evidence,after,planet_after
                if known and kind(card)=='joker' then
                    local adjustment
                    after=after_joker_purchase(snapshot,card)
                    adjustment,evidence=shop_score_evidence(snapshot,after,card)
                    if evidence then score=score+adjustment; reason=reason..' '..evidence.reason end
                elseif kind(card)=='consumable' and hand_type(card) then
                    local adjustment
                    adjustment,evidence,planet_after=planet_purchase_evidence(snapshot,card)
                    if evidence then score=score+adjustment;reason=reason..' '..evidence.reason end
                end
                local dominated=final_endpoint and survival_dominated(evidence)
                if dominated and snapshot._shop_scoring then
                    local ctx=snapshot._shop_scoring
                    ctx.survival_dominated_actions=ctx.survival_dominated_actions or {}
                    ctx.survival_dominated_actions['buy:'..area..':'..index]={area=area,index=index,key=card.key,evidence=evidence}
                end
                local candidate={score=score-purchase_penalty(snapshot, cost, card,after,evidence and evidence.after_readiness),
                    reason=reason,card=card,area=area,index=index,known=known,forecast=forecast,scoring_evidence=evidence}
                if area=='shop_jokers' and kind(card)=='consumable' and hand_type(card) then
                    planet_candidates[#planet_candidates+1]={candidate=candidate,after=planet_after,eligible=score>0 and not dominated}
                end
                if score>0 and not dominated then
                    candidates[#candidates+1]=candidate
                end
            end
        end
    end
    if final_endpoint and planet_shop_commitment then planet_shop_commitment(snapshot,planet_candidates) end
    table.sort(candidates, function(a, b)
        if a.score == b.score then
            if a.area == b.area then return a.index < b.index end
            return a.area < b.area
        end
        return a.score > b.score
    end)
    if final_endpoint and planet_shop_dominance then
        local selected,diagnostics=planet_shop_dominance(snapshot,candidates)
        if selected then return selected,diagnostics end
    end
    return candidates[1]
end

local function after_egg_sale(snapshot, index)
    local out = {}
    for key, value in pairs(snapshot) do out[key] = value end
    out.jokers = {}
    for i, owned in ipairs(snapshot.jokers or {}) do
        if i ~= index then out.jokers[#out.jokers + 1] = owned end
    end
    local egg = snapshot.jokers[index]
    change_preview_cash(out,num(egg.sell_cost))
    adjust_joker_resources(out,egg,-1)
    -- Selling a Negative Egg removes the slot it supplied. It cannot make
    -- space for an ordinary replacement in an otherwise full Joker row.
    out.joker_limit = num(snapshot.joker_limit, 5) - (edition(egg, 'negative') and 1 or 0)
    for i,joker in ipairs(out.jokers) do
        if joker.key=='j_campfire' and not joker.debuff then
            local copy=copy_table(joker); copy.ability=copy_table(ability(joker))
            copy.ability.x_mult=num(copy.ability.x_mult,1)+num(copy.ability.extra,0.25)
            out.jokers[i]=copy
        end
    end
    return out
end

local function egg_sale_plan(snapshot, direct, choose)
    if not omelette(snapshot) or modifiers(snapshot).all_eternal then return end
    local best
    for index, egg in ipairs(snapshot.jokers or {}) do
        if egg.key == 'j_egg' and not ability(egg).eternal then
            local state = after_egg_sale(snapshot, index)
            local candidate = choose(state, deck_stats(state), components(state))
            if candidate then
                local in_pack = snapshot.phase == 'pack'
                local blocked = not capacity(snapshot, candidate.card, in_pack) or
                    not in_pack and (num(candidate.card.cost) > math.max(0, num(snapshot.dollars) - num(snapshot.bankrupt_at)) or
                        kind(candidate.card) == 'booster' and (candidate.card.key or ''):find('buffoon', 1, true) and
                            #(snapshot.jokers or {}) >= num(snapshot.joker_limit, 5))
                -- Do not liquidate an Egg for a purchase that was already
                -- usable, or for a speculative reroll with no known upgrade.
                if blocked then
                    local penalty = 10
                    if has(snapshot, 'j_swashbuckler') then
                        local total = joker_sell_value(snapshot, has(snapshot, 'j_swashbuckler'))
                        penalty = penalty + 70 * num(egg.sell_cost) / math.max(1, total)
                    end
                    if edition(egg, 'foil') then penalty = penalty + 20 end
                    if edition(egg, 'holo') then penalty = penalty + 28 end
                    if edition(egg, 'polychrome') then penalty = penalty + 30 end
                    local score = candidate.score - penalty
                    if kind(candidate.card)=='joker' and snapshot._shop_scoring then
                        local _,evidence=shop_score_evidence(snapshot,after_joker_purchase(state,candidate.card),candidate.card,true)
                        if evidence and (evidence.ratio<0.85 or survival_dominated(evidence)) then score=-math.huge end
                    end
                    if score >= 26 and (not direct or score > direct.score) and
                        (not best or score > best.score or score == best.score and num(egg.sell_cost) < num(best.egg.sell_cost)) then
                        best = {score=score, egg=egg, index=index, purchase=candidate}
                    end
                end
            end
        end
    end
    return best
end

local function sale_advice(snapshot, sale)
    local purchase = sale.purchase
    local verb = snapshot.phase == 'pack' and 'choose' or purchase.area == 'shop_booster' and 'open' or 'buy'
    local result = {title='Sell Egg #' .. tostring(sale.index) .. ' ($' .. tostring(num(sale.egg.sell_cost)) .. ')',
        lines={'Then ' .. verb .. ' ' .. name(purchase.card) .. (snapshot.phase == 'shop' and ' ($' .. tostring(num(purchase.card.cost)) .. ')' or '') .. '.',
            purchase.reason, 'This plan sells one Egg; refresh advice after selling before taking the next action.'}, warnings={},
        forecast=purchase.forecast, action={kind='sell', area='jokers', index=sale.index,
            followup={kind=verb, area=purchase.area or 'pack_cards', index=purchase.index}}}
    if has(snapshot, 'j_swashbuckler') then
        result.lines[#result.lines + 1] = 'Selling this Egg removes ' .. tostring(num(sale.egg.sell_cost)) .. ' Mult from Swashbuckler, plus its future growth.'
    end
    if purchase.known == false then result.warnings[1] = 'This Joker has only a generic strategic rating.' end
    return result
end

local function shallow_copy(value)
    local out = {}; for k,v in pairs(value or {}) do out[k]=v end; return out
end

local function expired(card)
    return ability(card).perishable and num(ability(card).perish_tally,5)<=0
end

local function after_joker_sale(snapshot, index)
    local sold = snapshot.jokers[index]
    -- A charged Invisible Joker replaces itself with a random copy. A promised
    -- empty slot (and a fixed follow-up purchase) would therefore be false.
    if sold.key=='j_invisible' and not sold.debuff and
        num(ability(sold).invis_rounds)>=num(ability(sold).extra,2) then return nil end
    local out = after_egg_sale(snapshot,index)
    if sold.key=='j_credit_card' and not sold.debuff then
        out.bankrupt_at=num(snapshot.bankrupt_at)+num(ability(sold).extra,20)
    end
    if sold.key=='j_to_the_moon' and not sold.debuff then
        out.interest_amount=num(snapshot.interest_amount,1)-num(ability(sold).extra,1)
    end
    return out
end

-- Compare complete retained rows, not rarity or the incoming card alone. These
-- are bounded strategic utility units, not score simulations or win chances.
local function replacement_build_value(snapshot, stats, include_inventory)
    local state=shallow_copy(snapshot); state.jokers={}
    state.shop_forecast=nil; state.shop_jokers={}; state.pack_cards={}; state.phase='replacement'
    for _,card in ipairs(snapshot.jokers or {}) do
        local copy=shallow_copy(card)
        -- Temporary boss debuffs can recover. Only an exhausted perishable is
        -- expendable merely because its effects are currently disabled.
        copy.debuff=not not expired(card)
        state.jokers[#state.jokers+1]=copy
    end
    local engine=components(state)
    local total,strengths=0,{}
    for i,card in ipairs(state.jokers) do
        local value=0
        if not expired(card) then
            local context=state
            if card.key=='j_blueprint' or card.key=='j_brainstorm' then
                context=shallow_copy(state); context.jokers={}
                for j,other in ipairs(state.jokers) do if i~=j then context.jokers[#context.jokers+1]=other end end
            end
            value=math.max(0,(joker_value(context,card,stats,engine)))
            local a=ability(card); local extra=type(a.extra)=='table' and a.extra or {}
            local mult=math.max(0,num(a.mult,num(extra.mult)))
            local chips=math.max(0,num(a.t_chips,num(extra.chips)))
            local factor=math.max(1,num(a.x_mult,num(extra.Xmult,1)))
            if card.key=='j_swashbuckler' then mult=joker_sell_value(state,card) end
            if card.key=='j_bull' then chips=math.max(0,num(state.dollars))*num(a.extra,2) end
            if card.key=='j_bootstraps' then mult=math.floor(math.max(0,num(state.dollars))/5)*num(extra.mult,2) end
            strengths[i]=14*math.log(1+mult/4)+12*math.log(1+chips/40)+30*math.log(factor)
            strengths[i]=strengths[i]*commitment_factor(state,card)
            value=value+strengths[i]
            if Strategy.synergies then
                local synergy=Strategy.synergies.forecast(state,card)
                if #(synergy.existing or {})>0 then value=value+num(synergy.bonus) end
            end
        end
        total=total+value
    end
    for i,card in ipairs(state.jokers) do
        if not expired(card) and (card.key=='j_blueprint' or card.key=='j_brainstorm') then
            local best=0
            for j,other in ipairs(state.jokers) do
                if i~=j and other.blueprint_compat~=false then best=math.max(best,strengths[j] or 0) end
            end
            total=total+best*0.65
        end
    end
    if engine.mult>0 and engine.chips>0 then total=total+24 end
    if engine.mult>0 and engine.xmult>0 then total=total+36 end
    -- A Joker sale can remove Perkeo copying or change the supported copy
    -- chain while every held consumable remains in place. Count the complete
    -- inventory at both replacement endpoints, including Negative copies and
    -- Observatory. The sequence API keeps its Joker-only value below because
    -- that planner already adds the same inventory utility separately.
    if include_inventory then total=total+inventory_value(state) end
    return total
end

local function replacement_sale_plan(snapshot,direct,choose)
    if jokerless(snapshot) or modifiers(snapshot).all_eternal or
        #(snapshot.jokers or {})<num(snapshot.joker_limit,5) then return end
    local stats=deck_stats(snapshot)
    local before=replacement_build_value(snapshot,stats,true)
    local best
    for index,sold in ipairs(snapshot.jokers or {}) do
        local _,_,known=joker_value(snapshot,sold,stats,components(snapshot))
        -- Unknown effects are preserved; Diet Cola is a known non-scoring sale
        -- resource. Eggs retain their specialized Omelette economy policy.
        if not ability(sold).eternal and (known or expired(sold) or sold.key=='j_diet_cola') and
            not (omelette(snapshot) and sold.key=='j_egg') then
            local state=after_joker_sale(snapshot,index)
            local candidate=state and choose(state,deck_stats(state),components(state))
            if candidate and kind(candidate.card)=='joker' and candidate.known and candidate.score>=26 and
                not capacity(snapshot,candidate.card,snapshot.phase=='pack') then
                local after=after_joker_purchase(state,candidate.card)
                local cost=snapshot.phase=='shop' and num(candidate.card.cost) or 0
                local gain=replacement_build_value(after,deck_stats(after),true)-before
                local adjustment,evidence=shop_score_evidence(snapshot,after,candidate.card,true)
                local merit=gain-purchase_penalty(state,cost,candidate.card,after,evidence and evidence.after_readiness)-6
                if evidence then
                    merit=merit+adjustment
                    if evidence.ratio<0.85 or survival_dominated(evidence) then merit=-math.huge end
                end
                if merit>=26 and (not direct or direct.score<26 or merit>direct.score) and
                    (not best or merit>best.score) then
                    best={score=merit,index=index,sold=sold,purchase=candidate,gain=gain,
                        remaining_cash=after.dollars,scoring_evidence=evidence}
                end
            end
        end
    end
    return best
end

local function replacement_sale_advice(snapshot,sale)
    local purchase=sale.purchase; local verb=snapshot.phase=='pack' and 'choose' or 'buy'
    local lines={'Then '..verb..' '..name(purchase.card)..(snapshot.phase=='shop' and ' ($'..num(purchase.card.cost)..')' or '')..'.',
        purchase.reason,
        'The resulting Joker row has a substantial estimated improvement after retained synergies, current scaling, and spending are considered.',
        'Sell only this Joker, then refresh advice before taking the next action.'}
    if expired(sale.sold) then lines[#lines+1]='The replaced perishable Joker has no rounds left.' end
    if ability(sale.sold).rental then lines[#lines+1]='Selling it also removes its $3 per-round rental charge.' end
    if sale.sold.key=='j_credit_card' then lines[#lines+1]='Affordability is checked after removing this Credit Card\'s borrowing allowance.' end
    if sale.sold.key=='j_diet_cola' then lines[#lines+1]='Selling Diet Cola also grants a Double Tag; no future tag payout is counted as purchase cash.' end
    if has(snapshot,'j_campfire') and sale.sold.key~='j_campfire' then lines[#lines+1]='The retained Campfire grows from this sale.' end
    if sale.scoring_evidence then lines[#lines+1]=sale.scoring_evidence.reason end
    if commitment(snapshot) then lines[#lines+1]='Prepare the retained row before the slot lock; this replacement is already visible and affordable after the one sale.' end
    return {title='Sell '..name(sale.sold)..' #'..sale.index..' ($'..num(sale.sold.sell_cost)..')',lines=lines,warnings={},
        forecast=purchase.forecast,action={kind='sell',area='jokers',index=sale.index,
            followup={kind=verb,area=purchase.area or 'pack_cards',index=purchase.index}},
        replacement={utility_gain=sale.gain,cash_after_purchase=sale.remaining_cash}}
end

local function temperance_before_spending(snapshot, best, sale)
    if not omelette(snapshot) then return end
    local gain = math.min(50, joker_sell_value(snapshot))
    if gain <= 0 then return end
    for index, card in ipairs(snapshot.consumeables or {}) do
        if card.key == 'c_temperance' then
            local funded = {}
            for key, value in pairs(snapshot) do funded[key] = value end
            funded.dollars = num(snapshot.dollars) + gain
            funded.consumeables = {}
            for i, owned in ipairs(snapshot.consumeables or {}) do
                if i ~= index then funded.consumeables[#funded.consumeables + 1] = owned end
            end
            if edition(card,'negative') then funded.consumable_limit=math.max(0,num(snapshot.consumable_limit)-1) end
            local purchase = snapshot.phase == 'shop' and best_shop_purchase(funded, deck_stats(funded), components(funded))
            local improves = purchase and purchase.score >= 26 and (not best or purchase.score > best.score)
            local loss,_,last=preservation_cost(snapshot,funded,index)
            if not last and loss<=gain*2 and (sale or gain >= 50 or improves) then
                return {title='Use Temperance (+$' .. tostring(gain) .. ')',
                    lines={'Collect the current Joker sell value without selling any Joker.',
                        sale and 'Use it before selling an Egg so the Egg still contributes to the payout; then refresh advice.' or
                            'Refresh advice after the payout before spending or selling an Egg.'}, warnings={},
                    action={kind='use', area='consumeables', index=index}}
            end
        end
    end
end

local function shop_advice(snapshot, stats, engine)
    local context=snapshot._shop_scoring
    local readiness=context and context.readiness and context:readiness(snapshot)
    snapshot._readiness=readiness
    local best,planet_comparison = best_shop_purchase(snapshot, stats, engine,true)
    local sale = egg_sale_plan(snapshot, best, best_shop_purchase)
    local temperance = temperance_before_spending(snapshot, best, sale)
    if temperance then return temperance end
    if sale then return sale_advice(snapshot, sale) end
    local replacement=replacement_sale_plan(snapshot,best,best_shop_purchase)
    if replacement then return replacement_sale_advice(snapshot,replacement) end
    local result = {title='Leave the shop and save your money', lines={}, warnings={}, action={kind='leave_shop'}}
    result.shop_planet_dominance=planet_comparison
    if context and context.survival_dominated_actions then result.survival_rejections=context.survival_dominated_actions end
    if best and best.score >= 26 then
        local verb = best.area == 'shop_booster' and 'Open ' or best.area == 'shop_vouchers' and 'Redeem ' or 'Buy '
        result.title = verb .. name(best.card) .. ' ($' .. tostring(num(best.card.cost)) .. ')'
        result.lines[1] = best.reason
        result.action = {kind=best.area == 'shop_booster' and 'open' or 'buy', area=best.area, index=best.index}
        result.forecast = best.forecast
        result.scoring_evidence=best.scoring_evidence
        result.shop_planet_commitment=best.planet_commitment
        if best.known == false then result.warnings[#result.warnings + 1] = 'This Joker has only a generic strategic rating.' end
        if num(snapshot.dollars) - num(best.card.cost) < 0 then
            result.warnings[#result.warnings + 1] = 'This purchase uses Credit Card debt; future income must repay it.'
        end
    else
        result.lines[1] = 'No affordable upgrade clearly beats its cash and slot cost in this heuristic.'
        local reroll = num(snapshot.reroll_cost, num(snapshot.current_round and snapshot.current_round.reroll_cost, 5))
        if reroll == 0 then
            result.title = 'Use the free shop reroll'
            result.action = {kind='reroll'}
            result.lines[1] = 'The current choices are weak or unusable; a free shop refresh has no cash cost.'
        elseif Strategy.paid_reroll then
            local scoring=snapshot._shop_scoring and snapshot._shop_scoring:compare(snapshot,snapshot)
            local weak=engine.mult==0 or engine.chips==0 or num(snapshot.ante,1)>=3 and engine.xmult==0
            if readiness and readiness.supported then
                weak=readiness.status~='sampled_safe'
            end
            if weak then
                local rating=copy_table(snapshot)
                rating.shop_forecast,rating._shop_scoring=nil,nil
                rating.shop_jokers,rating.pack_cards={},{}
                local weakest_filler
                for _,owned in ipairs(snapshot.jokers or {}) do
                    local a=ability(owned)
                    local expendable=owned.key=='j_egg' and not has(snapshot,'j_swashbuckler') or owned.key=='j_joker' or
                        a.perishable and num(a.perish_tally,5)<=0 or
                        owned.key=='j_popcorn' and num(a.mult)<=4 or
                        owned.key=='j_ice_cream' and num(type(a.extra)=='table' and a.extra.chips,100)<=20
                    if expendable and not a.eternal and not modifiers(snapshot).all_eternal and not edition(owned,'negative') then
                        local value=card_value(rating,owned,stats,engine)
                        weakest_filler=math.min(weakest_filler or math.huge,value)
                    end
                end
                local plan=Strategy.paid_reroll.suggest(snapshot,function(entry,price)
                    local candidate=copy_table(entry);candidate.cost=price
                    local score,_,known=card_value(rating,candidate,stats,engine)
                    if not known or score<55 or not (flat_mult[entry.key] or flat_chips[entry.key] or xmult[entry.key] or
                        entry.key=='j_blueprint' or entry.key=='j_brainstorm' or entry.key=='j_photograph' or entry.key=='j_hanging_chad') then return false end
                    if #(snapshot.jokers or {})<num(snapshot.joker_limit,5) then return true end
                    return weakest_filler~=nil and score>=weakest_filler+24
                end,scoring)
                if plan then result=plan end
            end
        elseif #(snapshot.jokers or {}) == 0 and not jokerless(snapshot) and num(snapshot.dollars) >= reroll + 8 then
            result.title = 'Reroll the shop once ($' .. tostring(reroll) .. ')'
            result.action = {kind='reroll'}
            result.lines[1] = 'You still need a scoring Joker; keep at least $8 to buy one and reassess after the reroll.'
        end
        if #(snapshot.jokers or {}) >= num(snapshot.joker_limit, 5) and not jokerless(snapshot) then
            result.lines[#result.lines + 1] = omelette(snapshot) and
                'Keep the Eggs growing until a useful replacement is visible; selling now loses future value.' or
                'Joker slots are full; compare a sellable weak Joker before replacing it.'
        end
    end
    if not no_interest(snapshot) and not modifiers(snapshot).minus_hand_size_per_X_dollar and num(snapshot.dollars) < num(snapshot.interest_cap, 25) then
        result.lines[#result.lines + 1] = 'Build toward $' .. tostring(num(snapshot.interest_cap, 25)) .. ' for maximum interest, once survival is covered.'
    end
    return result
end

-- Pack consumables are used immediately, so a usable recommendation must include
-- its actual hand targets. Rank complete legal target sets by deck utility;
-- never call live use/legality callbacks or consume random numbers here.
local pack_targets = {
    c_magician={'enhance','m_lucky',2}, c_empress={'enhance','m_mult',2},
    c_heirophant={'enhance','m_bonus',2}, c_lovers={'enhance','m_wild',1},
    c_chariot={'enhance','m_steel',1}, c_justice={'enhance','m_glass',1},
    c_devil={'enhance','m_gold',1}, c_tower={'enhance','m_stone',1},
    c_star={'suit','Diamonds',3}, c_moon={'suit','Clubs',3},
    c_sun={'suit','Hearts',3}, c_world={'suit','Spades',3},
    c_strength={'strength',nil,2}, c_hanged_man={'remove',nil,2},
    c_death={'death',nil,2}, c_aura={'aura',nil,1},
    c_talisman={'seal','Gold',1}, c_deja_vu={'seal','Red',1},
    c_trance={'seal','Blue',1}, c_medium={'seal','Purple',1}, c_cryptid={'copy',nil,1},
}
local function suit_count(snapshot,stats,suit)
    local count=(stats.suits[suit] or 0)
    if has(snapshot,'j_smeared') then
        local other=({Hearts='Diamonds',Diamonds='Hearts',Clubs='Spades',Spades='Clubs'})[suit]
        count=count+(stats.suits[other] or 0)
    end
    return count
end
local function card_matches_suit(snapshot,card,wanted)
    if card.enhancement=='m_stone' then return false end
    if card.enhancement=='m_wild' then return true end
    if card.suit==wanted then return true end
    if has(snapshot,'j_smeared') then
        return ({Hearts='Diamonds',Diamonds='Hearts',Clubs='Spades',Spades='Clubs'})[card.suit]==wanted
    end
    return false
end
local function target_value(snapshot, card, stats)
    local value = playing_value(snapshot, card, stats)
    local rank = num(card.rank, num(card.base and card.base.id))
    local stone = card.enhancement == 'm_stone'
    if not stone then
        value = value + (rank == 14 and 11 or math.min(rank,10)) * 0.3
        local focus = favored_hand(snapshot)
        if focus ~= 'Straight' and focus ~= 'Straight Flush' and focus ~= 'Flush' then
            value = value + (stats.ranks[rank] or 0) * 1.5
        end
        if focus == 'Flush' or focus == 'Straight Flush' then
            value = value + suit_count(snapshot,stats,card.suit) * 1.5
        end
        for _,j in ipairs(snapshot.jokers or {}) do
            if not j.debuff then
                local wanted=suit_jokers[j.key]
                if j.key=='j_ancient' then wanted=((snapshot.current_round or {}).ancient_card or {}).suit end
                if wanted and card_matches_suit(snapshot,card,wanted) then value=value+(j.key=='j_ancient' and 18 or 12) end
            end
        end
        if rank == 13 and has(snapshot,'j_baron') then value = value + 30 end
        if rank == 2 and has(snapshot,'j_wee') then value = value + 30 end
        if rank == 14 and has(snapshot,'j_scholar') then value = value + 18 end
        if rank <= 5 and rank >= 2 and has(snapshot,'j_hack') then value = value + 16 end
        if ({[2]=true,[3]=true,[5]=true,[8]=true,[14]=true})[rank] and has(snapshot,'j_fibonacci') then value = value + 16 end
        if rank >= 11 and rank <= 13 then
            if has(snapshot,'j_photograph') or has(snapshot,'j_sock_and_buskin') then value = value + 18 end
            if has(snapshot,'j_ride_the_bus') then value = value - 20 end
        end
    end
    -- Generic seal values alone tie Red with Blue/Purple. Retriggering a held
    -- Steel King or a scoring Glass/Photograph card is a different opportunity.
    if card.seal=='Red' then
        if card.enhancement=='m_steel' or card.enhancement=='m_glass' then value=value+18 end
        if card.enhancement=='m_gold' then value=value+8 end
        if not stone and rank==13 and has(snapshot,'j_baron') then value=value+22 end
        if not stone and rank==2 and has(snapshot,'j_wee') then value=value+14 end
        if not stone and rank==14 and has(snapshot,'j_scholar') then value=value+10 end
        if not stone and (rank>=11 and rank<=13 or has(snapshot,'j_pareidolia')) and has(snapshot,'j_photograph') then value=value+18 end
    end
    return value
end

local function development_gain(before,after,targets,profile)
    profile=profile or build_profile(before)
    if profile.horizon<=0 then return 0 end
    local gain=0
    for _,index in ipairs(targets or {}) do
        local old,new=before.hand[index],after.hand[index]
        if old and new then
            local delta=target_value(before,new,profile.stats)-target_value(before,old,profile.stats)
            if old.enhancement~=new.enhancement or old.seal~=new.seal then
                delta=delta*participation(before,new,profile)
            end
            if profile.rank then
                delta=delta+24*((num(new.rank,num((new.base or {}).id))==profile.rank and 1 or 0)-
                    (num(old.rank,num((old.base or {}).id))==profile.rank and 1 or 0))
            end
            gain=gain+delta
        end
    end
    local old=(before.hands or {})[profile.hand] or {}
    local new=(after.hands or {})[profile.hand] or {}
    if num(new.level,1)>num(old.level,1) then
        local chips,mult=math.max(1,num(old.chips,10)),math.max(1,num(old.mult,2))
        gain=gain+50*(math.max(1,num(new.chips,chips))/chips*math.max(1,num(new.mult,mult))/mult-1)
    end
    return gain*math.min(1,profile.horizon/3)
end
local function suit_batch_targets(snapshot,hand,replacement,minimum,maximum,stats)
    local candidates={}
    for i,c in ipairs(hand) do
        if c.suit and c.suit~=replacement and c.enhancement~='m_stone' and c.enhancement~='m_wild' then candidates[#candidates+1]=i end
    end
    local focus=favored_hand(snapshot)
    local function concentration(counts)
        local total=0
        if has(snapshot,'j_smeared') then
            for _,group in ipairs({{'Hearts','Diamonds'},{'Spades','Clubs'}}) do
                local n=(counts[group[1]] or 0)+(counts[group[2]] or 0); total=total+n*(n-1)
            end
        else for _,n in pairs(counts) do total=total+n*(n-1) end end
        return total
    end
    local initial=concentration(stats.suits)
    local chosen,best,best_gain={},nil,0
    local function visit(start)
        if #chosen>=minimum then
            local counts={}; for suit,n in pairs(stats.suits) do counts[suit]=n end
            local gain=0
            for _,index in ipairs(chosen) do
                local c=hand[index]; local changed={}; for k,v in pairs(c) do changed[k]=v end
                changed.suit=replacement
                gain=gain+target_value(snapshot,changed,stats)-target_value(snapshot,c,stats)
                counts[c.suit]=math.max(0,(counts[c.suit] or 0)-1)
                counts[replacement]=(counts[replacement] or 0)+1
            end
            if focus=='Flush' or focus=='Straight Flush' then
                gain=gain+6*(concentration(counts)-initial)/math.max(1,stats.size)
            end
            if gain>best_gain then best_gain=gain; best={}; for i,v in ipairs(chosen) do best[i]=v end end
        end
        if #chosen>=maximum then return end
        for i=start,#candidates do chosen[#chosen+1]=candidates[i]; visit(i+1); chosen[#chosen]=nil end
    end
    visit(1)
    return best,'These targets improve the suit group together and account for current suit-dependent Jokers.'
end
local function choose_pack_targets(snapshot, card, stats)
    local development=Strategy.deck_development
    if development and development.supports(card.key) then
        return development.targets(snapshot,card,build_profile(snapshot,stats),nil,Strategy),
            'Targets account for deck concentration, permanent Joker growth and scarce card resources.'
    end
    local definition = pack_targets[card.key]
    if not definition then
        -- Unknown targeted effects cannot be made executable by guessing targets.
        if (ability(card).consumeable or {}).max_highlighted then return nil end
        return {}
    end
    local hand, effect, replacement = snapshot.hand or {}, definition[1], definition[2]
    local profile=build_profile(snapshot,stats)
    local config = ability(card).consumeable or {}
    local maximum = math.min(definition[3], num(config.mod_num, num(config.max_highlighted,definition[3])))
    local minimum = num(config.min_highlighted, effect == 'death' and 2 or 1)
    if #hand < minimum or maximum < minimum then return nil end
    if effect == 'death' then
        local best, gain = nil, 0
        for left=1,#hand-1 do for right=left+1,#hand do
            local projected={hand={}};projected.hand[left]=hand[right]
            local delta = development_gain(snapshot,projected,{left},profile)
            if delta > gain then best,gain={left,right},delta end
        end end
        if best then return best, 'Death copies the selected RIGHT card onto the LEFT card.' end
        local source,target,highest,lowest
        for i,c in ipairs(hand) do
            local value=target_value(snapshot,c,stats)
            if highest==nil or value>highest then source,highest=i,value end
            if lowest==nil or value<lowest then target,lowest=i,value end
        end
        if source and target and highest>lowest and source<#hand then
            local order={}
            for i=1,#hand do if i~=source then order[#order+1]=i end end
            order[#order+1]=source
            return {},'Move current card #'..source..' to the far right so Death can copy it onto a weaker card.',order
        end
        return nil
    end
    if effect=='suit' then return suit_batch_targets(snapshot,hand,replacement,minimum,maximum,stats) end
    local candidates = {}
    for index, held in ipairs(hand) do
        local original = target_value(snapshot,held,stats)
        local changed = {}; for k,v in pairs(held) do changed[k]=v end
        local delta
        if effect == 'remove' then delta = 14-original
        elseif effect == 'copy' then delta = original
        elseif effect == 'aura' then if not held.edition then delta = 20+original*0.05 end
        elseif effect == 'seal' then
            changed.seal=replacement
            delta = target_value(snapshot,changed,stats)-original
            -- Purple seals need discards; prefer expendable cards over core scorers.
            if replacement=='Purple' and delta>0 then delta=delta-original*0.1 end
        elseif effect == 'enhance' then
            changed.enhancement=replacement
            delta = (target_value(snapshot,changed,stats)-original)*participation(snapshot,held,profile)
        elseif effect == 'strength' then
            local rank=num(held.rank,num(held.base and held.base.id))
            changed.rank=rank==14 and 2 or rank+1
            delta=target_value(snapshot,changed,stats)-original
            if profile.rank then delta=delta+24*((changed.rank==profile.rank and 1 or 0)-(rank==profile.rank and 1 or 0)) end
        end
        if delta and delta>0 then candidates[#candidates+1]={index=index,value=delta} end
    end
    table.sort(candidates,function(a,b) return a.value>b.value or a.value==b.value and a.index<b.index end)
    local targets={}
    for i=1,math.min(maximum,#candidates) do targets[i]=candidates[i].index end
    if #targets<minimum then return nil end
    table.sort(targets)
    return targets, 'Targets favor the current deck and Jokers while preserving existing upgrades.'
end

local function planet_finishing_worlds(evidence)
    if not evidence or not evidence.complete_finishing or evidence.uncertain or evidence.incomplete or
        evidence.samples~=4 or type(evidence.before_target)~='number' or evidence.before_target<=0 or
        evidence.before_target>=math.huge or evidence.before_target~=evidence.after_target or
        evidence.blind=='bl_arm' then return end
    for _,field in ipairs({'before_finishing','after_finishing'}) do
        local finish=evidence[field]
        if not finish or not finish.complete or not finish.supported or not finish.known_mechanics or
            finish.samples~=4 or not finish.selected or type(finish.selected.worlds)~='table' or
            #finish.selected.worlds~=4 then return end
        for _,world in ipairs(finish.selected.worlds) do
            for _,key in ipairs({'progress','hands_used','discards_used','dollars_after','population_loss','finish_reward'}) do
                local value=world[key]
                if type(value)~='number' or value~=value or math.abs(value)==math.huge then return end
            end
            if world.progress<0 or world.progress>1 or world.hands_used<0 or world.discards_used<0 or world.population_loss<0 then return end
        end
    end
    return evidence.after_finishing.selected.worlds
end

-- Equal played/level histories should not make table order a permanent hand
-- commitment. Reuse the already completed paid-use comparisons to restore at
-- most the existing main-hand prior, without changing any unopened pack value.
planet_shop_commitment=function(snapshot,offers)
    if #(snapshot.jokers or {})>0 or not Strategy.liquidity or not Strategy.liquidity.estimate or
        (snapshot.used_vouchers or {}).v_observatory or (snapshot.vouchers or {}).v_observatory or
        (snapshot._shop_scoring or {}).truncated or #offers>12 then return end
    local preferred=favored_hand(snapshot)
    local prior=(snapshot.hands or {})[preferred]
    local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
    if not prior or not finite(prior.played) or not finite(prior.level) or prior.played<=0 or prior.level<1 then return end
    local family,baseline,target={},nil,nil
    for _,offer in ipairs(offers) do
        local candidate=offer.candidate
        local hand=hand_type(candidate.card)
        local history=(snapshot.hands or {})[hand]
        if hand~=preferred and ability(candidate.card).set=='Planet' and history and
            history.played==prior.played and history.level==prior.level then
            local evidence=candidate.scoring_evidence
            local worlds=planet_finishing_worlds(evidence)
            -- Complete the admitted tied family before admitting any credit;
            -- later unsupported offers must not leave a source-order winner.
            if not worlds or not evidence.planet_use or not offer.after then return end
            if target and target~=evidence.before_target then return end
            target=evidence.before_target
            local before=evidence.before_finishing.selected.worlds
            if baseline then
                for i=1,4 do
                    for _,key in ipairs({'progress','hands_used','discards_used','dollars_after','population_loss','finish_reward'}) do
                        if baseline[i][key]~=before[i][key] then return end
                    end
                end
            else baseline=before end
            family[#family+1]=offer
        end
    end
    for _,offer in ipairs(family) do
        local candidate,after=offer.candidate,offer.after
        local cost=candidate.card.cost
        local evidence=candidate.scoring_evidence
        local funded=finite(cost) and cost>=0 and finite(after.dollars) and
            after.dollars==num(snapshot.dollars)-cost and
            #(after.consumeables or {})==#(snapshot.consumeables or {}) and
            num(after.consumable_limit,2)==num(snapshot.consumable_limit,2)
        local allowance=funded and Strategy.liquidity.estimate(after,evidence.after_readiness)
        funded=funded and allowance and finite(allowance.shortfall) and allowance.shortfall==0
        local strict,safe=false,not not funded
        local before_progress,after_progress=0,0
        for i=1,4 do
            local before=evidence.before_finishing.selected.worlds[i]
            local changed=evidence.after_finishing.selected.worlds[i]
            if changed.progress<before.progress or changed.hands_used>before.hands_used or
                changed.discards_used>before.discards_used or changed.population_loss>before.population_loss or
                changed.finish_reward<before.finish_reward or not finite(cost) or
                changed.dollars_after<before.dollars_after-cost then safe=false end
            strict=strict or changed.progress>before.progress+0.000001
            before_progress=before_progress+before.progress/4
            after_progress=after_progress+changed.progress/4
        end
        if offer.eligible and safe and strict then
            local old_score=candidate.score
            candidate.score=candidate.score+(69-22)
            candidate.planet_commitment={complete=true,hand=hand_type(candidate.card),history_tied_with=preferred,
                played=prior.played,level=prior.level,credit=69-22,previous_score=old_score,selected_score=candidate.score,
                cost=cost,cash_after_purchase=after.dollars,reserve=allowance.reserve,
                before_mean_progress=before_progress,after_mean_progress=after_progress,
                compared=#family,samples=4,
                scope='Equal-history priority only: paid use improves fixed-policy progress in common worlds without worse sampled hands, discards, population, rewards or cash beyond its purchase price.'}
            candidate.reason=candidate.reason..' Its hand ties the leading play history; complete paid-use evidence earns the same development priority while preserving the cash reserve.'
        end
    end
end

-- Future growth counters and permanent card/hand development are not retained
-- by the finishing diagnostic. Only these unchanged vanilla scoring effects
-- may use its limited dominance certificate. Other rows keep their existing
-- strategic preference, including inactive growth cards that can return later.
local planet_static_jokers={}
for _,key in ipairs({'j_joker','j_greedy_joker','j_lusty_joker','j_wrathful_joker','j_gluttenous_joker',
    'j_jolly','j_zany','j_mad','j_crazy','j_droll','j_sly','j_wily','j_clever','j_devious','j_crafty',
    'j_half','j_banner','j_mystic_summit','j_raised_fist','j_fibonacci','j_scary_face','j_abstract',
    'j_even_steven','j_odd_todd','j_scholar','j_blackboard','j_hack','j_baron','j_photograph',
    'j_arrowhead','j_onyx_agate','j_stuntman','j_juggler','j_sock_and_buskin','j_hanging_chad',
    'j_smiley','j_flower_pot','j_duo','j_trio','j_family','j_order','j_tribe','j_stencil',
    'j_mime','j_four_fingers','j_shortcut','j_smeared','j_splash','j_pareidolia','j_shoot_the_moon',
    'j_acrobat','j_triboulet','j_bull','j_bootstraps'}) do planet_static_jokers[key]=true end

-- A one-off past hand is a weak reason to develop a hand the present deck does
-- not realize. Prefer a revealed Planet only when its complete fixed policy is
-- at least as good in every paired world, including resources and population.
-- The comparison consumes existing evidence; it adds no worlds or score calls.
local function planet_pack_dominance(snapshot,candidates,diagnostics)
    if not diagnostics or diagnostics.incomplete or #candidates>12 or
        (snapshot._shop_scoring or {}).truncated then return end
    -- Future copying and Observatory inventory tradeoffs are outside the
    -- bounded next-blind certificate. Preserve their existing whole-inventory
    -- values instead of claiming four worlds establish a lifetime dominance.
    if perkeo_effects(snapshot)>0 or (snapshot.used_vouchers or {}).v_observatory or
        (snapshot.vouchers or {}).v_observatory then return end
    for _,joker in ipairs(snapshot.jokers or {}) do if not planet_static_jokers[joker.key] then return end end
    local planets={}
    for _,candidate in ipairs(candidates) do
        if candidate.score>0 and hand_type(candidate.card) and ability(candidate.card).set=='Planet' then
            local worlds=planet_finishing_worlds(candidate.scoring_evidence)
            -- Require the whole revealed Planet family before overriding its
            -- strategic prior, including candidates later in source order.
            if not worlds then return end
            planets[#planets+1]={candidate=candidate,worlds=worlds}
        end
    end
    if #planets<2 then return end
    local function dominates(left,right)
        local le,re=left.candidate.scoring_evidence,right.candidate.scoring_evidence
        if le.before_target~=re.before_target then return false end
        local strict=false
        for i=1,4 do
            local lb,rb=le.before_finishing.selected.worlds[i],re.before_finishing.selected.worlds[i]
            local l,r=left.worlds[i],right.worlds[i]
            for _,key in ipairs({'progress','hands_used','discards_used','dollars_after','population_loss','finish_reward'}) do
                if lb[key]~=rb[key] then return false end
            end
            if l.progress<r.progress or l.hands_used>r.hands_used or l.discards_used>r.discards_used or
                l.dollars_after<r.dollars_after or l.population_loss>r.population_loss or l.finish_reward<r.finish_reward then return false end
            strict=strict or l.progress>r.progress+0.000001
        end
        return strict
    end
    local records={}
    for _,right in ipairs(planets) do
        for _,left in ipairs(planets) do
            if left~=right and dominates(left,right) then
                right.candidate.planet_dominated_by=left.candidate.index
                records[#records+1]={index=right.candidate.index,key=right.candidate.card.key,
                    preferred_index=left.candidate.index,preferred_key=left.candidate.card.key}
                break
            end
        end
    end
    if #records>0 then
        diagnostics.planet_dominance={complete=true,rejections=records,
            scope='Complete fixed policies in four common worlds; greater capped progress without worse actions, cash, population or finishing rewards. No win-rate claim.'}
        for _,offer in ipairs(diagnostics.offers) do
            for _,record in ipairs(records) do if offer.index==record.index then offer.planet_dominated_by=record.preferred_index end end
        end
    end
end

-- Shop Planets pay their actual price and use the existing exact use/retention
-- transition before comparison. A past rare hand must not defeat a better
-- affordable visible development merely because the choice is outside a pack.
-- Reuse the complete four-world certificate, including endpoint cash; no new
-- score call or assumption about an unopened pack enters this pass.
planet_shop_dominance=function(snapshot,candidates)
    local original=candidates[1]
    if not original or original.area~='shop_jokers' or not hand_type(original.card) or
        ability(original.card).set~='Planet' then return end
    local diagnostics={offers={}}
    for _,candidate in ipairs(candidates) do
        diagnostics.offers[#diagnostics.offers+1]={index=candidate.index,area=candidate.area,
            key=candidate.card.key,score=candidate.score}
    end
    planet_pack_dominance(snapshot,candidates,diagnostics)
    if not original.planet_dominated_by then return end
    for _,candidate in ipairs(candidates) do
        -- Preserve the ordinary purchase threshold. Dominance alone does not
        -- promote a purchase that still fails the current cash/slot valuation.
        if not candidate.planet_dominated_by and candidate.score>=26 then
            diagnostics.planet_dominance.previous_score=original.score
            diagnostics.planet_dominance.selected_score=candidate.score
            return candidate,diagnostics.planet_dominance
        end
    end
end

local function pack_target_comparison(snapshot,card,targets,evidence,stats)
    local definition=pack_targets[card.key]
    local hand=snapshot.hand or {}
    if not definition or definition[1]~='enhance' or definition[3]~=1 or
        not targets or #targets~=1 or #hand<2 or #hand>8 or #(snapshot.jokers or {})>0 or
        (snapshot.used_vouchers or {}).v_observatory or (snapshot.vouchers or {}).v_observatory or
        not planet_finishing_worlds(evidence) then return end
    -- This slice compares a whole visible, plain target family. Existing seals,
    -- editions and enhancements retain the original permanent-development path.
    for _,held in ipairs(hand) do
        if held.face_down or held.facing=='back' or held.unknown or held.debuff or held.seal or held.edition or
            held.enhancement and held.enhancement~='c_base' or held.key~='c_base' then return end
    end
    local profile=build_profile(snapshot,stats)
    local function merit(held)
        local changed=copy_table(held);changed.enhancement=definition[2]
        return (target_value(snapshot,changed,stats)-target_value(snapshot,held,stats))*participation(snapshot,held,profile)
    end
    local original=targets[1]
    if not hand[original] then return end
    local original_merit=merit(hand[original])
    local diagnostics={complete=false,original_target=original,considered=0,target_count=#hand,targets={},
        scope='Complete visible single-enhancement targets in four common worlds; no lower permanent-development priority or worse sampled resources.'}
    local best={targets=targets,evidence=evidence,merit=original_merit}
    local function dominates(left,right)
        if left.before_target~=right.before_target then return false end
        local strict=false
        for i=1,4 do
            local a,b=left.after_finishing.selected.worlds[i],right.after_finishing.selected.worlds[i]
            local x,y=left.before_finishing.selected.worlds[i],right.before_finishing.selected.worlds[i]
            for _,key in ipairs({'progress','hands_used','discards_used','dollars_after','population_loss','finish_reward'}) do
                if x[key]~=y[key] then return false end
            end
            if a.progress<b.progress or a.hands_used>b.hands_used or a.discards_used>b.discards_used or
                a.dollars_after<b.dollars_after or a.population_loss>b.population_loss or a.finish_reward<b.finish_reward then return false end
            strict=strict or a.progress>b.progress+0.000001
        end
        return strict
    end
    for index,held in ipairs(hand) do
        local compared,transition=evidence,nil
        if index~=original then
            local after
            after,transition=Strategy.pack_scoring.project(snapshot,card,{index},nil,
                {strategy=Strategy,consumables=Strategy.consumables})
            compared=after and snapshot._shop_scoring:compare(snapshot,after)
        end
        local worlds=planet_finishing_worlds(compared)
        local priority=merit(held)
        local entry={index=index,complete=not not worlds,development_priority=priority,progress={}}
        diagnostics.targets[#diagnostics.targets+1]=entry
        diagnostics.considered=#diagnostics.targets
        if not worlds or snapshot._shop_scoring.truncated then
            diagnostics.reason='An alternate target lacks complete supported finishing evidence; keep the original target.'
            return nil,diagnostics
        end
        for i,world in ipairs(worlds) do entry.progress[i]=world.progress end
        if index~=original and priority>=original_merit and dominates(compared,evidence) and
            (best.targets==targets or num(compared.adjustment)>num(best.evidence.adjustment)) then
            best={targets={index},evidence=compared,transition=transition,merit=priority}
        end
    end
    diagnostics.complete=true;diagnostics.selected_target=best.targets[1]
    if best.targets~=targets then return best,diagnostics end
    return nil,diagnostics
end

local function best_pack_choice(snapshot, stats, engine, diagnostics)
    local best,candidates=nil,{}
    for index, card in ipairs(snapshot.pack_cards or {}) do
        local entry
        if diagnostics then
            entry={index=index,card=card,selection_cost=0,legal=capacity(snapshot,card,true)}
            diagnostics.offers[#diagnostics.offers+1]=entry
        end
        if capacity(snapshot, card, true) then
            local score, reason, known, forecast = card_value(snapshot, card, stats, engine)
            -- Targeting Tarot/Spectral cards requires a hand in the pack.
            local category = kind(card)
            local target = ability(card).consumeable
            local targets, target_reason, hand_order, evidence
            if category=='joker' and snapshot._shop_scoring then
                local adjustment
                adjustment,evidence=shop_score_evidence(snapshot,after_joker_purchase(snapshot,card),card,true)
                if evidence then score=score+adjustment;reason=reason..' '..evidence.reason end
                if diagnostics then
                    diagnostics.comparisons[#diagnostics.comparisons+1]={index=index,kind='choose',
                        score=score,evidence=evidence,status=evidence and 'complete' or 'unavailable',
                        unavailable_reason=not evidence and snapshot._shop_scoring.unavailable_reason or nil}
                    if not evidence then
                        diagnostics.incomplete=true
                        diagnostics.incomplete_reason=diagnostics.incomplete_reason or snapshot._shop_scoring.unavailable_reason
                    end
                end
            end
            if category == 'consumable' then
                targets,target_reason,hand_order=choose_pack_targets(snapshot,card,stats)
                if not targets then score=0 end
                if type(target) == 'table' and target.max_highlighted and
                    #(snapshot.hand or {}) < num(target.min_highlighted, 1) then score = 0 end
                if card.key == 'c_death' and #(snapshot.hand or {}) < 2 then score = 0 end
                if card.key == 'c_aura' then
                    local eligible = false
                    for _, held in ipairs(snapshot.hand or {}) do if not held.edition then eligible = true end end
                    if not eligible then score = 0 end
                end
                if ({c_familiar=true,c_grim=true,c_incantation=true,c_immolate=true,c_sigil=true,c_ouija=true})[card.key]
                    and #(snapshot.hand or {}) <= 1 then score = 0 end
            end
            if category~='joker' and snapshot._shop_scoring and score>0 and Strategy.pack_scoring then
                local after,transition=Strategy.pack_scoring.project(snapshot,card,targets,hand_order,
                    {strategy=Strategy,consumables=Strategy.consumables})
                evidence=after and snapshot._shop_scoring:compare(snapshot,after)
                if after and evidence and not hand_order then
                    local alternative,target_diagnostics=pack_target_comparison(snapshot,card,targets,evidence,stats)
                    if entry then entry.target_comparison=target_diagnostics end
                    if alternative then
                        targets,evidence,transition=alternative.targets,alternative.evidence,alternative.transition
                        target_reason='A complete target comparison improves next-blind progress without a lower development priority or worse sampled resource costs.'
                    end
                end
                if evidence then
                    -- Keep the existing target/population safeguards and long-term
                    -- development value; add only bounded next-blind evidence.
                    score=score+num(evidence.adjustment)
                    reason=reason..' '..evidence.reason
                end
                if diagnostics then
                    diagnostics.comparisons[#diagnostics.comparisons+1]={index=index,kind='develop',score=score,
                        evidence=evidence,transition=after and transition or nil,
                        status=evidence and 'complete' or 'unavailable',
                        unavailable_reason=not evidence and (not after and transition or snapshot._shop_scoring.unavailable_reason) or nil}
                    if not evidence then
                        diagnostics.incomplete=true
                        diagnostics.incomplete_reason=not after and transition or snapshot._shop_scoring.unavailable_reason
                    end
                end
            end
            if entry then
                entry.score=score;entry.reason=reason;entry.known=known;entry.scoring_evidence=evidence
                if score>0 and evidence and not hand_order and (category~='consumable' or targets) then
                    entry.action={kind='choose',area='pack_cards',index=index,targets=copy_table(targets)}
                end
            end
            local candidate={score=score, reason=reason, card=card, index=index, known=known,forecast=forecast,
                targets=targets,target_reason=target_reason,hand_order=hand_order,scoring_evidence=evidence}
            candidates[#candidates+1]=candidate
            if not best or score>best.score then best=candidate end
        elseif entry then entry.reason='No legal direct selection with the current Joker capacity.' end
    end
    planet_pack_dominance(snapshot,candidates,diagnostics)
    if best and best.planet_dominated_by then
        best=nil
        for _,candidate in ipairs(candidates) do
            if not candidate.planet_dominated_by and (not best or candidate.score>best.score) then best=candidate end
        end
        if best then best.reason=best.reason..' A rejected Planet has weaker complete paired next-blind progress without a sampled resource advantage; its history-based rating does not decide this choice.' end
    end
    if Strategy.pack_survival then
        local selected,receipt=Strategy.pack_survival.choose(snapshot,candidates,best,diagnostics)
        if diagnostics then diagnostics.survival_priority=receipt end
        if selected then best=selected;best.reason=best.reason..' '..receipt.reason end
    end
    return best
end

local function pack_advice(snapshot, stats, engine)
    local diagnostics={offers={},comparisons={}}
    local function finish(result)
        diagnostics.complete=snapshot._shop_scoring~=nil and not diagnostics.incomplete and not snapshot._shop_scoring.truncated
        for _,offer in ipairs(diagnostics.offers) do
            if offer.legal and num(offer.score)>0 and not offer.scoring_evidence then diagnostics.complete=false end
        end
        diagnostics.selected_action=result.action
        result.pack_diagnostics=diagnostics
        return result
    end
    local best = best_pack_choice(snapshot, stats, engine, diagnostics)
    local buffoon=false
    for _,card in ipairs(snapshot.pack_cards or {}) do if kind(card)=='joker' then buffoon=true end end
    local sale,replacement
    if buffoon and not jokerless(snapshot) and not modifiers(snapshot).all_eternal and
        #(snapshot.jokers or {})>=num(snapshot.joker_limit,5) then
        local before=replacement_build_value(snapshot,stats,true)
        -- Compare every actual offer with each supported one-sale retained row.
        -- Selecting an incoming card first can miss a different best partner
        -- for the Joker being retained. No unseen pack card or future buy enters.
        for sold_index,sold in ipairs(snapshot.jokers or {}) do
            local _,_,known=joker_value(snapshot,sold,stats,engine)
            local legal=not ability(sold).eternal and not sold.pinned and not ability(sold).pinned and
                (known or expired(sold) or sold.key=='j_diet_cola')
            local state=legal and after_joker_sale(snapshot,sold_index)
            for index,card in ipairs(snapshot.pack_cards or {}) do
                if kind(card)=='joker' and not capacity(snapshot,card,true) then
                    local entry={kind='sell_then_choose',index=index,sold_index=sold_index,
                        legal=not not (state and capacity(state,card,true))}
                    diagnostics.comparisons[#diagnostics.comparisons+1]=entry
                    if entry.legal then
                        local score,reason,candidate_known,forecast=card_value(state,card,deck_stats(state),components(state))
                        local after=after_joker_purchase(state,card)
                        local adjustment,evidence=shop_score_evidence(snapshot,after,card,true)
                        entry.evidence=evidence
                        entry.status=evidence and 'complete' or snapshot._shop_scoring and 'unavailable' or 'strategic'
                        if snapshot._shop_scoring and not evidence then
                            entry.unavailable_reason=snapshot._shop_scoring.unavailable_reason
                            diagnostics.incomplete=true
                            diagnostics.incomplete_reason=diagnostics.incomplete_reason or entry.unavailable_reason
                        end
                        local gain=replacement_build_value(after,deck_stats(after),true)-before
                        local merit=gain-6+num(adjustment)
                        local egg=omelette(snapshot) and sold.key=='j_egg'
                        if egg then
                            local penalty=10
                            if has(snapshot,'j_swashbuckler') then
                                penalty=penalty+70*num(sold.sell_cost)/math.max(1,joker_sell_value(snapshot,has(snapshot,'j_swashbuckler')))
                            end
                            if edition(sold,'foil') then penalty=penalty+20 end
                            if edition(sold,'holo') then penalty=penalty+28 end
                            if edition(sold,'polychrome') then penalty=penalty+30 end
                            merit=score-penalty+num(adjustment)
                        end
                        local preserves_score=not evidence or evidence.ratio>=0.85
                        entry.score=merit;entry.utility_gain=gain;entry.cash_after_selection=after.dollars
                        entry.known=candidate_known;entry.preserves_score=preserves_score
                        if candidate_known and score>=26 and merit>=26 and preserves_score and
                            (not best or best.score<26 or merit>best.score) and
                            (not replacement or merit>replacement.score) then
                            local candidate={score=score,reason=reason,card=card,index=index,known=candidate_known,
                                forecast=forecast,scoring_evidence=evidence}
                            replacement={score=merit,index=sold_index,sold=sold,egg=egg and sold or nil,
                                purchase=candidate,gain=gain,remaining_cash=after.dollars,scoring_evidence=evidence}
                        end
                    else entry.status='blocked';entry.reason='The owned Joker cannot be safely sold or its sale does not free a legal slot.' end
                end
            end
        end
        if replacement and replacement.egg then sale=replacement;replacement=nil end
    elseif not buffoon then
        sale=egg_sale_plan(snapshot,best,best_pack_choice)
        replacement=replacement_sale_plan(snapshot,best,best_pack_choice)
    end
    local temperance = temperance_before_spending(snapshot, best, sale)
    if temperance then return finish(temperance) end
    if sale then return finish(sale_advice(snapshot, sale)) end
    if replacement then return finish(replacement_sale_advice(snapshot,replacement)) end
    if best and best.score > 0 then
        if best.hand_order then
            local labels={}; for _,index in ipairs(best.hand_order) do labels[#labels+1]='#'..index end
            return finish({title='Move the source card right before Death',
                lines={best.target_reason,'New left-to-right order using current card numbers: '..table.concat(labels,', ')..'.',
                    'Close the panel, drag the source card to the far right, then refresh advice. Select or use Death only after the new recommendation appears.'},
                warnings={},action={kind='reorder_hand',area='hand',order=best.hand_order}})
        end
        local lines={best.reason}
        if best.target_reason then lines[#lines+1]=best.target_reason end
        lines[#lines+1]='After each choice, refresh advice for the remaining options.'
        return finish({title='Choose ' .. name(best.card), lines=lines,
            warnings=best.known == false and {'This Joker has only a generic strategic rating.'} or {},
            action={kind='choose', area='pack_cards', index=best.index,targets=best.targets},forecast=best.forecast,
            scoring_evidence=best.scoring_evidence})
    end
    return finish({title='Skip the remaining pack', lines={'No usable option clearly improves this deck. Plain extra cards can weaken future draws.'}, warnings={},action={kind='skip_pack'}})
end

local function blind_advice(snapshot, engine)
    local states = snapshot.blind_states or {}
    local current = snapshot.blind_on_deck
    if current ~= 'Small' and current ~= 'Big' and current ~= 'Boss' then
        for _, blind in ipairs({'Small', 'Big', 'Boss'}) do
            if states[blind] == 'Select' then current = blind; break end
        end
    end
    current = current or 'Small'
    local plan=commitment(snapshot)
    if plan and num(snapshot.ante)==plan.lock and current=='Boss' then
        -- These known empty rental effects are harmful even without a promised
        -- replacement. Preserve editions, copied value, debt capacity and all
        -- unmodeled identities; useful ordinary filler is better than a hole.
        for index,card in ipairs(snapshot.jokers or {}) do
            local key,a=card.key,ability(card)
            local empty=expired(card) or key=='j_credit_card' and num(snapshot.dollars)>=0
                or key=='j_egg' and commitment_factor(snapshot,card)<0.2
                or key=='j_diet_cola'
            if a.rental and not a.eternal and empty and not card.edition and
                not has(snapshot,'j_swashbuckler') and not has(snapshot,'j_blueprint') and not has(snapshot,'j_brainstorm') then
                return {title='Sell '..name(card)..' before the Joker-slot lock',
                    lines={'This rental has no retained scoring or income role and would keep charging $3 each round.',
                        'No replacement or future shop outcome is assumed; refresh advice after this sale.'},warnings={},
                    action={kind='sell',area='jokers',index=index},commitment={lock=plan.lock}}
            end
        end
    end
    local result = {title='Play the ' .. current .. ' Blind', lines={}, warnings={},action={kind='select_blind',blind=current}}
    if current == 'Boss' then result.lines[1] = 'Prepare consumables and Joker order before selecting the boss.'; return result end
    result.lines[1] = 'Playing gives a shop visit, income, hand experience, and Joker growth.'
    local egg_growth = 0
    if omelette(snapshot) then
        for _, owned in ipairs(snapshot.jokers or {}) do
            if owned.key == 'j_egg' and not owned.debuff then egg_growth = egg_growth + num(ability(owned).extra, 3) end
        end
        result.lines[1] = 'Playing gives a shop visit, hand experience, and Joker growth; this challenge has no blind payout, unused-hand cash, or interest.'
        if egg_growth > 0 then result.lines[#result.lines + 1] = 'Completing this blind grows your Eggs by $' .. tostring(egg_growth) .. ' in total resale value; skipping forfeits that growth and this shop.' end
    end
    local tag = (snapshot.skip_tags or {})[current]
    if type(tag) == 'table' then tag = tag.key or tag.name end
    local special = has(snapshot, 'j_throwback') and 'Throwback gains X0.25 Mult from a skip.'
    if tag == 'tag_double' then
        result.lines[#result.lines + 1] = 'Double Tag pays later; it does not strengthen the next blind immediately.'
    elseif tag == 'tag_investment' and omelette(snapshot) and egg_growth > 0 then
        result.lines[#result.lines + 1] = 'Investment Tag pays $25 after the boss, but first compare the lost Egg growth and shop access; this policy keeps the played round.'
    elseif tag == 'tag_investment' and current == 'Small' and num(snapshot.ante, 1) == 1 and engine.scaling == 0 then
        result.lines[#result.lines+1] = 'Consider skipping for Investment Tag only after checking that the deck can clear Big and Boss without this shop. The tag pays $25 after the boss.'
        result.lines[#result.lines+1] = 'The next blind has not been simulated, so the current recommendation keeps this played round and its shop.'
    elseif (tag == 'tag_charm' or tag == 'tag_meteor') and jokerless(snapshot) and current == 'Small' then
        result.lines[#result.lines + 1] = 'The free pack is relevant to Jokerless; consider skipping only if the current deck can already clear the next blind.'
    end
    if special then result.lines[#result.lines + 1] = special end
    if challenge(snapshot) == 'c_fragile_1' then
        result.lines[#result.lines + 1] = 'Skipping conserves Glass cards, but sacrifices a shop. Consider it when the deck is running short.'
    end
    return result
end

local function consumable_tip(snapshot)
    for index, card in ipairs(snapshot.consumeables or {}) do
        local key, hand = card.key, hand_type(card)
        local after={};for k,v in pairs(snapshot) do after[k]=v end
        after.consumeables={};for i,c in ipairs(snapshot.consumeables or {}) do if i~=index then after.consumeables[#after.consumeables+1]=c end end
        local loss,reason,last=preservation_cost(snapshot,after,index)
        if last then return reason
        elseif key == 'c_hermit' and num(snapshot.dollars) >= 20 and loss<=40 then
            return 'Use The Hermit before spending: current cash already reaches its $20 payout cap.'
        elseif key == 'c_temperance' and #(snapshot.jokers or {}) > 0 then
            local value = 0
            for _, owned in ipairs(snapshot.jokers or {}) do value = value + num(owned.sell_cost) end
            if value >= 20 then return 'Temperance can generate $' .. tostring(math.min(50, value)) .. ' without selling your Jokers.' end
        elseif hand and loss>0 then
            return 'Compare holding '..name(card)..' for Perkeo or Observatory against its permanent '..hand..' level.'
        elseif hand then
            return 'Use ' .. name(card) .. ' to level ' .. hand .. ' before committing a scoring hand; keep it only for a deliberate Observatory plan.'
        elseif key == 'c_black_hole' then
            return 'Use Black Hole before the next play to increase every hand level.'
        elseif snapshot.phase == 'hand' and (key == 'c_justice' or key == 'c_chariot' or key == 'c_death' or key == 'c_empress' or key == 'c_heirophant' or key == 'c_strength') then
            return name(card) .. ' can improve this hand; select suitable targets, use it, then refresh the score advice.'
        end
    end
end

function Strategy.advise(snapshot, options)
    snapshot = snapshot or {}
    snapshot=copy_table(snapshot)
    if options and options.shop_scoring then
        snapshot=copy_table(snapshot)
        snapshot._shop_scoring=options.shop_scoring
    end
    if snapshot.phase=='pack' and snapshot._shop_scoring and snapshot._shop_scoring.readiness then
        snapshot._readiness=snapshot._shop_scoring:readiness(snapshot)
    end
    local stats, engine = deck_stats(snapshot), components(snapshot)
    local result
    if snapshot.phase == 'shop' then result = shop_advice(snapshot, stats, engine)
    elseif snapshot.phase == 'pack' then result = pack_advice(snapshot, stats, engine)
    elseif snapshot.phase == 'blind' then result = blind_advice(snapshot, engine)
    elseif snapshot.phase == 'round' then result = {title='Cash out, then assess the shop', lines={}, warnings={},action={kind='cash_out'}}
    else result = {title='Review the current hand', lines={}, warnings={}} end
    if snapshot._readiness then
        result.readiness=snapshot._readiness
        if snapshot._readiness.status~='sampled_safe' then
            result.lines[#result.lines+1]=snapshot._readiness.reason
        end
    end
    local tip = challenge_tips[challenge(snapshot)]
    if tip then result.lines[#result.lines + 1] = tip end
    local boss = snapshot.blind or {}
    local key = boss.key
    if snapshot.phase == 'blind' or snapshot.phase == 'shop' then
        key = (snapshot.blind_choices or {}).Boss or key
        if type(key) == 'table' then key = key.key end
    end
    if boss_tips[key] and (snapshot.phase ~= 'hand' or not boss.disabled) then
        result.lines[#result.lines + 1] = ((snapshot.phase == 'blind' or snapshot.phase == 'shop') and 'Upcoming boss - ' or '') .. boss_tips[key]
    end
    if snapshot.phase=='shop' and #(snapshot.consumeables or {})==0 and perkeo_effects(snapshot)>0 then
        result.lines[#result.lines+1]='Perkeo has nothing to copy when you leave this shop. Retain a useful consumable if affordable after survival needs.'
    end
    local consumable = not (options and options.tactical_consumables) and consumable_tip(snapshot)
    if consumable then result.lines[#result.lines + 1] = consumable end
    if snapshot.phase == 'hand' and has(snapshot, 'j_ceremonial') then
        -- The sacrifice has already happened; do not recommend selling during play.
        result.lines[#result.lines + 1] = 'Before the next blind, inspect the Joker immediately right of Ceremonial Dagger.'
    end
    return result
end

Strategy.build_profile=build_profile
Strategy.target_value=target_value
Strategy.commitment=commitment
Strategy.owned_joker_value=function(snapshot,card)
    return joker_value(snapshot,card,deck_stats(snapshot),components(snapshot))
end
Strategy.inventory_value=inventory_value
Strategy.inventory_marginal=inventory_marginal
Strategy.preservation_cost=preservation_cost
Strategy.perkeo_effects=perkeo_effects
Strategy.development_gain=development_gain
Strategy.development_targets=function(snapshot,card,profile)
    return choose_pack_targets(snapshot,card,(profile or build_profile(snapshot)).stats)
end
Strategy.shop_sequence_api={kind=kind,capacity=capacity,after_joker_purchase=after_joker_purchase,
    after_joker_sale=after_joker_sale,purchase_penalty=purchase_penalty,
    build_value=function(s) return replacement_build_value(s,deck_stats(s)) end,
    replacement_value=function(s) return replacement_build_value(s,deck_stats(s),true) end,
    card_value=function(s,c) return card_value(s,c,deck_stats(s),components(s)) end}

local function catalog_replacement_plans(snapshot,card)
    local row=snapshot.jokers or {}
    if #row>6 then return nil,'The complete replacement row exceeds six owned Jokers.' end
    local plans={};local funded=copy_table(snapshot)
    change_preview_cash(funded,-num(snapshot.reroll_cost,num((snapshot.current_round or {}).reroll_cost,5)))
    if num(funded.dollars)<num(funded.bankrupt_at) then return nil,'The refresh itself is unaffordable before any later sale.' end
    local stats,engine=deck_stats(snapshot),components(snapshot)
    for index,sold in ipairs(row) do
        local a=ability(sold)
        if not modifiers(snapshot).all_eternal and not a.eternal and not sold.pinned and not a.pinned then
            local _,_,known=joker_value(snapshot,sold,stats,engine)
            -- An unknown legal sale alternative invalidates the candidate's
            -- whole victim comparison; it cannot be silently excluded while a
            -- favorable known sale is credited with the full catalog mass.
            if not known or sold.key=='j_diet_cola' or sold.key=='j_luchador' or sold.key=='j_chaos' or sold.key=='j_astronomer' then
                return nil,'A legal owned sale has effects outside the complete replacement model.'
            end
            local state=after_joker_sale(funded,index)
            if not state then return nil,'A legal owned sale can create a random replacement.' end
            if capacity(state,card,false) and num(card.cost)<=num(state.dollars)-num(state.bankrupt_at) then
                local after=after_joker_purchase(state,card)
                plans[#plans+1]={state=after,before_purchase=state,sold_index=index,sold_key=sold.key,
                    sale_proceeds=num(sold.sell_cost),net_purchase_spend=num(card.cost)-num(sold.sell_cost)}
            end
        end
    end
    return #plans>0 and plans or nil,'No supported legal sale funds a real replacement slot.'
end

function Strategy.shortfall_reroll(snapshot,base,context)
    local reroll=Strategy.paid_reroll
    if not reroll or not reroll.catalog or not context or context.truncated or not base then return end
    local action=base.action or {}
    local sequence=base.shop_sequence
    local complete_sequence=sequence and sequence.complete and type(sequence.actions)=='table' and sequence.scoring_evidence and
        (action.kind=='leave_shop' and #sequence.actions==0 or sequence.actions[1] and
        sequence.actions[1].kind==action.kind and sequence.actions[1].area==action.area and sequence.actions[1].index==action.index)
    if action.kind~='leave_shop' and not (action.kind=='buy' and action.area=='shop_jokers') and
        not (complete_sequence and (action.kind=='sell' and action.area=='jokers' or
        action.kind=='use' and action.area=='consumeables')) then return end
    local visible,visible_cost
    if complete_sequence then
        visible=sequence.scoring_evidence
        visible_cost=num(snapshot.dollars)-num(sequence.cash_after)
    elseif action.kind=='buy' then
        local offered=(snapshot.shop_jokers or {})[action.index]
        if not offered or not base.scoring_evidence then return end
        visible=base.scoring_evidence
        visible_cost=num(offered.cost)
    end
    local evidence=context:compare(snapshot,snapshot)
    if not evidence then return end
    local rating=copy_table(snapshot);rating._shop_scoring=nil;rating.shop_forecast=nil
    rating._readiness=evidence.before_readiness
    local stats,engine=deck_stats(rating),components(rating)
    if ((snapshot.shop_forecast or {}).rates or {}).joker==0 and reroll.planet_suggest then
        if not Strategy.consumables then return end
        return reroll.planet_suggest(snapshot,function(entry,price)
            local card=reroll.planet_card(entry,price)
            if not card or not capacity(snapshot,card,false) then return false end
            local value=card_value(rating,card,stats,engine)
            return value>0 and value or false
        end,evidence,{visible_evidence=visible,visible_cost=visible_cost,
            visible_actions=complete_sequence and sequence.actions or nil,
            compare_miss=function()
                local funded=copy_table(snapshot)
                local cost=num(snapshot.reroll_cost,num((snapshot.current_round or {}).reroll_cost,5))
                change_preview_cash(funded,-cost)
                local paired=context:compare(snapshot,funded)
                local gain=reroll.opening_gain(paired)
                context.reroll_miss_diagnostics={cost=cost,cash_after=num(funded.dollars),evidence=paired,gain=gain,
                    status=context.truncated and 'incomplete' or gain==nil and 'unsupported' or 'complete',
                    positive_growth_credited=false}
                return paired,context.truncated and 'incomplete' or gain==nil and 'unsupported' or nil
            end,
            compare=function(entry,price)
                local card=reroll.planet_card(entry,price)
                if not card or not capacity(snapshot,card,false) then return nil,'Planet purchase is unsupported or has no inventory space.' end
                local funded=copy_table(snapshot);funded._shop_scoring=nil
                change_preview_cash(funded,-num(snapshot.reroll_cost,num((snapshot.current_round or {}).reroll_cost,5)))
                local held=copy_table(funded);held.consumeables=copy_table(funded.consumeables)
                held.consumeables[#held.consumeables+1]=card
                change_preview_cash(held,-price)
                local index=#held.consumeables
                local used,why=Strategy.consumables.apply(held,index,{})
                if not used then return nil,why end
                local loss,reason,last=preservation_cost(held,used,index)
                local profile=build_profile(funded)
                local _,old_inventory=inventory_value(funded,nil,{profile=profile})
                local endpoints={{state=held,mode='hold'}}
                if not last and loss<=0 then endpoints[#endpoints+1]={state=used,mode='use'} end
                local best,records=nil,{}
                for _,endpoint in ipairs(endpoints) do
                    local paired=context:compare(snapshot,endpoint.state)
                    if context.truncated then return nil,'incomplete' end
                    local gain=reroll.opening_gain(paired)
                    if gain==nil then return nil,'A Planet endpoint lacks a complete supported paired comparison.' end
                    local _,new_inventory=inventory_value(funded,endpoint.state.consumeables,{profile=profile})
                    local inventory_delta=new_inventory.future+new_inventory.held-old_inventory.future-old_inventory.held
                    local liquidity=Strategy.liquidity and Strategy.liquidity.estimate(endpoint.state,paired.after_readiness)
                    local affordable=not liquidity or num(endpoint.state.dollars)>=liquidity.purchase_floor
                    local protected=inventory_delta>=-0.000001 and not survival_dominated(paired)
                    records[#records+1]={mode=endpoint.mode,opening_gain=gain,cash_after=num(endpoint.state.dollars),
                        inventory_delta=inventory_delta,status=not affordable and 'unfunded_reserve' or
                        not protected and 'protected_inventory_or_finish' or 'complete'}
                    if affordable and protected and (not best or gain>best.gain) then
                        best={gain=gain,evidence=paired,mode=endpoint.mode}
                    end
                end
                if not best then return nil,'No complete Planet endpoint preserves inventory, finishing and resource allowances.' end
                local result=copy_table(best.evidence)
                result.planet_plan={mode=best.mode,comparisons=records,complete=true,use_preservation_reason=reason}
                return result
            end})
    end
    local full_row=#(snapshot.jokers or {})>=num(snapshot.joker_limit,5)
    local before_build=full_row and replacement_build_value(rating,stats,true)
    if full_row then context.catalog_replacement_diagnostics={candidates={},scope='Complete supported legal victim sets, at most twelve paired comparisons.'} end
    return reroll.suggest(snapshot,function(entry,price)
        local card=reroll.catalog.create(entry,price,snapshot)
        if not card then return false end
        local value,_,known=card_value(rating,card,stats,engine)
        return known and value>0 and value or false
    end,evidence,{tactical_only=true,shortlist_limit=6,visible_evidence=visible,visible_cost=visible_cost,
        visible_actions=complete_sequence and sequence.actions or nil,
        replacement_plans=full_row and function(entry,price)
            local card=reroll.catalog.create(entry,price,snapshot)
            if not card then return nil,'Original source candidate is unsupported.' end
            local plans,why=catalog_replacement_plans(snapshot,card)
            context.catalog_replacement_diagnostics.candidates[#context.catalog_replacement_diagnostics.candidates+1]=
                {key=entry.key,price=price,victims=plans and #plans or 0,status=plans and 'eligible_for_shortlist' or 'unsupported',reason=not plans and why or nil}
            return plans,why
        end or nil,
        compare_miss=function()
            local funded=copy_table(snapshot)
            local cost=num(snapshot.reroll_cost,num((snapshot.current_round or {}).reroll_cost,5))
            change_preview_cash(funded,-cost)
            -- Keep the actual retained row on a miss. In particular, no sale
            -- contingent on finding an upgrade and no Flash Card growth is
            -- inserted into this conservative cash-only refresh transition.
            local paired=context:compare(snapshot,funded)
            local gain=reroll.opening_gain(paired)
            context.reroll_miss_diagnostics={cost=cost,cash_after=num(funded.dollars),evidence=paired,gain=gain,
                status=context.truncated and 'incomplete' or gain==nil and 'unsupported' or 'complete',
                positive_growth_credited=false}
            return paired,context.truncated and 'incomplete' or gain==nil and 'unsupported' or nil
        end,
        compare=function(entry,price,plans)
            local card,why=reroll.catalog.create(entry,price,snapshot)
            if not card then return nil,why end
            if plans then
                local best,records=nil,{}
                local assessment={key=entry.key,price=price,status='comparing',comparisons=records}
                context.catalog_replacement_diagnostics.candidates[#context.catalog_replacement_diagnostics.candidates+1]=assessment
                for _,plan in ipairs(plans) do
                    local paired=context:compare(snapshot,plan.state)
                    if context.truncated then assessment.status='incomplete';return nil,'incomplete' end
                    if not paired or not reroll.opening_gain(paired) then
                        assessment.status='unsupported'
                        return nil,'A legal victim lacks a complete supported paired comparison; the whole candidate receives zero credit.'
                    end
                    local after=copy_table(plan.state);after._readiness=paired.after_readiness
                    local liquidity=Strategy.liquidity and Strategy.liquidity.estimate(after,paired.after_readiness)
                    local affordable=not liquidity or num(after.dollars)>=liquidity.purchase_floor
                    local merit=replacement_build_value(after,deck_stats(after),true)-before_build+num(paired.adjustment)-6-
                        purchase_penalty(plan.before_purchase,price,card,after,paired.after_readiness)
                    local gain=reroll.opening_gain(paired)
                    records[#records+1]={sold_index=plan.sold_index,sold_key=plan.sold_key,sale_proceeds=plan.sale_proceeds,
                        cash_after=num(after.dollars),joker_limit=after.joker_limit,opening_gain=gain,utility=merit,
                        liquidity=liquidity,status=not affordable and 'unfunded_reserve' or merit<26 and 'retained_build_not_improved' or 'complete'}
                    if affordable and merit>=26 and gain>0 and (not best or gain>best.gain or gain==best.gain and merit>best.merit) then
                        best={evidence=paired,plan=plan,gain=gain,merit=merit}
                    end
                end
                assessment.status=best and 'complete' or 'no_supported_improvement'
                if not best then return nil,'All legal victims were compared; none preserves enough whole-build value and resource allowance.' end
                local result=copy_table(best.evidence)
                result.catalog_net_purchase_spend=best.plan.net_purchase_spend
                result.catalog_replacement={sold_index=best.plan.sold_index,sold_key=best.plan.sold_key,
                    sale_proceeds=best.plan.sale_proceeds,cash_after=num(best.plan.state.dollars),utility=best.merit,
                    comparisons=records,complete=true}
                return result
            end
            local funded=copy_table(snapshot)
            change_preview_cash(funded,-num(snapshot.reroll_cost,num((snapshot.current_round or {}).reroll_cost,5)))
            local after=after_joker_purchase(funded,card)
            local paired=context:compare(snapshot,after)
            return paired,context.truncated and 'incomplete' or not paired and context.unavailable_reason or nil
        end})
end
return Strategy
