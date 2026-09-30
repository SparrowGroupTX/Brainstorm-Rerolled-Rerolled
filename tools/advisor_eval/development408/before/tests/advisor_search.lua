local Search = dofile('Brainstorm/Advisor/search.lua')
local Snapshot = dofile('Brainstorm/Advisor/snapshot.lua')
local checks = 0
local function check(value, message)
  assert(value, message)
  checks = checks + 1
end
local function equal(actual, expected, message)
  check(actual == expected, (message or 'values differ') .. ': ' .. tostring(actual) .. ' ~= ' .. tostring(expected))
end
local function card(id, rank, suit)
  return {id = id, rank = rank, suit = suit or 'Hearts', ability = {}}
end
local function state()
  local s = {
    hand = {}, deck = {}, blind = {chips = 200}, chips = 0, dollars = 20,
    hand_size = 8, hand_limit = 5, discards_left = 2, discards_used = 1,
    hands_left = 4, hands_played = 0, modifiers = {}, current_round = {discards_used = 1},
  }
  for i = 1, 8 do s.hand[i] = card('h' .. i, i + 1) end
  for i = 1, 10 do s.deck[i] = card('d' .. i, 14, 'Spades') end
  return s
end
local sum_scorer = {score = function(s, indices)
  local score = 0
  for _, i in ipairs(indices) do score = score + s.hand[i].rank end
  return {score = score, legal = true, hand = 'Test hand', warnings = {}}
end}

do
  local seen, sizes = {}, {}
  Search.combinations(8, 5, function(indices)
    local key = table.concat(indices, ',')
    check(not seen[key], 'each combination occurs once')
    seen[key] = true
    sizes[#indices] = (sizes[#indices] or 0) + 1
    for i, index in ipairs(indices) do
      check(index >= 1 and index <= 8 and (i == 1 or indices[i - 1] < index), 'sorted valid indices')
    end
  end)
  for size, expected in ipairs({8, 28, 56, 70, 56}) do equal(sizes[size], expected, 'complete subset size ' .. size) end
  local calls = 0
  Search.combinations(0, 5, function() calls = calls + 1 end)
  equal(calls, 0, 'no empty play')
end

do
  local s = state()
  s.discards_left = 0
  local result = Search.run(s, sum_scorer)
  equal(result.evaluations, 218, 'every one-to-five-card play evaluated')
  equal(result.play.score, 35, 'highest sum selected')
  equal(table.concat(result.play.indices, ','), '4,5,6,7,8', 'correct best cards')
  equal(#result.alternatives, 218, 'all legal alternatives retained')
end

do
  local s = state()
  s.blind.chips = 12
  local result = Search.run(s, {score = function(trial, indices)
    check(trial == s, 'no discard simulation once an existing play clears')
    return sum_scorer.score(trial, indices)
  end})
  equal(result.kind, 'play', 'play when blind clears')
  equal(result.discard, nil, 'save discards on clear')
  equal(#result.play.indices, 2, 'prefer fewer cards when both plays clear')
  check(result.play.score >= 12, 'selected play still clears')
end

do
  local s = state()
  s.discards_left = 0
  local result = Search.run(s, {score = function(trial, indices)
    return {score = #indices >= 2 and 36 or 1, legal = true, hand = 'Pair'}
  end})
  equal(#result.play.indices, 2, 'equal-score plays omit non-scoring cards')
  equal(table.concat(result.play.indices, ','), '1,2', 'equal-score ties use deterministic card order')
end

do
  local s = state()
  s.hand[2].ability.forced_selection = true
  s.discards_left = 0
  local calls = 0
  Search.run(s, {score = function(trial, indices)
    local found = false
    for _, i in ipairs(indices) do if i == 2 then found = true end end
    check(found, 'forced card included in every scored play')
    calls = calls + 1
    return sum_scorer.score(trial, indices)
  end})
  equal(calls, 99, 'all subsets containing the forced card')
end

do
  local s = state()
  local before = Snapshot.fingerprint(s)
  local old_random, old_randomseed = math.random, math.randomseed
  local old_pseudorandom, old_pseudoseed = pseudorandom, pseudoseed
  math.random = function() error('advisor used global math.random') end
  math.randomseed = function() error('advisor seeded global RNG') end
  pseudorandom = function() error('advisor used game RNG') end
  pseudoseed = function() error('advisor used game seed') end
  local first = Search.run(s, sum_scorer, {samples = 4, candidates = 5, max_evaluations = 20000})
  local second = Search.run(s, sum_scorer, {samples = 4, candidates = 5, max_evaluations = 20000})
  math.random, math.randomseed = old_random, old_randomseed
  pseudorandom, pseudoseed = old_pseudorandom, old_pseudoseed
  equal(Snapshot.fingerprint(first), Snapshot.fingerprint(second), 'same input produces same search result')
  equal(Snapshot.fingerprint(s), before, 'search leaves input and nested state unchanged')
  check(first.discard and first.discard.count == 4, 'completed samples reported')
  check(first.discard.probability >= 0 and first.discard.probability <= 1, 'sample rate bounded')
end

local function inspect_draws(s, serpent)
  local original, checked, trials = {}, {}, 0
  for _, c in ipairs(s.hand) do original[c.id] = true end
  local before = Snapshot.fingerprint(s)
  local result = Search.run(s, {score = function(trial, indices)
    if trial ~= s and not checked[trial] then
      checked[trial], trials = true, trials + 1
      local kept, drawn, ids = 0, 0, {}
      for _, c in ipairs(trial.hand) do
        check(not ids[c.id], 'no duplicate sampled card')
        ids[c.id] = true
        if original[c.id] then kept = kept + 1 else drawn = drawn + 1 end
      end
      for _, c in ipairs(trial.deck) do
        check(not ids[c.id], 'sampled card removed from draw pool')
        ids[c.id] = true
      end
      local removed = #s.hand - kept
      local expected_draws = serpent and math.min(3, #s.deck)
        or math.min(#s.deck, math.max(0, s.hand_size - kept))
      equal(drawn, expected_draws, 'correct draw count')
      equal(#trial.deck + drawn, #s.deck, 'remaining composition conserved')
      equal(trial.discards_left, s.discards_left - 1, 'consume one discard')
      equal(trial.discards_used, s.discards_used + 1, 'advance discard context')
      equal(trial.current_round.discards_used, trial.discards_used, 'nested round synchronized')
      equal(trial.dollars, s.dollars - (s.modifiers.discard_cost or 0), 'challenge discard cost applied')
    end
    return sum_scorer.score(trial, indices)
  end}, {samples = 4, candidates = 6, max_evaluations = 60000})
  check(trials >= 4, 'sampled distinct discard trials')
  check(result.evaluations <= 60000, 'search respects evaluation budget')
  equal(Snapshot.fingerprint(s), before, 'sampling never alters source composition')
end

do
  local s = state()
  s.hand_size = 6
  s.deck = {s.deck[1], s.deck[2]}
  s.modifiers.discard_cost = 1
  inspect_draws(s, false)
end

do
  local s = state()
  s.hand = {s.hand[1], s.hand[2], s.hand[3], s.hand[4]}
  inspect_draws(s, false)
end

do
  local s = state()
  s.blind.name, s.blind.key = 'The Serpent', 'bl_serpent'
  inspect_draws(s, true)
end

do
  local s = state()
  s.blind.name, s.blind.key, s.blind.disabled = 'The Serpent', 'bl_serpent', true
  inspect_draws(s, false)
end

do
  local s = state()
  s.discards_left = 0
  local result = Search.run(s, sum_scorer, {max_evaluations = 2})
  equal(result.evaluations, 2, 'hard budget during initial plays')
  equal(result.truncated, true, 'initial-play truncation reported on early return')
  s.discards_left = 2
  result = Search.run(s, sum_scorer, {max_evaluations = 300, samples = 4, candidates = 6})
  check(result.evaluations <= 300, 'hard budget during lookahead')
  equal(result.truncated, true, 'lookahead truncation reported')
  equal(result.discard, nil, 'partial trials are not presented as sampled evidence')
  check(result.search_diagnostics.discard_skipped, 'too-small sampling budget is rejected before partial work')
end

for _, bell in ipairs({false, true}) do
  local s = state()
  if bell then s.blind.name, s.blind.key = 'Cerulean Bell', 'bl_final_bell' end
  s.hand[1].ability.forced_selection = true
  local before, seen, forced_ids = Snapshot.fingerprint(s), {}, {}
  Search.run(s, {score = function(trial, indices)
    if trial ~= s and not seen[trial] then
      seen[trial] = true
      local forced = 0
      for _, c in ipairs(trial.hand) do
        if c.ability.forced_selection then forced = forced + 1; forced_ids[c.id] = true end
      end
      equal(forced, bell and 1 or 0, 'discard resets prior forced selection and Bell picks one new card')
    end
    return sum_scorer.score(trial, indices)
  end}, {samples = 4, candidates = 6, max_evaluations = 60000})
  if bell then
    local distinct = 0
    for _ in pairs(forced_ids) do distinct = distinct + 1 end
    check(distinct > 1, 'Bell choices are sampled instead of permanently forcing the old card')
  end
  equal(Snapshot.fingerprint(s), before, 'forced-card resampling leaves source abilities unchanged')
end

do
  local s = state()
  s.jokers = {
    {name = 'Green Joker', ability = {mult = 10, extra = {discard_sub = 2, hand_add = 1}}},
    {name = 'Ramen', ability = {x_mult = 2, extra = 0.1}},
  }
  local original, seen, tested = {}, {}, 0
  for _, c in ipairs(s.hand) do original[c.id] = true end
  local before = Snapshot.fingerprint(s)
  Search.run(s, {score = function(trial, indices)
    if trial ~= s and not seen[trial] then
      seen[trial], tested = true, tested + 1
      local retained = 0
      for _, c in ipairs(trial.hand) do if original[c.id] then retained = retained + 1 end end
      equal(trial.jokers[1].ability.mult, 8, 'Green Joker loses Mult once per discard action')
      local ramen = 2
      for _ = 1, #s.hand - retained do ramen = ramen - 0.1 end
      equal(trial.jokers[2].ability.x_mult, ramen, 'Ramen loses XMult for every discarded card')
      check(trial.jokers[1].ability.extra ~= s.jokers[1].ability.extra, 'nested Joker parameters detached for trial')
    end
    return sum_scorer.score(trial, indices)
  end}, {samples = 4, candidates = 6, max_evaluations = 60000})
  check(tested > 0, 'discard scoring penalties exercised')
  equal(Snapshot.fingerprint(s), before, 'discard penalties leave original Joker state untouched')
end

for _, negative in ipairs({false, true}) do
  local s = state()
  s.joker_limit = negative and 6 or 5
  s.jokers = {
    {name = 'Ramen', sell_cost = 5, edition = negative and {negative = true} or nil,
      ability = {x_mult = 1.005, extra = 0.01}},
    {name = 'Swashbuckler', sell_cost = 2, ability = {mult = 12}},
    {name = 'Joker Stencil', sell_cost = 4, ability = {x_mult = s.joker_limit - 3}},
    {name = 'Green Joker', sell_cost = 3, ability = {mult = 10, extra = {discard_sub = 2}}},
  }
  local before, seen, tested = Snapshot.fingerprint(s), {}, 0
  Search.run(s, {score = function(trial, indices)
    if trial ~= s and not seen[trial] then
      seen[trial], tested = true, tested + 1
      equal(#trial.jokers, 3, 'exhausted Ramen removed before scoring the next hand')
      equal(trial.joker_limit, 5, 'negative Ramen removal also removes its extra slot')
      equal(trial.jokers[1].ability.mult, 7, 'Swashbuckler no longer includes exhausted Ramen sell value')
      equal(trial.jokers[2].ability.x_mult, 3, 'Stencil recalculates vacancies after Ramen removal')
      equal(trial.jokers[3].ability.mult, 8, 'remaining Green Joker still applies discard penalty')
    end
    return sum_scorer.score(trial, indices)
  end}, {samples = 4, candidates = 6, max_evaluations = 60000})
  check(tested > 0, 'Ramen exhaustion exercised')
  equal(Snapshot.fingerprint(s), before, 'Ramen removal occurs only in detached trials')
end

do
  local s = state()
  s.jokers = {
    {name = 'Green Joker', debuff = true, ability = {mult = 10, extra = {discard_sub = 2}}},
    {name = 'Ramen', debuff = true, ability = {x_mult = 1.005, extra = 0.01}},
  }
  local seen = {}
  Search.run(s, {score = function(trial, indices)
    if trial ~= s and not seen[trial] then
      seen[trial] = true
      equal(#trial.jokers, 2, 'debuffed Ramen does not decay or disappear')
      equal(trial.jokers[1].ability.mult, 10, 'debuffed Green Joker does not lose Mult')
      equal(trial.jokers[2].ability.x_mult, 1.005, 'debuffed Ramen preserves XMult')
    end
    return sum_scorer.score(trial, indices)
  end}, {samples = 4, candidates = 3, max_evaluations = 30000})
end

print('advisor_search: ' .. checks .. ' checks passed')
