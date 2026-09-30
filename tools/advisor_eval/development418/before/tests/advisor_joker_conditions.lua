-- Decisions must follow the owned Joker's trigger, not just raw card ranks.
local Scoring = dofile('Brainstorm/Advisor/scoring.lua')
local Search = dofile('Brainstorm/Advisor/search.lua')
local Snapshot = dofile('Brainstorm/Advisor/snapshot.lua')
local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ': ' .. tostring(actual) .. ' ~= ' .. tostring(expected))
end
local function card(rank, suit)
  return {rank=rank, nominal=rank==14 and 11 or math.min(rank,10), suit=suit or 'Hearts', ability={}}
end
local function joker(name, ability)
  ability=ability or {}; ability.name=name
  return {name=name, ability=ability, blueprint_compat=true}
end
local function state(cards, jokers)
  return {phase='hand',hand=cards,jokers=jokers,deck={},hands={},hand_size=8,
    blind={chips=100000},chips=0,dollars=10,hands_left=1,discards_left=0,
    modifiers={},probabilities={normal=1},current_round={}}
end
local function best(s)
  local before=Snapshot.fingerprint(s)
  local result=Search.run(s,Scoring)
  eq(Snapshot.fingerprint(s),before,'conditional evaluation leaves state unchanged')
  return result.play
end
local s=state({card(14),card(4)}, {joker('Walkie Talkie',{extra={chips=10,mult=4}})})
eq(best(s).indices[1],2,'play lower Four to trigger Walkie Talkie')
eq(best(s).score,95,'Walkie Talkie Chips and Mult both counted')
s.jokers[1].debuff=true
eq(best(s).indices[1],1,'debuffed Walkie Talkie no longer favors Four')

s=state({card(14),card(3,'Spades')},{joker('Arrowhead',{extra=50})})
eq(best(s).indices[1],2,'Spade trigger can outweigh an off-suit Ace')
s.hand[2].debuff=true
eq(best(s).indices[1],1,'debuffed Spade does not trigger Arrowhead')

s=state({card(13),card(8)},{joker('Fibonacci',{extra=8})})
eq(best(s).indices[1],2,'Fibonacci prefers Eight to face card')
s=state({card(14),card(10)},{joker('Even Steven',{extra=4})})
eq(best(s).indices[1],2,'Even Steven does not treat Ace as even')
s=state({card(13),card(3)},{joker('Odd Todd',{extra=31})})
eq(best(s).indices[1],2,'Odd Todd does not treat King as an odd number')

s=state({card(14),card(11,'Clubs')},{joker('Ancient Joker',{extra=1.5})})
s.current_round.ancient_card={suit='Clubs'}
eq(best(s).indices[1],2,'Ancient Joker current suit drives the selection')
s.current_round.ancient_card.suit='Hearts'
eq(best(s).indices[1],1,'Ancient Joker recommendation changes with its suit')
s=state({card(14),card(10,'Clubs')},{joker('The Idol',{extra=2})})
s.current_round.idol_card={id=10,suit='Clubs'}
eq(best(s).indices[1],2,'Idol matches both rank and suit')
s.current_round.idol_card.suit='Spades'
eq(best(s).indices[1],1,'rank match alone does not trigger Idol')

s=state({card(2,'Hearts'),card(6,'Hearts'),card(8,'Hearts'),card(11,'Hearts'),card(14,'Hearts')},
  {joker('Droll Joker',{t_mult=10,type='Flush'})})
eq(best(s).hand,'Flush','hand-type Joker rewards the matching hand')
eq(best(s).score,1008,'Droll adds Mult once to the flush')
eq(Scoring.score(s,{5}).mult,1,'Droll does not add Mult to a High Card')
s.jokers={joker('Blueprint'),joker('Droll Joker',{t_mult=10,type='Flush'})}
eq(Scoring.score(s,{1,2,3,4,5}).mult,24,'Blueprint copies the satisfied hand-type condition')
eq(Scoring.score(s,{5}).mult,1,'Blueprint does not bypass an unsatisfied condition')

s=state({card(14),card(2,'Clubs')},{joker('Lusty Joker',{effect='Suit Mult',extra={suit='Hearts',s_mult=3}})})
eq(Scoring.score(s,{1,2}).mult,4,'only scoring cards trigger suit Mult')
s.jokers[2]=joker('Splash')
s.hand[2].suit='Hearts'
eq(Scoring.score(s,{1,2}).mult,7,'Splash makes both matching cards trigger')
s.jokers[1]=joker('Bloodstone',{extra={odds=2,Xmult=1.5}})
eq(Scoring.score(s,{1,2}).uncertain,true,'random suit triggers remain estimates')

print('advisor_joker_conditions: '..checks..' checks passed')
