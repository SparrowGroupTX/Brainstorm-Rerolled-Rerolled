-- Manufactured states only; no captured policy/scorer evaluation or source game.
local D=dofile(ADVISOR_DECISION_PATH or 'Brainstorm/Advisor/decision.lua')
local C=dofile('Brainstorm/Advisor/consumables.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local S=dofile('Brainstorm/Advisor/strategy.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function eq(a,b,m)check(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function state(n)
 local s={phase='hand',ante=4,chips=0,dollars=20,hand={},deck={},playing_cards={},jokers={},
  consumeables={{id='empress',key='c_empress',ability={consumeable={}}}},
  blind={key='bl_serpent',name='The Serpent',chips=1000000},hands={},modifiers={},current_round={},
  probabilities={normal=1},hand_limit=5,hand_size=8,hands_left=3,hands_played=1,
  discards_left=3,discards_used=0,consumable_limit=2}
 for i=1,n do s.hand[i]={id='h'..i,rank=2+(i-1)%13,nominal=math.min(10,2+(i-1)%13),
  suit=({'Spades','Hearts','Clubs','Diamonds'})[(i-1)%4+1],enhancement='c_base',ability={}}
  s.playing_cards[#s.playing_cards+1]=s.hand[i] end
 for i=1,16 do s.deck[i]={id='d'..i,rank=2+(i-1)%13,nominal=math.min(10,2+(i-1)%13),
  suit=({'Hearts','Clubs','Diamonds','Spades'})[(i-1)%4+1],enhancement='c_base',ability={}}
  s.playing_cards[#s.playing_cards+1]=s.deck[i] end
 return s
end
local function cost(n,k)local t,v=1,0;for i=1,math.min(n,k)do t=t*(n-i+1)/i;v=v+t end;return v end
math.random=function()error('uncontrolled RNG')end
pseudorandom=math.random
for n=1,21 do
 local s=state(n);local before=Snapshot.fingerprint(s)
 for _,cap in ipairs({0,1,10,100,25000,50000})do
  local reserve=C.comparison_reserve(s,{max_evaluations=cap})
  eq(reserve,n<=20 and cost(n,5)<=math.min(cap,25000) and math.min(cap,25000) or 0,'reserve admits complete pass '..n..'/'..cap)
 end
 eq(Snapshot.fingerprint(s),before,'capacity check does not mutate input')
end
do
 local s=state(14)
 for _,key in ipairs({'c_unknown','c_judgement','c_emperor','c_high_priestess'})do
  s.consumeables[1].key=key;eq(C.comparison_reserve(s),0,'unsupported/generated outcomes do not reserve')
 end
 s.consumeables[1].key='c_empress';s.consumeables[1].debuff=true;eq(C.comparison_reserve(s),0,'inactive inventory')
 s.consumeables[1].debuff=false;s.consumeables[1].edition={negative=true};eq(C.comparison_reserve(s),25000,'Negative copies count')
 s.consumeables[1].ability.consumeable={min_highlighted=3,max_highlighted=2};eq(C.comparison_reserve(s),0,'impossible target cardinality')
 s.consumeables={};eq(C.comparison_reserve(s),0,'empty inventory')
 s=state(19);s.consumeables[1].key='c_cryptid';eq(C.comparison_reserve(s),0,'enlarged hand must fit complete scope')
 s=state(14);s.phase='shop';eq(C.comparison_reserve(s),0,'shop budget untouched')
 s=state(14);s.consumeables[1].ability.consumeable.mod_conv='m_bonus';eq(C.comparison_reserve(s),0,'modified effect unsupported')
 s=state(14);s.consumeables[1].key='c_pluto';s.consumeables[1].ability.consumeable.min_highlighted=1
 eq(C.comparison_reserve(s),0,'Planet cannot require highlighted targets')
 s=state(14);s.consumeables[1].ability.set='Spectral';eq(C.comparison_reserve(s),0,'modified set unsupported')
 s=state(14);s.consumeables[1].key='c_cryptid';eq(C.comparison_reserve(s),0,'missing deck mutation module')
 local old=C.deck_development;C.deck_development=dofile('Brainstorm/Advisor/deck_development.lua')
 s=state(1);s.consumeables[1].key='c_hanged_man';eq(C.comparison_reserve(s),0,'empty follow-up is not a play pass')
 s=state(14);s.consumeables[1].key='c_hanged_man';s.playing_cards=nil
 eq(C.comparison_reserve(s),0,'incomplete population rejected')
 C.deck_development=old
 s=state(14);s.hand[1].ability.forced_selection=true;s.hand[2].ability.forced_selection=true;s.hand[3].ability.forced_selection=true
 eq(C.comparison_reserve(s),0,'impossible forced targets rejected')
 -- At most eight transitions are inspected and none invokes the scorer.
 s=state(14);s.consumeables[1].ability.consumeable.mod_conv='m_bonus'
 local apply,probes=C.apply,0;C.apply=function(...)probes=probes+1;return apply(...)end
 eq(C.comparison_reserve(s),0,'bounded unsupported preflight');eq(probes,8,'eight-transition bound')
 C.apply=apply
end
-- Exhausting ordinary-search stand-in exercises production consumable selection
-- with real scores, full candidate passes and exact shared call accounting.
do
 local s=state(14);s.hands_left=1;s.discards_left=0;s.blind.chips=1e6
 local p=Score.score(s,{1,2,3,4,5});p.indices={1,2,3,4,5}
 local baseline_best=0;Search.combinations(14,5,function(ids)baseline_best=math.max(baseline_best,Score.score(s,ids).score)end)
 local upgraded=C.apply(s,1,{1});local upgraded_best=0
 Search.combinations(14,5,function(ids)upgraded_best=math.max(upgraded_best,Score.score(upgraded,ids).score)end)
 check(upgraded_best>baseline_best,'manufactured enhancement can improve current complete play family')
 s.blind.chips=upgraded_best;p.score=baseline_best
 local calls,cap=0
 local scorer=setmetatable({score=function(...)calls=calls+1;return Score.score(...)end},{__index=Score})
 local search={run=function(snapshot,scoring,opts)
  cap=opts.max_evaluations or 140000
  for i=1,cap do scoring.score(snapshot,{1})end
  return {kind='play',play=p,evaluations=cap}
 end}
 local before=Snapshot.fingerprint(s)
 local result=D.run(s,{search=search,scoring=scorer,consumables=C})
 eq(cap,115000,'ordinary search leaves existing specialist allowance')
 check(result.consumable and result.consumable.play.score>=s.blind.chips,'reserved complete consumable comparison finds supported clear')
 eq(result.action.kind,'use','publishes supported use')
 check(result.consumable_diagnostics.evaluated_candidates>=1,'at least one complete candidate')
 eq(result.evaluations,calls,'all actual scoring calls charged')
 check(calls<=140000,'total cap remains unchanged')
 eq(Snapshot.fingerprint(s),before,'whole input and inventory preserved')
end
-- Allocation boundary integration without spending the requested score counts.
for _,requested in ipairs({0,1,69,70,100,115000,130000,140000,200000})do
 local s=state(8);local seen
 local search={run=function(_,_,opts)seen=opts.max_evaluations;return nil end}
 local result=D.run(s,{search=search,scoring=Score,consumables=C},nil,{search={max_evaluations=requested}})
 eq(seen,math.min(requested,115000),'caller cap retained '..requested)
 eq(result.kind,'unsupported','nil search result still handled')
end
-- Production clear path stays within 70, and gains no invented future actions.
do
 local s=state(12);local before=Snapshot.fingerprint(s)
 local result=D.run(s,{search=Search,scoring=Score,consumables=C,strategy=S})
 check(result.consumable_diagnostics.evaluated_candidates>0,'production enlarged-hand search leaves complete consumable work')
 eq(result.action.kind,'use','production comparison finds tactical enhancement')
 check(result.consumable.play.score>result.play.score,'selected tactical comparison improves current score')
 check(result.evaluations<=140000,'production ordinary shared cap')
 eq(Snapshot.fingerprint(s),before,'production ordinary leaves public input unchanged')
end
do
 local s=state(8);s.blind={chips=1};s.ante=8;s.blind.boss=true
 local calls=0;local scorer=setmetatable({score=function(...)calls=calls+1;return Score.score(...)end},{__index=Score})
 local result=D.run(s,{search=Search,scoring=scorer,consumables=C,strategy=S})
 check(result.fast_clear,'existing shortlist clear')
 check(result.evaluations<=70 and calls<=70,'fast-clear contract retained')
 eq(result.action.kind,'play','final clear takes win')
end
print('advisor_consumable_reserve360: '..checks..' checks passed')
