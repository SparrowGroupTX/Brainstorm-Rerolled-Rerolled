-- Invented positions only. This file has no access to cases.json or journals.
local C=Adapter.copy;local checks=0
local function check(v,msg)checks=checks+1;assert(v,msg)end
local function reject(fn,msg)check(not pcall(fn),msg)end
local function card(id,rank,suit)
 local nominal=rank==14 and 11 or math.min(rank,10)
 return {id=id,rank=rank,suit=suit or 'Clubs',nominal=nominal,base={id=rank,nominal=nominal},key='c_base',
  name='Default Base',enhancement='c_base',debuff=false,face_down=false,
  ability={name='Default Base',set='Default',effect='Base',bonus=0,mult=0,x_mult=1,h_mult=0,h_x_mult=0,
   h_dollars=0,p_dollars=0,t_mult=0,t_chips=0}}
end
local function joker(key,name,a)
 local ability={name=name,set='Joker',effect='',mult=0,x_mult=1,bonus=0,t_chips=0,t_mult=0,
  h_mult=0,h_x_mult=0,h_dollars=0,p_dollars=0,h_size=0,d_size=0}
 for k,v in pairs(a or{})do ability[k]=v end
 return {key=key,id=key,ability=ability,blueprint_compat=true,debuff=false,cost=7,sell_cost=2}
end
local function state()
 local s={phase='hand',teacher_profile='perkeo_yorick_win_v1',ante=3,win_ante=8,round=3,
  hand={},deck={},playing_cards={},jokers={},consumeables={},hands={},hand_size=8,hand_limit=5,
  hands_left=4,hands_played=0,discards_left=3,discards_used=0,chips=0,dollars=30,
  current_round={},round_resets={hands=4,discards=3},round_bonus={},modifiers={},probabilities={normal=1},
  consumable_limit=2,joker_limit=5,blind={key='bl_big',name='Big Blind',chips=5},hands_played_total=12}
 for i=1,8 do s.hand[i]=card('hand'..i,13,'Clubs')end
 for i=1,18 do s.deck[i]=card(string.format('draw%02d',i),2+i%12,({'Clubs','Spades','Diamonds','Hearts'})[i%4+1])end
 for _,area in ipairs({s.hand,s.deck})do for _,c in ipairs(area)do s.playing_cards[#s.playing_cards+1]=C(c)end end
 s.jokers={joker('j_yorick','Yorick',{x_mult=4,yorick_discards=15,extra={discards=23,xmult=1}}),joker('j_perkeo','Perkeo')}
 return s
end
local function ids(s)local t={};for _,c in ipairs(s.deck)do t[#t+1]=c.id end;return t end
local function input(s,ad,role)
 return {mode='continuation',case='invented',role=role or'default',snapshot=s,admission=ad,
  world=0,world_seed=435,world_order=ids(s),sorting='rank',action_cap=16}
end
local function modules_with_actions(actions)
 local m={};for k,v in pairs(A)do m[k]=v end;local i=0
 m.decision={run=function(s)i=i+1;return {action=C(actions[math.min(i,#actions)]),evaluations=0}end}
 return m
end
local s=state();local original=A.snapshot.fingerprint(s);local canon=Adapter.canonical(s)
check(A.snapshot.fingerprint(s)==original,'Canonicalization leaves caller unchanged')
check(canon.hand[1].id==s.hand[1].id and canon.deck[1].id=='draw01','Only composition order canonicalized')
local bad=C(s);bad.deck[2].id=bad.deck[1].id;reject(function()Adapter.canonical(bad)end,'Duplicate IDs rejected')
bad=C(s);bad.deck[1].unknown=true;reject(function()Adapter.canonical(bad)end,'Unknown cards rejected')
check(not Adapter.legal(s,{kind='discard',indices={1,1}}),'Repeated selection rejected')
check(not Adapter.legal(s,{kind='play',indices={1,2,3,4,5,6}}),'Oversize selection rejected')
bad=C(s);bad.discards_left=0;check(not Adapter.legal(bad,{kind='discard',indices={1}}),'Zero-discard selection rejected')
local after,e=A.scoring.after_discard(canon,{1,2,3,4,5});check(after~=nil,'Real discard transition supported')
check(after.discards_left==2 and #after.hand==3 and #after.playing_cards==26,'Discard resources and population conserved')
check(after.jokers[1].ability.yorick_discards==10,'Physical Yorick receives exactly five cards')
local drawn,remaining=Adapter.refill(A,after,ids(canon),435,1,'rank')
check(drawn and #drawn.hand==8 and #drawn.deck==13 and #remaining==13,'Exactly five private cards drawn')
check(drawn.deck[1].id=='draw06','Public deck re-canonicalized after refill')
local reversed=ids(canon);for i=1,math.floor(#reversed/2)do reversed[i],reversed[#reversed-i+1]=reversed[#reversed-i+1],reversed[i]end
local other=Adapter.refill(A,after,reversed,435,1,'rank')
check(A.snapshot.fingerprint(drawn)~=A.snapshot.fingerprint(other),'Different private worlds produce different dealt hands')
local empty,why=Adapter.refill(A,after,{},435,1,'rank');check(not empty and why=='New unregistered draw identity','Missing private identities fail closed')
local pack=state();pack.phase='pack';pack.pack_type='BUFFOON_PACK';pack.pack_choices=1;pack.dollars=6
pack.pack_cards={joker('j_sly','Sly Joker',{type='Pair',t_chips=50}),joker('j_trio','The Trio',{type='Three of a Kind',x_mult=3})}
pack.active_tags={};pack.next_blind={key='bl_goad',name='The Goad',chips=600,boss=true,debuff={suit='Spades'}}
pack.hands={Pair={level=2,chips=25,mult=3,played=8,played_this_round=2}};pack.hands_played=2;pack.discards_used=3
pack.playing_cards[1].suit='Spades';pack.playing_cards[2].enhancement='m_stone';pack.playing_cards[2].suit='Spades'
pack.playing_cards[3].enhancement='m_wild';for _,c in ipairs(pack.playing_cards)do c.face_down=true end
local fp=A.snapshot.fingerprint(pack)
for _,key in ipairs({'j_sly','j_trio'})do
 local p=Adapter.pack_start(A,pack,key)
 check(p.dollars==6 and #p.jokers==3 and p.jokers[3].key==key,'Free pack endpoint preserves dollars and acquired row')
 check(p.hands_left==4 and p.discards_left==3 and p.hands_played==0 and p.discards_used==0 and p.chips==0,'New blind counters reset')
 check(p.teacher_profile==pack.teacher_profile and p.hands_played_total==12 and p.hands.Pair.played==8 and p.hands.Pair.played_this_round==0,'Teacher and permanent history retained')
 check(p.blind.key=='bl_goad'and p.blind.chips==600 and #p.hand==0 and #p.deck==26,'Exact known blind startup')
 local map={};for _,c in ipairs(p.playing_cards)do map[c.id]=c;check(not c.face_down,'Known card backs become face-up')end
 check(map.hand1.debuff and not map.hand2.debuff and map.hand3.debuff,'Goad debuffs Spades and Wild; Stone immune')
end
check(A.snapshot.fingerprint(pack)==fp,'Pack startup pure')
local diagnostic=Adapter.run(A,{mode='pack_diagnostic',snapshot=pack,case='invented-pack'})
check(diagnostic.input_unchanged and diagnostic.evaluations<=50000,'Actual paired shop comparison respects cap and input purity')
bad=C(pack);bad.consumeables={{key='c_pluto'}};reject(function()Adapter.pack_start(A,bad,'j_sly')end,'Unmodeled Perkeo closure rejected')
bad=C(pack);bad.next_blind.key='bl_house';reject(function()Adapter.pack_start(A,bad,'j_sly')end,'Unqualified blind rejected')
bad=C(pack);bad.modifiers.minus_hand_size_per_X_dollar=5;reject(function()Adapter.pack_start(A,bad,'j_sly')end,'Resource-changing startup rejected')
bad=C(pack);bad.pack_cards[1].ability.rental=true;reject(function()Adapter.pack_start(A,bad,'j_sly')end,'Sticker rejected')
-- Actual unmodified Decision parity and input-order isolation.
local admission=Adapter.admission(A,s);local direct=A.decision.run(canon,A,nil,nil)
check(A.player_journal.encode(admission.default)==A.player_journal.encode(direct.action),'Adapter matches actual current Decision on manufactured public snapshot')
check(admission.admitted and #admission.five.indices==5,'Manufactured complete first action admitted')
bad=C(s);bad.deck={};for i=#s.deck,1,-1 do bad.deck[#bad.deck+1]=C(s.deck[i])end
local again=Adapter.admission(A,bad)
check(A.player_journal.encode(admission.default)==A.player_journal.encode(again.default),'Private composition order cannot affect first policy decision')
local mock={};for k,v in pairs(A)do mock[k]=v end
mock.decision={run=function()return {action={kind='discard',indices={1,2}},evaluations=0,
 discard_comparison_complete=true,discard_alternatives={
 {indices={1,2,3,4,5},count=4,probability=0.5,value=20},
 {indices={2,3,4,5,6},count=4,probability=0.75,value=10}}}end}
local ranked=Adapter.admission(mock,s);check(ranked.five.indices[1]==1,'Existing value controls nonterminal admission')
local last=C(s);last.hands_left=1;ranked=Adapter.admission(mock,last)
check(ranked.five.indices[1]==2,'Last-hand probability precedes value')
mock.decision={run=function()return {action={kind='discard',indices={1,2}},discard_comparison_complete=false,
 discard_alternatives={{indices={1,2,3,4,5},count=4,probability=1,value=100}}}end}
check(not Adapter.admission(mock,s).admitted,'Incomplete family never admitted')
local r=Adapter.run(A,input(s,admission));local repeated=Adapter.run(A,input(s,admission))
check(A.player_journal.encode(r)==A.player_journal.encode(repeated),'Fixed world and policy reproduce full trace')
check(r.input_unchanged and r.status=='supported_clear'and r.discards==3,'Actual teacher continuation uses available discards and clears')
check(r.cards_discarded>=13 and r.five_card_discards>=2 and r.final_resources_supported,'Real full-five volume and resource endpoints recorded')
local forced=Adapter.run(A,input(s,admission,'five'))
check(A.player_journal.encode(forced.steps[1].card_ids)==A.player_journal.encode(admission.five_ids),'Forced first discard maps exact admitted physical cards')
-- Explicit adapter controls, not policy-improvement evidence.
local function ad_for(t,a)return {admitted=true,default=a,five=a,initial_fingerprint=A.snapshot.fingerprint(Adapter.canonical(t))}end
local t=state();t.discards_left=0;t.jokers={};local play={kind='play',indices={1,2,3,4,5}}
local order={kind='reorder_hand',order={2,1,3,4,5,6,7,8}}
local control=modules_with_actions({play});local z=Adapter.run(control,input(t,ad_for(t,order)))
check(z.status=='supported_clear'and z.steps[2].card_ids[1]=='hand2','Reorder is physically executed before scoring')
t.hand[1].pinned=true;z=Adapter.run(control,input(t,ad_for(t,order)))
check(z.status=='unsupported'and z.reason=='Pinned reorder','Pinned cards cannot be moved')
t=state();t.discards_left=0;t.jokers={};t.consumeables={{id='planet',key='c_pluto',ability={name='Pluto',set='Planet'}}}
local planet=C(t);planet.hand={card('planet-held',13)};planet.hand_size=1;planet.deck={};planet.playing_cards=C(planet.hand)
planet.hands_left=1;planet.blind.chips=40
local chosen=A.decision.run(planet,A,nil,nil)
check(chosen.action and chosen.action.kind=='use'and chosen.action.area=='consumeables','Actual production Decision emits raw use action')
z=Adapter.run(modules_with_actions({{kind='play',indices={1}}}),input(planet,ad_for(planet,chosen.action)))
check(z.status=='supported_clear'and #z.resources.consumables==0,'Actual production consumable action executes deterministic transition')
local identity={kind='reorder_hand',order={1,2,3,4,5,6,7,8}}
z=Adapter.run(modules_with_actions({identity}),input(t,ad_for(t,identity)))
check(z.status=='loop','Repeated physical public state censored')
z=Adapter.run(modules_with_actions({play}),input(t,ad_for(t,{kind='launch_rocket'})))
check(z.status=='unsupported','Unknown actions censored')
local one=input(t,ad_for(t,order));one.action_cap=1;z=Adapter.run(modules_with_actions({play}),one)
check(z.status=='action_cap','Action cap respected')
local burnt=state();burnt.jokers={joker('j_yorick','Yorick',{x_mult=4,yorick_discards=15,extra={discards=23,xmult=1}}),
 joker('j_blueprint','Blueprint',{effect='Copycat'}),joker('j_burnt','Burnt Joker',{extra=4})}
burnt.jokers[3].ability.effect=nil
local growth,ge=A.scoring.after_discard(burnt,{1,2,3,4,5})
check(growth and ge.burnt_levels==2 and growth.jokers[1].ability.yorick_discards==10,'Copied Burnt levels twice; physical Yorick progresses once')
-- Owned Lucky is deliberately outside stochastic transition support.
t=state();t.discards_left=0;t.hand[1].enhancement='m_lucky';t.hand[1].key='m_lucky'
t.hand[1].name='Lucky Card';t.hand[1].ability.name='Lucky Card';t.hand[1].ability.effect='Lucky Card';t.hand[1].ability.mult=20;t.hand[1].ability.p_dollars=20
t.playing_cards[1]=C(t.hand[1]);z=Adapter.run(modules_with_actions({play}),input(t,ad_for(t,play)))
check(z.status=='supported_clear_floor'and z.final_resources_supported==false,'Supported Lucky clearing floor cannot certify final resources')
t.blind.chips=1e12;z=Adapter.run(modules_with_actions({play}),input(t,ad_for(t,play)))
check(z.status=='unsupported'and z.final_resources_supported==false,'Unsupported random nonclear never converted to loss')
check(A.snapshot.fingerprint(s)==original,'All original manufactured inputs unchanged')
return assert(A.player_journal.encode({status='passed',manufactured_assertions=checks,policy_parity=true,
 public_only=true,continuation={status=r.status,discards=r.discards,cards=r.cards_discarded,fives=r.five_card_discards}}))
