-- Manufactured public hands only. No captured state, source run, save or RNG.
local D=dofile(ADVISOR_DECISION_PATH or 'Brainstorm/Advisor/decision.lua')
local G=dofile('Brainstorm/Advisor/growth.lua')
local C=dofile('Brainstorm/Advisor/consumables.lua')
local S=dofile('Brainstorm/Advisor/strategy.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function equal(a,b,m)check(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function card(id,rank,suit)
 return {id=id,rank=rank,nominal=rank==14 and 11 or math.min(rank,10),suit=suit or 'Spades',enhancement='c_base',ability={}}
end
local function joker(key,name,ability)
 ability=ability or {};ability.name=name;return {key=key,ability=ability,blueprint_compat=true}
end
local function tarot(key,id)
 return {key=key,id=id,ability={set='Tarot',consumeable={}},edition={negative=true,type='negative'},debuff=false}
end
local function state()
 local s={phase='hand',ante=1,win_ante=8,chips=0,blind={chips=1200},dollars=20,
  hand_limit=5,hand_size=8,hands_left=3,hands_played=0,discards_left=3,discards_used=0,
  current_round={},modifiers={},probabilities={normal=1},hands={},consumable_limit=4,
  hand={card('ace',14),card('two',2,'Hearts'),card('three',3,'Clubs'),card('four',4,'Diamonds'),
   card('five',5,'Hearts'),card('six',6,'Clubs'),card('seven',7,'Diamonds'),card('eight',8,'Hearts')},
  jokers={joker('j_joker','Joker',{mult=100}),
   joker('j_yorick','Yorick',{x_mult=1,yorick_discards=23,extra={discards=23,xmult=1}}),joker('j_perkeo','Perkeo')},
  consumeables={tarot('c_empress','empress1'),tarot('c_empress','empress2')},deck={},playing_cards={}}
 for i=1,20 do s.deck[i]=card('deck'..i,i<=12 and 13 or 9,i%2==0 and 'Hearts' or 'Spades')end
 for _,c in ipairs(s.hand)do s.playing_cards[#s.playing_cards+1]=c end
 for _,c in ipairs(s.deck)do s.playing_cards[#s.playing_cards+1]=c end
 s.hands['Four of a Kind']={level=3,chips=120,mult=13,l_chips=30,l_mult=3,played=9,visible=true}
 return s
end
local function run(s)
 local calls,develop_calls,growth_calls=0,0,0
 local base=Score.score
 Score.score=function(...)calls=calls+1;return base(...)end
 local consumables=setmetatable({develop=function(...)
  develop_calls=develop_calls+1;return C.develop(...)
 end},{__index=C})
 local growth={suggest=function(...)growth_calls=growth_calls+1;return G.suggest(...)end}
 local result=D.run(s,{scoring=Score,strategy=S,search=Search,consumables=consumables,growth=growth})
 Score.score=base
 equal(result.evaluations,calls,'actual scorer work equals reported decision work')
 check(result.evaluations<=70 and result.fast_clear,'production decision retains its bounded fast clear')
 return result,develop_calls,growth_calls
end
do
 local s=state();local before=Snapshot.fingerprint(s)
 local baseline=Search.run(s,Score,{strategy=S})
 check(baseline.fast_clear and baseline.play,'production search finds a known clear')
 local development=C.develop(s,Score,baseline.play,{strategy=S,max_development_evaluations=6,arm_cost=Search.arm_cost})
 check(development and development.action.kind=='use','same opening independently admits useful Empress development')
 local growth=G.suggest(s,{scoring=Score,strategy=S,search=Search,consumables=C},baseline.play,{max_evaluations=12})
 check(growth and growth.action.kind=='discard','same opening independently admits safe Yorick development')
 local r,develop_calls,growth_calls=run(s)
 equal(r.action.kind,'discard','safe Yorick discard takes precedence over optional opening Empress')
 equal(#r.action.indices,5,'full five-card discard is used when the retained clear permits it')
 equal(develop_calls,0,'deferred consumable candidates perform no scorer work')
 equal(growth_calls,1,'growth comparison runs once per observed state')
 check(r.growth and r.growth.action==r.action,'published action carries its exact growth proof')
 local after=assert(Score.after_discard(s,r.action.indices))
 check(Score.score(after,r.growth.play.indices).score>=s.blind.chips*1.05,'reserved physical cards retain the safety margin without a draw')
 equal(after.jokers[2].ability.yorick_discards,18,'exact selected discard contributes five Yorick cards')
 equal(#after.consumeables,2,'all Empress copies remain available after the discard')
 equal(after.consumeables[1].id,'empress1','first physical copy retained')
 equal(after.consumeables[2].id,'empress2','second physical copy retained')
 equal(after.consumable_limit,4,'Negative inventory capacity remains unchanged')
 equal(#after.playing_cards,#s.playing_cards,'discard conserves the full card population')
 equal(Snapshot.fingerprint(s),before,'decision and transitions do not mutate the input')
 -- A fresh manufactured observed hand after one discard, with its ordinary
 -- remaining deck. This is one unit-test transition, not a rollout experiment.
 while #after.hand<after.hand_size and #after.deck>0 do after.hand[#after.hand+1]=table.remove(after.deck,1)end
 local next_result=run(after)
 equal(next_result.action.kind,'discard','a fresh safe observed draw permits another Yorick discard')
 equal(after.discards_left,2,'the previous discard allowance is not renewed')
 after.discards_left=0
 local exhausted,uses=run(after)
 equal(exhausted.action.kind,'use','Empress development remains available after discards are exhausted')
 equal(uses,1,'consumable comparison executes once after growth declines')
end
do
 local s=state();s.jokers[2]=joker('j_burnt','Burnt Joker')
 s.hand={card('ace',14),card('pair1',7,'Hearts'),card('pair2',7,'Clubs'),card('pair3',7),
  card('low1',2,'Hearts'),card('low2',2,'Clubs')};s.hand_size=6
 s.hands.Pair={level=1,chips=10,mult=2,l_chips=15,l_mult=1,played=5}
 s.hands['Three of a Kind']={level=1,chips=30,mult=3,l_chips=20,l_mult=2,played=0}
 s.hands['Full House']={level=12,chips=315,mult=26,l_chips=25,l_mult=2,played=20}
 local r,uses=run(s)
 equal(r.action.kind,'discard','first Burnt discard also precedes optional Empress development')
 check(r.growth.growth.effects.burnt_hand~=nil,'Burnt compares an actual supported discard category')
 equal(uses,0,'Burnt priority does not spend the Empress first')
 s.discards_used=1
 r,uses=run(s)
 equal(r.action.kind,'use','already-spent Burnt trigger cannot defer development')
 equal(uses,1,'inactive Burnt falls through to the ordinary consumable comparison')
end
do
 local s=state();s.jokers[2].debuff=true
 local r=run(s)
 equal(r.action.kind,'use','debuffed Yorick does not block development')
 s=state();s.ante=8;s.blind.boss=true
 r=run(s)
 equal(r.action.kind,'play','final boss clears instead of investing in future discards or Tarot growth')
 s=state();s.modifiers.discard_cost=100
 r=run(s)
 equal(r.action.kind,'use','unaffordable discard investment yields to useful consumable development')
 s=state();s.blind.key='bl_final_bell'
 r=run(s)
 equal(r.action.kind,'use','draw-forcing boss safeguard remains intact')
end
do
 -- Small manufactured collaborators isolate aggregate accounting near the
 -- two existing ceilings. Production policy work is tested above; no search
 -- result is forged to claim a game outcome here.
 for _,ceiling in ipairs({70,140000})do
  for _,remaining in ipairs({0,1,2})do
   local spent,growth_calls,develop_calls=0,0,0
   local growth_budget,development_budget
   local modules={scoring={score=function()spent=spent+1;return {score=2000}end},strategy=S,
    search={run=function()
     local r={kind='play',play={score=2000,indices={1}},evaluations=ceiling-remaining}
     r[ceiling==70 and 'fast_clear' or 'clear_shortcut']={};return r
    end}}
   modules.growth={suggest=function(_,m,_,opts)
    growth_calls=growth_calls+1;growth_budget=opts.max_evaluations
    if opts.max_evaluations<1 then return nil,0,{}end
    m.scoring.score();return {action={kind='discard',area='hand',indices={2,3,4,5,6}},
     growth={kind='discard',effects={yorick_growth=0}}},1,{}
   end}
   modules.consumables={develop=function(_,scorer,_,opts)
    develop_calls=develop_calls+1;development_budget=opts.max_development_evaluations
    if opts.max_development_evaluations<1 then return nil,0,{}end
    scorer.score();return {action={kind='use',index=1,targets={1,2}}},1,{}
   end}
   local r=D.run(state(),modules)
   equal(r.evaluations,ceiling-remaining+spent,'both paths charge every admitted score exactly once')
   check(r.evaluations<=ceiling,'priority never increases the existing aggregate ceiling')
   check(not growth_budget or growth_budget<=remaining,'growth receives only the shared remainder')
   if remaining>0 then
    equal(r.action.kind,'discard','last available proof slot can establish growth before optional development')
    equal(growth_calls,1,'bounded priority comparison is not repeated')
    equal(develop_calls,0,'accepted growth does not spend an unused development allowance')
   else
    equal(spent,0,'exhausted aggregate allowance invokes no scorer')
    equal(r.action.kind,'play','complete incumbent survives an exhausted allowance')
    check(not development_budget or development_budget==0,'consumable development cannot renew an exhausted allowance')
   end
  end
 end
end
do
 local function comparison(s,growth_action,development)
  local spent,growth_calls,develop_calls=0,0,0
  local modules={scoring={score=function()spent=spent+1;return {score=2000}end},strategy=S,
   search={run=function()return {kind='play',play={score=2000,indices={1}},evaluations=0,fast_clear={}}end}}
  modules.growth={suggest=function(_,m,_,opts)
   growth_calls=growth_calls+1;m.scoring.score()
   return growth_action and {action=growth_action,growth={kind='death_cycle'}},1,{}
  end}
  modules.consumables={develop=function(_,scorer)
   develop_calls=develop_calls+1;scorer.score()
   return development and {action={kind='use',index=1,targets={1,2}}},1,{}
  end}
  local r=D.run(s,modules)
  equal(r.evaluations,spent,'failed or deferred growth work remains charged')
  return r,growth_calls,develop_calls
 end
 local r,gc,dc=comparison(state(),nil,true)
 equal(r.action.kind,'use','rejected growth permits the complete consumable candidate')
 equal(gc,1,'unsuccessful priority comparison is not repeated');equal(dc,1,'fallback compares consumables once')
 r,gc,dc=comparison(state(),nil,false)
 equal(r.action.kind,'play','two declined optional investments preserve the clearing play')
 equal(gc,1,'declined growth is not retried after a declined consumable comparison')
 r,gc,dc=comparison(state(),{kind='play',area='hand',indices={2}},true)
 equal(r.action.kind,'use','Death cycling does not gain discard-only priority over an available consumable')
 equal(gc,1,'deferred Death-cycle result is not recomputed');equal(dc,1,'consumable development retains precedence over cycling')
 for _,mode in ipairs({'absent','debuffed','perma_debuffed','expired','spent_burnt','no_discards'})do
  local s=state();local j=s.jokers[2]
  if mode=='absent' then s.jokers[2]=joker('j_juggler','Juggler')
  elseif mode=='debuffed' then j.debuff=true
  elseif mode=='perma_debuffed' then j.ability.perma_debuff=true
  elseif mode=='expired' then j.ability.perishable=true;j.ability.perish_tally=0
  elseif mode=='spent_burnt' then s.jokers[2]=joker('j_burnt','Burnt Joker');s.discards_used=1
  else s.discards_left=0 end
  r,gc,dc=comparison(s,{kind='discard',area='hand',indices={2,3,4,5,6}},true)
  equal(r.action.kind,'use',mode..' cannot activate early discard priority')
  equal(gc,0,mode..' performs no unnecessary growth comparison before accepted development')
  equal(dc,1,mode..' retains its ordinary consumable comparison')
 end
end
print('advisor_growth_priority359: '..checks..' manufactured checks passed')
