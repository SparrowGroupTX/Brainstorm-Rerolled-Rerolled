local A=dofile('tests/fixtures/modules436.lua');local F=dofile('tests/fixtures/repair416.lua')
local Adapter=dofile('tools/advisor_eval/continuation_adapter.lua')
local checks=0;local function check(v,m)checks=checks+1;assert(v,m)end
local kinds={'Pair','Three of a Kind','Two Pair','Straight','Flush'}
local chips={{'sly','Sly Joker',50},{'wily','Wily Joker',100},{'clever','Clever Joker',80},{'devious','Devious Joker',100},{'crafty','Crafty Joker',80}}
local mult={{'jolly','Jolly Joker',8},{'zany','Zany Joker',12},{'mad','Mad Joker',10},{'crazy','Crazy Joker',12},{'droll','Droll Joker',10}}
local xs={{'duo','The Duo','Pair',2,'X1.5 Mult'},{'trio','The Trio','Three of a Kind',3,'X2 Mult'},
 {'family','The Family','Four of a Kind',4,'X3 Mult'},{'order','The Order','Straight',3,'X3 Mult'},{'tribe','The Tribe','Flush',2,'X3 Mult'}}
local cards={}
for i,v in ipairs(chips)do local j=F.joker('j_'..v[1],v[2],{type=kinds[i],t_chips=v[3]});j.ability.effect=nil;cards[#cards+1]=j end
for i,v in ipairs(mult)do cards[#cards+1]=F.joker('j_'..v[1],v[2],{type=kinds[i],t_mult=v[3],effect='Type Mult'})end
for _,v in ipairs(xs)do cards[#cards+1]=F.joker('j_'..v[1],v[2],{type=v[3],x_mult=v[4],effect=v[5]})end
for _,j in ipairs(cards)do
 local s=F.state();s.jokers={F.copy(j),F.joker('j_blueprint','Blueprint',{effect='Copycat'}),F.joker('j_perkeo','Perkeo',{})}
 s.blind={key='bl_final_heart',name='Crimson Heart',crimson_pending=true};local fp=A.snapshot.fingerprint(s)
 local disabled=assert(A.scoring.after_draw(s,{crimson_index=1}))
 check(disabled.jokers[1].debuff and not disabled.blind.crimson_pending,'Canonical type Joker disabled')
 disabled.blind.crimson_pending=true
 local enabled=assert(A.scoring.after_draw(disabled,{crimson_index=3}))
 check(not enabled.jokers[1].debuff and enabled.jokers[3].debuff,'Old debuff restored before new selection')
 check(enabled.hand_size==s.hand_size and enabled.discards_left==s.discards_left and enabled.dollars==s.dollars,'No canonical resource drift')
 check(A.snapshot.fingerprint(s)==fp,'Heart transition detached')
 for _,mutate in ipairs({function(t)t.ability.h_size=2 end,function(t)t.ability.d_size=2 end,
   function(t)t.ability.type=nil end,function(t)t.ability.type='High Card'end,function(t)t.ability.t_mult=999 end,
   function(t)t.key='j_counterfeit'end,function(t)t.ability.name='Counterfeit'end,function(t)t.unknown=true end})do
  local bad=F.copy(s);mutate(bad.jokers[1]);local out=A.scoring.after_draw(bad,{crimson_index=1})
  check(not out,'Malformed conditional effect cannot receive resource support')
 end
 local expired=F.copy(s);expired.jokers[1].ability.perishable=true;expired.jokers[1].ability.perish_tally=0;expired.jokers[1].debuff=true
 local kept=assert(A.scoring.after_draw(expired,{crimson_index=3}));check(kept.jokers[1].debuff,'Expired perishable remains disabled')
end
local selections={}
for _,sorting in ipairs({'rank','suit'})do for _,remaining_count in ipairs({0,1,4,12})do
 local s=F.state();s.blind={key='bl_final_bell',name='Cerulean Bell'};s.hand={s.hand[1],s.hand[2]};s.deck={}
 local ids={};for i=1,remaining_count do local c=F.card('bell:'..i,2+i%12,i%2==0 and 'Clubs'or 'Spades');s.deck[i]=c;ids[i]=c.id end
 F.population(s);local fp=A.snapshot.fingerprint(s)
 for step=1,3 do
  local filled,next_ids=assert(Adapter.refill(A,s,ids,438,step,sorting));local forced={}
  for i,c in ipairs(filled.hand)do if c.ability.forced_selection then forced[#forced+1]=i end end
  check(#forced==1,'Exactly one post-draw forced card')
  local count=2+math.min(remaining_count,s.hand_size-2)
  local expected=math.floor(A.sampled_outcomes.roll(438,step,'bell',0)*count)+1
  local unsorted=expected<=2 and s.hand[expected]or s.deck[expected-2]
  check(filled.hand[forced[1]].id==unsorted.id,'Sorting preserves independent physical Bell selection')
  local other=forced[1]==1 and 2 or 1
  check(not Adapter.legal(filled,{kind='play',indices={other}})and not Adapter.legal(filled,{kind='discard',indices={other}}),'Forced card required for play and discard')
  check(Adapter.legal(filled,{kind='discard',indices={forced[1]}}),'Forced card can be discarded legally')
 end
 s.blind.disabled=true;local disabled=assert(Adapter.refill(A,s,ids,438,1,sorting))
 for _,c in ipairs(disabled.hand)do check(not c.ability.forced_selection,'Disabled Bell does not force')end
 s.blind.disabled=nil;check(A.snapshot.fingerprint(s)==fp,'Bell refill detached')
end end
local empty=F.state();empty.hand={};empty.deck={};empty.blind={key='bl_final_bell',name='Cerulean Bell'}
check(#assert(Adapter.refill(A,empty,{},438,1,'rank')).hand==0,'Empty hand/deck has no invalid forced sample')
print('Heart Bell438: '..checks..' checks passed')
