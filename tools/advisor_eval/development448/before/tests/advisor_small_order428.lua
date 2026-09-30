-- Invented cards only. No saved game, journal or captured state is executed.
local F=dofile('tests/fixtures/retained418.lua');local m=F.modules()
if GROWTH428_PATH then m.growth=dofile(GROWTH428_PATH) end
local count=0;local function check(v,msg)count=count+1;assert(v,msg)end
local function state(size)
 local s=F.state(false);s.ante=5;s.blind={key='bl_big',name='Big Blind',chips=900}
 s.hand={};s.deck={};s.consumeables={};s.hand_size=8
 for i,r in ipairs(size==3 and {13,13,13,2,4,6,8,10} or {13,13,2,4,6,8,10,12})do
  s.hand[i]=F.card('order428:h'..i,r,({'Clubs','Hearts','Spades','Diamonds'})[(i-1)%4+1],i==1 and 'm_glass' or i==2 and 'm_mult' or nil)
 end
 for i=1,24 do s.deck[i]=F.card('order428:d'..i,2+i%8,'Hearts')end
 s.jokers={F.j('j_yorick'),F.j('j_perkeo')}
 s.hands={Pair={chips=30,mult=5,level=3,l_chips=15,l_mult=1,played=9},
  ['Three of a Kind']={chips=30,mult=5,level=1,l_chips=20,l_mult=2,played=4},
  ['High Card']={chips=5,mult=1,level=1,l_chips=10,l_mult=1,played=0}}
 F.population(s);return s
end
local function clear(s,size)
 local indices=size==3 and {2,1,3} or {2,1}
 local c=m.scoring.lower_bound(s,indices);c.indices=indices;return c
end
local function run(s,c,cap,modules)
 local before=m.snapshot.fingerprint(s)
 local r,n,d=m.growth.suggest(s,modules or m,c,{exhaust_discards=true,max_evaluations=cap or 12})
 check(m.snapshot.fingerprint(s)==before,'complete input preserved')
 check(n<=(cap or 12),'growth budget unchanged')
 return r,n,d
end
for _,size in ipairs({2,3})do
 local s=state(size);local c=clear(s,size);local r,n,d=run(s,c)
 if EXPECT_BASELINE428 then
  check(not r and table.concat(d.reasons,' '):find('sorting',1,true),'baseline rejects enhanced anchor order')
 else
  check(r and r.action.kind=='discard' and #r.action.indices==5,'enhanced '..size..'-card anchor permits full five')
  check(r.growth.order_floor.complete and r.growth.order_floor.members==(size==2 and 2 or 6),'every order is compared')
  check(r.growth.order_floor.minimum>=s.blind.chips,'worst order clears')
  local receipt=dofile('Brainstorm/Advisor/player_journal.lua').compact_yorick_review({growth=r,growth_diagnostics=d})
  check(receipt.order_floor.complete and receipt.order_floor.members==r.growth.order_floor.members and
    receipt.order_floor.minimum==r.play.score,'public receipt preserves complete floor provenance')
 end
end
if EXPECT_BASELINE428 then print('Baseline428: enhanced small anchors blocked by order guard');return end
-- Independent enumeration checks the production receipt on every order, with
-- real copied Yorick, Red Seal, Photograph, editions and unlucky floors.
for _,variant in ipairs({'plain','photograph','chad','polychrome','holo','foil','lucky','copies','smeared'})do
 local s=state(3)
 if variant=='photograph' then s.jokers[3]=F.joker('j_photograph','Photograph',{extra=2})
 elseif variant=='chad' then s.jokers[3]=F.j('j_hanging_chad')
 elseif variant=='copies' then table.insert(s.jokers,1,F.j('j_blueprint'));s.jokers[#s.jokers+1]=F.j('j_brainstorm')
 elseif variant=='smeared' then s.jokers[3]=F.joker('j_smeared','Smeared Joker');s.jokers[3].edition={negative=true,type='negative'}
 elseif variant=='polychrome' then s.hand[3].edition={polychrome=true,x_mult=1.5,type='polychrome'}
 elseif variant=='holo' then s.hand[3].edition={holo=true,mult=10,type='holo'}
 elseif variant=='foil' then s.hand[3].edition={foil=true,chips=50,type='foil'}
 elseif variant=='lucky' then
  local c=s.hand[3];c.key='m_lucky';c.enhancement='m_lucky';c.name='Lucky Card'
  c.ability.name='Lucky Card';c.ability.set='Enhanced';c.ability.effect='Lucky Card';c.ability.mult=20;c.ability.p_dollars=20
 end
 s.hand[1].seal='Red';F.population(s)
 local c=clear(s,3)
 -- Retain the already-exposed worst Glass order for the Chad case.
 if variant=='chad' then c=m.scoring.lower_bound(s,{1,2,3});c.indices={1,2,3} end
 local single_max=0;for i=1,3 do single_max=math.max(single_max,m.scoring.lower_bound(s,{i}).score)end
 s.blind.chips=single_max+1
 local r=run(s,c)
 check(r and #r.action.indices==5,'complete enhanced family admitted: '..variant)
 local after=assert(m.scoring.after_discard(s,r.action.indices));local minimum=math.huge;local maximum=0
 F.permutations(r.play.indices,function(order)
  local v=m.scoring.lower_bound(after,order);minimum=math.min(minimum,v.score);maximum=math.max(maximum,v.glass_loss)
  check(v.legal and not v.uncertain and v.score>=s.blind.chips,'every actual order clears: '..variant)
 end)
 check(r.play.score==minimum and r.growth.order_floor.minimum==minimum,'no favorable order selection: '..variant)
 check(r.play.glass_loss==maximum and r.growth.order_floor.maximum_glass==maximum,'maximum exposure independent of minimum score: '..variant)
end
-- Repeated fresh real Decision calls must discard before optional Tarot use.
for _,size in ipairs({2,3})do
 local s=state(size)
 s.consumeables={{id='optional428',key='c_heirophant',ability={name='The Hierophant',set='Tarot'}}}
 for left=3,1,-1 do
  local before=m.snapshot.fingerprint(s)
  local r=m.decision.run(s,m,nil,{prepared_scoring=false,search={fast_clear=false,samples=24,candidates=5,resource_samples=0}})
  check(r.action.kind=='discard','Decision exhausts discards before Tarot: '..size..'/'..left)
  local discarded=#r.action.indices
  if discarded<5 then
   --442: after refill a zero-Glass Flush can replace the original Glass Pair.
   -- A five-card redraw must not silently buy growth with new Glass exposure.
   check(r.play.glass_loss==0 and r.risky_yorick_clear and
    r.risky_yorick_clear.by_size[5].resources>0,'shorter batch preserves the newly available zero-Glass clear')
  else check(discarded==5,'largest free batch remains five')end
  check(r.evaluations<=140000 and (r.discard_preference_work or 0)<=12,'combined Decision budget unchanged')
  check(m.snapshot.fingerprint(s)==before,'Decision input unchanged')
  local old=s.jokers[1].ability.yorick_discards;local pop=#s.playing_cards
  s=assert(m.scoring.after_discard(s,r.action.indices))
  check(s.discards_left==left-1 and s.jokers[1].ability.yorick_discards==old-discarded,'physical discard and Yorick counters')
  check(#s.consumeables==1 and #s.playing_cards==pop,'inventory and physical population retained')
  while #s.hand<8 do s.hand[#s.hand+1]=table.remove(s.deck)end
 end
end
-- Budget must fit the whole family after anchor probes; no partial minima.
do
 local s=state(3);local r,n,d=run(s,clear(s,3),8)
 check(not r and n==3,'six-order proof cannot fit five remaining calls')
 check(table.concat(d.reasons,' '):find('complete selected-card order family',1,true),'budget abstention is explicit')
end
-- One winning order does not establish a draw-independent retained floor.
do
 local s=state(2);local c=clear(s,2)
 local worst=m.scoring.lower_bound(s,{1,2}).score
 check(worst<c.score,'fixture has a real noncommuting order difference')
 s.blind.chips=worst+1
 local r=run(s,c);check(not r,'bad permutation vetoes the entire discard family')
end
do
 -- Boundary double tests the veto independently of score minimum. Vanilla
 -- Glass rolls once per physical scoring card, including with Chad/Red above.
 local s=state(3);local c=clear(s,3);local scoped=F.copy(m);scoped.scoring=F.copy(m.scoring)
 scoped.scoring.lower_bound=function(snapshot,indices)
  local r=m.scoring.lower_bound(snapshot,indices)
  if #snapshot.hand==3 and #indices==3 and indices[1]==1 then r.glass_loss=1 end
  return r
 end
 local r=run(s,c,12,scoped);check(not r,'greater exposure veto is checked on every member, not only the lowest score')
end
for _,case in ipairs({
 {'Blackboard',function(s)s.jokers[3]=F.joker('j_blackboard','Blackboard',{extra=3})end},
 {'Raised Fist',function(s)s.jokers[3]=F.joker('j_raised_fist','Raised Fist')end},
 {'unknown Joker',function(s)s.jokers[3]=F.joker('j_mod_unknown','Unknown')end},
 {'modified card held effect',function(s)s.deck[1].ability.h_mult=1 end},
 {'modified Joker held effect',function(s)s.jokers[1].ability.h_mult=1 end},
 {'modified edition',function(s)s.deck[1].edition={foil=true,chips=51,type='foil'}end},
 {'mixed edition',function(s)s.deck[1].edition={foil=true,chips=50,polychrome=true,x_mult=1.5}end},
 {'paid discard',function(s)s.modifiers.discard_cost=1 end},
 {'concealed anchor',function(s)s.hand[1].face_down=true end},
 {'Hook',function(s)s.blind.key='bl_hook';s.blind.name='The Hook' end},
 {'generic profile',function(s)s.teacher_profile=nil end}})do
 local s=state(2);case[2](s);F.population(s)
 local r=run(s,clear(s,2));check(not r,'unchanged safety guard: '..case[1])
end
-- A canonical deck edition cannot affect held arithmetic. Smeared only alters
-- suit membership, fixed for the same selected set; additive five-card proof
-- still covers all120 orders without spending120 runtime scores.
do
 local s=state(2);s.hand={}
 for i,r in ipairs({13,11,8,6,4,2,3,5})do s.hand[i]=F.card('add428:'..i,r,i<=5 and 'Clubs' or 'Hearts',i<=2 and 'm_mult' or nil)end
 s.jokers[3]=F.joker('j_smeared','Smeared Joker');s.jokers[3].edition={negative=true,type='negative'}
 s.deck[1].edition={foil=true,chips=50,type='foil'};F.population(s)
 local c=m.scoring.lower_bound(s,{1,2,3,4,5});c.indices={1,2,3,4,5};s.blind.chips=c.score
 local r,n=run(s,c);check(r and #r.action.indices==3,'Smeared/additive Flush retains all available spares')
 local after=assert(m.scoring.after_discard(s,r.action.indices))
 F.permutations(r.play.indices,function(order)check(m.scoring.lower_bound(after,order).score==r.play.score,'complete additive Flush order equality')end)
end
do
 local s=state(2);s.hand[3]=F.card('heldGold428',2,'Hearts','m_gold');s.hand[4].seal='Blue';F.population(s)
 local r=run(s,clear(s,2));check(r and #r.action.indices==4,'Gold and Blue retention limits physically available discard size')
 for _,i in ipairs(r.action.indices)do check(i~=3 and i~=4,'held end-of-round resources preserved')end
end
-- A pre-existing additive certificate must keep its cheap proof. Otherwise
-- checking every order of the first losing candidate exhausts work needed to
-- find the next full-five candidate that preserves a required held Steel.
for _,chad in ipairs({false,true})do
 local s=state(3);s.hand_size=9;s.hand={};s.deck={}
 for i,r in ipairs({13,13,13,2,4,6,8,10,12})do
  s.hand[i]=F.card('budget428:'..i,r,i>=5 and 'Hearts' or 'Clubs',i==4 and 'm_steel' or i<=3 and 'm_mult' or nil)
 end
 for i=1,12 do s.deck[i]=F.card('budget428:d'..i,2+i%8,'Spades')end
 if chad then s.jokers[3]=F.j('j_hanging_chad')end
 F.population(s);local c=clear(s,3);s.blind.chips=c.score
 local r,n=run(s,c)
 check(r and #r.action.indices==5,'existing cheap certificate reaches a safe alternate full-five: '..tostring(chad))
 for _,i in ipairs(r.action.indices)do check(i~=4,'required held Steel remains')end
 check(not r.growth.order_floor or r.growth.order_floor.scope=='qualified_first_scoring_card_family','no factorial charge for existing additive scope')
end
-- A false positive from two negative scoring factors is not a random floor.
do
 local s=state(2)
 for i=1,2 do s.hand[i]=F.card('negative428:'..i,13,'Clubs','m_mult');s.hand[i].ability.mult=-3;s.hand[i].ability.bonus=-100 end
 s.hands.Pair={chips=10,mult=2,level=1};s.hands['High Card']={chips=25,mult=3,level=1}
 s.jokers[3]=F.joker('j_misprint','Misprint',{effect='Random Mult',extra={min=0,max=23}})
 s.blind.chips=2000;F.population(s)
 local c=clear(s,2);check(c.score>=2000,'negative-input fixture exposes the false raw floor')
 local r=run(s,c);check(not r,'negative scoring arithmetic cannot obtain order-floor admission')
end
for _,change in ipairs({function(s)s.hands.Pair.mult=-1 end,function(s)s.hand[1].ability.x_mult=-2 end,
 function(s)s.hand[2].ability.mult=4.5 end,function(s)s.hand[1].ability.perma_bonus=-50 end})do
 local s=state(2);local c=clear(s,2);change(s)
 local r=run(s,c);check(not r,'malformed selected/hand fields rejected even beside stale clear')
end
print('Small order428: '..count..' manufactured assertions passed')
