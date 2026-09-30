-- Manufactured current hands only: no captured-state replay, RNG or game I/O.
local C=dofile('Brainstorm/Advisor/consumables.lua')
local S=dofile('Brainstorm/Advisor/strategy.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function equal(a,b,m)check(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function card(rank,id)
 return {id=id,rank=rank,nominal=rank==14 and 11 or math.min(rank,10),suit='Spades',enhancement='c_base',ability={}}
end
local function item(key,id)
 return {key=key,id=id,ability={set='Tarot',consumeable={}},edition={negative=true,type='negative'},debuff=false}
end
local function state()
 local s={phase='hand',ante=2,win_ante=8,chips=0,blind={chips=1000},dollars=20,
  hand_limit=5,hand_size=6,hands_left=3,hands_played=0,discards_left=2,discards_used=0,
  current_round={},modifiers={},probabilities={normal=1},hands={},consumable_limit=4,
  hand={card(14,'ace'),card(13,'king'),card(9,'nine'),card(2,'two'),card(3,'three'),card(4,'four')},
  jokers={{key='j_joker',ability={name='Joker',mult=100}},{key='j_perkeo',ability={name='Perkeo'}}},
  consumeables={item('c_magician','first'),item('c_magician','second')},deck={},playing_cards={}}
 for _,c in ipairs(s.hand)do s.playing_cards[#s.playing_cards+1]=c end
 for rank=5,12 do local c=card(rank,'deck:'..rank);s.deck[#s.deck+1]=c;s.playing_cards[#s.playing_cards+1]=c end
 return s
end
local function baseline(s)
 local p=Score.score(s,{1});p.indices={1};return p
end
local function counted()
 local calls={score=0,floor=0}
 return {score=function(s,indices)calls.score=calls.score+1;return Score.score(s,indices)end,
  lower_bound=function(s,indices)calls.floor=calls.floor+1;return Score.lower_bound(s,indices)end},calls
end
local function develop(s,scorer,cap)
 return C.develop(s,scorer or Score,baseline(s),{strategy=S,max_development_evaluations=cap or 6})
end
do
 local s=state();local fingerprint=Snapshot.fingerprint(s);local scorer,calls=counted()
 local use,work,d=develop(s,scorer)
 check(use and use.action.kind=='use','surplus Magician develops a retained clear without assuming a Lucky trigger')
 equal(table.concat(use.action.targets,','),'1,3','complete two-target action includes Ace and deck-supported rank')
 equal(work,1,'one supported floor replaces one rescore');equal(calls.floor,1,'floor charged once');equal(calls.score,0,'no duplicate mean score')
 check(use.play.reliable_bound and use.play.bound_kind=='supported_random_floor' and use.play.score>=s.blind.chips,
  'published retained score is a supported floor')
 check(use.development.conservative and use.development.deterministic_exact==false,'development labels its conservative proof')
 local after=assert(C.apply(s,use.action.index,use.action.targets))
 equal(#after.consumeables,1,'one physical copy spent');equal(after.consumeables[1].id,'second','last template retained')
 equal(after.consumable_limit,3,'Negative capacity removed exactly once')
 equal(after.hand[1].enhancement,'m_lucky','first target developed');equal(after.hand[3].enhancement,'m_lucky','second target developed')
 equal(#after.playing_cards,#s.playing_cards,'population count unchanged')
 equal(Score.lower_bound(after,{1}).score,baseline(s).score,'no Lucky activation is needed to finish')
 equal(Snapshot.fingerprint(s),fingerprint,'original state and inventory remain unchanged')
 check(not develop(after),'last useful Magician is preserved for Perkeo')
end
do
 local s=state();s.jokers[#s.jokers+1]={key='j_misprint',ability={name='Misprint',extra={min=0,max=23}}}
 check(baseline(s).uncertain,'manufactured mean score is uncertain')
 local scorer,calls=counted();local use,work,d=develop(s,scorer)
 check(use and d.baseline_floor_verified,'uncertain mean requires a separately verified baseline floor')
 equal(work,2,'baseline and changed floors share the six-call allowance');equal(calls.floor,2,'both floors are charged')
 scorer,calls=counted();local result,n=C.suggest(s,scorer,{play=baseline(s)},nil,{strategy=S,max_evaluations=2,max_development_evaluations=6})
 check(result and result.action.kind=='use','ordinary suggestion entry reaches safe surplus development')
 equal(n,2,'ordinary allowance covers both proof calls');equal(calls.floor+calls.score,2,'work accounting matches actual calls')
 for cap=0,1 do
  scorer,calls=counted();local no,cost=develop(s,scorer,cap)
  check(not no,'insufficient complete proof budget declines');equal(cost,cap,'bounded attempted proof accounting')
  equal(calls.floor+calls.score,cap,'no score call above cap')
 end
end
do
 local s=state();s.jokers[1].ability.mult=0
 s.jokers[#s.jokers+1]={key='j_misprint',ability={name='Misprint',extra={min=0,max=23}}};s.blind.chips=150
 check(baseline(s).score>=150 and Score.lower_bound(s,{1}).score<150,'average clear is not a supported floor clear')
 local scorer,calls=counted();local no,work=develop(s,scorer)
 check(not no,'high uncertain average cannot justify development');equal(work,1,'failed baseline floor is still charged')
 scorer,calls=counted();local result,n,d=C.suggest(s,scorer,{play=baseline(s)},nil,{strategy=S,max_evaluations=1,max_development_evaluations=6})
 check(not result and d.truncated,'ordinary fallback remains bounded after failed floor proof')
 equal(n,1,'fallback includes failed proof work');equal(calls.floor+calls.score,1,'fallback cannot renew its allowance')
end
do
 local s=state();local scorer,calls=counted()
 scorer.lower_bound=function()calls.floor=calls.floor+1;return {legal=true,score=1000000,uncertain=true,reliable_bound=false,bound_kind='supported_random_floor'}end
 check(not develop(s,scorer),'unsupported floor cannot become a development proof')
 scorer.lower_bound=function()return {legal=true,score=1000000,uncertain=false,reliable_bound=false,bound_kind='supported_random_floor'}end
 check(not develop(s,scorer),'explicit unsupported receipt is rejected even with a high score')
 scorer.lower_bound=function()return {legal=true,score=math.huge,uncertain=false,reliable_bound=true,bound_kind='supported_random_floor'}end
 check(not develop(s,scorer),'nonfinite floor is not a valid clear')
 scorer,calls=counted();scorer.lower_bound=function()calls.floor=calls.floor+1;return nil end
 local no,n=develop(s,scorer)
 check(not no,'absent floor result declines');equal(n,1,'failed floor call is charged')
 equal(calls.floor,1,'absent floor attempted once');equal(calls.score,0,'absent floor never triggers an uncharged mean fallback')
 local missing={score=Score.score}
 check(not develop(s,missing),'missing floor API retains earlier Lucky uncertainty rejection')
 s.consumeables={item('c_empress','one'),item('c_empress','two')}
 check(develop(s,missing),'ordinary deterministic Empress development remains supported without floor API')
 s.jokers[#s.jokers+1]={key='unknown_callback',ability={name='Unknown callback'}}
 check(not develop(s),'unknown scoring mechanics remain unsupported')
end
do
 local s=state();s.consumeables={item('c_justice','glass1'),item('c_justice','glass2')}
 s.hand={s.hand[1]}
 check(not develop(s),'additional scoring Glass exposure remains forbidden')
 s=state();s.hand[3].ability.forced_selection=true;s.consumeables[1].ability.consumeable.max_highlighted=1
 local scorer,calls=counted();local opts={strategy=S,arm_cost=function(_,hand)return hand=='High Card' and 1 or 0 end}
 local b=Score.score(s,{1,3});b.indices={1,3};local use,work=C.develop(s,scorer,b,opts)
 check(use and use.action.targets[1]==3 and #use.action.targets==1,'forced selection and reduced legal target count remain respected')
 s.consumeables[1].ability.consumeable.mod_conv='m_glass'
 check(not C.develop(s,scorer,b,opts),'modified consumable transformation remains unsupported')
 s=state();s.ante=8;s.blind.boss=true
 check(not develop(s),'final boss does not invest in future deck development')
end
do
 -- Equal permanent enhancement gains use card suitability, not current hand
 -- order. This is a heuristic tie-break, never a universal rank prescription.
 local s=state();s.hand={card(2,'low'),card(3,'low2'),card(14,'high'),card(13,'face')};s.playing_cards=s.hand;s.deck={}
 s.consumeables={item('c_empress','one'),item('c_empress','two')};s.jokers={}
 local targets=S.development_targets(s,s.consumeables[1])
 equal(table.concat(targets,','),'3,4','reversed hand favors higher-value equal-gain cards')
 s.jokers={{key='j_wee',ability={name='Wee Joker',extra={chips=0,chip_mod=8}}}}
 targets=S.development_targets(s,s.consumeables[1])
 check(targets[1]==1,'build-specific value outranks unconditional high-rank preference')
 s.jokers={};s.hand={card(11,'jack'),card(10,'ten'),card(13,'king'),card(12,'queen')};s.playing_cards=s.hand
 targets=S.development_targets(s,s.consumeables[1])
 equal(table.concat(targets,','),'3,4','equal nominal and strategic values use actual rank before hand position')
 s.consumeables[1].key='c_death'
 targets=S.development_targets(s,s.consumeables[1])
 check(targets==nil or #targets==0 or targets[1]<targets[2],'Death retains its directed target contract')
end
print('advisor_surplus_development358: '..checks..' manufactured checks passed')
