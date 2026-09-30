-- Survival decisions use the real scorer and synthetic, fully specified deck
-- compositions; they are regression scenarios, not measured full-run wins.
local Search = dofile('Brainstorm/Advisor/search.lua')
local Scoring = dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot = dofile('Brainstorm/Advisor/snapshot.lua')
local checks = 0
local function check(value, message) assert(value, message); checks = checks + 1 end
local function equal(actual, expected, message)
  check(actual == expected, message .. ': ' .. tostring(actual) .. ' ~= ' .. tostring(expected))
end
local function card(id, rank, suit)
  return {id = id, rank = rank, nominal = rank == 14 and 11 or math.min(rank, 10),
    suit = suit or 'Spades', enhancement = 'c_base', ability = {}}
end
local function state()
  return {hand = {}, deck = {}, jokers = {}, hands = {}, modifiers = {},
    blind = {chips = 1000}, chips = 0, dollars = 20, hand_size = 8, hand_limit = 5,
    hands_left = 3, hands_played = 0, discards_left = 2, discards_used = 0,
    current_round = {hands_left = 3, hands_played = 0, discards_left = 2, discards_used = 0},
    probabilities = {normal = 1}}
end
local function desperate()
  local s = state()
  s.hand, s.deck = {card('ace', 14)}, {card('king', 13), card('two', 2), card('foil', 2)}
  s.deck[3].edition = {foil = true}
  s.hand_size, s.hands_left, s.current_round.hands_left = 1, 1, 1
  s.blind.chips = 17
  return s
end
local function rich_draws()
  local s = state()
  local suits = {'Spades', 'Hearts', 'Clubs', 'Diamonds'}
  for i, rank in ipairs({14, 13, 11, 9, 7, 5, 3, 2}) do
    s.hand[i] = card('h' .. i, rank, suits[(i - 1) % 4 + 1])
  end
  for i = 1, 10 do s.deck[i] = card('d' .. i, 10, suits[(i - 1) % 4 + 1]) end
  return s
end
local options = {samples = 24, candidates = 16, max_evaluations = 140000}

do
  local s = desperate()
  local result = Search.run(s, Scoring, options)
  equal(result.play.score, 16, 'the available Ace cannot clear seventeen chips')
  check(result.discard and result.discard.probability > 0, 'some replacement cards can clear the blind')
  equal(result.kind, 'discard', 'do not spend the final hand on a guaranteed loss while a discard can win')
end

do
  local s = rich_draws()
  local result = Search.run(s, Scoring, options)
  equal(result.kind, 'discard', 'a poor opening hand benefits from a rich replacement deck')
  equal(#result.discard.indices, 5, 'shortlist includes a full five-card redraw when it has the best outcomes')
  equal(result.discard.probability, 1, 'five drawn tens clear this blind in every modeled sample')
end

do
  local s = rich_draws()
  local observed, trials = {}, {}
  local instrumented = {score = function(trial, indices)
    if trial ~= s and not observed[trial] then
      observed[trial] = true
      local drawn = {}
      for _, c in ipairs(trial.hand) do
        if c.id:sub(1, 1) == 'd' then drawn[#drawn + 1] = c.id end
      end
      trials[#trials + 1] = drawn
    end
    return Scoring.score(trial, indices)
  end, after_play = Scoring.after_play}
  -- Eight-card hands take 218 scores. This budget allows four complete
  -- five-candidate rounds, then two whole candidates and a partial third.
  local budget = 218 + 4 * 5 * 218 + 2 * 218 + 17
  local result = Search.run(s, instrumented, {samples = 24, candidates = 5, max_evaluations = budget,future_clear=false})
  equal(result.evaluations, budget, 'paired comparisons still honor the exact shared hard budget')
  equal(result.truncated, true, 'an interrupted comparison is reported')
  equal(result.discard.count, 4, 'only four complete comparison rounds contribute sampling evidence')
  for sample = 0, 3 do
    local longest = trials[sample * 5 + 5]
    equal(#longest, 5, 'a full redraw is represented in each bounded round')
    for candidate = 1, 5 do
      local drawn = trials[sample * 5 + candidate]
      equal(#drawn, candidate, 'shortlist represents each available discard size')
      for i, id in ipairs(drawn) do
        equal(id, longest[i], 'each candidate shares the same sampled replacement order')
      end
    end
  end
end

do
  local s = desperate()
  s.blind.chips = 16
  local result = Search.run(s, Scoring, options)
  equal(result.kind, 'play', 'an existing clearing hand saves the discard')
  equal(result.discard, nil, 'no sampling is needed after an existing certain clear')
end

do
  local s = desperate()
  s.discards_left, s.current_round.discards_left = 0, 0
  local result = Search.run(s, Scoring, options)
  equal(result.kind, 'play', 'no nonexistent discard is recommended')
  equal(result.discard, nil, 'no discard result without a remaining discard')
end

for _, dollars in ipairs({0, -20}) do
  local s, inspected = desperate(), {}
  s.dollars, s.bankrupt_at, s.modifiers.discard_cost = dollars, -20, 1
  local before = Snapshot.fingerprint(s)
  local instrumented = {score = function(trial, indices)
    if trial ~= s and not inspected[trial] then
      inspected[trial] = true
      equal(trial.dollars, dollars - 1, 'Golden Needle costs one dollar for the discard action')
    end
    return Scoring.score(trial, indices)
  end, after_play = Scoring.after_play}
  local result = Search.run(s, instrumented, options)
  -- Vanilla can_discard has no affordability check, and ease_dollars permits
  -- a negative balance. Credit limits constrain purchases, not this action.
  equal(result.kind, 'discard', 'Golden Needle can legally discard at or below zero money')
  equal(Snapshot.fingerprint(s), before, 'discard cost is applied only to the detached trial')
end

do
  local s = rich_draws()
  s.hand_limit = 2
  local result = Search.run(s, Scoring, options)
  check(#result.play.indices <= 2, 'plays honor a reduced live selection limit')
  check(not result.discard or #result.discard.indices <= 2, 'discards honor a reduced live selection limit')
end

do
  local s = desperate()
  s.blind.name, s.blind.key = 'The Fish', 'bl_fish'
  s.hand[1].face_down = true
  local result = Search.run(s, Scoring, options)
  local disclosed = false
  for _, warning in ipairs(result.play.warnings or {}) do
    if warning:find('face%-down') then disclosed = true end
  end
  check(disclosed, 'Fish hand estimates disclose use of face-down card identities')
end

do
  local s = desperate()
  local before = Snapshot.fingerprint(s)
  local old_random, old_randomseed = math.random, math.randomseed
  local old_pseudorandom, old_pseudoseed = pseudorandom, pseudoseed
  math.random = function() error('search consumed global RNG') end
  math.randomseed = function() error('search changed global RNG seed') end
  pseudorandom = function() error('search consumed game RNG') end
  pseudoseed = function() error('search consumed game seed') end
  local first, second = Search.run(s, Scoring, options), Search.run(s, Scoring, options)
  math.random, math.randomseed = old_random, old_randomseed
  pseudorandom, pseudoseed = old_pseudorandom, old_pseudoseed
  equal(Snapshot.fingerprint(first), Snapshot.fingerprint(second), 'unchanged states give identical survival decisions')
  equal(Snapshot.fingerprint(s), before, 'survival sampling leaves the source snapshot untouched')
end

do
  local s = desperate()
  local result = Search.run(s, Scoring, {samples = 24, candidates = 16, max_evaluations = 3})
  check(result.evaluations <= 3, 'the survival fallback respects the hard evaluation budget')
  equal(result.discard, nil, 'fewer than four complete trials do not become claimed sampling evidence')
end

local function resource_state(name,ability,target)
  local s=state()
  s.hand={card('ace',14),card('king',13,'Hearts')}
  s.hand_size=2; s.hands_left=4; s.current_round.hands_left=4
  s.discards_left=3; s.current_round.discards_left=3
  s.jokers={{name=name,ability=ability}}
  s.blind.chips=target
  for i=1,10 do s.deck[i]=card('draw'..i,13,i%2==0 and 'Spades' or 'Hearts') end
  return s
end
local function deterministic_continuation(s,discard_first)
  local current=Snapshot.copy(s)
  if discard_first then
    table.remove(current.hand,1)
    current.discards_left=current.discards_left-1
    current.current_round.discards_left=current.discards_left
    if current.jokers[1] and current.jokers[1].name=='Green Joker' then current.jokers[1].ability.mult=current.jokers[1].ability.mult-1 end
    current.hand[#current.hand+1]=table.remove(current.deck,1)
  end
  while current.hands_left>0 do
    local best
    Search.combinations(#current.hand,5,function(indices)
      local play=Scoring.score(current,indices)
      if play.legal~=false and (not best or play.score>best.score) then
        best=play; best.indices={}; for i,v in ipairs(indices) do best.indices[i]=v end
      end
    end)
    current=assert(Scoring.after_play(current,best.indices))
    if current.chips>=current.blind.chips then return current.chips end
    while #current.hand<current.hand_size and #current.deck>0 do current.hand[#current.hand+1]=table.remove(current.deck,1) end
  end
  return current.chips
end

do
  -- Every remaining card is a King: the counterfactual is exact, independent
  -- of draw order. One tempting discard permanently removes 30 Banner chips
  -- from each of four upcoming hands; playing first retains enough total score.
  local s=resource_state('Banner',{extra=30},800)
  equal(deterministic_continuation(s,false),826,'playing first clears with persistent Banner chips')
  equal(deterministic_continuation(s,true),720,'the superficially stronger redraw loses over four hands')
  local result=Search.run(s,Scoring,options)
  equal(result.kind,'play','continuation value preserves Banner when a discard turns a clear into a loss')
  check(result.resource_comparison~=nil,'resource comparison is explicit evidence')
  equal(result.resource_comparison.play.probability,1,'all deterministic play continuations clear')
  equal(result.resource_comparison.prior_discard.probability,0,'all deterministic discard continuations lose')
  check(result.play.future_note~=nil,'the resource-preserving choice is explained')
  check(result.evaluations<=options.max_evaluations,'continuations share the hard scoring budget')
end

do
  local s=resource_state('Green Joker',{mult=10,extra={hand_add=1,discard_sub=1}},1650)
  -- Ten permanent Hiker chips make the Ace worth playing before growing Green
  -- Joker on the three subsequent pairs. Its ordinary one-point discard loss
  -- and the missed growth then persist on every following hand.
  s.hand[1].ability.perma_bonus=10
  equal(deterministic_continuation(s,false),1662,'playing the Hiker Ace first retains Green growth')
  equal(deterministic_continuation(s,true),1620,'discarding the Ace loses persistent Green value')
  local result=Search.run(s,Scoring,options)
  equal(result.kind,'play','Green Joker continuation prevents a narrow deterministic loss')
  check(result.resource_comparison and result.resource_comparison.play.probability==1,'Green continuation uses real post-play growth')
end

do
  local s=resource_state('Banner',{extra=30},850)
  -- Larger redraws remain essential when the existing hand cannot contribute
  -- enough and the replacement cards unlock a very strong current poker hand.
  s.hand_size=5; s.hand={card('h1',14),card('h2',11,'Hearts'),card('h3',9,'Clubs'),card('h4',7,'Diamonds'),card('h5',2)}
  for i,c in ipairs(s.deck) do c.rank,c.nominal=10,10 end
  local result=Search.run(s,Scoring,options)
  equal(result.kind,'discard','Banner is not an unconditional prohibition on a necessary redraw')
  check(result.discard.probability>0,'the retained discard offers immediate clearing outcomes')
  s.hands_left=1; s.current_round.hands_left=1
  result=Search.run(s,Scoring,options)
  equal(result.kind,'discard','final-hand survival still takes priority over preserving Banner')
end

do
  local s=resource_state('Ramen',{x_mult=1.2,extra=0.01},300)
  local before=Snapshot.fingerprint(s)
  local result=Search.run(s,Scoring,options)
  check(result.evaluations<=options.max_evaluations,'Ramen continuation respects the same hard budget')
  equal(Snapshot.fingerprint(s),before,'Ramen consumption and subsequent hands remain detached')
end

do
  local s=resource_state('Banner',{extra=30},800)
  local before=Snapshot.fingerprint(s)
  local old_random,old_randomseed=math.random,math.randomseed
  local old_pseudorandom,old_pseudoseed=pseudorandom,pseudoseed
  math.random=function() error('continuation consumed global RNG') end
  math.randomseed=function() error('continuation changed global RNG seed') end
  pseudorandom=function() error('continuation consumed game RNG') end
  pseudoseed=function() error('continuation consumed game seed') end
  local first,second=Search.run(s,Scoring,options),Search.run(s,Scoring,options)
  math.random,math.randomseed=old_random,old_randomseed
  pseudorandom,pseudoseed=old_pseudorandom,old_pseudoseed
  equal(Snapshot.fingerprint(first),Snapshot.fingerprint(second),'resource continuation is deterministic for the same snapshot')
  equal(Snapshot.fingerprint(s),before,'all resource continuation branches leave the live input untouched')
  local limited=Search.run(s,Scoring,{samples=24,candidates=16,max_evaluations=250})
  check(limited.evaluations<=250,'resource work cannot exceed a small shared budget')
  equal(limited.resource_comparison,nil,'insufficient continuation budget produces no claimed comparison')
  s.blind.name,s.blind.key='The Hook','bl_hook'
  local unsupported=Search.run(s,Scoring,options)
  equal(unsupported.resource_comparison,nil,'unsupported Hook transitions never become continuation evidence')
end

do
  -- No resource Joker is involved. The stronger first pair after discarding
  -- consumes a King from a finite draw pile. Playing the enhanced Ace first
  -- contributes real chips while leaving enough Kings for two later pairs.
  local s=resource_state('unused',{},170)
  s.jokers={}; s.hand[1].ability.perma_bonus=38
  s.hands_left=3; s.current_round.hands_left=3
  while #s.deck>4 do table.remove(s.deck) end
  equal(deterministic_continuation(s,false),174,'ordinary play-first continuation clears the finite-deck blind')
  equal(deterministic_continuation(s,true),135,'ordinary discard-first continuation runs out of paired cards and loses')
  local immediate=Search.run(s,Scoring,{resource_samples=0})
  equal(immediate.kind,'discard','next-play-only comparison prefers the superficially stronger pair')
  local before=Snapshot.fingerprint(s)
  local result=Search.run(s,Scoring,options)
  equal(result.kind,'play','general continuation retains a useful scoring card without a resource Joker')
  equal(result.resource_comparison.play.probability,1,'all paired play-first draws clear')
  equal(result.resource_comparison.prior_discard.probability,0,'all paired immediate-discard alternatives lose')
  check(result.resource_comparison.full_remaining_horizon,'three remaining hands are fully inside the bounded horizon')
  equal(result.resource_comparison.scope,'remaining_blind','comparison is explicitly about this blind')
  equal(Snapshot.fingerprint(s),before,'general continuation remains detached')
  equal(Snapshot.fingerprint(result),Snapshot.fingerprint(Search.run(s,Scoring,options)),'general continuation is deterministic')

  -- Card Sharp adds a supported history-dependent scoring effect to the same
  -- finite-deck decision: the second Pair, rather than the first, receives X3.
  s.jokers={{name='Card Sharp',ability={name='Card Sharp',extra={Xmult=3}}}}
  s.blind.chips=280; s.discards_left=6; s.current_round.discards_left=6
  equal(deterministic_continuation(s,false),294,'Card Sharp play-first path carries pair history into XMult')
  equal(deterministic_continuation(s,true),255,'Card Sharp discard-first path still lacks enough cumulative chips')
  equal(Search.run(s,Scoring,{resource_samples=0}).kind,'discard','immediate comparison also misses the Card Sharp continuation')
  result=Search.run(s,Scoring,options)
  equal(result.kind,'play','general continuation accounts for supported Card Sharp history')
  check(result.resource_comparison.play.probability>result.resource_comparison.prior_discard.probability,
    'Card Sharp choice improves modeled blind completion, not only mean next-hand score')
end

do
  local s=resource_state('unused',{},300)
  s.jokers={}; s.hand_size=12
  for i=3,12 do s.hand[i]=card('h'..i,2,i%2==0 and 'Spades' or 'Hearts') end
  s.blind.name,s.blind.key,s.blind.only_hand='The Mouth','bl_mouth','High Card'
  local result=Search.run(s,Scoring,options)
  check(result.evaluations<=140000,'twelve-card immediate and continuation search share the hard budget')
  check(result.search_diagnostics.continuation_reserve>0,'continuation work is reserved before draw sampling')
  check(result.search_diagnostics.discard_samples_limited or result.search_diagnostics.discard_shortlist_reduced,
    'large current hands reduce immediate sampling rather than starve cumulative comparison')
  check(result.resource_comparison and result.resource_comparison.samples>=4,'twelve-card search completes fair continuation rounds')
  s.jokers={{name='Burnt Joker',ability={name='Burnt Joker'}}}
  result=Search.run(s,Scoring,options)
  check(result.resource_comparison and result.resource_comparison.samples>=4,'exact Burnt discard growth supports continuation')
  check(not result.search_diagnostics.continuation_skipped,'modeled Burnt transition has no obsolete blocker')
end

print('advisor_resource_decisions: ' .. checks .. ' checks passed')
