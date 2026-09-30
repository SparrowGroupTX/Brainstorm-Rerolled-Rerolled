-- Mechanical fixture with actual scoring/transitions and a fixed toy draw tape.
-- This is not a captured state, original-source run or terminal validation.
local Finish=dofile('Brainstorm/Advisor/resource_finish.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Draws=dofile('Brainstorm/Advisor/draws.lua')
local Outcomes=dofile('Brainstorm/Advisor/sampled_outcomes.lua')
local Multi=dofile('Brainstorm/Advisor/multi_discard.lua')
local Support=dofile('Brainstorm/Advisor/blind_finishing.lua')
local Rewards=dofile('Brainstorm/Advisor/finish_rewards.lua')
local checks=0
local function check(v,why) checks=checks+1;assert(v,why) end
local function card(id,rank,suit)
  return {id=id,rank=rank,nominal=math.min(rank,10),suit=suit,enhancement='c_base',ability={}}
end
local s={phase='hand',ante=3,hand_size=5,hand_limit=5,hands_left=4,hands_played=0,
  discards_left=3,discards_used=0,blind={key='bl_small',chips=600},chips=0,dollars=9,bankrupt_at=0,
  current_round={},hands={},jokers={},consumeables={},consumable_limit=2,modifiers={},probabilities={normal=1},
  hand={card('h1',13,'Spades'),card('h2',13,'Hearts'),card('h3',13,'Clubs'),
        card('h4',2,'Diamonds'),card('h5',3,'Clubs')},deck={},playing_cards={}}
local ranks={5,7,9,11,13,4,6,8,10,12,2,4,6,8,10,12,3,5,7,9}
local suits={'Diamonds','Spades','Hearts','Clubs'}
for i,r in ipairs(ranks) do s.deck[i]=card(string.format('d%02d',i),r,suits[(i-1)%4+1]) end
for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do s.playing_cards[#s.playing_cards+1]=c end end
local fixed={roll=Outcomes.roll,after_play=Outcomes.after_play}
function fixed.fill(state,deck,scorer,draws,seed,turn,bell)
  local order=Snapshot.copy(deck);table.sort(order,function(a,b) return a.id<b.id end)
  return Outcomes.fill(state,order,scorer,draws,seed,turn,bell)
end
local modules={snapshot=Snapshot,scoring=Scoring,search=Search,draws=Draws,sampled_outcomes=fixed,
  multi_discard=Multi,blind_finishing=Support,finish_rewards=Rewards}
local play=Scoring.score(s,{1,2,3});play.indices={1,2,3}
local result={kind='discard',play=play,discard={indices={4,5}}}
local input=Snapshot.fingerprint(s)
local advice,count,diag=Finish.suggest(s,modules,result)
check(diag.complete,'every old/new schedule and common world completes: '..tostring(diag.reason))
check(#diag.candidates==15,'old nine plans retained beside six repeated-discard plans')
local old_best,repeat_best=0,0;local winning,initial_discards
for _,plan in ipairs(diag.candidates) do
  local repeated=plan.policy=='repeat_early' or plan.policy=='repeat_final'
  if repeated then repeat_best=math.max(repeat_best,plan.probability) else old_best=math.max(old_best,plan.probability) end
  for _,world in ipairs(plan.worlds) do
    check(#plan.worlds==4,'complete common worlds retained')
    if repeated and world.win==1 then winning=world end
    if plan.kind=='discard' and plan.policy=='repeat_early' and world.win==1 then initial_discards=world end
    check(world.discards<=3 and world.discards_left>=0,'exact finite discard resources')
  end
end
print('repeated resource toy: old '..old_best..' / repeated '..repeat_best..' / '..count..' scores / '..diag.classifications..' classifications')
check(old_best==0 and repeat_best==1,'only repeated observed draws preserve the held rank group until the fourth card arrives')
check(diag.best.probability==1,'complete comparison recognizes the useful repeated-draw policy')
check(initial_discards and initial_discards.actions[1].kind=='discard' and initial_discards.actions[2].kind=='discard' and
  initial_discards.actions[3].kind=='discard' and initial_discards.actions[4].kind=='play',
  'new schedule can use the two observed discards after the fixed first discard, before spending any hand')
local later,plays=0,0
for _,a in ipairs(winning.actions) do
  if a.kind=='play' then plays=plays+1 else check(plays>0,'later discards follow the fixed first play');later=later+1 end
end
check(later>=2,'mechanical win requires at least two later observed discards')
check(later==2 and winning.discards_left==1,'repeated schedule stops as soon as the observed legal play reliably clears')
check(winning.actions[#winning.actions].hand=='Four of a Kind','actual scored final category creates the nonlinear threshold crossing')
check(diag.observation_cache_hits>0 and diag.observation_cache_entries<=128,'exact state reuse remains bounded')
check(count<=12000 and diag.classifications<=150000,'unchanged score and classification caps')
check(Snapshot.fingerprint(s)==input,'all cards, cash and inventory preserved in caller')
local none,n,cut=Finish.suggest(s,modules,result,nil,{max_classifications=17})
check(not none and not cut.complete and cut.classifications==17,'classification truncation never selects a favorable partial family')
none,n,cut=Finish.suggest(s,modules,result,nil,{max_evaluations=9})
check(not none and not cut.complete and n==9,'score truncation never selects a favorable partial family')
local paid=Snapshot.copy(s);paid.modifiers.discard_cost=4;paid.dollars=4
local _,_,limited=Finish.suggest(paid,modules,result)
check(limited.complete,'unaffordable optional later discards are not invented')
for _,plan in ipairs(limited.candidates) do for _,world in ipairs(plan.worlds) do
  check(world.discards<=1 and world.dollars_after>=0,'repeated schedule respects the actual borrowing bound after every discard')
end end
local flawed={};for k,v in pairs(Scoring) do flawed[k]=v end
flawed.after_discard=function(state,indices)
  local out,why=Scoring.after_discard(state,indices);if out then out.discards_left=state.discards_left end;return out,why
end
local bad={};for k,v in pairs(modules) do bad[k]=v end;bad.scoring=flawed
none,n,cut=Finish.suggest(s,bad,result)
check(not none and not cut.complete and cut.reason:find('exactly one remaining discard',1,true),'a non-consuming transition cannot create an unbounded repeat')
print('advisor_repeated_resource_discard: '..checks..' checks passed')
