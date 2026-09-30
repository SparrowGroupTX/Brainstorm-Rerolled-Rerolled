-- Invented states only. No captured-state policy/scorer execution.
local F=dofile('tests/fixtures/retained418.lua');local m=F.modules()
if GROWTH423_PATH then m.growth=dofile(GROWTH423_PATH) end
if DECISION423_PATH then m.decision=dofile(DECISION423_PATH) end
local count=0;local function check(v,msg)count=count+1;assert(v,msg)end
local shapes={
 j_lusty_joker={'Lusty Joker',{effect='Suit Mult',extra={s_mult=3,suit='Hearts'}}},
 j_wrathful_joker={'Wrathful Joker',{effect='Suit Mult',extra={s_mult=3,suit='Spades'}}},
 j_gluttenous_joker={'Gluttonous Joker',{effect='Suit Mult',extra={s_mult=3,suit='Clubs'}}},
 j_sly={'Sly Joker',{type='Pair',t_chips=50}},j_clever={'Clever Joker',{type='Two Pair',t_chips=80}},
 j_crafty={'Crafty Joker',{type='Flush',t_chips=80}},
 j_jolly={'Jolly Joker',{type='Pair',t_mult=8,effect='Type Mult'}},
 j_zany={'Zany Joker',{type='Three of a Kind',t_mult=12,effect='Type Mult'}},
 j_mad={'Mad Joker',{type='Two Pair',t_mult=10,effect='Type Mult'}},
 j_crazy={'Crazy Joker',{type='Straight',t_mult=12,effect='Type Mult'}}}
local function joker(key)
 local x=shapes[key];local j=F.joker(key,x[1],F.copy(x[2]));if x[2].t_chips then j.ability.effect=nil end;return j
end
local function state(key)
 local s=F.state(false);s.blind={key='bl_big',name='Big Blind',chips=2000};s.hand={};s.hand_size=8
 for i,r in ipairs({13,13,2,4,6,8,10,12})do s.hand[i]=F.card('made423:'..i,r,'Hearts',i<=2 and 'm_mult' or 'c_base')end
 s.jokers={F.j('j_yorick'),F.j('j_perkeo'),joker(key),F.j('j_fortune_teller'),F.j('j_brainstorm')}
 s.consumeable_usage_total={tarot=9};F.population(s);return s
end
for key in pairs(shapes)do
 local s=state(key);local c=F.clear(m,s,{1,2});s.blind.chips=c.score
 local before=m.snapshot.fingerprint(s);local g,n,d=m.growth.suggest(s,m,c,{exhaust_discards=true})
 check(g and g.action.kind=='discard' and #g.action.indices==5,key..' supports full retained discard: '..table.concat(d.reasons,' / '))
 check(n<=12 and m.snapshot.fingerprint(s)==before,'bounded detached proof '..key)
 local after=assert(m.scoring.after_discard(s,g.action.indices))
 F.permutations(g.play.indices,function(indices)
  local p=m.scoring.score(after,indices);check(p.score==g.play.score,'retained permutations agree '..key)
 end)
 local invalid=F.copy(s);invalid.jokers[3].ability.h_mult=1
 local no=m.growth.suggest(invalid,m,F.clear(m,invalid,{1,2}),{exhaust_discards=true})
 check(not no,'modified held arithmetic rejected '..key)
end
for _,spec in ipairs({{'j_zany',{13,13,13,2,4}},{'j_clever',{13,13,12,12,4}},
 {'j_mad',{13,13,12,12,4}},{'j_crazy',{13,12,11,10,9}},{'j_crafty',{13,11,8,5,2}}})do
 local key=spec[1];local s=state(key)
 for i,r in ipairs(spec[2])do s.hand[i]=F.card('active423:'..i,r,key=='j_crafty' and 'Hearts' or ({'Clubs','Spades','Diamonds','Hearts'})[(i-1)%4+1],'m_mult')end
 F.population(s);local c=F.clear(m,s,{1,2,3,4,5});s.blind.chips=c.score
 local plain=F.copy(s);table.remove(plain.jokers,3)
 check(F.clear(m,plain,{1,2,3,4,5}).score<c.score,'conditional family actually active '..key)
 local g,n,d=m.growth.suggest(s,m,c,{exhaust_discards=true})
 check(g and g.action.kind=='discard' and n<=12,'active category admits retained proof '..key..' '..table.concat(d.reasons,' / '))
 local after=assert(m.scoring.after_discard(s,g.action.indices))
 F.permutations(g.play.indices,function(indices)check(m.scoring.score(after,indices).score==g.play.score,'active-family order invariant '..key)end)
end
-- A mature Yorick previously bypassed pre-development discard arbitration.
-- The exact starting hand already clears, so optional enhancement must wait.
for _,key in ipairs({'j_lusty_joker','j_sly'})do
 local s=state(key);s.jokers[1].ability.x_mult=10;s.ante=6
 s.blind.chips=F.clear(m,s,{1,2}).score
 s.consumeables={{id='empress423',key='c_empress',ability={name='The Empress',set='Tarot',consumeable={max_highlighted=2,mod_conv='m_mult',mod_num=2}}}}
 local initial=m.snapshot.fingerprint(s)
 local r=m.decision.run(s,m,nil,{prepared_scoring=false,search={fast_clear=false,max_evaluations=140000}})
 check(r.action.kind=='discard' and #r.action.indices==5,'production defers optional Empress '..key..': '..tostring(r.action.kind))
 check(r.evaluations<=140000 and (r.discard_preference_work or 0)<=12,'shared production budgets '..key)
 check(m.snapshot.fingerprint(s)==initial,'production does not mutate input '..key)
 -- Refill with invented ordinary cards after each legal discard, then observe
 -- the fresh state. No next-card assumption enters the actual proof.
 for left=2,1,-1 do
  s=assert(m.scoring.after_discard(s,r.action.indices))
  while #s.hand<8 do s.hand[#s.hand+1]=table.remove(s.deck) end
  F.population(s);r=m.decision.run(s,m,nil,{prepared_scoring=false,search={fast_clear=false,max_evaluations=140000}})
  check(s.discards_left==left and r.action.kind=='discard','continues through last discard '..key..' '..left)
 end
end
do
 local s=state('j_sly');s.jokers[3].ability.t_chips=51
 local g=m.growth.suggest(s,m,F.clear(m,s,{1,2}),{exhaust_discards=true});check(not g,'modified type amount remains outside canonical qualification')
 s=state('j_lusty_joker');s.jokers[3].ability.extra.s_mult=3.5
 s.blind.chips=F.clear(m,s,{1,2}).score
 g=m.growth.suggest(s,m,F.clear(m,s,{1,2}),{exhaust_discards=true});check(not g,'fractional card arithmetic excluded')
 s=state('j_sly');s.modifiers.discard_cost=1
 g=m.growth.suggest(s,m,F.clear(m,s,{1,2}),{exhaust_discards=true});check(not g,'paid-discard policy not silently relaxed')
end
print('Discard order423: '..count..' manufactured assertions passed')
