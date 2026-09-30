-- Invented mechanics and source-shaped metadata; no captured hand or seed.
local F=dofile('tests/fixtures/repair416.lua');local m=F.modules()
if ADVISOR417_ROOT then m.growth=dofile(ADVISOR417_ROOT..'growth.lua') end
local checks=0;local function check(v,msg)checks=checks+1;assert(v,msg)end
local function cloud()
 local j=F.joker('j_cloud_9','Cloud 9',{extra=1,nine_tally=3,order=73,hands_played_at_create=11,extra_value=0,perma_bonus=0,type='',eternal=true})
 j.ability.effect=nil;j.blueprint_compat=false;return j
end
local function popcorn()
 local j=F.joker('j_popcorn','Popcorn',{extra=4,mult=20,order=97,hands_played_at_create=9,extra_value=0,perma_bonus=0,type=''})
 j.ability.effect=nil;return j
end
local function psychic()
 local s=F.state();s.hand_size=8;s.blind={key='bl_psychic',name='The Psychic',chips=1000}
 s.hand={};for i,r in ipairs({13,12,11,7,3,4,6,8}) do
  s.hand[i]=F.card('invented'..i,r,({'Clubs','Spades','Diamonds','Hearts'})[(i-1)%4+1],i<=3 and 'm_mult' or 'c_base')
  local a=s.hand[i].ability;a.type='';a.extra_value=0;a.perma_bonus=0;a.hands_played_at_create=5
 end
 s.jokers={cloud(),popcorn(),F.joker('j_yorick','Yorick',{x_mult=3,yorick_discards=21,extra={discards=23,xmult=1}}),F.joker('j_perkeo','Perkeo')}
 F.population(s);return s
end
local function clear(s,indices)local c=m.scoring.score(s,indices);c.indices=indices;return c end
local s=psychic();local before=m.snapshot.fingerprint(s);local indices={1,2,3,4,5};local c=clear(s,indices)
check(c.legal and c.score>=1000,'invented five-card Psychic High Card clears')
local kept,work=m.growth.suggest(s,m,c,{exhaust_discards=true,max_evaluations=12})
check(kept and #kept.action.indices==3,'canonical Cloud9/Popcorn row retains five cards and discards all legal spares')
check(work<=12 and m.snapshot.fingerprint(s)==before,'new qualification is detached and bounded')
local after=assert(m.scoring.after_discard(s,kept.action.indices));local expected=m.scoring.score(after,indices).score
local count=0
local function permute(order,used)
 if #order==5 then
  check(m.scoring.score(after,order).score==expected,'all 120 retained physical card orders have the same actual score')
  count=count+1;return
 end
 for i=1,5 do if not used[i] then used[i]=true;order[#order+1]=i;permute(order,used);order[#order]=nil;used[i]=nil end end
end
permute({},{});check(count==120,'complete independent order family')
for n=3,1,-1 do
 local result=m.decision.run(s,m)
 check(result.action.kind=='discard' and result.discard_before_clear.selected,'production decision spends each remaining Psychic discard')
 check(result.evaluations<=140000 and result.discard_before_clear.evaluations<=12,'final arbitration shares score allowance')
 s=assert(m.scoring.after_discard(s,result.action.indices));s=assert(m.draws.fill(s,s.deck))
 check(s.discards_left==n-1,'actual detached settlement consumes one discard')
end
local final=m.decision.run(s,m)
check(final.action.kind=='play' and m.scoring.score(s,final.action.indices).score>=1000,'fresh actual hand clears after all discards')

s=F.state();s.blind={key='bl_flint',name='The Flint',chips=350}
s.hand={};for i,r in ipairs({13,13,10,8,6,4,2}) do s.hand[i]=F.card('flint'..i,r,({'Clubs','Spades','Diamonds','Hearts'})[(i-1)%4+1],i==1 and 'm_mult' or 'c_base') end
s.jokers={F.joker('j_yorick','Yorick',{x_mult=3,yorick_discards=21,extra={discards=23,xmult=1}}),cloud()};F.population(s)
c=clear(s,{1,2});check(c.score>=350,'manufactured Flint pair clears')
for i=1,#s.hand do check(m.scoring.score(s,{i}).score<350,'no one-card shortcut can mask the multi-card admission gap') end
kept,work=m.growth.suggest(s,m,c,{exhaust_discards=true,max_evaluations=12})
check(kept and #kept.action.indices==5 and work<=12,'Cloud9 permits the five-spare discard with a required additive pair')
local r=m.decision.run(s,m);check(r.action.kind=='discard','production Flint path selects the qualified discard')
for _,change in ipairs({function(x)x.jokers[2].ability.extra=2 end,function(x)x.jokers[2].ability.nine_tally=0/0 end,
 function(x)x.jokers[2].ability.h_mult=1 end,function(x)x.jokers[2].edition={holo=true} end,
 function(x)x.jokers[2].key='j_modded_cloud' end}) do
 local bad=F.copy(s);change(bad)
 check(not m.growth.suggest(bad,m,clear(bad,{1,2}),{exhaust_discards=true,max_evaluations=12}),'modified or unqualified row cannot borrow a vanilla additive proof')
end
for _,change in ipairs({function(x)x.jokers[2].ability.extra=2 end,function(x)x.jokers[2].ability.mult=19 end,
 function(x)x.jokers[2].ability.h_x_mult=0.5 end}) do
 local bad=psychic();change(bad)
 check(not m.growth.suggest(bad,m,clear(bad,indices),{exhaust_discards=true,max_evaluations=12}),'modified Popcorn does not enter the canonical arithmetic scope')
end

-- Safe already-scored pair replaces a sorting-sensitive pair with the same
-- resource costs. No extra scores are permitted inside anchor selection itself.
s=F.state();s.hand={F.card('m1',12,'Clubs','m_mult'),F.card('m2',12,'Spades'),F.card('p1',11,'Hearts'),F.card('p2',11,'Diamonds'),F.card('spare',2,'Clubs')};s.hand_size=5
s.jokers={F.joker('j_joker','Joker',{mult=4}),F.joker('j_yorick','Yorick',{x_mult=4,yorick_discards=22,extra={discards=23,xmult=1}})}
s.blind.chips=600;F.population(s)
local incumbent=clear(s,{1,2});local alternative=clear(s,{3,4})
check(incumbent.score>=600 and alternative.score>=600 and m.scoring.score(s,{1}).score<600,'both pairs clear while all single-card shortcuts fail')
local chosen,diag=m.growth.select_clear(s,incumbent,{incumbent,alternative},{exhaust_discards=true})
check(chosen==alternative and diag.changed,'hazardous score-valid incumbent yields to an already-scored safe pair')
local worse=F.copy(alternative);worse.population_cost=1
check(m.growth.select_clear(s,incumbent,{worse},{exhaust_discards=true})==incumbent,'resource regression still blocks the alternative')
local scoped={scoring=m.scoring,strategy=m.strategy,growth=m.growth,search={run=function()
 return {kind='play',play=F.copy(incumbent),alternatives={F.copy(incumbent),F.copy(alternative)},evaluations=2}
end}}
r=m.decision.run(s,scoped)
check(r.action.kind=='discard' and r.growth_anchor_diagnostics.changed,'final production arbitration executes the safer scored anchor route')
for _,i in ipairs(r.action.indices) do check(i~=3 and i~=4,'safe physical pair stays held') end
check(r.evaluations<=14 and r.discard_before_clear.evaluations<=12,'selection adds no hidden score work')

-- Bell remains a legal-selection constraint, not an elective unhighlight.
s=psychic();s.blind={key='bl_final_bell',name='Cerulean Bell',chips=100};s.hand[1].ability.forced_selection=true;F.population(s)
check(not m.scoring.after_discard(s,{6,7,8}),'actual Bell transition refuses a discard that omits the forced card')
r=m.decision.run(s,m);check(r.action.kind=='play' and r.discard_before_clear.status=='exception','no unsupported promise to keep a forced winning card')
print('retained scope417: '..checks..' checks passed')
