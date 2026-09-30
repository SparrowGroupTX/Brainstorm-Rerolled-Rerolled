local Search=dofile('Brainstorm/Advisor/search.lua');local S=dofile('Brainstorm/Advisor/scoring.lua')
local F=dofile('tests/fixtures/repair416.lua');local A=dofile('tests/fixtures/modules436.lua')
local checks=0;local function check(v,m)checks=checks+1;assert(v,m)end
local function c(size,id)local r={indices={},id=id};for i=1,size do r.indices[i]=i end;return r end
local prior,a,b,five=c(3,'prior'),c(1,'leader'),c(2,'runnerup'),c(5,'five')
local ranked={a,b,prior,five};local old=Search.resource_discard_candidates(ranked,prior,false)
check(#old==3 and old[1]==prior and old[2]==a and old[3]==b,'Control reproduces three smaller discard branches')
local selected=Search.resource_discard_candidates(ranked,prior,true)
check(#selected==3 and selected[1]==prior and selected[2]==a and selected[3]==five,'Full-five admission preserves actual prior/leader and cap')
selected=Search.resource_discard_candidates({five,a,b},prior,true)
check(#selected==3 and selected[1]==prior and selected[2]==five,'Already represented five is not duplicated')
local function branch(kind,values)
 local r={kind=kind,worlds={},wins=0,utility=0}
 for i,v in ipairs(values)do local win=v==1 and 1 or 0;r.worlds[i]={utility=v,win=win};r.wins=r.wins+win;r.utility=r.utility+v end
 r.value=.7*r.utility/#values+.3*r.wins/#values;return r
end
local before=branch('discard',{1,.8,.3,.2});local cross=branch('play',{.9,1,.5,.4})
check(cross.wins==before.wins and cross.value>before.value+.04,'Crossed fixture reaches actual meaningful-gain override threshold')
local state=F.state();state.jokers={F.joker('j_yorick','Yorick',{x_mult=2})}
check(not Search.resource_override_supported(state,before,cross),'Active teacher Yorick cannot lose a prior clearing world when future discards omitted')
check(Search.resource_override_supported(state,before,branch('play',{1,.9,.4,.3})),'Actual per-world dominance remains admissible')
state.discards_left=1;check(Search.resource_override_supported(state,before,cross),'Single-discard prior contract retained')
state.discards_left=3;state.teacher_profile=nil;check(Search.resource_override_supported(state,before,cross),'Nonteacher owned policy unchanged')
state.teacher_profile='perkeo_yorick_win_v1';state.jokers[1].debuff=true
check(Search.resource_override_supported(state,before,cross),'Debuffed growth engine does not enter new scope')

-- A finite two-play toy separates immediate score from cumulative survival.
-- Discarding five yields40 then80; smaller discards yield90 then0. The real
-- Search kernel must actually compare and select the weaker-immediate five.
local s=F.state();s.hands_left=2;s.hand_size=8;s.blind.chips=100;s.hand={};s.deck={};s.jokers={}
for i=1,8 do s.hand[i]=F.card('h'..i,2+i)end
for i=1,18 do s.deck[i]=F.card('d'..i,13)end;F.population(s)
local calls=0
local toy={classify=S.classify,after_discard=function(t,ix)
 local out,e=S.after_discard(t,ix);if out then out.toy_discard_count=#ix end;return out,e
end}
function toy.score(t,ix)
 calls=calls+1;local n=t.toy_discard_count;local later=(t.hands_played or 0)>0
 local score=n==5 and (later and 80 or 40)or n and (later and 0 or 90)or 10
 return {score=score,legal=true,uncertain=false,warnings={},hand='High Card',scoring_indices={ix[1]}}
end
function toy.after_play(t,ix)
 local p=toy.score(t,ix);local out=F.copy(t);out.chips=out.chips+p.score;out.hands_left=out.hands_left-1
 out.hands_played=(out.hands_played or 0)+1;local remove={};for _,i in ipairs(ix)do remove[i]=true end
 out.hand={};for i,card in ipairs(t.hand)do if not remove[i]then out.hand[#out.hand+1]=F.copy(card)end end
 return out,{},p
end
local options={samples=4,candidates=5,max_evaluations=140000,resource_samples=4,resource_horizon=2,future_clear=false}
local original=Search.resource_discard_candidates
Search.resource_discard_candidates=function(r,p)return original(r,p,false)end
local missed=Search.run(s,toy,options)
Search.resource_discard_candidates=original;calls=0
local fixed=Search.run(s,toy,options)
check(missed.resource_comparison and missed.resource_comparison.best.probability==0,'Old admission misses the only two-play clear')
check(fixed.resource_comparison and fixed.resource_comparison.best.probability==1,'Newly admitted five completes in every same draw world')
check(fixed.kind=='discard'and #fixed.discard.indices==5,'Real final Search arbitration selects stronger cumulative five')
check(#fixed.resource_comparison.compared_discards<=3 and fixed.evaluations<=140000,'No branch or score-budget increase')
check(calls==fixed.evaluations,'Every toy score/final transition charged exactly once')
-- Actual vanilla negative control: tied continuation means must not displace a
-- prequalified full discard. The old diagnostic best alone was not an override.
local t=F.state();t.hand={};t.deck={};t.hand_size=8;t.blind.chips=100
for i=1,8 do t.hand[i]=F.card('k'..i,13)end;for i=1,18 do t.deck[i]=F.card('p'..i,13)end
t.jokers={F.joker('j_yorick','Yorick',{x_mult=2,yorick_discards=15,extra={discards=23,xmult=1}})};F.population(t)
local r=Search.run(t,S,{strategy=A.strategy,draws=A.draws,sampled_outcomes=A.sampled_outcomes,
 samples=24,candidates=16,max_evaluations=140000,fast_clear=false,win_first_yorick_clear_discard=true})
check(r.kind=='discard'and #r.discard.indices==5,'Tied survival preserves qualified discard preference')
print('Discard policy437: '..checks..' checks passed')
