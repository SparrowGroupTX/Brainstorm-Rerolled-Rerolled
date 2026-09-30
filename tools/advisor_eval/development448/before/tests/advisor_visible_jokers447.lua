-- Invented populations only; no saved game or recorded run is executed.
local F=dofile('tests/fixtures/retained418.lua');local m=F.modules()
if GROWTH447_PATH then m.growth=dofile(GROWTH447_PATH)end
local n=0;local function check(v,msg)n=n+1;assert(v,msg)end
local function joker(key)
 local j=F.joker(key,key=='j_astronomer' and 'Astronomer' or 'Photograph',key=='j_photograph' and {extra=2}or{})
 j.blueprint_compat=key~='j_astronomer';return j
end
local function state(key)
 local s=F.state(false);s.hand={};s.deck={};s.hand_size=8;s.hands={};s.consumeables={}
 for i,r in ipairs({14,12,2,4,6,8,9,10})do s.hand[i]=F.card('visible447:'..i,r,({'Clubs','Spades','Hearts','Diamonds'})[(i-1)%4+1])end
 for i=1,24 do s.deck[i]=F.card('draw447:'..i,2+i%8,'Hearts')end
 s.hand[8].face_down=true;s.blind={key='bl_wheel',name='The Wheel',chips=key=='j_astronomer' and 60 or 90}
 s.jokers={F.j('j_yorick'),joker(key),F.j('j_perkeo')};F.population(s);return s
end
local function visible(s,cap)
 local calls=0;local modules={};for k,v in pairs(m)do modules[k]=v end
 modules.scoring=setmetatable({}, {__index=m.scoring})
 for _,k in ipairs({'lower_bound','score'})do local method=k
  modules.scoring[k]=function(...)calls=calls+1;return m.scoring[method](...)end
 end
 local before=m.snapshot.fingerprint(s)
 local r,work,d=m.growth.visible_retained(s,modules,cap or 12)
 check(calls==work and work<=(cap or 12),'every proof call charged within the same allowance')
 check(m.snapshot.fingerprint(s)==before,'public and hidden input remains unchanged')
 return r,work,d
end
if EXPECT_BASELINE447 then
 for _,key in ipairs({'j_astronomer','j_photograph'})do
  local r,work,d=visible(state(key))
  check(not r and work==0 and d.reason=='A Joker lacks a monotone public held-card floor.',key..' blocked before any proof')
 end
 print('Baseline447: both canonical rows rejected before scoring; '..n..' checks');return
end
for _,key in ipairs({'j_astronomer','j_photograph'})do
 local s=state(key);local r,work,d=visible(s)
 check(r and d.complete and r.action.kind=='discard' and #r.action.indices==5,'canonical '..key..' spends a full five')
 if key=='j_photograph'then
  check(m.scoring.score(s,{2}).score==120,'independent plain Queen arithmetic: (5+10)*2*4')
  check(not d.hidden_discard_scope,'Photograph is not mislabeled as identity-independent additive discard')
  for _,i in ipairs(r.action.indices)do check(i~=8,'Photograph hidden slot stays protected')end
 else check(d.hidden_discard_scope~=nil,'canonical inert Astronomer preserves identity-independent scope')end
 -- Every hidden/deck assignment produces the same public observation and action.
 for slot=1,#s.deck do
  local x=F.copy(s);x.hand[8],x.deck[slot]=x.deck[slot],x.hand[8]
  x.hand[8].face_down=true;x.deck[slot].face_down=false
  for i=1,math.floor(#x.deck/2)do x.deck[i],x.deck[#x.deck-i+1]=x.deck[#x.deck-i+1],x.deck[i]end
  F.population(x);local other=visible(x)
  check(other and m.snapshot.fingerprint(other.action)==m.snapshot.fingerprint(r.action) and other.play.score==r.play.score,
   'hidden physical assignment and deck order cannot change the action/floor')
 end
 for _,edition in ipairs({{foil=true,type='foil',chips=50},{holo=true,type='holo',mult=10},
    {polychrome=true,type='polychrome',x_mult=1.5},{negative=true,type='negative'}})do
  local x=state(key);x.jokers[2].edition=edition
  check(visible(x),'canonical Joker edition remains in the physical row')
 end
 -- Fresh observations after actual discards preserve the incumbent physical card.
 local current=state(key)
 for left=3,1,-1 do
  local result=m.decision.run(current,m,nil,{prepared_scoring=false,concealed_belief={copy_order=false}})
  check(result.action.kind=='discard' and #result.action.indices==5,'fresh Decision spends full discard '..key..'/'..left)
  check(result.evaluations<=12 and result.concealed_belief.scope=='visible_retained_floor','production uses bounded public proof')
  local pop=#current.playing_cards;local cash=current.dollars
  current=assert(m.scoring.after_discard(current,result.action.indices))
  check(current.discards_left==left-1 and #current.playing_cards==pop and current.dollars==cash,'physical counters/population/cash preserved')
  check(m.scoring.lower_bound(current,result.growth.play.indices).score>=current.blind.chips,
   'actual remaining physical cards clear before any replacement is drawn')
  while #current.hand<8 do current.hand[#current.hand+1]=table.remove(current.deck)end
 end
 local result=m.decision.run(current,m,nil,{prepared_scoring=false,concealed_belief={copy_order=false}})
 check(result.action.kind=='play' and current.discards_left==0,'only finishes after all three discards')
 check(m.scoring.score(current,result.action.indices).score>=current.blind.chips,'actual manufactured finish clears')
 for _,change in ipairs({function(x)x.jokers[2].ability.extra=3 end,function(x)x.jokers[2].ability.h_mult=-1 end,
  function(x)x.jokers[2].ability.effect='Modified' end,function(x)x.jokers[2].edition={holo=true,type='holo',mult=-10}end,
  function(x)x.jokers[2].key='j_unknown' end,function(x)x.hand[8].ability.forced_selection=true end,
  function(x)x.modifiers.discard_cost=1 end,function(x)for _,c in ipairs(x.hand)do c.face_down=true end end})do
  local x=state(key);change(x);F.population(x)
  check(not visible(x),'modified, constrained or absent visible proof refuses '..key)
 end
 for _,alias in ipairs({'face_down','identity_redacted','identity_unknown','unknown','concealed','facing'})do
  local x=state(key);x.jokers[2][alias]=alias=='facing'and'back'or true
  check(not visible(x),'hidden/unknown Joker payload cannot certify public discard: '..key..'/'..alias)
 end
 check(not visible(s,1),'one call cannot begin retained comparison')
end
for _,copykey in ipairs({'j_blueprint','j_brainstorm'})do
 local s=state('j_photograph');local photo=s.jokers[2]
 if copykey=='j_blueprint'then s.jokers={F.j(copykey),photo,s.jokers[1],s.jokers[3]}
 else s.jokers={photo,s.jokers[1],s.jokers[3],F.j(copykey)}end
 check(m.scoring.score(s,{2}).score==240,'independent copied Queen arithmetic: (5+10)*2*2*4')
 local r=visible(s);check(r and #r.action.indices==5,'real '..copykey..' route preserves visible Photograph proof')
 local after=assert(m.scoring.after_discard(s,r.action.indices))
 check(m.scoring.lower_bound(after,r.play.indices).score>=r.play.score,'physical copy route remains intact after the actual discard')
end
-- Photograph with Chad and mixed card effects is order-sensitive.
-- Independently enumerate the whole selected family, never the best order only.
local function pair_state(chad)
 local s=state('j_photograph')
 s.hand[1]=F.card('pair447:glass',13,'Clubs','m_glass')
 s.hand[2]=F.card('pair447:mult',13,'Spades','m_mult')
 s.jokers[1].ability.x_mult=4
 if chad then s.jokers[#s.jokers+1]=F.j('j_hanging_chad')end
 s.hands={Pair={level=3,chips=30,mult=5,l_chips=15,l_mult=1,played=9}};F.population(s)
 return s
end
for _,chad in ipairs({false,true})do
 local s=pair_state(chad);local lo,hi=math.huge,0
 F.permutations({1,2},function(order)local v=m.scoring.lower_bound(s,order).score;lo=math.min(lo,v);hi=math.max(hi,v)end)
 check(hi>lo,'Photograph mixed-card family has a real adverse ordering')
 local single=0;for i=1,7 do single=math.max(single,m.scoring.lower_bound(s,{i}).score)end
 check(lo>single,'complete Pair floor genuinely requires both cards')
 s.blind.chips=lo;local r,_,d=visible(s)
 check(r and r.growth.order_floor and r.growth.order_floor.complete and r.growth.order_floor.members==2,
  'complete two-order certificate survives visible admission')
 local after=assert(m.scoring.after_discard(s,r.action.indices))
 F.permutations(r.play.indices,function(order)
  local v=m.scoring.lower_bound(after,order)
  check(v.score>=s.blind.chips and v.glass_loss<=r.play.glass_loss,'each actual retained order preserves score and maximum Glass exposure')
 end)
 s.blind.chips=lo+1
 check(not visible(s),'one clearing order cannot qualify when its alternative fails')
 s.blind.chips=lo
 check(not visible(s,4),'incomplete residual allowance cannot publish favorable partial family')
end
-- Identity-sensitive discard callbacks and hidden rewards remain protected.
for _,key in ipairs({'j_burnt','j_faceless','j_hit_the_road'})do
 local s=state('j_astronomer')
 local specs={j_burnt={'Burnt Joker',{extra=4}},j_faceless={'Faceless Joker',{extra={dollars=5,faces=3}}},
  j_hit_the_road={'Hit the Road',{extra=0.5,x_mult=1,effect='Jack Discard Effect'}}}
 local spec=specs[key];s.jokers[#s.jokers+1]=F.joker(key,spec[1],spec[2]);F.population(s)
 local r,_,d=visible(s);check(not d.hidden_discard_scope,'hidden callback cannot become identity-independent: '..key)
 if r then for _,i in ipairs(r.action.indices)do check(i~=8,'hidden callback slot remains protected')end end
end
for _,seal in ipairs({'Blue','Purple','Gold'})do
 local s=state('j_astronomer');s.deck[1].seal=seal;F.population(s)
 local r,_,d=visible(s);check(not d.hidden_discard_scope,'possible hidden reward is retained')
 if r then for _,i in ipairs(r.action.indices)do check(i~=8,'reward-bearing hidden assignment cannot be discarded')end end
end
print('Visible Jokers447: '..n..' manufactured assertions passed')
