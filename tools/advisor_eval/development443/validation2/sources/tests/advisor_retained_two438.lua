-- Invented marginal clear; no captured state or saved game is executed.
local A=dofile('tests/fixtures/modules436.lua');local F=dofile('tests/fixtures/repair416.lua')
local checks=0;local function check(v,m)checks=checks+1;assert(v,m)end
local function state()
 local s=F.state();s.hand_size=8;s.hand={};s.deck={};s.ante=6
 for i,r in ipairs({13,13,12,12,2,4,6,8})do
  s.hand[i]=F.card('invented:h'..i,r,i%2==0 and 'Spades'or 'Clubs',i==1 and 'm_mult'or i==2 and 'm_glass'or nil)
 end
 for i,r in ipairs({2,3,5,7,9,10})do s.deck[i]=F.card('invented:d'..i,r,'Hearts',i==2 and 'm_steel'or nil)end
 s.hands.Pair={chips=60,mult=10,level=4,played=1,played_this_round=0}
 s.jokers={F.joker('j_yorick','Yorick',{x_mult=4,yorick_discards=12,extra={discards=23,xmult=1}}),
  F.joker('j_brainstorm','Brainstorm',{effect='Copycat'}),F.joker('j_blue_joker','Blue Joker',{extra=2})}
 s.jokers[3].ability.effect=nil
 s.blind={key='bl_final_vessel',name='Violet Vessel',boss=true,chips=1,debuff={}}
 F.population(s)
 local p=A.scoring.score(s,{1,2});p.indices={1,2};s.blind.chips=p.score
 return s,p
end
local s,p=state();local before=A.snapshot.fingerprint(s)
local old,oldwork=A.growth.suggest(s,A,p,{exhaust_discards=true,max_evaluations=12})
check(not old,'Same-hand draw/order floor misses the manufactured finish')
local g,n,d=A.growth.suggest_portfolio(s,A,p,{}, {exhaust_discards=true,max_evaluations=12})
check(g and g.action.kind=='discard'and #g.action.indices==4,'Disjoint held pairs admit four discarded cards')
check(n<=12 and g.growth.two_play.complete and #g.growth.two_play.members==4,'All four order pairs fit the shared cap')
check(g.growth.two_play.first_draws==4 and g.growth.two_play.second_draws==2,'Both Blue Joker draw debits charged')
check(g.growth.two_play.additional_play_cost>=7,'Extra hand reward and action cost are priced')
check(A.snapshot.fingerprint(s)==before,'Proof leaves full input unchanged')
local receipt=g.growth.two_play
local first_ids,second_ids={},{}
for _,i in ipairs(receipt.retained_original_indices)do first_ids[s.hand[i].id]=true end
for _,i in ipairs(receipt.second_original_indices)do second_ids[s.hand[i].id]=true end
local function indices(st,ids,reverse)
 local ix={};for i,c in ipairs(st.hand)do if ids[c.id]then ix[#ix+1]=i end end
 if reverse then ix[1],ix[2]=ix[2],ix[1]end;return ix
end
-- Every replacement set from six invented cards, both orders of both anchors,
-- and both first-play Glass outcomes. New Steel may help; it is never required.
for a=1,6 do for b=a+1,6 do for c=b+1,6 do for e=c+1,6 do
 local chosen={[a]=true,[b]=true,[c]=true,[e]=true};local order={}
 for i=1,6 do if chosen[i]then order[#order+1]=s.deck[i]end end
 for i=1,6 do if not chosen[i]then order[#order+1]=s.deck[i]end end
 for x=0,1 do for y=0,1 do for broken=0,1 do
  local discarded=assert(A.scoring.after_discard(s,g.action.indices))
  local drawn=assert(A.draws.fill(discarded,order))
  local first=indices(drawn,first_ids,x==1);local outcomes={};for _,i in ipairs(first)do outcomes[i]=broken==1 end
  local played,effects,score=assert(A.scoring.after_play(drawn,first,{glass_outcomes=outcomes}))
  local final=assert(A.draws.fill(played,played.deck));local last=indices(final,second_ids,y==1)
  local finish=A.scoring.score(final,last)
  check(score.score+finish.score>=receipt.minimum and score.score+finish.score>=s.blind.chips,'Every physical draw/order/Glass branch exceeds certified floor')
  check(#final.deck==0 and final.hands_left==s.hands_left-1 and final.discards_left==s.discards_left-1,'Physical resources conserved')
  check(#played.playing_cards==#s.playing_cards-broken,'Glass population removal is physical, not repeated by copies')
 end end end
end end end end
for _,cap in ipairs({0,1,5,9,10,11,12})do
 local candidate,work=A.growth.suggest_portfolio(s,A,p,{}, {exhaust_discards=true,max_evaluations=cap})
 check(work<=cap,'Caller score limit preserved')
 if candidate and candidate.growth.two_play then check(candidate.growth.two_play.complete,'No partial order family certifies')end
end
local stones=F.copy(s)
for _,i in ipairs({3,4})do local c=stones.hand[i]
 c.key='m_stone';c.name='Stone Card';c.enhancement='m_stone';c.ability.name='Stone Card';c.ability.effect='Stone Card'
 c.ability.set='Enhanced';c.ability.bonus=50;c.ability.perma_bonus=10000
end
stones.hand[8].seal='Blue';F.population(stones)
local sg,sw,sd=A.growth.suggest_portfolio(stones,A,p,{}, {exhaust_discards=true,max_evaluations=12})
check(not(sg and sg.growth.two_play),'Raw Stone ranks cannot change the retained Blue planet from Pair to High Card')
check(sd.retained_two_play and sd.retained_two_play.reason:find('same%-category'),'Actual second classification is checked, not inferred from raw ranks')
check(sw<=12,'Stone rejection preserves the shared allowance')
for _,mutate in ipairs({
 function(t)t.hands_left=1 end,
 function(t)t.blind.key='bl_hook';t.blind.name='The Hook'end,
 function(t)t.modifiers.discard_cost=1 end,
 function(t)t.hand[3].ability.forced_selection=true end,
 function(t)t.hand[3].face_down=true end,
 function(t)t.jokers[3].ability.extra=4 end,
 function(t)t.deck[1].ability.h_mult=-1 end,
 function(t)t.jokers[1].identity_redacted=true end,
 function(t)t.hand[3].seal='Blue';t.hand[4].seal='Blue'end,
 function(t)t.hand[3].enhancement='m_glass';t.hand[4].enhancement='m_glass'end,
})do
 local t=F.copy(s);mutate(t);F.population(t)
 local candidate,work,diag=A.growth.suggest_portfolio(t,A,p,{}, {exhaust_discards=true,max_evaluations=12})
 check(not(candidate and candidate.growth.two_play),'Hazard never receives a two-play guarantee')
 check(work<=12,'Rejected scope keeps bounded work')
end
local result=A.decision.run(s,A,nil,nil)
check(result.action.kind=='discard'and #result.action.indices>=4,'Actual Decision chooses discard before optional development')
check(result.evaluations<=(result.fast_clear and 70 or 140000),'Actual Decision keeps aggregate allowance')
check(result.discard_before_clear.reason=='supported_retained_two_play','Final-action receipt distinguishes two-play certificate')
local compact=A.player_journal.compact_yorick_review(result)
check(compact.two_play.complete and compact.two_play.second_draws==2 and compact.two_play.minimum>=s.blind.chips,
 'Public journal retains complete two-play floor and both draw charges')
local invalid={growth_diagnostics={bounded_growth=true,retained_two_play=setmetatable({}, {__index=function()error('unsafe receipt')end})}}
check(not A.player_journal.compact_yorick_review(invalid).two_play,'Unsafe receipt table is not traversed')
print('Retained two438: '..checks..' checks passed')
