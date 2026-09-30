local Growth=dofile('Brainstorm/Advisor/growth.lua')
local S=dofile('Brainstorm/Advisor/scoring.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local modules={scoring=S,strategy=Strategy,search=Search,growth=Growth}
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local function eq(a,b,label) check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(id,r,suit) return {id=id,rank=r,suit=suit or 'Spades',ability={},enhancement='c_base'} end
local function state()
  local s={phase='hand',ante=1,blind={chips=1200},chips=0,hands_left=3,hands_played=0,
    discards_left=3,discards_used=0,current_round={},dollars=20,hand_size=8,hand_limit=5,
    jokers={{key='j_joker',ability={name='Joker',mult=100}},
      {key='j_yorick',ability={name='Yorick',x_mult=1,yorick_discards=23,extra={discards=23,xmult=1}}}},
    hand={},deck={},playing_cards={},modifiers={},consumeables={},hands={},probabilities={normal=1}}
  for i=1,8 do s.hand[i]=card('h'..i,i==1 and 14 or i) end
  s.hand[2].seal='Blue';s.hand[3].enhancement='m_gold'
  for i=1,20 do s.deck[i]=card('d'..i,2+i%10,i%2==0 and 'Hearts' or 'Clubs') end
  for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do s.playing_cards[#s.playing_cards+1]=c end end
  return s
end
local function clear(s)
  local p=S.score(s,{1});p.indices={1};return p
end
local function suggest(s,options) return Growth.suggest(s,modules,clear(s),options) end
local s=state()
local initial=Snapshot.fingerprint(s)
for step=1,3 do
  local g,n,d=suggest(s)
  check(g~=nil,'available safe Yorick discard '..step)
  eq(#g.action.indices,5,'full batch '..step)
  eq(g.growth.remaining_discards,3-step,'actual remaining resource '..step)
  check(g.growth.repeatable_yorick,'advice explains repeated investment')
  check(n<=12 and d.max_evaluations==12,'unchanged growth cap '..step)
  for _,i in ipairs(g.action.indices) do
    check(s.hand[i].seal~='Blue' and s.hand[i].enhancement~='m_gold','spare ordinary cards preserve end rewards')
  end
  local before=Snapshot.fingerprint(s)
  local again=suggest(s)
  eq(Snapshot.fingerprint(again),Snapshot.fingerprint(g),'deterministic current-state action '..step)
  eq(Snapshot.fingerprint(s),before,'input unchanged '..step)
  local after,effects=S.after_discard(s,g.action.indices)
  eq(effects.discarded_count,5,'exact transition uses five cards '..step)
  eq(after.jokers[2].ability.yorick_discards,23-step*5,'physical Yorick progress '..step)
  check(S.score(after,g.play.indices).score>=s.blind.chips*1.05,'finish needs no favorable replacement '..step)
  -- A fixed synthetic draw supplies the next observed state, never a hidden
  -- source run or claim that these particular replacements occur in game.
  while #after.hand<after.hand_size and #after.deck>0 do after.hand[#after.hand+1]=table.remove(after.deck,1) end
  s=after
end
eq(suggest(s),nil,'stop when actual discards are exhausted')
check(initial~=Snapshot.fingerprint(s),'three transitions are distinct states, not repeated allowance resets')

s=state();s.modifiers.money_per_discard=10
eq(suggest(s),nil,'foregone Green-style discard income can outweigh growth')
s=state();s.modifiers.discard_cost=10
eq(suggest(s),nil,'paid discards can outweigh growth')
s=state();s.hand[4].seal='Blue'
local g=suggest(s)
check(g and #g.action.indices==4,'do not force five when fifth card loses Blue value')
s=state();s.hands_played=2;s.current_round.hands_played=2;s.discards_used=1;s.discards_left=2
check(suggest(s)~=nil,'remaining discards can develop Yorick after earlier survival plays')
s.blind.chips=1550
eq(suggest(s),nil,'repeated investment cannot bypass known-clear margin')
s=state();s.ante=8;s.blind.boss=true
eq(suggest(s),nil,'final boss finishes instead of investing for nonexistent later blinds')
s=state();s.jokers[2].ability.x_mult=30
eq(suggest(s),nil,'mature distant growth can lose to action cost')
s=state();s.jokers[2].ability.yorick_discards=3
g=suggest(s)
check(g and g.growth.effects.yorick_growth==1,'full batch crosses exact threshold once')
local after=S.after_discard(s,g.action.indices)
eq(after.jokers[2].ability.yorick_discards,21,'remainder carries after threshold')

s=state();s.jokers[2]={key='j_burnt',ability={name='Burnt Joker'}}
s.hand[4].rank=7;s.hand[5].rank=7;s.hand[6].rank=7
s.hands={['Three of a Kind']={level=1,chips=30,mult=3,l_chips=20,l_mult=2,played=4}}
s.hands_played=1;s.current_round.hands_played=1
g=suggest(s)
check(g and g.growth.effects.burnt_levels==1,'Burnt first discard remains available after a play')
eq(g.growth.effects.burnt_hand,S.classify(s,g.action.indices),'Burnt category is actual selected cards')
s.discards_used=1
eq(suggest(s),nil,'Burnt alone cannot repeat a first-discard upgrade')
s.discards_used=nil;s.current_round.discards_used=1
eq(suggest(s),nil,'nested first-discard resource fallback is honored')

s=state();s.discards_used=1;s.discards_left=2
local calls,score=0,S.score
S.score=function(...) calls=calls+1;return score(...) end
local decision=Decision.run(s,modules)
S.score=score
check(decision.fast_clear and decision.growth,'real decision publishes repeated growth on fast clear')
eq(decision.action.kind,'discard','published action is the growth discard')
check(calls<=70 and decision.evaluations<=70,'whole fast clear stays within seventy scores')
eq(calls,decision.evaluations,'real scoring work is reported')
print('advisor discard investment: '..checks..' checks passed')
