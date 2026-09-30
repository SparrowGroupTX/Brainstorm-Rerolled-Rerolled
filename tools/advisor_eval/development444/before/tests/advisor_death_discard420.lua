local F=dofile('tests/fixtures/retained418.lua');local m=F.modules()
if GROWTH420_PATH then m.growth=dofile(GROWTH420_PATH)end
if CONSUMABLES420_PATH then m.consumables=dofile(CONSUMABLES420_PATH)end
local checks=0;local function check(v,msg)checks=checks+1;assert(v,msg)end
-- Seltzer repeats every scoring card once, including on its last remaining play.
for _,holo in ipairs({false,true})do for _,chad in ipairs({false,true})do
 local s=F.state(false);s.blind={key='bl_psychic',name='The Psychic',chips=1}
 local sel=F.joker('j_selzer','Seltzer',{extra=1,rental=true});sel.ability.effect=nil
 if holo then sel.edition={holo=true,mult=10,type='holo'}end
 s.jokers={F.j('j_yorick'),F.j('j_blueprint'),sel,F.joker('j_smiley','Smiley Face',{extra=5})}
 if chad then s.jokers[#s.jokers+1]=F.j('j_hanging_chad')end
 local clear=F.clear(m,s);s.blind.chips=clear.score*.5
 local a,n=m.growth.suggest(s,m,clear,{exhaust_discards=true,max_evaluations=12})
 check(a and a.action.kind=='discard' and n<=12,'canonical Seltzer row can use discards within the same allowance')
 local after=assert(m.scoring.after_discard(s,a.action.indices));local minimum=math.huge
 F.permutations(a.play.indices,function(order)
  local score=m.scoring.score(after,order).score;minimum=math.min(minimum,score)
  check(score>=a.play.score,'all physical scoring orders respect Seltzer retained floor')
 end)
 check(minimum==a.play.score,'complete independent order oracle matches the published minimum')
 check(after.jokers[3].ability.extra==1,'discard does not spend Seltzer lifetime')
 local bad=F.copy(s);bad.jokers[3].ability.extra=0
 check(not m.growth.suggest(bad,m,clear,{exhaust_discards=true,max_evaluations=12}),'expired Seltzer contract refused')
 bad=F.copy(s);bad.jokers[3].edition={holo=true,mult=11,type='holo'}
 check(not m.growth.suggest(bad,m,clear,{exhaust_discards=true,max_evaluations=12}),'modified Holo amount refused')
end end
local function death(id)return {id=id,key='c_death',ability={name='Death',set='Tarot',consumeable={mod_conv='card',mod_num=2,max_highlighted=2,min_highlighted=2}}}end
local function prepare()
 local s=F.state(false);s.hand={};s.jokers={F.j('j_yorick')};s.consumeables={death('one'),death('two')}
 s.hands={Straight={level=3,played=6,chips=100,mult=8},Pair={level=8,played=5,chips=200,mult=12},['High Card']={level=1,played=0,chips=5,mult=1}}
 for i,r in ipairs({9,10,11,12,13,2,3,5})do s.hand[i]=F.card('copy:'..i,r,'Clubs',r==13 and 'm_mult' or nil)end
 s.blind={key='bl_big',name='Big Blind',chips=6000};F.population(s)
 return s
end
do
 local s=prepare();local baseline=F.clear(m,s,{1,2,3,4,5});check(baseline.score>=s.blind.chips,'manufactured baseline is a supported five-card clear')
 local decision=m.decision.run(s,m,nil,{search={fast_clear=true}})
 check(decision.consumable and decision.consumable.development.discard_preparation and
  (decision.action.kind=='reorder_hand' or decision.action.kind=='use'),'production arbitration prepares Death instead of settling for a smaller discard')
 check(decision.evaluations<=70 and decision.discard_preference_work<=12 and
  decision.consumable_diagnostics.evaluations<=6,'production total and both local proof allowances remain bounded')
 local a,n,d=m.consumables.develop(s,m.scoring,baseline,{strategy=m.strategy,max_development_evaluations=6,
  arm_cost=m.search.arm_cost,discard_preparation={modules=m,min_count=3,max_evaluations=6}})
 check(a and a.development.discard_preparation and a.development.discard_preparation.cards==5,'legal Death prepares a full five-card discard from a smaller winning pair')
 check(n<=6 and d.discard_preparation_evaluations<=6,'joint proof is charged inside existing development and remaining growth budgets')
 local action=a.action
 if action.kind=='reorder_hand' then
  local fresh=F.copy(s);fresh.hand={};for i,k in ipairs(action.order)do fresh.hand[i]=s.hand[k]end
  s=fresh;baseline=F.clear(m,s,{1,2,3,4,8})
  a=m.consumables.develop(s,m.scoring,baseline,{strategy=m.strategy,max_development_evaluations=6,
   arm_cost=m.search.arm_cost,discard_preparation={modules=m,min_count=3,max_evaluations=6}})
 end
 check(a and a.action.kind=='use','fresh observation publishes Death use only after legal source order')
 local after=assert(m.consumables.apply(s,a.action.index,a.action.targets))
 local r=m.decision.run(after,m)
 check(r.action.kind=='discard' and #r.action.indices==5,'actual refreshed decision takes the prepared five-card discard')
 local receipt=dofile('Brainstorm/Advisor/player_journal.lua').compact_copy_death_review({consumable=a,action=a.action})
 check(receipt.discard_preparation and receipt.discard_preparation.cards==5 and not receipt.discard_preparation.future_draw_assumed,'public receipt reports legal retained proof without a promised draw')
 local bad=prepare();bad.consumeables={death('last')};bad.jokers[2]=F.j('j_perkeo')
 local none=m.consumables.develop(bad,m.scoring,F.clear(m,bad,{1,2,3,4,5}),{strategy=m.strategy,max_development_evaluations=6,
  discard_preparation={modules=m,min_count=3,max_evaluations=6}})
 check(not none,'last valuable Perkeo source is not consumed merely to inflate discard volume')
 for _,change in ipairs({function(x)x.modifiers.discard_cost=1 end,
  function(x)x.hand[5]=F.card('copy:5',13,'Clubs','m_glass');F.population(x)end})do
  local x=prepare();change(x)
  local unsafe=m.consumables.develop(x,m.scoring,F.clear(m,x,{1,2,3,4,5}),{strategy=m.strategy,max_development_evaluations=6,
   discard_preparation={modules=m,min_count=3,max_evaluations=6}})
  check(not unsafe,'paid discard or increased Glass exposure cannot receive a preparation certificate')
 end
 local x=prepare()
 for _,allowance in ipairs({0,1,2})do
  check(not m.consumables.develop(x,m.scoring,F.clear(m,x,{1,2,3,4,5}),{strategy=m.strategy,max_development_evaluations=allowance,
   discard_preparation={modules=m,min_count=3,max_evaluations=6}}),'incomplete bounded preparation never publishes a speculative action')
 end
 local rewards=prepare();rewards.hand={}
 for i,r in ipairs({4,6,8,10,12,13,2,3})do
  rewards.hand[i]=F.card('reward:'..i,r,i<=5 and 'Clubs' or 'Hearts',i==6 and 'm_gold' or nil)
 end
 rewards.hand[6].seal='Blue'
 rewards.hands.Flush={level=5,played=8,chips=180,mult=12}
 F.population(rewards)
 local kept=F.clear(m,rewards,{1,2,3,4,5})
 check(kept.score>=rewards.blind.chips,'held Gold/Blue control starts with an independently verified clear')
 local lost=m.consumables.develop(rewards,m.scoring,kept,{strategy=m.strategy,max_development_evaluations=6,
  discard_preparation={modules=m,min_count=3,max_evaluations=6}})
 check(not lost,'compact Death anchor must not play a previously held Gold or Blue source to claim extra discards')
end
print('Death/discard420: '..checks..' checks passed')
