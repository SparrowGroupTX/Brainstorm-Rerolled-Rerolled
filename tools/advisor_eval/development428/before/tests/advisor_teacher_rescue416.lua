local F=dofile('tests/fixtures/repair416.lua');local m=F.modules()
local checks=0;local function check(v,msg)checks=checks+1;assert(v,msg)end
local function fixture()
 local s=F.state();s.hand={s.hand[1],s.hand[3],s.hand[4]};s.hand_size=3;s.deck={};s.hands_left=1;s.discards_left=0;s.blind.chips=900
 s.jokers={F.joker('j_yorick','Yorick',{x_mult=1,yorick_discards=18,extra={discards=23,xmult=1}}),F.joker('j_perkeo','Perkeo')}
 s.consumeables={{key='c_judgement',ability={name='Judgement',set='Tarot',consumeable={}}}}
 F.population(s);return s
end
local function suggest(s,cap)
 local base=m.search.run(s,m.scoring,{max_evaluations=1000})
 return m.consumables.suggest(s,m.scoring,base,nil,{strategy=m.strategy,max_evaluations=cap or 25000})
end
local s=fixture();local before=m.snapshot.fingerprint(s)
local use,work,diag=suggest(s)
check(use and use.generator and use.generator.terminal_teacher_override,'last owned generator may rescue a certified otherwise losing teacher hand')
check(diag.generator_ceiling.complete and use.generator.immediate_ceiling<900,'all ordered plays lose even under their supported upper bounds')
check(work==15,'all fifteen ordered selections accounted')
check(use.generator.public_replan and not use.play and not use.generator.probability,'unknown Joker is revealed before fresh scoring')
check(m.snapshot.fingerprint(s)==before,'no imaginary generation or inventory mutation')
s.consumeables[2]=F.copy(s.consumeables[1]);check(suggest(s),'duplicate Judgements do not trigger a blanket Perkeo veto')
for _,change in ipairs({function(x)x.teacher_profile=nil end,function(x)x.hands_left=2 end,function(x)x.discards_left=1 end,
 function(x)x.jokers[3]=F.joker('j_mr_bones','Mr. Bones')end,function(x)x.joker_limit=2 end,
 function(x)x.hand[1].face_down=true end,function(x)x.blind.chips=10 end}) do
 local bad=fixture();change(bad);local result=suggest(bad);check(not result or not result.generator,'teacher waiver cannot bypass survival, legality or visibility prerequisites')
end
check(not suggest(fixture(),14),'partial upper-bound family cannot authorize consuming last stock')
local r=m.decision.run(fixture(),m)
check(r.action.kind=='use' and r.action.index==1,'production arbitration selects the known Judgement use')
local revealed=fixture();revealed.consumeables={};revealed.jokers[3]=F.joker('j_joker','Joker',{mult=100})
local fresh=m.decision.run(revealed,m)
check(fresh.action.kind=='play' and m.scoring.score(revealed,fresh.action.indices).score>=900,'fresh actual revealed Joker enables a separately scored finish')
print('teacher rescue416: '..checks..' checks passed')
