-- Manufactured states only: no captured state, hidden RNG, source or game execution.
local C=dofile('Brainstorm/Advisor/consumables.lua')
local S=dofile('Brainstorm/Advisor/scoring.lua')
local Q=dofile('Brainstorm/Advisor/search.lua')
local Snap=dofile('Brainstorm/Advisor/snapshot.lua')
local n=0;local function check(v,m)n=n+1;assert(v,m)end
local function card(i)return {id='synthetic:'..i,rank=2+i,suit='Clubs',enhancement='c_base',ability={}}end
local function state(count)
 local s={phase='hand',hand={},deck={},playing_cards={},jokers={},consumeables={
 {key='c_empress',ability={name='The Empress',set='Tarot',consumeable={max_highlighted=1}}}},
 hands={},blind={chips=100},chips=0,dollars=20,hands_left=1,discards_left=0,hand_limit=5,
 hand_size=count,modifiers={},current_round={},probabilities={normal=1},consumable_limit=2}
 for i=1,count do s.hand[i]=card(i);s.playing_cards[i]=s.hand[i] end
 return s
end
local prior={kind='play',play={legal=true,uncertain=false,score=10,hand='High Card',indices={1}}}
local function suggest(s,scorer,cap,opts,baseline)
 opts=opts or {};opts.max_evaluations=cap or 100;opts.sequences=false
 return C.suggest(s,scorer,baseline or prior,nil,opts)
end
local calls,bounds=0,0
local scorer={score=function(s,ii)
 calls=calls+1;return {legal=true,uncertain=true,score=ii[1]==1 and 1000 or 150,hand='High Card',warnings={}}
end,lower_bound=function(s,ii)
 calls=calls+1;bounds=bounds+1
 return {legal=true,uncertain=false,score=ii[1]==1 and 20 or 110,hand='High Card',warnings={},reliable_bound=true,bound_kind='supported_random_floor'}
end}
local s=state(2);local fp=Snap.fingerprint(s)
local g,work,d=suggest(s,scorer)
check(g and g.play.score==110 and g.play.indices[1]==2,'lower-mean safe subset survives comparison against a higher mean')
check(g.play.expected_score==150 and g.play.conservative and not g.play.deterministic_exact,'floor and mean remain distinct')
check(g.play.bound_kind=='supported_random_floor' and not g.play.uncertain,'verified floor is supported, not an exact random outcome')
check(work==calls and d.floor_checks==bounds and bounds>0,'all probes charged')
check(Snap.fingerprint(s)==fp,'complete snapshot unchanged')
check(table.concat(g.lines,' '):find('supported minimum',1,true),'advice identifies the floor')
for _,bad in ipairs({'uncertain','unreliable','illegal','nan','infinite','unmodeled','wrong_kind','wrong_hand','low'})do
 local probe={score=scorer.score,lower_bound=function()
 local b={score=110,legal=true,uncertain=false,reliable_bound=true,bound_kind='supported_random_floor',hand='High Card',warnings={}}
 if bad=='uncertain' then b.uncertain=true elseif bad=='unreliable' then b.reliable_bound=false
 elseif bad=='illegal' then b.legal=false elseif bad=='nan' then b.score=0/0
 elseif bad=='infinite' then b.score=math.huge elseif bad=='unmodeled' then b.warnings={'Unmodeled effect'}
 elseif bad=='wrong_kind' then b.bound_kind='supported_random_ceiling' elseif bad=='wrong_hand' then b.hand='Flush' else b.score=99 end
 return b
 end}
 local a=suggest(state(1),probe)
 check(a and a.play.uncertain and not a.play.reliable_bound,'invalid floor does not certify '..bad)
end
calls=0;bounds=0;g,work,d=suggest(state(1),scorer,1)
check(work==1 and bounds==0 and d.floor_coverage=='partial','exact mean-pass cap never borrows a floor call')
check(g and g.play.uncertain,'unsupported mean remains explicitly uncertain under cap')
calls=0;bounds=0;g,work,d=suggest(state(3),scorer,11)
check(work==11 and bounds==4 and d.floor_coverage=='partial','seven means plus at most four floors, no partial mean family')
check(d.floor_total_uncertain==7 and d.floor_limit_per_state==4,'shortlisted scope disclosed')
calls=0;bounds=0;g,work,d=suggest(state(2),scorer,3)
check(work==3 and calls==3 and bounds==0,'last complete mean pass preserved')
local disabled=suggest(state(1),scorer,10,{score_bounds=false})
check(disabled and disabled.play.uncertain,'caller can retain mean-only comparison')
-- A baseline supported floor avoids spending a Tarot for a merely higher mean.
local base={kind='play',play={legal=true,uncertain=true,score=200,hand='High Card',indices={1}}}
local safe={score=scorer.score,lower_bound=function()return {legal=true,uncertain=false,score=120,hand='High Card',
 reliable_bound=true,bound_kind='supported_random_floor',warnings={}}end}
g,work,d=suggest(state(1),safe,10,nil,base)
check(not g and work==1 and d.baseline_floor_score==120,'verified baseline preserves needless targeted consumable')
-- Real Lucky scorer: Pluto raises the floor, while Lucky upside remains uncertain.
s=state(1);s.hand[1].rank=14;s.hand[1].nominal=11;s.hand[1].enhancement='m_lucky';s.hand[1].ability={name='Lucky Card',mult=20,p_dollars=20}
s.consumeables={{key='c_pluto',ability={name='Pluto',set='Planet',consumeable={hand_type='High Card'}}}}
s.blind.chips=50;local p=S.score(s,{1});p.indices={1}
g,work,d=suggest(s,S,20,nil,{kind='play',play=p})
check(g and g.play.bound_kind=='supported_random_floor' and g.play.score>=50,'real scoring verifies Planet rescue beside Lucky upside')
check(g.play.expected_score>g.play.score,'real mean exceeds guaranteed floor')
-- Ordinary search must not prefer a smaller uncertain hand just because both means exceed target.
s=state(2);s.consumeables={};s.discards_left=0
local uncertain={score=function(q,ii)return {score=#ii==1 and 110 or 180,uncertain=true,legal=true,hand='High Card'}end}
local r=Q.run(s,uncertain,{max_evaluations=20,score_bounds=false,fast_clear=false})
check(#r.play.indices==2 and r.play.score==180,'clear-only conservation tie-break cannot suppress stronger uncertain mean')
-- Complete two-use sequence: insufficient floor budget must not publish rescue.
s=state(1);s.consumeables={{key='c_pluto',ability={name='Pluto',set='Planet',consumeable={hand_type='High Card'}}},
 {key='c_empress',ability={name='The Empress',set='Tarot',consumeable={max_highlighted=1}}}}
local sequence_calls=0
local seqscorer={score=function(q,ii)
 sequence_calls=sequence_calls+1
 local upgraded=q.hands['High Card'] and q.hands['High Card'].level>=2
 local enhanced=q.hand[1].enhancement=='m_mult'
 return {score=upgraded and enhanced and 200 or upgraded and 90 or 80,legal=true,uncertain=upgraded and enhanced,hand='High Card'}
end,lower_bound=function(q,ii)
 sequence_calls=sequence_calls+1
 return {score=120,legal=true,uncertain=false,reliable_bound=true,bound_kind='supported_random_floor',hand='High Card'}
end}
g,work,d=C.suggest(s,seqscorer,prior,nil,{max_evaluations=4})
check(g and g.sequence and g.sequence.play.score==120 and g.sequence.play.expected_score==200,'two-use rescue can rely on a verified floor')
check(table.concat(g.lines,' '):find('supported minimum',1,true),'sequence advice distinguishes floor from exact outcome')
check(work==4 and sequence_calls==4 and d.evaluated_sequences==1,'two singles, one full sequence, one charged floor')
sequence_calls=0;g,work,d=C.suggest(s,seqscorer,prior,nil,{max_evaluations=3})
check(not g and work==3 and sequence_calls==3,'without the extra proof call no uncertain sequence is sold as rescue')
check(d.floor_coverage=='partial','sequence floor budget gap disclosed')
print('risk floors368: '..n..' checks passed')
