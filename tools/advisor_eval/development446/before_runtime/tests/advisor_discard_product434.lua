-- Invented finite populations; independent exhaustive card orders/draw sets.
local F=dofile('tests/fixtures/retained418.lua');local m=F.modules()
local T=dofile('tests/fixtures/shop433.lua');local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local function card(id,rank,key)
 local c=F.card(id,rank,'Clubs',key)
 if key=='m_stone'then c.name='Stone Card';c.ability.name=c.name;c.ability.effect=c.name;c.ability.bonus=50 end
 if key=='m_lucky'then c.name='Lucky Card';c.ability.name=c.name;c.ability.effect=c.name;c.ability.mult=20;c.ability.p_dollars=20 end
 return c
end
local function state(key,size)
 local s=F.state(false);s.blind={key='bl_big',name='Big Blind',chips=1};s.hand={};s.deck={};s.consumeables={};s.hand_size=size+5
 for i=1,size do s.hand[i]=card('held434:'..i,13,i==1 and 'm_glass' or 'c_base')end
 for i=1,5 do s.hand[#s.hand+1]=card('spare434:'..i,2+i,'c_base')end
 for i,r in ipairs({2,3,4,8,11,14})do s.deck[i]=card('draw434:'..i,r,i==2 and 'm_steel' or 'c_base')end
 s.jokers={F.j('j_yorick'),F.j('j_perkeo'),T.joker(key)}
 s.hands={['Four of a Kind']={chips=120,mult=12,level=4,played=5},['Five of a Kind']={chips=150,mult=15,level=3,played=6}}
 F.population(s);return s
end
local keys={'j_joker','j_acrobat','j_ride_the_bus','j_green_joker','j_hack','j_square','j_golden','j_campfire','j_hit_the_road'}
for _,key in ipairs(keys)do for _,copied in ipairs({false,true})do for _,edition in ipairs({'base','foil','holo','polychrome'})do
 local s=state(key,5);local j=s.jokers[3]
 if edition~='base'then j.edition=edition=='foil' and {foil=true,chips=50} or edition=='holo' and {holo=true,mult=10} or {polychrome=true,x_mult=1.5}end
 if copied then s.jokers[4]=F.j('j_blueprint');s.jokers[3],s.jokers[4]=s.jokers[4],s.jokers[3]end
 if key=='j_campfire' or key=='j_hit_the_road'then j.ability.x_mult=2.5 end
 local indices={1,2,3,4,5};local clear=m.scoring.lower_bound(s,indices);clear.indices=indices;s.blind.chips=clear.score*0.4
 local before=m.snapshot.fingerprint(s)
 local r,work=m.growth.suggest(s,m,clear,{exhaust_discards=true,max_evaluations=12,skip_singleton_probes=true})
 check(r and #r.action.indices==5,'five-card product floor '..key..'/'..edition)
 check(work<=12 and r.growth.order_floor.scope=='canonical_card_product_floor','complete algebraic floor fits original budget')
 local after=assert(m.scoring.after_discard(s,r.action.indices))
 for excluded=1,6 do
  local future=F.copy(after);future.deck={F.copy(s.deck[excluded])}
  for i,c in ipairs(s.deck)do if i~=excluded then future.hand[#future.hand+1]=F.copy(c)end end
  F.permutations(r.play.indices,function(order)
   local score=m.scoring.lower_bound(future,order)
   check(score.legal and not score.uncertain and score.score>=r.play.score,'every physical draw/order exceeds certified floor')
  end)
 end
 check(m.snapshot.fingerprint(s)==before,'public state preserved')
 local bad=F.copy(s);bad.jokers[copied and 4 or 3].ability.unknown_callback=1
 check(not m.growth.suggest(bad,m,clear,{exhaust_discards=true,skip_singleton_probes=true}),'modified shape rejected')
end end end
-- Four-card Glass floor, Wild/Stone/Lucky and canonical Foil selected cards.
for _,key in ipairs({'m_wild','m_stone','m_lucky','m_bonus','c_base'})do
 local s=state('j_joker',4);s.hand[2]=card('special434',13,key);s.hand[3].edition={foil=true,chips=50}
 F.population(s);local indices={1,2,3,4};local c=m.scoring.lower_bound(s,indices);c.indices=indices;s.blind.chips=c.score*0.4
 local r=m.growth.suggest(s,m,c,{exhaust_discards=true,skip_singleton_probes=true})
 check(r and #r.action.indices==5,'canonical selected effect admits full discard '..key)
 local after=assert(m.scoring.after_discard(s,r.action.indices))
 F.permutations(r.play.indices,function(order)check(m.scoring.lower_bound(after,order).score>=r.play.score,'all 24 selected orders exceed floor')end)
end
for _,case in ipairs({'mixed_mult','polychrome_card','modified_glass','hidden','paid','budget','card_mult_joker'})do
 local s=state('j_joker',5);local opts={exhaust_discards=true,skip_singleton_probes=true}
 if case=='mixed_mult'then s.hand[2]=card('mult434',13,'m_mult')
 elseif case=='polychrome_card'then s.hand[2].edition={polychrome=true,x_mult=1.5}
 elseif case=='modified_glass'then s.hand[1].ability.x_mult=3
 elseif case=='hidden'then s.hand[1].face_down=true
 elseif case=='paid'then s.modifiers.discard_cost=100
 elseif case=='budget'then opts.max_evaluations=0
 elseif case=='card_mult_joker'then s.jokers[3]=T.joker('j_smiley')end
 F.population(s);local c=m.scoring.lower_bound(s,{1,2,3,4,5});c.indices={1,2,3,4,5}
 check(not m.growth.suggest(s,m,c,opts),'unsafe product rejected '..case)
end
for _,key in ipairs({'j_green_joker','j_blue_joker'})do
 local s=state(key,5);local c=m.scoring.lower_bound(s,{1,2,3,4,5});c.indices={1,2,3,4,5}
 local r,_,d=m.growth.suggest(s,m,c,{exhaust_discards=true,skip_singleton_probes=true})
 check(r and d.two_discard_scope=='unqualified','single exact debit never claims neutral second-step scope '..key)
end
-- Activate the timing/rank/hand-size mechanisms that the broad King matrix
-- intentionally leaves inert, then independently enumerate every played order.
for _,key in ipairs({'j_hack','j_acrobat','j_square'})do
 local size=key=='j_square' and 4 or 5;local s=state(key,size)
 if key=='j_hack'then for i=1,size do s.hand[i]=card('hack434:'..i,3,i==1 and 'm_glass' or 'c_base')end end
 if key=='j_acrobat'then s.hands_left=1 end
 F.population(s);local indices={};for i=1,size do indices[i]=i end
 local c=m.scoring.lower_bound(s,indices);c.indices=indices;s.blind.chips=c.score*0.5
 local inactive=F.copy(s);inactive.jokers[3].debuff=true
 check(c.score>m.scoring.lower_bound(inactive,indices).score,'oracle actually activates '..key)
 local r=m.growth.suggest(s,m,c,{exhaust_discards=true,skip_singleton_probes=true})
 check(r and #r.action.indices==5,'active mechanism retains full-five proof '..key)
 local after=assert(m.scoring.after_discard(s,r.action.indices))
 F.permutations(r.play.indices,function(order)check(m.scoring.lower_bound(after,order).score>=r.play.score,'active mechanism order floor '..key)end)
end
for _,copied in ipairs({false,true})do
 local s=state('j_hit_the_road',2);s.blind={key='bl_wheel',name='The Wheel',chips=1}
 if copied then s.jokers[4]=s.jokers[3];s.jokers[3]=F.j('j_blueprint')end
 for i=3,#s.hand do s.hand[i].face_down=true end;F.population(s)
 local r,_,d=m.growth.visible_retained(s,m,12)
 check(not d.hidden_discard_scope,'hidden Road growth never mislabeled identity independent')
 if r then for _,i in ipairs(r.action.indices)do check(i<=2,'hidden Jack-dependent slot protected')end end
end
print('Discard product434: '..n..' manufactured assertions passed')
