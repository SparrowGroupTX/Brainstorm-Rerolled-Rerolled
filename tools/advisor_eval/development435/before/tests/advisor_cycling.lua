-- Regression scenarios use the real hand classifier/scorer. Padding a play
-- must improve its next draw, while retaining cards that still have value.
local Search = dofile('Brainstorm/Advisor/search.lua')
local Scoring = dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot = dofile('Brainstorm/Advisor/snapshot.lua')
local checks = 0
local function check(value, message)
  assert(value, message)
  checks = checks + 1
end
local function equal(actual, expected, message)
  check(actual == expected, message .. ': ' .. tostring(actual) .. ' ~= ' .. tostring(expected))
end
local function card(id, rank, suit, enhancement)
  return {id = id, rank = rank, suit = suit or 'Spades',
    nominal = rank == 14 and 11 or math.min(rank, 10),
    enhancement = enhancement or 'c_base', ability = {}}
end
local function joker(name, ability)
  ability = ability or {}
  ability.name = name
  return {name = name, ability = ability, blueprint_compat = true}
end
local function state()
  local s = {
    hand = {}, deck = {}, jokers = {}, hands = {}, modifiers = {},
    blind = {chips = 10000}, chips = 0, dollars = 25,
    hand_size = 8, hand_limit = 5, hands_left = 3, hands_played = 0,
    discards_left = 0, discards_used = 0, probabilities = {normal = 1},
    current_round = {hands_left = 3, hands_played = 0, discards_left = 0},
  }
  local suits = {'Spades', 'Hearts', 'Clubs', 'Diamonds'}
  for i, rank in ipairs({14, 13, 11, 9, 7, 5, 3, 2}) do
    s.hand[i] = card('h' .. i, rank, suits[(i - 1) % 4 + 1])
  end
  for i = 1, 10 do s.deck[i] = card('d' .. i, 10, suits[(i - 1) % 4 + 1]) end
  return s
end
local options = {samples = 8, candidates = 12, cycle_samples = 8,
  cycle_candidates = 12, max_evaluations = 100000}
local function run(s, custom_options) return Search.run(s, Scoring, custom_options or options) end
local function selected(play, index)
  for _, i in ipairs(play.indices) do if i == index then return true end end
  return false
end
local function no_cycle(s, message)
  local result = run(s)
  equal(result.kind, 'play', message .. ' is a play')
  check(not result.play.cycle_indices or #result.play.cycle_indices == 0, message)
  equal(#result.play.indices, 1, message .. ' retains one selected card')
end

do
  local s = state()
  local before = Snapshot.fingerprint(s)
  local result = run(s)
  equal(result.kind, 'play', 'zero discards still permit play cycling')
  equal(result.play.hand, 'High Card', 'cycling preserves the recommended poker hand')
  equal(result.play.score, Scoring.score(s, {1}).score, 'cycling does not sacrifice immediate score')
  check(#result.play.indices > 1, 'draw-rich High Card selects extra non-scoring cards')
  check(result.play.cycle_indices and #result.play.cycle_indices > 0, 'cycled cards are identified')
  equal(#result.play.scoring_indices, 1, 'extra selections do not become scoring cards')
  equal(result.play.scoring_indices[1], 1, 'the original scoring Ace remains selected')
  equal(#result.play.indices, #result.play.cycle_indices + 1, 'all extra cards are explained as cycling')
  check(type(result.play.cycle_note) == 'string' and #result.play.cycle_note > 0, 'cycling has a user-visible explanation')
  equal(Snapshot.fingerprint(s), before, 'lookahead does not mutate live state or card abilities')
  check(result.evaluations <= options.max_evaluations, 'cycling respects the shared evaluation budget')
end

do
  local s = state()
  -- A lowered capacity leaves eight cards held until enough are played. The
  -- one-card baseline receives no draw, while a larger play opens useful slots.
  s.hand_size = 7
  local result = run(s)
  check(#s.hand - 1 >= s.hand_size, 'over-capacity fixture has no baseline replacement draw')
  check(#result.play.indices > 1, 'cycling can open replacement slots in an over-capacity hand')
  equal(result.play.score, Scoring.score(s, {1}).score, 'over-capacity cycling retains the original score')
end

do
  -- The low pair is not this turn's scoring hand, but retaining it makes
  -- next turn's stronger matching-rank hands available with fewer draws.
  local s = state()
  s.hand[2], s.hand[3] = card('pair1', 7, 'Hearts'), card('pair2', 7, 'Spades')
  s.hand[5] = card('junk', 8, 'Clubs')
  s.hands['High Card'] = {chips = 5, mult = 4}
  for i, c in ipairs(s.deck) do c.rank, c.nominal = 7, 7 end
  local result = run(s)
  equal(result.play.hand, 'High Card', 'leveled High Card remains the best current play')
  check(#result.play.indices > 1, 'pair-retention scenario still cycles junk')
  check(not selected(result.play, 2) and not selected(result.play, 3), 'cycling retains the useful held pair')
end

do
  -- Both available draws are known to be hearts, but their order is unknown.
  -- Drawing both improves the flush while all four original hearts remain useful.
  local s = state()
  s.hand = {card('ace', 14), card('heart1', 13, 'Hearts'), card('heart2', 12, 'Hearts'),
    card('heart3', 11, 'Hearts'), card('heart4', 9, 'Hearts'), card('junk1', 6, 'Clubs'),
    card('junk2', 4, 'Spades'), card('junk3', 2, 'Diamonds')}
  s.deck = {card('draw1', 8, 'Hearts'), card('draw2', 2, 'Hearts')}
  local result = run(s)
  check(#result.play.indices > 1, 'a second draw can improve a four-card flush setup')
  for i = 2, 5 do check(not selected(result.play, i), 'cycling preserves useful flush card ' .. i) end
end

do
  local s = state()
  s.jokers = {joker('Half Joker', {extra = {size = 3, mult = 20}})}
  local result = run(s)
  check(#result.play.indices > 1, 'Half Joker can cycle within its limit')
  check(#result.play.indices <= 3, 'cycling keeps Half Joker active')
  equal(result.play.score, Scoring.score(s, {1}).score, 'Half Joker keeps its scoring benefit')
end

for _, setup in ipairs({
  function(s) s.hand[2].enhancement = 'm_steel' end,
  function(s) s.jokers = {joker('Baron', {extra = 1.5})} end,
  function(s) s.hand[2].enhancement = 'm_gold'; s.hand[2].ability.h_dollars = 3 end,
  function(s) s.hand[2].seal = 'Blue' end,
}) do
  local s = state()
  setup(s)
  local result = run(s)
  check(not selected(result.play, 2), 'cycling retains valuable held effects, economy, or Blue seal')
  equal(result.play.score, Scoring.score(s, {1}).score, 'valuable held card keeps the current score intact')
end

do
  local s = state()
  s.jokers = {joker('Reserved Parking', {extra = {dollars = 1, odds = 2}})}
  s.hand[4], s.hand[5], s.hand[6] = card('run1', 9, 'Spades'), card('run2', 8, 'Spades'), card('run3', 7, 'Spades')
  s.hand[7], s.hand[8] = card('junk1', 4, 'Diamonds'), card('junk2', 2, 'Clubs')
  local result = run(s)
  check(not selected(result.play, 2) and not selected(result.play, 3),
    'free cycling retains held faces that earn Reserved Parking dollars')
  equal(result.play.expected_dollars, Scoring.score(s, {1}).expected_dollars,
    'cycling preserves modeled immediate earnings as well as score')
end

do local s = state(); s.jokers = {joker('DNA')}; no_cycle(s, 'first-hand DNA remains a single card') end
do
  local s = state()
  s.hand = {card('six', 6), card('four', 4, 'Hearts'), card('three', 3, 'Clubs'), card('two', 2, 'Diamonds')}
  s.hand_size = 4
  s.jokers = {joker('Sixth Sense')}
  no_cycle(s, 'first-hand Sixth Sense remains a single six')
end
do local s = state(); s.blind.name = 'The Tooth'; no_cycle(s, 'The Tooth does not spend dollars padding a hand') end
do local s = state(); s.modifiers.debuff_played_cards = true; no_cycle(s, 'permanent-debuff challenge stays conservative') end
do local s = state(); s.hands_left = 1; s.current_round.hands_left = 1; no_cycle(s, 'last hand has no next draw to improve') end
do local s = state(); s.blind.chips = 16; no_cycle(s, 'a clearing hand does not throw away extra held cards') end
do local s = state(); s.deck = {}; no_cycle(s, 'an empty deck offers no useful replacement') end
do local s = state(); s.deck = {card('onlydraw', 14)}; no_cycle(s, 'no extra selection when it cannot improve the next hand') end
do
  local s = state()
  s.blind.name, s.blind.key = 'The Serpent', 'bl_serpent'
  no_cycle(s, 'Serpent draws three regardless of padding, so equal next hands retain cards')
end
do
  local s = state()
  s.blind.name, s.blind.key = 'The Mouth', 'bl_mouth'
  no_cycle(s, 'Mouth locks the next hand to High Card, making matching-rank draws unhelpful')
end
do
  local s = state()
  s.blind.name, s.blind.key = 'Cerulean Bell', 'bl_final_bell'
  s.hand[8].ability.forced_selection = true
  local before = Snapshot.fingerprint(s)
  local result = run(s)
  check(selected(result.play, 8), 'cycling includes the Bell-forced card')
  equal(Scoring.score(s, result.play.indices).legal, true, 'Bell cycling remains a legal selection')
  equal(Snapshot.fingerprint(s), before, 'future Bell selection does not change the real forced card')
end

do
  local s = state()
  local before = Snapshot.fingerprint(s)
  local old_random, old_randomseed = math.random, math.randomseed
  local old_pseudorandom, old_pseudoseed = pseudorandom, pseudoseed
  math.random = function() error('cycling used the global random generator') end
  math.randomseed = function() error('cycling changed the global random seed') end
  pseudorandom = function() error('cycling consumed game RNG') end
  pseudoseed = function() error('cycling consumed game seed') end
  local first, second = run(s), run(s)
  math.random, math.randomseed = old_random, old_randomseed
  pseudorandom, pseudoseed = old_pseudorandom, old_pseudoseed
  equal(Snapshot.fingerprint(first), Snapshot.fingerprint(second), 'cycling is deterministic for an unchanged state')
  equal(Snapshot.fingerprint(s), before, 'repeated cycling leaves the snapshot unchanged')
end

do
  local s = state()
  local result = run(s, {samples = 8, cycle_samples = 8, cycle_candidates = 12, max_evaluations = 240})
  check(result.evaluations <= 240, 'small budget is respected during cycling')
  check(not result.play.cycle_indices or #result.play.cycle_indices == 0,
    'incomplete sample comparisons do not replace the fully evaluated play')
  equal(result.play.score, Scoring.score(s, {1}).score, 'budget exhaustion retains the existing score')
end

print('advisor_cycling: ' .. checks .. ' checks passed')
