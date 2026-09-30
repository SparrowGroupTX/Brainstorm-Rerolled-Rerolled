local Start=dofile('Brainstorm/Advisor/blind_start.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
Shop.blind_start=Start
Shop.paired_deck=dofile('Brainstorm/Advisor/paired_deck.lua')
Shop.blind_prep=dofile('Brainstorm/Advisor/blind_prep.lua')
Shop.strategy=dofile('Brainstorm/Advisor/strategy.lua')
local checks=0
local function check(x,label) checks=checks+1;assert(x,label) end
local function joker(key,id,a)
  a=a or {};a.name=a.name or ({j_ceremonial='Ceremonial Dagger',j_joker='Joker',j_chicot='Chicot',j_blueprint='Blueprint',j_burglar='Burglar'})[key]
  return {key=key,id=id,ability=a,sell_cost=4}
end
local function state()
  return {phase='shop',jokers={joker('j_ceremonial','d',{mult=20,eternal=true}),
      joker('j_joker','v',{mult=4}),joker('j_chicot','c')},
    playing_cards={{id=1,rank=2,suit='Spades',nominal=2,ability={}},
      {id=2,rank=2,suit='Hearts',nominal=2,ability={}}},
    hand_size=8,hand_limit=5,joker_limit=5,hands_left=4,discards_left=3,
    current_round={hands_left=4,discards_left=3},round_resets={hands=4,discards=3},
    probabilities={normal=1},hands={},dollars=20,consumeables={},modifiers={},
    blind={key='bl_wall',name='The Wall',boss=true,chips=600,debuff={}},
    next_blind={key='bl_wall',name='The Wall',boss=true,chips=600}}
end
local s=state();local fingerprint=Snapshot.fingerprint(s)
local a,d=Start.project(s)
check(a and #a.jokers==2 and a.jokers[1].ability.mult==28,'Dagger removes its exact victim before Chicot disable')
check(a.blind.disabled and a.blind.chips==300,'retained Chicot disables Wall after callbacks')
check(d.events[1].kind=='dagger' and d.events[2].kind=='chicot','ordered events recorded')
check(Snapshot.fingerprint(s)==fingerprint,'input unchanged')
s=state();s.jokers[2]=s.jokers[3];s.jokers[3]=nil
a=Start.project(s)
check(a and #a.jokers==1 and not a.blind.disabled and a.blind.chips==600,'sliced Chicot never queues disable')
s=state();s.jokers[1].debuff=true
a=Start.project(s)
check(a and #a.jokers==3 and a.jokers[1].ability.mult==20,'late reactivation cannot retroactively trigger Dagger')
check(not a.jokers[1].debuff,'eligible Dagger debuff clears after dispatch')
s.jokers[1].ability.perma_debuff=true
a=Start.project(s)
check(a and a.jokers[1].debuff,'permanent debuff survives boss disable')
s=state();s.jokers[4]=joker('j_chicot','c2')
a=Start.project(s)
check(a and a.blind.chips==150,'two real Chicots each divide Wall target')
s=state();s.jokers[4]=joker('j_blueprint','bp');s.jokers[5]=joker('j_chicot','c2')
a=Start.project(s)
check(a and a.blind.chips==150,'Blueprint does not create a third disable')
s=state();s.blind={key='bl_water',name='The Water',boss=true,chips=300,debuff={}}
Shop.apply_blind(s,s.blind,false,true)
check(s.discards_left==0 and s.blind.discards_sub==3,'prepare records Water reduction before dispatch')
a=Start.project(s)
check(a and a.discards_left==3,'Water restores its actual initial discard reduction')
s=state();s.blind={key='bl_needle',name='The Needle',boss=true,chips=300,debuff={}}
Shop.apply_blind(s,s.blind,false,true)
check(s.hands_left==1 and s.blind.hands_sub==3,'prepare records Needle reduction')
a=Start.project(s)
check(a and a.hands_left==4,'Needle restores exact hands')
s.jokers[4]=joker('j_burglar','b',{extra=3})
check(not Start.project(s),'queued Burglar/resource interaction stays explicit')
s=state();s.blind.key='bl_manacle'
check(not Start.project(s),'Manacle disable draw remains unsupported')
s=state();s.jokers[2].debuff=true
check(not Start.project(s),'unknown passive reactivation remains unsupported')
s=state();s.jokers[1].pinned=true
local context=Shop.new(s,Score)
local e=context:compare(s,s)
check(e and e.before_target==300 and e.before_startup,'shop models fixed Dagger setup then retained Chicot: '..tostring(context.unavailable_reason)..' target '..tostring(e and e.before_target))
check(e.before_startup.samples[1].removed[1]=='v','every sample uses actual protected-victim preparation')
s=state();s.jokers={s.jokers[1],s.jokers[3]};s.jokers[1].pinned=true
e=Shop.new(s,Score):compare(s,s)
check(e and e.before_target==600,'shop gives no disable credit to the unavoidable sliced Chicot')
print('advisor Chicot start tests: '..checks..' checks passed')
