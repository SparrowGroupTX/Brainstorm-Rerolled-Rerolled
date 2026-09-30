local F=dofile('tests/fixtures/retained418.lua');local m=F.modules()
if ADVISOR418_ROOT then m.growth=dofile(ADVISOR418_ROOT..'growth.lua') end
local checks=0;local function check(v,msg)checks=checks+1;assert(v,msg)end
local function suggest(s,cap)
 return m.growth.suggest(s,m,F.clear(m,s),{exhaust_discards=true,max_evaluations=cap or 12})
end
local s=F.state(false);local before=m.snapshot.fingerprint(s)
local choice,work=suggest(s)
check(choice and #choice.action.indices==3,'Flower Pot/Even Steven/Greedy retains a required five-card Psychic anchor')
check(work<=12 and m.snapshot.fingerprint(s)==before,'qualification preserves input and proof budget')
local expected=F.clear(m,s).score;local n=0
F.permutations({1,2,3,4,5},function(order)n=n+1;check(m.scoring.score(s,order).score==expected,'all additive physical orders commute')end)
check(n==120,'complete120-member independent family')
s.hand[1].seal='Red';F.population(s)
check(suggest(s),'canonical Red retrigger is additive in this family')
local ordinary=F.copy(s);ordinary.teacher_profile=nil
check(not m.growth.suggest(ordinary,m,F.clear(m,ordinary),{max_evaluations=12}),'nonteacher planner retains its existing reserved-seal boundary')
for _,change in ipairs({function(x)x.jokers[2].ability.extra=0.5 end,
 function(x)x.jokers[3].ability.extra=5 end,function(x)x.jokers[4].ability.extra.s_mult=-3 end,
 function(x)x.jokers[4].ability.extra.suit='Clubs' end,
 function(x)x.hand[2]=F.card('wild',12,'Clubs','m_wild') end,
 function(x)x.jokers[2].edition={negative=true,type='negative',mult=10} end}) do
 local bad=F.copy(s);change(bad);F.population(bad);check(not suggest(bad),'unqualified arithmetic, Wild allocation or mixed edition cannot borrow additive proof')
end

-- The winning first order is not enough: every possible first scorer must clear.
s=F.state(true);before=m.snapshot.fingerprint(s);choice,work=suggest(s)
check(choice and choice.growth.order_floor and choice.growth.order_floor.complete,'Chad produces an explicit complete first-scorer floor')
check(work<=12 and choice.growth.order_floor.members==5,'all five rotations fit existing shared proof cap')
local after=assert(m.scoring.after_discard(s,choice.action.indices));local minimum=math.huge;local maximum=0
F.permutations({1,2,3,4,5},function(order)
 local score=m.scoring.score(after,order).score;minimum=math.min(minimum,score);maximum=math.max(maximum,score)
 check(score>=choice.play.score,'independent120-order oracle dominates the published floor')
end)
check(minimum==choice.play.score and minimum<maximum,'computed minimum is exact and the fixture really has order-sensitive scores')
check(m.snapshot.fingerprint(s)==before,'all first-card probes are detached')
local bad=F.copy(s);bad.blind.chips=6000
check(F.clear(m,bad).score>=6000 and minimum<6000,'favorable order clears but a later adverse first scorer loses')
check(not suggest(bad),'one losing family member vetoes the discard')
local short,spent=suggest(s,9)
check(not short and spent<=9,'incomplete family cannot be promoted when single-card probes leave too little budget')
for _,change in ipairs({function(x)x.jokers[2].ability.extra=3 end,function(x)x.jokers[3].ability.extra.chip_mod=6 end,
 function(x)x.hand[1]=F.card('glass',13,'Clubs','m_glass') end,
 function(x)x.hand[1].edition={polychrome=true,x_mult=1.5} end}) do
 bad=F.copy(s);change(bad);F.population(bad);check(not suggest(bad),'modified repetition/decay or card-stage multiplication stays outside Chad proof')
end
-- Real copies, a non-scoring kicker, debuffed first scorer, Gold and Red.
for mode=1,4 do
 local x=F.state(true);x.blind.chips=1000
 x.jokers={F.j('j_blueprint'),F.j('j_hanging_chad'),F.j('j_yorick'),F.j('j_fortune_teller'),F.j('j_card_sharp')}
 x.hands['Two Pair']={played_this_round=1}
 if mode==1 then x.hand[1].debuff=true end
 if mode==2 then x.hand[2]=F.card('gold',13,'Spades','m_gold') end
 if mode==3 then x.hand[3].seal='Red' end
 if mode==4 then x.jokers[5]=F.j('j_devious') end
 F.population(x);local kept,used=suggest(x)
 check(kept and kept.growth.order_floor and used<=12,'copy/edition/Gold/Red family qualifies')
 local endpoint=assert(m.scoring.after_discard(x,kept.action.indices))
 F.permutations({1,2,3,4,5},function(order)check(m.scoring.score(endpoint,order).score>=kept.play.score,'all copied/debuffed first-scorer identities respect minimum')end)
end

-- Public-only hidden discards: the identity cannot affect any callback or reward.
local function hidden()
 local x=F.state(false);x.blind={key='bl_house',name='The House',chips=2000}
 for i=6,8 do x.hand[i].face_down=true end
 F.population(x);return x
end
s=hidden();before=m.snapshot.fingerprint(s)
local kept,used,proof=m.growth.visible_retained(s,m,12)
check(kept and proof.complete and proof.hidden_discard_scope,'visible straight survives discarding otherwise-inert concealed spares')
check(used<=12 and m.snapshot.fingerprint(s)==before,'public projection is detached and bounded')
for _,i in ipairs(kept.action.indices) do check(i>=6,'visible winning cards stay held') end
local changed=F.copy(s);changed.hand[6],changed.deck[4]=changed.deck[4],changed.hand[6]
changed.hand[6].face_down=true;changed.deck[4].face_down=false
local reverse={};for i=#changed.deck,1,-1 do reverse[#reverse+1]=changed.deck[i] end;changed.deck=reverse;F.population(changed)
local invariant=m.growth.visible_retained(changed,m,12)
check(invariant and m.snapshot.fingerprint(invariant.action)==m.snapshot.fingerprint(kept.action),'hidden assignment and private deck order cannot affect public action')
for _,seal in ipairs({'Purple','Blue','Gold'}) do
 local x=hidden();x.deck[1].seal=seal;F.population(x)
 check(not m.growth.visible_retained(x,m,12),'possible concealed reward cannot be erased for a hidden discard')
end
local x=hidden();x.deck[1]=F.card('gold-deck',2,'Hearts','m_gold');F.population(x)
check(not m.growth.visible_retained(x,m,12),'possible held Gold reward prevents blind resource disposal')
x=hidden();x.hand[6].ability.forced_selection=true;F.population(x)
check(not m.growth.visible_retained(x,m,12),'forced hidden slot cannot be discarded without a legal complete plan')
x=hidden();x.modifiers.discard_cost=1
check(not m.growth.visible_retained(x,m,12),'paid hidden discard fails cash protection')
x=hidden();for _,c in ipairs(x.hand) do c.face_down=true end;F.population(x)
check(not m.growth.visible_retained(x,m,12),'no visible anchor means no concealed retained guarantee')

-- Fresh real modules reconsider every physical discard and clear afterwards.
s=F.state(true)
for left=3,1,-1 do
 local r=m.decision.run(s,m);check(r.action.kind=='discard','production arbitration chooses discard for a Chad-supported clear')
 check(r.discard_before_clear.evaluations<=12 and r.evaluations<=140000,'production charge stays in both caps')
 s=assert(m.scoring.after_discard(s,r.action.indices));s=assert(m.draws.fill(s,s.deck));check(s.discards_left==left-1,'settlement consumes exactly one discard')
end
local r=m.decision.run(s,m);check(r.action.kind=='play' and m.scoring.score(s,r.action.indices).score>=s.blind.chips,'fresh final actual hand clears with zero discards')
print('retained families418: '..checks..' checks passed')

-- Count the same actual score calls through exact-fit and failed preflight.
do
 local raw=m.scoring;local calls=0
 m.scoring=setmetatable({score=function(...)calls=calls+1;return raw.score(...)end,
  lower_bound=function(...)calls=calls+1;return raw.lower_bound(...)end},{__index=raw})
 for _,cap in ipairs({9,10,12}) do
  local x=F.state(true);local c=F.clear(m,x);calls=0
  local kept,used=m.growth.suggest(x,m,c,{exhaust_discards=true,max_evaluations=cap})
  check(calls==used and used<=cap,'first-scorer accounting includes every real scorer call')
  check((kept~=nil)==(cap>=10),'exact complete-family threshold is respected')
 end
 local x=hidden();x.blind.chips=1000000000;calls=0
 local failed=m.decision.run(x,m,nil,{concealed_belief={max_evaluations=25,copy_order=false},search={max_evaluations=25}})
 check(failed.evaluations==calls and calls<=25,'failed visible preflight and concealed fallback share one allowance')
 m.scoring=raw
end

-- Acorn cannot reuse a first-scorer floor for another hidden copy/Joker order.
do
 local x=F.state(true);x.blind={key='bl_final_acorn',name='Amber Acorn',chips=400}
 x.hand[1]=F.card('plain-k',13,'Clubs');x.hand_size=8;F.population(x)
 local row={F.j('j_yorick'),F.j('j_hanging_chad')}
 local b=assert(m.acorn_belief.start(row,'manufactured418',{public_before_shuffle=true}))
 x.public_joker_belief=b;x.jokers={{face_down=true},{face_down=true}}
 local immediate={action={kind='play',indices={1,2,3,4}},immediate_clear_all_worlds=true}
 local kept,used,why=m.acorn_discard.retained(x,b,immediate,m.scoring,m.scoring,m.acorn_belief,m,{max_evaluations=12})
 check(not kept and why.reason=='The complete Joker-order and first-scoring-card family is not qualified.','Acorn explicitly declines the unimplemented product family')
 check(used<=12,'Acorn refusal preserves shared proof cap')
end
print('retained families418 total: '..checks..' checks passed')
