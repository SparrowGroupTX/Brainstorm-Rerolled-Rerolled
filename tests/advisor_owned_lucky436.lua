-- Manufactured inputs, exact conditional arithmetic; no captured replay or RNG.
local S=dofile('Brainstorm/Advisor/scoring.lua');local R=dofile('Brainstorm/Advisor/sampled_outcomes.lua')
local D=dofile('Brainstorm/Advisor/draws.lua');local Snap=dofile('Brainstorm/Advisor/snapshot.lua')
local Finish=dofile('Brainstorm/Advisor/blind_finishing.lua')
local F=dofile('tests/fixtures/repair416.lua');local centers={}
for _,j in ipairs(dofile('tests/fixtures/joker_centers421.lua'))do centers[j.key]=j end
local checks=0;local function check(v,m)checks=checks+1;assert(v,m)end
local function eq(a,b,m)check(a==b,(m or '')..': '..tostring(a)..' ~= '..tostring(b))end
local function j(key,id)local x=F.copy(assert(centers[key]));x.id=id or key;return x end
local function state()
 local s=F.state();s.hand={F.card('lucky',13,'Spades'),F.card('held',2,'Hearts')}
 s.hand[1].enhancement='m_lucky';s.hand[1].key='m_lucky';s.hand[1].ability.name='Lucky Card'
 s.hand[1].ability.set='Enhanced';s.hand[1].ability.effect='Lucky Card';s.hand[1].ability.mult=20;s.hand[1].ability.p_dollars=20
 s.hand_size=2;s.deck={F.card('draw1',4,'Clubs'),F.card('draw2',6,'Hearts')};s.dollars=10
 s.hands={['High Card']={level=1,chips=5,mult=1,played=2,played_this_round=0}}
 s.consumeable_usage_total={tarot=3};s.jokers={j('j_fortune_teller'),j('j_blue_joker'),j('j_supernova'),j('j_yorick'),j('j_perkeo')}
 s.jokers[4].ability.x_mult=4;s.jokers[4].ability.yorick_discards=15;F.population(s);return s
end
local function ev(m,d)return {mult=m,dollars=d}end
local function ctx(events,index)return {lucky_owned=true,lucky_outcomes={[index or 1]=events}}end
local s=state();local before=Snap.fingerprint(s)
local mean=S.score(s,{1});check(mean.uncertain and mean.uncertainty.lucky,'Public ranking remains a mean with typed uncertainty')
local a,e,p=S.after_play(s,{1},ctx({ev(true,true)}))
check(a and p.legal and not p.uncertain and p.sampled_lucky and p.score_guaranteed==false,'Qualified five-Joker transition resolves privately')
eq(p.score,2052,'Exact Fortune/Blue/Supernova/Yorick arithmetic');eq(a.dollars,30,'Actual Lucky dollars')
eq(a.hands['High Card'].played,3,'Public hand history advances once');eq(a.jokers[4].ability.yorick_discards,15,'Play cannot grow Yorick')
local discarded=S.after_discard(a,{1});eq(discarded.jokers[4].ability.yorick_discards,14,'Following physical discard grows Yorick once')
local filled=D.fill(discarded,discarded.deck);check(filled and #filled.hand==2,'Physical draw completes after owned Lucky')
local next_state,_,next_score=R.after_play(filled,{1},S,436,2);check(next_state and not next_score.uncertain,'Fresh ordinary follow-up transition')
eq(Snap.fingerprint(s),before,'Original input remains unchanged')
check(Finish.choice_supported(s,mean,S,{1}),'Whole-blind admission accepts only qualified owned Lucky')
s.suppress_warnings=true;local silent=S.score(s,{1});eq(#silent.warnings,0)
check(Finish.choice_supported(s,silent,S,{1}),'Typed Lucky evidence survives suppressed human text')
local unknown=F.copy(silent);unknown.uncertainty.other=true;check(not Finish.choice_supported(s,unknown,S,{1}),'Other typed uncertainty is never erased')
unknown=F.copy(silent);unknown.uncertainty=nil;check(not Finish.choice_supported(s,unknown,S,{1}),'Missing reasons do not imply Lucky-only support')
s=state();s.hand[1].seal='Red';s.jokers={j('j_blueprint'),j('j_lucky_cat')}
a,e,p=S.after_play(s,{1},ctx({ev(true,true),ev(false,false)}))
eq(a.jokers[2].ability.x_mult,1.25,'Both-positive then miss grows one physical Cat only once')
eq(a.jokers[1].ability.x_mult,1,'Copy source state is not grown');eq(p.score,820,'Both copies score fresh Cat growth after both card repetitions')
s.jokers={j('j_lucky_cat','cat1'),j('j_lucky_cat','cat2')};s.jokers[2].ability.x_mult=2
a,e,p=S.after_play(s,{1},ctx({ev(false,true),ev(true,false)}))
eq(a.jokers[1].ability.x_mult,1.5);eq(a.jokers[2].ability.x_mult,2.5,'Each physical Cat grows per successful repetition')
check(not p.uncertain,'Exact sampled Cat growth carries no approximation warning')
s=state();s.hand[1].seal='Red';s.jokers={j('j_blueprint'),j('j_hanging_chad'),j('j_lucky_cat')}
local plan=S.sampled_lucky_plan(s,{1});eq(plan.counts[1],6,'Red plus physical and copied Chad repetitions')
local events={};for i=1,6 do events[i]=ev(true,true)end
a,e,p=S.after_play(s,{1},ctx(events));eq(p.sampled_lucky_events,6);eq(a.dollars,130);eq(a.jokers[3].ability.x_mult,2.5)
eq(p.score,19662,'Repeated Lucky plus physical Cat has exact conditional score')
local missing=ctx({ev(false,false)});eq(S.after_play(s,{1},missing),nil,'Missing repetition is rejected')
for _,key in ipairs({'j_sock_and_buskin','j_dusk','j_hack'})do
 local t=state();t.jokers={j(key)};t.hands_left=1
 if key=='j_hack'then t.hand[1].rank=2;t.hand[1].base.id=2;t.hand[1].nominal=2 end
 eq(S.sampled_lucky_plan(t,{1}).counts[1],2,'Shared repetition plan for '..key)
end
s=state();s.jokers={j('j_blueprint'),j('j_selzer'),j('j_yorick')};s.jokers[2].ability.extra=1
s.jokers[2].edition={negative=true,card_limit=1};s.joker_limit=6
eq(S.sampled_lucky_plan(s,{1}).counts[1],3,'Last Seltzer charge contributes all physical/copy repeats')
a,e,p=S.after_play(s,{1},ctx({ev(false,false),ev(false,false),ev(false,false)}));eq(#a.jokers,2);eq(a.joker_limit,5)
a.hand={F.copy(s.hand[1])};a.deck={};a.playing_cards=F.copy(a.hand)
eq(S.sampled_lucky_plan(a,{1}).counts[1],1,'Fresh plan follows new Blueprint adjacency after Seltzer removal')
s=state();s.jokers={};for i=1,50 do s.jokers[i]=j('j_blueprint','bp'..i)end;s.jokers[51]=j('j_hanging_chad')
eq(S.sampled_lucky_plan(s,{1}),nil,'Unclamped count above100 fails closed')
s=state();s.jokers={j('j_stencil'),j('j_selzer')};s.jokers[1].ability.x_mult=4;s.jokers[2].ability.extra=1
a,e,p=S.after_play(s,{1},ctx({ev(false,false),ev(false,false)}))
eq(p.score,100,'Source-shaped Stencil X4 on last Seltzer hand')
eq(#a.jokers,1,'Physical Seltzer expires before next play')
a.hand={F.copy(s.hand[1])};a.deck={};F.population(a)
local second,_,nextscore=S.after_play(a,{1},ctx({ev(false,false)}))
check(second and not nextscore.uncertain,'Two-play owned Lucky Stencil chain remains exact')
eq(nextscore.score,75,'Stencil recomputes X5 after expiry despite stale source X4')
for _,field in ipairs({'unknown','face_down','identity_redacted','identity_unknown','concealed'})do
 s=state();s.jokers[1][field]=true;eq(S.sampled_lucky_plan(s,{1}),nil,'Hidden row rejected')
end
for _,key in ipairs({'j_duo','j_trio','j_family','j_order','j_tribe'})do
 s=state();s.jokers={j(key)};s.jokers[1].ability.type=nil
 eq(S.sampled_lucky_plan(s,{1}),nil,'Missing type cannot become unconditional '..key)
 eq(S.after_play(s,{1},ctx({ev(true,true)})),nil,'Forged conditional marker is rejected')
 check(not Finish.choice_supported(s,S.score(s,{1}),S,{1}),'Missing-type mean cannot admit complete finishing')
end
s=state();s.jokers={j('j_sly')};s.jokers[1].ability.t_chips=nil
eq(S.sampled_lucky_plan(s,{1}),nil,'Missing required conditional Chips rejected')
s=state();s.jokers={j('j_jolly')};s.jokers[1].ability.t_mult=nil
eq(S.sampled_lucky_plan(s,{1}),nil,'Missing required conditional Mult rejected')
for _,key in ipairs({'j_vampire','j_midas_mask','j_dna','j_business','j_reserved_parking','j_bloodstone','j_space','j_misprint'})do
 s=state();s.jokers[1]=j(key);eq(S.sampled_lucky_plan(s,{1}),nil,'Unqualified family '..key)
 eq(S.after_play(s,{1},ctx({ev(true,true)})),nil,'Supplied marker cannot bypass row qualification')
end
s=state();s.jokers[1].ability.custom_callback=1;eq(S.sampled_lucky_plan(s,{1}),nil,'Unknown ability field rejected')
s=state();s.jokers[1].ability.mult=99;eq(S.sampled_lucky_plan(s,{1}),nil,'Nonneutral generic Mult rejected')
s=state();s.jokers[1].ability.effect='Suit Mult';eq(S.sampled_lucky_plan(s,{1}),nil,'Contradictory effect rejected')
s=state();s.jokers={j('j_hanging_chad')};s.jokers[1].ability.extra=1.5;eq(S.sampled_lucky_plan(s,{1}),nil,'Fractional retrigger rejected')
s=state();s.jokers={j('j_blueprint')};eq(S.sampled_lucky_plan(s,{1}),nil,'Unresolved copy route rejected')
s=state();s.hand={F.card('hook1',2),F.card('hook2',3),s.hand[1]};F.population(s)
s.blind={key='bl_hook',chips=99999};local hc=ctx({ev(true,true)},3);hc.hook_indices={1,2}
a,e,p=S.after_play(s,{3},hc);check(a and not p.uncertain,'Hook remaps and requalifies sampled owned Lucky')
eq(p.scoring_indices[1],3);eq(a.dollars,30)
s=state();s.hand_size=8;s.modifiers.minus_hand_size_per_X_dollar=5
a,e,p=S.after_play(s,{1},ctx({ev(false,true)}));eq(a.hand_size,4,'Actual Lucky dollars feed Tax capacity exactly')
s=state();s.jokers={j('j_lucky_cat')};s.hand[1].ability.p_dollars=0;s.probabilities.normal=15
local zero=R.context(s,{1},1,1,nil,S);check(zero.lucky_outcomes[1][1].mult and not zero.lucky_outcomes[1][1].dollars,'Zero payout cannot create a money trigger')
eq(S.after_play(s,{1},ctx({ev(true,true)})),nil,'Impossible zero-dollar event rejected')
for seed=1,32 do
 s=state();s.hand[1].seal='Red';s.jokers={j('j_hanging_chad'),j('j_lucky_cat')}
 local one=R.context(s,{1},seed,2,nil,S);local t=F.copy(s);t.hand={s.hand[2],s.hand[1]}
 local two=R.context(t,{2},seed,2,nil,S)
 eq(Snap.fingerprint(one.lucky_outcomes[1]),Snap.fingerprint(two.lucky_outcomes[2]),'Physical stream independent of held index')
 local x,_,score=R.after_play(s,{1},S,seed,2);local y,_,repeat_score=R.after_play(s,{1},S,seed,2)
 check(x and y and not score.uncertain,'Qualified sampled transition completes');eq(score.score,repeat_score.score);eq(x.dollars,y.dollars)
end
print('Owned Lucky436: '..checks..' manufactured checks passed')
