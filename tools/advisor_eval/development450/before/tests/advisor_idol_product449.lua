-- Invented finite populations; never a captured run or policy replay.
local F=dofile('tests/fixtures/retained418.lua');local T=dofile('tests/fixtures/shop433.lua');local m=F.modules()
if GROWTH449_PATH then m.growth=dofile(GROWTH449_PATH)end
local n=0;local function check(v,msg)n=n+1;assert(v,msg)end
local function state(size,spares)
 local s=F.state(false);s.hand={};s.deck={};s.consumeables={};s.ante=5;s.hand_size=size+(spares or 5)
 for i=1,size do s.hand[i]=F.card('idol449:held'..i,13,'Clubs')end
 for i=1,(spares or 5)do s.hand[#s.hand+1]=F.card('idol449:spare'..i,2+i,'Hearts')end
 for i=1,24 do s.deck[i]=F.card('idol449:draw'..i,2+i%8,'Diamonds')end
 s.jokers={F.j('j_yorick'),F.j('j_perkeo'),T.joker('j_idol')}
 s.jokers[1].ability.x_mult=4
 s.current_round={idol_card={id=13,rank='King',suit='Clubs'},discards_left=3,hands_left=4,discards_used=0,hands_played=0}
 s.hands={['Four of a Kind']={chips=120,mult=12,level=4,played=5},['Five of a Kind']={chips=150,mult=15,level=3,played=6},
  ['Flush Five']={chips=160,mult=16,level=1,played=0}}
 s.blind={key='bl_big',name='Big Blind',chips=30000};F.population(s);return s
end
local function clear(s,size)
 local indices={};for i=1,size do indices[i]=i end
 local c=m.scoring.lower_bound(s,indices);c.indices=indices;return c
end
local function run(s,c,opts)
 local hash=m.snapshot.fingerprint(s)
 local r,work,diag=m.growth.suggest(s,m,c,opts or {exhaust_discards=true,max_evaluations=12,skip_singleton_probes=true})
 check(work<=((opts or {}).max_evaluations or 12),'original work ceiling')
 check(m.snapshot.fingerprint(s)==hash,'public input preserved')
 return r,work,diag
end
for _,size in ipairs({4,5})do
 local s=state(size);local c=clear(s,size);local r,_,d=run(s,c)
 if EXPECT_BASELINE449 then
  check(not r and table.concat(d.reasons,' '):find('scoring-trigger order',1,true),'baseline blocks large Idol anchor')
 else
  check(r and #r.action.indices==5,'Idol full-five discard '..size)
  check(r.growth.order_floor.scope=='canonical_card_product_floor'and r.growth.order_floor.complete,'complete product certificate')
  local after=assert(m.scoring.after_discard(s,r.action.indices))
  local expected=(size==4 and 120+40 or 160+50)*(size==4 and 12 or 16)*2^size*4
  check(r.play.score==expected,'independent Idol power-of-two arithmetic '..size)
  local orders=0
  F.permutations(r.play.indices,function(order)
   orders=orders+1;local v=m.scoring.lower_bound(after,order)
   check(v.score==expected and v.glass_loss==0,'all physical orders equal before any draw')
  end)
  check(orders==(size==4 and 24 or 120),'complete independent order enumeration')
 end
end
if EXPECT_BASELINE449 then print('Baseline449: '..n..' checks; four/five-card Idol floors rejected');return end
-- Independently enumerate every scoring-card order and every five-of-six refill
-- subset. These are manufactured population members, not predictions of draws.
for _,variant in ipairs({'nonmatch','mixed_suits','wild_smeared','stone','debuffed_match','glass_red',
 'hack','seltzer','blueprint','brainstorm','both_copies','foil_card','foil_joker','holo_joker','poly_joker','high_finite'})do
 local s=state(5);local idol=s.jokers[3]
 if variant=='nonmatch'then s.current_round.idol_card.id=12;s.current_round.idol_card.rank='Queen'
 elseif variant=='mixed_suits'then s.hand[2]=F.card('mixed449',13,'Hearts')
 elseif variant=='wild_smeared'then s.hand[1]=F.card('wild449',13,'Hearts','m_wild');s.hand[2]=F.card('spade449',13,'Spades');s.jokers[4]=T.joker('j_smeared')
 elseif variant=='stone'then s.hand[2]=F.card('stone449',13,'Clubs','m_stone');local c=s.hand[2];c.name='Stone Card';c.ability.name=c.name;c.ability.effect=c.name;c.ability.bonus=50
 elseif variant=='debuffed_match'then s.hand[2].debuff=true
 elseif variant=='glass_red'then s.hand[1]=F.card('glass449',13,'Clubs','m_glass');s.hand[1].seal='Red'
 elseif variant=='hack'then
  s.current_round.idol_card={id=3,rank='3',suit='Clubs'}
  for i=1,5 do s.hand[i]=F.card('hack449:'..i,3,'Clubs')end;s.jokers[4]=T.joker('j_hack')
 elseif variant=='seltzer'then s.jokers[4]=T.joker('j_selzer');s.jokers[4].ability.extra=1
 elseif variant=='blueprint'then s.jokers[3]=F.j('j_blueprint');s.jokers[4]=idol
 elseif variant=='brainstorm'then s.jokers={idol,F.j('j_brainstorm'),F.j('j_yorick'),F.j('j_perkeo')}
 elseif variant=='both_copies'then s.jokers={idol,F.j('j_brainstorm'),F.j('j_blueprint'),F.copy(idol),F.j('j_yorick')};s.jokers[4].id='idol449:second'
 elseif variant=='foil_card'then s.hand[1].edition={foil=true,chips=50,type='foil'}
 elseif variant=='foil_joker'then idol.edition={foil=true,chips=50,type='foil'}
 elseif variant=='holo_joker'then idol.edition={holo=true,mult=10,type='holo'}
 elseif variant=='poly_joker'then idol.edition={polychrome=true,x_mult=1.5,type='polychrome'}
 elseif variant=='high_finite'then s.hands['Flush Five'].chips=1048576;s.hands['Flush Five'].mult=1048576 end
 F.population(s);local c=clear(s,5);s.blind.chips=math.max(1,c.score*.4)
 local r,work=run(s,c);check(r and #r.action.indices==5,'qualified product '..variant)
 check(r.growth.order_floor.complete and r.growth.order_floor.members==1,'algebraic completeness, not a partial enumeration')
 local after=assert(m.scoring.after_discard(s,r.action.indices))
 for excluded=1,6 do
  local future=F.copy(after);future.deck={}
  for i=1,6 do if i~=excluded then future.hand[#future.hand+1]=F.copy(s.deck[i])end end
  local orders=0
  F.permutations(r.play.indices,function(order)
   orders=orders+1;local v=m.scoring.lower_bound(future,order)
   check(v.legal and not v.uncertain and v.score==r.play.score and v.score<math.huge,'all refill/order members equal '..variant)
   check(v.glass_loss==r.play.glass_loss,'Glass exposure identical in every member '..variant)
  end)
  check(orders==120,'all120 members independently checked')
 end
 if variant=='hack'or variant=='seltzer'then
  local nominal=variant=='hack'and 3 or 10
  check(r.play.score==(160+5*nominal*2)*16*2^10*4,'independent per-card retrigger arithmetic '..variant)
 elseif variant=='blueprint'or variant=='brainstorm'then
  check(r.play.score==210*16*2^10*4,'independent two copies arithmetic '..variant)
 elseif variant=='both_copies'then check(r.play.score==210*16*2^20*4,'independent four physical/copy effects')end
 local exact=run(s,c,{exhaust_discards=true,skip_singleton_probes=true,max_evaluations=work})
 check(exact and exact.play.score==r.play.score,'exact charged allowance suffices '..variant)
end
-- Actual fresh decisions exhaust three discards with no dependency on drawing
-- a winning card. Eight-card hands retain four Kings; nine-card hands keep five
-- disposable slots. The retained finish is verified before every refill.
for _,spares in ipairs({4,5})do
 local s=state(4,spares);local total=0
 for left=3,1,-1 do
  local hash=m.snapshot.fingerprint(s)
  local result=m.decision.run(s,m,nil,{prepared_scoring=false,search={fast_clear=false,samples=24,candidates=5,resource_samples=0}})
  check(result.action.kind=='discard'and #result.action.indices==spares,'fresh Decision uses full safe batch '..spares..'/'..left)
  check(result.evaluations<=140000 and (result.discard_preference_work or 0)<=12,'aggregate and growth allowance unchanged')
  check(m.snapshot.fingerprint(s)==hash,'fresh Decision input unchanged')
  total=total+#result.action.indices;local population=#s.playing_cards
  s=assert(m.scoring.after_discard(s,result.action.indices))
  check(s.discards_left==left-1 and #s.playing_cards==population,'physical counters/population preserved')
  local kept={};for i,c in ipairs(s.hand)do if c.rank==13 then kept[#kept+1]=i end end
  check(#kept==4,'physical four-King anchor survives each actual discard')
  local finish=m.scoring.lower_bound(s,kept)
  check(finish.legal and finish.score>=s.blind.chips,'retained clear before any replacement draw')
  while #s.hand<s.hand_size do s.hand[#s.hand+1]=table.remove(s.deck)end
 end
 check(total==3*spares,'manufactured round discards12 or15 cards')
 local final=m.decision.run(s,m,nil,{prepared_scoring=false,search={fast_clear=false,samples=24,candidates=5,resource_samples=0}})
 check(final.action.kind=='play','finish after all three discards')
end
local negatives={
 {'missing target',function(s)s.current_round.idol_card=nil end},
 {'fractional target',function(s)s.current_round.idol_card.id=12.5 end},
 {'invalid suit',function(s)s.current_round.idol_card.suit='Other'end},
 {'contradictory rank',function(s)s.current_round.idol_card.rank='Queen'end},
 {'hidden target',function(s)s.current_round.idol_card.unknown=true end},
 {'modified extra',function(s)s.jokers[3].ability.extra=3 end},
 {'modified name',function(s)s.jokers[3].name='Other'end},
 {'unknown ability',function(s)s.jokers[3].ability.mod_effect=1 end},
 {'Mult card',function(s)s.hand[1]=F.card('badmult449',13,'Clubs','m_mult')end},
 {'Holo card',function(s)s.hand[1].edition={holo=true,mult=10,type='holo'}end},
 {'Polychrome card',function(s)s.hand[1].edition={polychrome=true,x_mult=1.5,type='polychrome'}end},
 {'Chad',function(s)s.jokers[4]=F.j('j_hanging_chad')end},
 {'Smiley',function(s)s.jokers[4]=T.joker('j_smiley')end},
 {'Photograph',function(s)s.jokers[4]=T.joker('j_photograph')end},
 {'Ancient',function(s)s.jokers[4]=T.joker('j_ancient')end},
 {'Bloodstone',function(s)s.jokers[4]=T.joker('j_bloodstone')end},
 {'Triboulet',function(s)s.jokers[4]=T.joker('j_triboulet')end},
 {'paid discard',function(s)s.modifiers.discard_cost=100 end},
 {'hidden selected card',function(s)s.hand[1].face_down=true end}}
for _,alias in ipairs({'face_down','identity_unknown','identity_redacted','unknown','concealed'})do
 negatives[#negatives+1]={alias,function(s)s.jokers[3][alias]=true end}
end
negatives[#negatives+1]={'facing',function(s)s.jokers[3].facing='back'end}
for _,location in ipairs({'selected','held','deck','Yorick','copy'})do
 for _,alias in ipairs({'unknown','identity_unknown','identity_redacted','concealed','face_down','facing'})do
  if location~='deck'or alias~='face_down'and alias~='facing'then
   for _,payload in ipairs({1,2})do
    negatives[#negatives+1]={location..'/'..alias..'/'..payload,function(s)
     local c=location=='selected'and s.hand[1]or location=='held'and s.hand[6]or location=='deck'and s.deck[1]or s.jokers[1]
     if location=='copy'then s.jokers[4]=s.jokers[3];s.jokers[3]=F.j('j_blueprint');c=s.jokers[3]end
     c[alias]=alias=='facing'and 'back'or true
     if payload==2 then if c.rank then c.rank=12;c.base.id=12 else c.ability.x_mult=16 end end
    end}
   end
  end
 end
end
for _,case in ipairs(negatives)do
 local s=state(5);case[2](s);F.population(s);local c=clear(s,5);s.blind.chips=1
 local r=run(s,c);check(not r,'unsafe/unknown product refused '..case[1])
end
do
 local s=state(4);local c=clear(s,4)
 check(not run(s,c,{exhaust_discards=true,skip_singleton_probes=true,max_evaluations=0}),'zero allowance cannot certify')
 s.blind.chips=c.score+1;check(not run(s,c),'known anchor below target never admitted')
end
do
 local s=state(5);for _,c in ipairs(s.deck)do c.face_down=true;c.facing='back'end
 local r=run(s,clear(s,5));check(r and #r.action.indices==5,'ordinary public deck backs remain valid')
end
do
 local s=state(4);s.hand[5]=F.card('steel449',3,'Hearts','m_steel');F.population(s)
 local c=clear(s,4);s.blind.chips=c.score*.9
 local r=run(s,c);check(r and #r.action.indices<=4,'required held Steel constrains disposable count')
 for _,i in ipairs(r.action.indices)do check(i~=5,'no discarded required Steel')end
 -- The unchanged shortlist can miss the largest subset when Steel is first
 -- among unprotected spares. An explicit protected anchor offers all four;
 -- neither route may silently discard it to claim a larger batch.
 local protected=run(s,c,{exhaust_discards=true,skip_singleton_probes=true,protected_indices={[5]=true}})
 check(protected and #protected.action.indices==4,'all four explicitly unprotected spares can be discarded')
 s.hand[6].seal='Blue';s.hand[7]=F.card('gold449',4,'Hearts','m_gold');F.population(s)
 local resource=run(s,clear(s,4));check(resource and #resource.action.indices<=2,'Steel/Blue/Gold resources constrain disposable count')
 for _,i in ipairs(resource.action.indices)do check(i~=5 and i~=6 and i~=7,'protected end-of-round assets preserved')end
end
print('Idol product449: '..n..' manufactured assertions passed')
