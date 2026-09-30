local Snapshot = dofile('Brainstorm/Advisor/snapshot.lua')
local checks = 0
local function check(value, message)
  assert(value, message)
  checks = checks + 1
end
local function equal(actual, expected, message)
  check(actual == expected, (message or 'values differ') .. ': ' .. tostring(actual) .. ' ~= ' .. tostring(expected))
end
local function card(rank, suit, key)
  return {
    base = {id = rank, nominal = math.min(rank, 10), suit = suit},
    config = {center = {key = key or 'c_base', set = key and 'Enhanced' or 'Default', name = 'Card'}},
    ability = {}, edition = {}, facing = 'front', cost = 5, sell_cost = 2,
    calculate_joker = function() error('live joker callback invoked') end,
    get_id = function() error('live card method invoked') end,
  }
end
local function area(list, limit)
  return {cards = list or {}, config = {card_limit = limit or 5, highlighted_limit = 5}}
end
local function game()
  local h1, h2, d1 = card(14, 'Spades'), card(8, 'Hearts', 'm_steel'), card(4, 'Diamonds')
  local joker = card(0, nil)
  joker.config.center = {key = 'j_ride_the_bus', name = 'Ride the Bus', set = 'Joker', blueprint_compat = true}
  joker.ability = {extra = 2, eternal = true}
  return {
    STAGES = {RUN = 1, MAIN_MENU = 2}, STAGE = 1,
    STATES = {SELECTING_HAND = 1, SHOP = 2, BLIND_SELECT = 3, ROUND_EVAL = 4,
      TAROT_PACK = 5, PLANET_PACK = 6, SPECTRAL_PACK = 7, STANDARD_PACK = 8, BUFFOON_PACK = 9},
    STATE = 1, hand = area({h1, h2}, 8), deck = area({d1, card(9, 'Clubs')}),
    jokers = area({joker}), consumeables = area({card(0, nil)}, 2),
    playing_cards = {h1, h2, d1}, shop_jokers = area({card(0, nil)}),
    shop_vouchers = area({card(0, nil)}), shop_booster = area({card(0, nil)}),
    pack_cards = area({card(7, 'Spades')}),
    GAME = {
      challenge = 'c_city_1', round = 2, dollars = 17, chips = 100, bankrupt_at = -20,
      hands = {Pair = {level = 2, chips = 25, mult = 3, played = 1}},
      modifiers = {no_interest = true, no_blind_reward = {Small = true}},
      current_round = {hands_left = 3, discards_left = 2, hands_played = 1, discards_used = 1, reroll_cost = 5},
      round_resets = {ante = 2, blind_choices = {Small = 'bl_small', Boss = 'bl_eye'},
        blind_states = {Small = 'Select', Boss = 'Upcoming'}, blind_tags = {Small = 'tag_coupon'}},
      blind = {name = 'The Eye', chips = 1200, config = {blind = {key = 'bl_eye'}},
        hands = {Pair = true}, debuff = {}, disabled = false,
        debuff_hand = function() error('live blind method invoked') end},
      probabilities = {normal = 1}, selected_back = {effect = {center = {key = 'b_challenge'}}},
      last_tarot_planet = 'c_mercury', consumeable_usage_total = {planet = 2},
    },
  }
end

equal(Snapshot.capture(nil), nil, 'missing game skipped')
do
  local g=game()
  g.P_BLINDS={bl_small={name='Small Blind',mult=1,dollars=3},bl_big={name='Big Blind',mult=1.5,dollars=4},
    bl_eye={name='The Eye',mult=2,dollars=5,boss=true,debuff={different_hands=true}}}
  for _,state in ipairs({g.STATES.SELECTING_HAND,g.STATES.SHOP,g.STATES.BLIND_SELECT,g.STATES.TAROT_PACK}) do
    g.STATE=state
    local s=Snapshot.capture(g)
    equal(s.route_ante,2,'visible route remains bound to its ante')
    equal(s.route_blinds.Small.chips,800,'visible small target in each decision phase')
    equal(s.route_blinds.Big.chips,1200,'visible big target in each decision phase')
    equal(s.route_blinds.Boss.chips,1600,'visible boss target in each decision phase')
    equal(s.route_blinds.Boss.key,'bl_eye','public boss identity is retained')
    equal(s.route_blinds.Boss.state,'Upcoming','public boss status is retained')
    check(s.route_blinds.Boss.debuff.different_hands,'public restriction is retained')
  end
  g.STATE=g.STATES.SELECTING_HAND
  equal(Snapshot.capture(g).next_blind,nil,'hand phase does not gain a next-action preparation contract')
  g.GAME.round_resets.ante=9
  equal(Snapshot.capture(g).route_blinds.Boss.chips,nil,'unsupported target scaling stays unknown')
end
do
  local g = game()
  g.STAGE = g.STAGES.MAIN_MENU
  equal(Snapshot.capture(g), nil, 'menu skipped')
end

do
  local first, second = card(2,'Hearts'), card(2,'Hearts')
  first.playing_card, second.playing_card = 17, 17
  first.sort_id, second.sort_id = 30, 900
  equal(Snapshot.card(first).id, Snapshot.card(second).id, 'saved playing-card id is independent of object address and sort id')
  first.playing_card, second.playing_card = nil, nil
  first.sort_id, second.sort_id = 42, 42
  equal(Snapshot.card(first).id, Snapshot.card(second).id, 'saved sort id stabilizes Joker identity')
  first.sort_id = nil
  equal(Snapshot.card(first).id, tostring(first), 'minimal fixture cards retain pointer fallback')
end

do
  local input = {number = 2, text = 'a', flag = false, nested = {value = 4}, method = function() end}
  input.cycle = input
  setmetatable(input.nested, {__index = {hidden = 99}})
  local output = Snapshot.copy(input)
  equal(output.cycle, nil, 'cycles omitted')
  equal(output.method, nil, 'functions omitted')
  equal(output.flag, false, 'false preserved')
  equal(getmetatable(output.nested), nil, 'metatables omitted')
  output.nested.value = 10
  equal(input.nested.value, 4, 'deep copy independent')
end

do
  local g = game()
  local before = Snapshot.fingerprint(Snapshot.copy(g))
  local old_random, old_pseudorandom = math.random, pseudorandom
  math.random = function() error('snapshot used global RNG') end
  pseudorandom = function() error('snapshot used game RNG') end
  local s = Snapshot.capture(g)
  math.random, pseudorandom = old_random, old_pseudorandom
  equal(Snapshot.fingerprint(Snapshot.copy(g)), before, 'capture leaves live game unchanged')
  equal(s.phase, 'hand', 'hand phase')
  equal(s.challenge, 'c_city_1', 'challenge id preserved')
  equal(s.deck_key, 'b_challenge', 'challenge deck recognized')
  equal(s.dollars - s.bankrupt_at, 37, 'credit limit available')
  equal(s.hand[2].enhancement, 'm_steel', 'enhancement key captured')
  equal(s.hand[1].rank, 14, 'base rank captured')
  equal(s.hand_size, 8, 'actual hand capacity')
  equal(s.jokers[1].blueprint_compat, true, 'copy compatibility captured')
  equal(s.modifiers.no_blind_reward.Small, true, 'custom challenge modifiers preserved')
  equal(#s.shop_jokers, 0, 'shop cards ignored outside shop')
  s.hand[1].ability.modified = true
  s.current_round.discards_left = 99
  s.blind.hands.Pair = false
  equal(g.hand.cards[1].ability.modified, nil, 'card ability isolated')
  equal(g.GAME.current_round.discards_left, 2, 'round isolated')
  equal(g.GAME.blind.hands.Pair, true, 'blind history isolated')
end

do
  local g = game()
  for name, phase in pairs({SHOP = 'shop', BLIND_SELECT = 'blind', ROUND_EVAL = 'round',
    TAROT_PACK = 'pack', PLANET_PACK = 'pack', SPECTRAL_PACK = 'pack',
    STANDARD_PACK = 'pack', BUFFOON_PACK = 'pack'}) do
    g.STATE = g.STATES[name]
    local s = Snapshot.capture(g)
    equal(s.phase, phase, 'phase ' .. name)
    if phase == 'pack' then equal(#s.pack_cards, 1, 'pack options captured') end
    if phase == 'shop' then equal(#s.shop_jokers + #s.shop_booster + #s.shop_vouchers, 3, 'all shop areas captured') end
  end
end

do
  local g = game()
  local before = Snapshot.fingerprint(Snapshot.capture(g))
  g.deck.cards[1], g.deck.cards[2] = g.deck.cards[2], g.deck.cards[1]
  equal(Snapshot.fingerprint(Snapshot.capture(g)), before, 'draw order ignored, composition preserved')
  equal(Snapshot.fingerprint({b = 2, a = 1}), Snapshot.fingerprint({a = 1, b = 2}), 'table insertion order ignored')
end

local mutations = {
  {'hand order', function(g) g.hand.cards[1], g.hand.cards[2] = g.hand.cards[2], g.hand.cards[1] end},
  {'joker counter', function(g) g.jokers.cards[1].ability.extra = 8 end},
  {'joker debuff', function(g) g.jokers.cards[1].debuff = true end},
  {'pinned Joker position', function(g) g.jokers.cards[1].pinned = true end},
  {'card edition', function(g) g.hand.cards[1].edition.polychrome = true end},
  {'forced selection', function(g) g.hand.cards[1].ability.forced_selection = true end},
  {'face down', function(g) g.hand.cards[1].facing = 'back' end},
  {'hand level', function(g) g.GAME.hands.Pair.level = 3 end},
  {'hand usage', function(g) g.GAME.hands.Pair.played = 2 end},
  {'blind hand history', function(g) g.GAME.blind.hands.Flush = true end},
  {'blind disabled', function(g) g.GAME.blind.disabled = true end},
  {'money', function(g) g.GAME.dollars = 18 end},
  {'discards', function(g) g.GAME.current_round.discards_left = 1 end},
  {'chips', function(g) g.GAME.chips = 200 end},
  {'capacity', function(g) g.hand.config.card_limit = 7 end},
  {'deck composition', function(g) table.remove(g.deck.cards) end},
  {'consumable inventory', function(g) table.remove(g.consumeables.cards) end},
  {'blind selection', function(g) g.GAME.round_resets.blind_states.Small = 'Defeated' end},
  {'challenge', function(g) g.GAME.challenge = 'c_omelette_1' end},
}
do
  local g = game()
  local before = Snapshot.fingerprint(Snapshot.capture(g))
  g.jokers.cards[1].ability.blueprint_compat_ui = 'Compatible'
  g.jokers.cards[1].ability.blueprint_compat_check = true
  equal(Snapshot.fingerprint(Snapshot.capture(g)), before, 'Joker tooltip caches do not invalidate advice')
  equal(g.jokers.cards[1].ability.blueprint_compat_ui, 'Compatible', 'live tooltip cache left unchanged')
end
for _, mutation in ipairs(mutations) do
  local g = game()
  local before = Snapshot.fingerprint(Snapshot.capture(g))
  mutation[2](g)
  check(Snapshot.fingerprint(Snapshot.capture(g)) ~= before, mutation[1] .. ' invalidates advice')
end

do
  local g = game()
  g.STATE = g.STATES.SHOP
  local before = Snapshot.fingerprint(Snapshot.capture(g))
  g.shop_jokers.cards[1].cost = 9
  check(Snapshot.fingerprint(Snapshot.capture(g)) ~= before, 'shop price invalidates advice')
end

do
  local g=game()
  g.STATE=g.STATES.SHOP
  local function center(key,extra)
    local out={key=key,name=key,cost=4,unlocked=true,rarity=1}
    for k,v in pairs(extra or {}) do out[k]=v end
    return out
  end
  g.P_JOKER_RARITY_POOLS={
    {center('j_hanging_chad'),center('j_locked',{unlocked=false}),center('j_banned'),
      center('j_missing_enhancement',{enhancement_gate='m_glass'}),center('j_have_enhancement',{enhancement_gate='m_steel'}),
      center('j_no_flag',{no_pool_flag='gone'}),center('j_yes_flag',{yes_pool_flag='ready'})},
    {center('j_hack',{rarity=2})},{center('j_wee',{rarity=3})}}
  g.GAME.shop={joker_max=4}
  g.GAME.joker_rate,g.GAME.tarot_rate,g.GAME.planet_rate,g.GAME.playing_card_rate,g.GAME.spectral_rate=20,8,4,2,0
  g.GAME.used_jokers={j_hanging_chad=true}
  g.GAME.banned_keys={j_banned=true}
  g.GAME.pool_flags={gone=true,ready=true}
  g.GAME.discount_percent,g.GAME.inflation,g.GAME.rental_rate=25,3,3
  g.P_BLINDS={bl_small={dollars=3},bl_big={dollars=4},bl_eye={dollars=5}}
  local s=Snapshot.capture(g)
  equal(s.shop_forecast.slots,4,'actual expanded shop capacity captured')
  equal(s.shop_forecast.rates.tarot,8,'actual modified shop rates captured')
  equal(s.shop_forecast.discount_percent,25,'actual price discount captured')
  equal(s.shop_forecast.blind_rewards.Boss,5,'known boss reward captured for conditional income forecast')
  equal(#s.shop_forecast.pools[1],3,'locked banned missing-enhancement and pool-flag exclusions applied')
  local keys={}
  for _, c in ipairs(s.shop_forecast.pools[1]) do keys[c.key]=true end
  check(keys.j_hanging_chad and keys.j_have_enhancement and keys.j_yes_flag,'only eligible common centers survive static filtering')
  check(s.shop_forecast.used.j_hanging_chad,'used exclusions remain separate so shown offers can be released on rerolls')
  local stable=Snapshot.fingerprint(s)
  g.P_JOKER_RARITY_POOLS[1][1].discovered=true
  g.P_JOKER_RARITY_POOLS[1][1].hover_cache={text='animated'}
  g.P_JOKER_RARITY_POOLS[1][1],g.P_JOKER_RARITY_POOLS[1][2]=g.P_JOKER_RARITY_POOLS[1][2],g.P_JOKER_RARITY_POOLS[1][1]
  equal(Snapshot.fingerprint(Snapshot.capture(g)),stable,'discovery UI cache and pool insertion order do not change advice')
  g.GAME.tags={{key='tag_rare'}}
  check(Snapshot.capture(g).shop_forecast.special_shop_rules,'forced shop tags are identified instead of pretending ordinary rates apply')
  g.GAME.tags={}
  g.GAME.used_jokers.j_hanging_chad=nil
  check(Snapshot.fingerprint(Snapshot.capture(g))~=stable,'meaningful pool exclusion changes refresh forecast')
  s.shop_forecast.pools[1][1].cost=999
  equal(g.P_JOKER_RARITY_POOLS[1][2].cost,4,'forecast pool entries do not alias live centers')
  g.STATE=g.STATES.SELECTING_HAND
  equal(Snapshot.capture(g).shop_forecast,nil,'large shop metadata stays out of hand-scoring snapshots')
end

do
  local g=game()
  local fool=card(0,nil,'c_fool')
  fool.config.center.set='Tarot';fool.config.center.name='The Fool'
  g.consumeables.cards={fool}
  g.GAME.last_tarot_planet='c_jupiter'
  g.P_CENTERS={c_jupiter={key='c_jupiter',name='Jupiter',set='Planet',
    effect='Hand Upgrade',order=5,cost=3,config={hand_type='Flush'}}}
  local s=Snapshot.capture(g)
  check(s.fool_source and s.fool_source.schema=='fool_last_center_v1' and
    s.fool_source.config.hand_type=='Flush','hand captures only the public Fool source center')
  s.fool_source.config.hand_type='Pair'
  equal(g.P_CENTERS.c_jupiter.config.hand_type,'Flush','Fool source descriptor does not alias live center')
  g.GAME.banned_keys={c_jupiter=true}
  equal(Snapshot.capture(g).fool_source,nil,'banned forced source is never admitted')
  g.GAME.banned_keys={};g.consumeables.cards={}
  equal(Snapshot.capture(g).fool_source,nil,'absent held Fool does not add a source descriptor')
  g.consumeables.cards={fool};g.STATE=g.STATES.SHOP
  equal(Snapshot.capture(g).fool_source,nil,'hand-only source descriptor does not enlarge shop observations')
end

do
  local g=game();g.STATE=g.STATES.SHOP
  g.P_BLINDS={bl_small={name='Small Blind',mult=1,dollars=3},bl_big={name='Big Blind',mult=1.5,dollars=4},
    bl_plant={name='The Plant',mult=2,boss={},debuff={is_face='face'},dollars=5}}
  g.GAME.round_resets.blind_choices.Boss='bl_plant'
  g.GAME.round_resets.blind_states={Small='Defeated',Big='Upcoming',Boss='Upcoming'}
  local s=Snapshot.capture(g)
  equal(s.next_blind.key,'bl_big','post-Small shop projects actual Big blind')
  equal(s.next_blind.chips,1200,'next target uses current ante and definition multiplier')
  g.GAME.round_resets.blind_states.Big='Defeated'
  s=Snapshot.capture(g)
  equal(s.next_blind.key,'bl_plant','post-Big shop captures actual next boss')
  equal(s.next_blind.debuff.is_face,'face','source-defined boss restrictions are copied')
  equal(s.next_blind.chips,1600,'actual boss target captured')
  s.next_blind.debuff.is_face='changed'
  equal(g.P_BLINDS.bl_plant.debuff.is_face,'face','forecast metadata cannot mutate live boss definition')
  g.STATE=g.STATES.BLIND_SELECT;g.GAME.blind_on_deck='Boss'
  equal(Snapshot.capture(g).next_blind.key,'bl_plant','blind-select preparation captures chosen boss')
  g.STATE=g.STATES.SHOP;g.GAME.round_resets.blind_states.Boss='Defeated';g.GAME.round_resets.ante=3
  equal(Snapshot.capture(g).next_blind.key,'bl_small','post-boss shop forecasts next ante Small instead of stale boss')
  equal(Snapshot.capture(g).next_blind.chips,2000,'post-boss target uses advanced ante')
  g.GAME.round_resets.blind_states={Small='Upcoming',Big='Upcoming',Boss='Upcoming'}
  g.GAME.round_resets.blind_ante=3;g.GAME.blind_on_deck='Small'
  equal(Snapshot.capture(g).next_blind.key,'bl_small','source reset_blinds has already cleared defeated states during post-boss shop')
  equal(Snapshot.capture(g).next_blind.chips,2000,'all-Upcoming post-boss shop keeps the new Small target')
  equal(Snapshot.capture(g).next_blind.ante,3,'payout horizons receive the actual projected ante')
  g.STATE=g.STATES.BUFFOON_PACK
  equal(Snapshot.capture(g).next_blind.key,'bl_small','revealed Buffoon pack also captures actual upcoming blind')
  g.GAME.round_resets.blind_states.Small='Skipped'
  equal(Snapshot.capture(g).next_blind.key,'bl_big','a skip-triggered pack forecasts the blind actually retained')
  g.GAME.round_resets.blind_states.Big='Hide'
  equal(Snapshot.capture(g).next_blind.key,'bl_plant','skipped and hidden blinds use the source selection predicate')
  g.STATE=g.STATES.BLIND_SELECT;g.GAME.blind_on_deck=nil
  equal(Snapshot.capture(g).next_blind.key,'bl_plant','missing selection cursor falls back to the next uncompleted blind')
end
do
  local g=game();g.STATE=g.STATES.SHOP
  g.shop_jokers.cards[1].base_cost=7
  g.P_JOKER_RARITY_POOLS={{{key='j_joker',name='Joker',set='Joker',effect='Mult',order=1,
    config={mult=4},cost=2,blueprint_compat=true,unlocked=true}},{},{}}
  local s=Snapshot.capture(g)
  equal(s.shop_jokers[1].base_cost,7,'Sequential repricing captures the observed base cost')
  local entry=s.shop_forecast.pools[1][1]
  equal(entry.source_config.mult,4,'Catalog scoring captures source ability configuration')
  equal(entry.source_set,'Joker','Catalog scoring captures the actual source set')
  equal(entry.source_order,1,'Catalog ordering is detached metadata')
  entry.source_config.mult=100
  equal(g.P_JOKER_RARITY_POOLS[1][1].config.mult,4,'Catalog metadata cannot mutate source definitions')
end
do
  local g=game()
  g.GAME.filter_info={challenge_opening=true,challenge_id=g.GAME.challenge,
    legendary_jokers={'j_perkeo','j_yorick'},later={target_key='j_blueprint',deadline=3},
    search={batches=1,misses=0,native_seconds=.2}}
  local first=Snapshot.capture(g)
  equal(first.filter_info.search,nil,'wall-clock search telemetry never enters policy observations')
  equal(first.filter_info.later.target_key,'j_blueprint','deterministic route metadata remains available to hints')
  g.GAME.filter_info.search={batches=7,misses=6,native_seconds=45.7,start_cursor='DIFFERENT'}
  local second=Snapshot.capture(g)
  equal(Snapshot.fingerprint(first),Snapshot.fingerprint(second),'search duration and miss history cannot perturb deterministic sampling')
  equal(g.GAME.filter_info.search.native_seconds,45.7,'actual product cost ledger remains intact')
end
do
  local g=game();g.STATE=g.STATES.SHOP;g.P_JOKER_RARITY_POOLS={{},{},{}}
  local function center(key,set,config,extra)
    local c={key=key,set=set,name=key,cost=3,config=config or {},effect='Hand Upgrade',order=1}
    for k,v in pairs(extra or {}) do c[k]=v end
    return c
  end
  g.P_CENTER_POOLS={Planet={center('c_mercury','Planet',{hand_type='Pair'}),
    center('c_hidden','Planet',{hand_type='Hidden',softlock=true}),
    center('c_played','Planet',{hand_type='Pair',softlock=true}),
    center('c_locked','Planet',{hand_type='Pair'},{unlocked=false}),
    center('c_banned','Planet',{hand_type='Pair'}),
    center('c_flag','Planet',{hand_type='Pair'},{yes_pool_flag='ready'}),
    center('c_no_flag','Planet',{hand_type='Pair'},{no_pool_flag='gone'}),
    center('c_black_hole','Planet',{}, {name='Black Hole'})},
    Tarot={center('c_strength','Tarot'),center('c_soul','Tarot',{}, {name='The Soul'}),
      center('c_judgement','Tarot'),center('c_missing','Tarot',{}, {enhancement_gate='m_glass'})}}
  g.GAME.banned_keys={c_banned=true,c_judgement=true};g.GAME.pool_flags={ready=true,gone=true}
  g.GAME.used_jokers={c_mercury=true,c_strength=true}
  local s=Snapshot.capture(g);local meta=s.shop_forecast
  equal(meta.consumable_pool_schema,'source_shop_consumables_v1','source consumable pool schema recorded')
  equal(#meta.planet_pool,3,'Planet softlocks, locks, bans, flags and special Soul/Black Hole exclusions applied')
  equal(#meta.tarot_pool,1,'Tarot bans and enhancement gates retain only eligible centers')
  check(meta.consumable_used.c_mercury and meta.consumable_used.c_strength,'consumable duplicate exclusions captured separately')
  equal(meta.planet_pool[2].source_config.hand_type,'Pair','eligible source Planet configuration copied')
  local fingerprint=Snapshot.fingerprint(s)
  g.P_CENTER_POOLS.Planet[1],g.P_CENTER_POOLS.Planet[2]=g.P_CENTER_POOLS.Planet[2],g.P_CENTER_POOLS.Planet[1]
  equal(Snapshot.fingerprint(Snapshot.capture(g)),fingerprint,'source pool order does not change deterministic metadata')
  meta.planet_pool[2].source_config.hand_type='changed'
  equal(g.P_CENTER_POOLS.Planet[2].config.hand_type,'Pair','Planet configuration cannot alias the live source')
  g.GAME.hands.Hidden={played=1};equal(#Snapshot.capture(g).shop_forecast.planet_pool,4,'played hidden hand unlocks its softlocked Planet')
end
do
  local g=game();g.GAME.filter_info={jokerless_opening={mode='jokerless_coupon_blue_v1',seed='EXAMPLE1'},
    jokerless_catalog_signature='catalog',search={compute_seconds=17}}
  local captured=Snapshot.capture(g)
  equal(captured.filter_info.jokerless_opening.mode,'jokerless_coupon_blue_v1','explicit Jokerless recipe reaches policy')
  equal(captured.filter_info.search,nil,'Jokerless search time excluded from deterministic observation')
  captured.filter_info.jokerless_opening.mode='changed'
  equal(g.GAME.filter_info.jokerless_opening.mode,'jokerless_coupon_blue_v1','recipe is detached')
end
print('advisor_snapshot: ' .. checks .. ' checks passed')
