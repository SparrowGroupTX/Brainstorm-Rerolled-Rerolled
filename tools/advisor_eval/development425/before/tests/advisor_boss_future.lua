local Search = dofile('Brainstorm/Advisor/search.lua')
local Scoring = dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot = dofile('Brainstorm/Advisor/snapshot.lua')
local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ': '..tostring(actual)..' ~= '..tostring(expected))
end
local function state()
  local s={phase='hand',hand={},jokers={},deck={},playing_cards={},dollars=10,
    hands_left=4,discards_left=0,chips=0,hand_size=8,modifiers={},
    blind={key='bl_arm',name='The Arm',chips=100},probabilities={normal=1},
    hands={Pair={level=5,chips=70,mult=6,l_chips=15,l_mult=1,played=30},
      ['Three of a Kind']={level=1,chips=30,mult=3,l_chips=20,l_mult=2,played=0}}}
  for i,suit in ipairs({'Spades','Hearts','Clubs'}) do
    s.hand[i]={id=tostring(i),rank=10,nominal=10,suit=suit,ability={}}
    s.playing_cards[i]=Snapshot.copy(s.hand[i])
  end
  return s
end
local s=state()
local before=Snapshot.fingerprint(s)
local r=Search.run(s,Scoring)
eq(r.play.hand,'Three of a Kind','use Level1 trips instead of damaging core upgraded Pair')
eq(#r.play.indices,3,'future value outranks fewer selected cards once both clear')
eq(r.play.score,180,'chosen hand still clears the real target')
eq(r.play.arm_cost,0,'Level1 cannot be downgraded')
eq(type(r.play.future_note),'string','explain why a lower-scoring hand was chosen')
eq(Snapshot.fingerprint(s),before,'future-cost comparison leaves run untouched')
s.blind.chips=300
r=Search.run(s,Scoring)
eq(r.play.hand,'Pair','survival takes precedence when trips cannot clear')
eq(r.play.score,375,'Pair estimate already includes The Arm downgrade')
s=state(); s.blind.disabled=true
r=Search.run(s,Scoring)
eq(r.play.hand,'Pair','disabled Arm does not penalize hand levels')
s=state(); s.blind={key='bl_small',chips=100}
r=Search.run(s,Scoring)
eq(r.play.hand,'Pair','ordinary blind retains established clearing tie behavior')
s=state(); s.hands.Pair={level=1,chips=10,mult=2,played=30}; s.blind.chips=50
r=Search.run(s,Scoring)
eq(r.play.hand,'Pair','if both hands Level1 prefer smaller clearing play')
s=state(); s.hands['Three of a Kind']={level=2,chips=50,mult=5,l_chips=20,l_mult=2,played=0}
r=Search.run(s,Scoring)
eq(r.play.hand,'Three of a Kind','even two upgrades differ in future strategic cost')

print('advisor_boss_future: '..checks..' checks passed')
