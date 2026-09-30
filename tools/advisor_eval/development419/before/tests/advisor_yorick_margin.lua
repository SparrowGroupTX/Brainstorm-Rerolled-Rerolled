-- Manufactured production mechanics only. No captured/source policy execution.
local Growth=dofile('Brainstorm/Advisor/growth.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local modules={growth=Growth,scoring=Score,strategy=Strategy,search=Search}
local checks=0
local function check(x,m) checks=checks+1;assert(x,m) end
local function eq(a,b,m) check(a==b,m..': '..tostring(a)..' ~= '..tostring(b)) end
local function copy(x) return Snapshot.copy(x) end
math.random=function() error('this retained-clear fixture requires no RNG') end
local function card(id,rank,suit)
  return {id=id,rank=rank,suit=suit or 'Spades',enhancement='c_base',ability={}}
end
local function joker(key,name,ability)
  ability=ability or {};ability.name=name;ability.set='Joker'
  return {id=key,key=key,name=name,ability=ability,blueprint_compat=true}
end
local function state(extra)
  local s={phase='hand',ante=2,win_ante=8,deck_key='b_red',blind={key='bl_small',name='Small Blind',chips=1000},
    chips=0,hands_left=4,hands_played=0,discards_left=3,discards_used=0,current_round={},dollars=25,
    hand_size=8,hand_limit=5,consumeable_buffer=0,consumable_limit=3,modifiers={},probabilities={normal=1},
    jokers={joker('j_yorick','Yorick',{x_mult=1,yorick_discards=23,extra={discards=23,xmult=1}}),
      joker('j_perkeo','Perkeo')},
    hand={card('h1',14),card('h2',2,'Hearts'),card('h3',4,'Clubs'),card('h4',6,'Diamonds'),
      card('h5',8,'Hearts'),card('h6',10,'Clubs'),card('h7',12,'Diamonds'),card('h8',3,'Hearts')},
    deck={},playing_cards={},consumeables={{id='t1',key='c_hermit',ability={name='The Hermit',set='Tarot'},edition={negative=true}}},
    hands={['High Card']={level=10,chips=95,mult=10,s_chips=5,s_mult=1,l_chips=10,l_mult=1,played=9}}}
  s.hand[1].ability.perma_bonus=extra or 0
  for i=1,12 do s.deck[i]=card('d'..i,2+i%10,i%2==0 and 'Clubs' or 'Diamonds') end
  for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do s.playing_cards[#s.playing_cards+1]=c end end
  return s
end
local function clear(s,indices)
  indices=indices or {1};local p=Score.score(s,indices);p.indices=copy(indices);return p
end
local function suggest(s,cap,p) return Growth.suggest(s,modules,p or clear(s),{max_evaluations=cap or 12}) end
local total_calls=0
for extra=0,3 do
  local s=state(extra);local before=Snapshot.fingerprint(s);local known=clear(s)
  eq(known.score,1060+10*extra,'manufactured exact current clear is106–109%')
  local g,n,diagnostics=suggest(s)
  check(g and g.action.kind=='discard','a106–109% clear reaches the complete retained-finish comparison')
  eq(#g.action.indices,5,'safe spare cards allow a full five-card Yorick batch')
  local after=assert(Score.after_discard(s,g.action.indices))
  eq(after.jokers[1].ability.yorick_discards,18,'only actual five physical discards count toward Yorick')
  eq(after.jokers[1].ability.x_mult,1,'partial progress does not fabricate an immediate multiplier')
  local finish=Score.score(after,g.play.indices)
  check(finish.legal and not finish.uncertain and finish.score>=s.blind.chips*1.05,
    'exact retained cards still pass the unchanged105% post-discard floor without drawing')
  eq(finish.score,known.score,'no favorable replacement score is assumed')
  eq(#after.hand,3,'only the actual discarded cards leave the held hand')
  eq(#after.deck,#s.deck,'the growth proof requires no deck draw')
  eq(#after.playing_cards,#s.playing_cards,'ordinary discards conserve the full population')
  eq(Snapshot.fingerprint(after.consumeables),Snapshot.fingerprint(s.consumeables),'whole Negative/Perkeo inventory preserved')
  eq(after.dollars,s.dollars,'ordinary growth spends no cash')
  eq(after.discards_left,s.discards_left-1,'exactly one discard action is spent')
  check(n>0 and n<=12 and diagnostics.max_evaluations==12,'same12-score local allowance')
  eq(Snapshot.fingerprint(s),before,'comparison preserves the input')
  local old=Score.score;local calls=0
  Score.score=function(...) calls=calls+1;return old(...) end
  local d=Decision.run(s,modules)
  Score.score=old
  check(d.fast_clear and d.growth and d.action.kind=='discard','real Decision publishes the completed growth action')
  eq(#d.action.indices,5,'production fast path keeps the full supported batch')
  check(calls<=70 and d.evaluations<=70,'whole production fast clear remains within70score calls')
  eq(calls,d.evaluations,'reported whole decision matches actual scorer work')
  total_calls=total_calls+calls
  eq(Snapshot.fingerprint(s),before,'production Decision leaves the full input unchanged')
end
local s=state();s.hand[1].rank=13
local boundary=suggest(s)
check(boundary and boundary.play.score==1050,'exact105% boundary is admitted without reducing the final floor')
s=state();s.blind.chips=1010
local low,n=suggest(s)
check(not low and n==0,'below105% current clear still stops before comparisons')
s=state();s.blind.chips=1100
check(not suggest(s),'non-clearing current hand remains ineligible')
s=state();s.modifiers.discard_cost=10
check(not suggest(s),'paid-discard cash and interest costs still defeat weak development')
s=state();s.blind.key='bl_final_bell'
check(not suggest(s),'forced-card replacement hazard remains blocked')
s=state();s.modifiers.flipped_cards=4
check(not suggest(s),'uncertain replacement visibility remains blocked')
s=state();s.jokers[#s.jokers+1]=joker('j_blackboard','Blackboard',{extra=3})
check(not suggest(s),'Blackboard held-card dependency remains blocked')
s=state();for i=2,#s.hand do s.hand[i].seal='Purple' end
check(not suggest(s),'unknown Purple generation does not disappear to earn Yorick progress')
s=state();for i=2,#s.hand do s.hand[i].seal='Blue' end
check(not suggest(s),'valuable Blue held resources remain charged')
s=state();s.ante=8;s.blind.boss=true
check(not suggest(s),'final boss finishes rather than investing in nonexistent development')
s=state();s.jokers[1].ability.x_mult=20;s.blind.chips=20000
check(not suggest(s),'mature distant Yorick retains the unchanged action-cost tradeoff')
s=state();s.hand[2].rank=14;s.hand[2].enhancement='m_glass'
s.hands.Pair={level=10,chips=145,mult=11,s_chips=10,s_mult=2,l_chips=15,l_mult=1,played=9}
check(not suggest(s,12,clear(s,{1,2})),'multi-card Glass sorting hazard stays outside the proof')
s=state();s.deck={};for i=1,201 do s.deck[i]=card('over'..i,2) end
check(not suggest(s),'oversized public decks retain the bounded guard')
s=state();local g,zero=suggest(s,0)
check(not g and zero==0,'zero caller budget cannot perform a comparison')
for cap=1,6 do
  local actual=0;local old=Score.score;local known=clear(s)
  Score.score=function(...) actual=actual+1;return old(...) end
  local result,used=suggest(s,cap,known)
  Score.score=old
  check(actual==used and used<=cap,'actual retained scoring respects smaller caller cap')
  if result then check(result.play.score>=1050,'a lower cap never relaxes the retained proof') end
end
-- Source-supported discard damage can turn an admitted current clear unsafe.
-- Partial progress alone must not compensate for a reduced finishing floor.
s=state();s.jokers[#s.jokers+1]=joker('j_ramen','Ramen',{x_mult=1.04,extra=.01});s.blind.chips=1040
local known=clear(s)
check(known.score>=1040*1.05 and known.score<1040*1.10,'Ramen example enters the repaired margin band')
local rejected,work=suggest(s,12,known)
check(not rejected and work>0,'every worthwhile discard fails the unchanged post-action floor after exact Ramen loss')
print('advisor_yorick_margin: '..checks..' checks passed; four production decisions '..total_calls..' score evaluations')
