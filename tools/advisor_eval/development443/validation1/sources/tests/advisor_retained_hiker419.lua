local F=dofile('tests/fixtures/retained418.lua');local m=F.modules()
if GROWTH419_PATH then m.growth=dofile(GROWTH419_PATH)end
local checks=0;local function check(v,msg)checks=checks+1;assert(v,msg)end
local function state(chad)
 local s=F.state(false);s.blind={key='bl_psychic',name='The Psychic',chips=250};s.joker_limit=5
 local h=F.joker('j_hiker','Hiker',{extra=5});h.ability.effect=nil
 local stencil=F.joker('j_stencil','Joker Stencil',{effect='Hand Size Mult',x_mult=3})
 s.jokers={F.j('j_perkeo'),h,stencil}
 if chad then s.jokers[4]=F.j('j_hanging_chad') end
 F.population(s);return s
end
local function suggest(s,cap)return m.growth.suggest(s,m,F.clear(m,s),{exhaust_discards=true,max_evaluations=cap or 12})end
for _,chad in ipairs({false,true})do
 local s=state(chad);local before=m.snapshot.fingerprint(s);local choice,used=suggest(s)
 check(choice and choice.action.kind=='discard','canonical Hiker/Stencil row can spend safe discards')
 check(used<=12 and m.snapshot.fingerprint(s)==before,'proof is bounded and detached')
 local after=assert(m.scoring.after_discard(s,choice.action.indices));local minimum=math.huge
 F.permutations({1,2,3,4,5},function(order)
  local score=m.scoring.score(after,order).score;minimum=math.min(minimum,score)
  check(score>=choice.play.score,'all120 physical scoring orders respect certified floor')
 end)
 check(minimum==choice.play.score,'published minimum equals independent exhaustive minimum')
 local bad=F.copy(s);bad.jokers[2].ability.extra=6;check(not suggest(bad),'modified Hiker refused')
 bad=F.copy(s);bad.jokers[3].ability.x_mult=.5;check(not suggest(bad),'fractional Stencil state refused')
 bad=F.copy(s);bad.hand[1].edition={polychrome=true};check(not suggest(bad),'card-stage multiplier not smuggled into additive proof')
end
local s=state(false)
for left=3,1,-1 do
 local r=m.decision.run(s,m);check(r.action.kind=='discard','actual final arbitration spends discard '..left)
 check(r.evaluations<=140000 and r.discard_before_clear.evaluations<=12,'ordinary and growth caps unchanged')
 s=assert(m.scoring.after_discard(s,r.action.indices));s=assert(m.draws.fill(s,s.deck));check(s.discards_left==left-1,'fresh physical discard/draw transition')
end
local r=m.decision.run(s,m);check(r.action.kind=='play' and m.scoring.score(s,r.action.indices).score>=s.blind.chips,'real final play clears with zero discards')
-- A smaller already-scored clear frees a full five-card discard even when
-- the incumbent is safe. Single-card probes alone cannot discover this pair.
do
 local x=F.state(false);x.blind={key='bl_big',name='Big Blind',chips=1}
 x.jokers={F.j('j_yorick'),F.j('j_perkeo')};x.hand={}
 for i,r in ipairs({13,13,2,3,4,6,8,10})do x.hand[i]=F.card('volume:'..i,r,'Clubs')end
 x.hands={Pair={level=3,played=4,chips=40,mult=4},['High Card']={level=1,played=0,chips=5,mult=1}}
 F.population(x)
 local incumbent=F.clear(m,x,{1,2,3,4,5});local small=F.clear(m,x,{1,2})
 x.blind.chips=(small.score+m.scoring.score(x,{1}).score)/2
 local anchor,d=m.growth.select_clear(x,incumbent,{small},{exhaust_discards=true})
 check(anchor==small and d.changed,'safe incumbent no longer hides a smaller safe scored anchor')
 local choice,work=m.growth.suggest(x,m,anchor,{exhaust_discards=true,max_evaluations=12})
 check(choice and #choice.action.indices==5 and work<=12,'two-card clear enables a full5 discard inside12 calls')
 local old=m.growth.select_clear(x,incumbent,{small},{exhaust_discards=false})
 check(old==incumbent,'non-exhaust profile keeps prior anchor behavior')
 local risk=F.copy(small);risk.glass_loss=1
 check(m.growth.select_clear(x,incumbent,{risk},{exhaust_discards=true})==incumbent,'smaller anchor cannot increase Glass risk')
 -- Burnt may favor a tiny category by heuristic merit; safe volume wins first.
 local burnt=F.joker('j_burnt','Burnt Joker',{extra=4});x.jokers[3]=burnt
 local custom={};for k,v in pairs(m)do custom[k]=v end
 custom.search=setmetatable({hand_growth_value=function(_,hand)return hand=='High Card' and 1000 or 0 end},{__index=m.search})
 choice,work=m.growth.suggest(x,custom,small,{exhaust_discards=true,max_evaluations=12})
 check(choice and #choice.action.indices==5,'safe full discard outranks much higher tiny-Burnt heuristic merit')
 -- Explicit resource protection survives the new cardinality priority.
 x.hand[3].seal='Blue';x.hand[4].enhancement='m_gold';x.hand[4].ability.h_dollars=3
 F.population(x)
 choice=m.growth.suggest(x,custom,small,{exhaust_discards=true,max_evaluations=12})
 if choice then for _,i in ipairs(choice.action.indices)do check(i~=3 and i~=4,'volume does not throw away protected Blue or held Gold')end end
 check(choice and #choice.action.indices==4,'four remaining safe spares beat consuming protected held rewards')
end
-- Chad requires both first-card rotations. If four smaller candidates are
-- checked between the two full batches, the12-call cap hides the safe batch.
do
 local x=F.state(false);x.hand={};x.blind={key='bl_big',name='Big Blind',chips=1}
 x.jokers={F.j('j_yorick'),F.j('j_perkeo'),F.j('j_hanging_chad')}
 x.hands={Pair={level=3,played=4,chips=40,mult=4},['High Card']={level=1,played=0,chips=5,mult=1}}
 for i,r in ipairs({13,13,2,3,4,6,8,10})do
  x.hand[i]=F.card('variant:'..i,r,i<=2 and 'Clubs' or i==3 and 'Spades' or 'Hearts',i==3 and 'm_steel' or nil)
 end
 F.population(x)
 local anchor=F.clear(m,x,{1,2})
 local bad=assert(m.scoring.after_discard(x,{3,4,5,6,7}))
 local good=assert(m.scoring.after_discard(x,{4,5,6,7,8}))
 local low=m.scoring.score(bad,{1,2}).score;local high=m.scoring.score(good,{1,2}).score
 x.blind.chips=(low+high)/2
 check(low<x.blind.chips and high>=x.blind.chips,'independent exact scores distinguish the two full batches')
 local choice,work=m.growth.suggest(x,m,anchor,{exhaust_discards=true,max_evaluations=12})
 check(choice and table.concat(choice.action.indices,',')=='4,5,6,7,8','safe second five-card variant is checked before smaller batches exhaust the allowance')
 check(work<=12 and choice.growth.order_floor.complete and choice.growth.order_floor.members==2,'both first-card rotations are certified inside the unchanged allowance')
end
print('Hiker retained419: '..checks..' manufactured checks passed')
