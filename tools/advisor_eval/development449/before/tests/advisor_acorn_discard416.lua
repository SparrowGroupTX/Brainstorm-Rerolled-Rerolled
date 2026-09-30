local F=dofile('tests/fixtures/repair416.lua');local m=F.modules()
local checks=0;local function check(v,msg)checks=checks+1;assert(v,msg)end
local function hidden()return setmetatable({face_down=true},{__index=function()error('private Joker payload accessed')end})end
local function fixture(target)
 local s=F.state();s.hand={};s.deck={};s.hand_size=5;s.blind={key='bl_final_acorn',name='Amber Acorn',chips=target}
 for i,r in ipairs({2,4,6,8,10}) do s.hand[i]=F.card('h'..i,r,({'Clubs','Spades','Diamonds','Hearts','Clubs'})[i]);s.deck[i]=F.card('d'..i,10) end
 s.public_joker_belief=assert(m.acorn_belief.start({F.joker('j_yorick','Yorick',{x_mult=1,yorick_discards=5,extra={discards=5,xmult=1}}),F.joker('j_joker','Joker',{mult=4})},'invented416',{public_before_shuffle=true}))
 s.jokers={hidden(),hidden()};F.population(s);return s
end
local s=fixture(1100);local before=m.snapshot.fingerprint(s);local raw=m.scoring;local calls=0
m.scoring=setmetatable({lower_bound=function(...)calls=calls+1;return raw.lower_bound(...)end,score=function(...)calls=calls+1;return raw.score(...)end},{__index=raw})
local r=m.decision.run(s,m)
check(r.action.kind=='discard','Acorn compares useful discards with three hands still available')
check(r.acorn_discard_diagnostics.complete and r.acorn_discard_diagnostics.supported_improvement,'complete per-order early improvement')
check(r.evaluations==calls and calls<=140000,'early comparison charges every actual pass')
check(m.snapshot.fingerprint(s)==before,'hidden row and belief remain immutable')
local low=m.decision.run(s,m,nil,{acorn_discard={max_evaluations=1}})
check(low.action.kind=='play' and not low.acorn_diagnostics.discard.complete,'partial early comparison is rejected')

s=fixture(60);calls=0;r=m.decision.run(s,m)
check(r.action.kind=='discard' and r.public_joker_belief.bound_kind=='public_retained_clear_floor','same physical clear retained in both public orders')
check(r.discard_before_clear.selected and r.acorn_diagnostics.retained.complete,'final arbitration preserves retained discard receipt')
check(r.discard_preference_work<=12 and r.evaluations==calls,'retained work shares ordinary and twelve-call limits')
local b=s.public_joker_belief;local indices=r.action.indices
for _,world in ipairs(b.worlds) do
 local actual=F.copy(s);actual.jokers={};for slot,ordinal in ipairs(world) do actual.jokers[slot]=F.copy(b.inventory[ordinal]) end
 actual=assert(raw.after_discard(actual,indices));actual=assert(m.draws.fill(actual,actual.deck))
 local advanced=m.acorn_belief.advance_public(b,{epoch=b.epoch,kind='discard',observed_complete=true,discarded_count=#indices})
 for slot,ordinal in ipairs(world) do check(m.snapshot.fingerprint(actual.jokers[slot].ability)==m.snapshot.fingerprint(advanced.inventory[ordinal].ability),'actual growth equals fresh public transition') end
 actual.public_joker_belief=advanced;actual.jokers={hidden(),hidden()}
 local fresh=m.decision.run(actual,m)
 check(fresh.action and fresh.action.kind=='discard','fresh settled state continues the physical retained-clear route')
end
-- A Green decrement crosses the target in one order only. Both initial orders
-- clear, so checking only the first world would incorrectly authorize a discard.
s=fixture(100)
s.public_joker_belief=assert(m.acorn_belief.start({F.joker('j_green_joker','Green Joker',{mult=4,extra={hand_add=1,discard_sub=1}}),F.joker('j_yorick','Yorick',{x_mult=2,yorick_discards=20,extra={discards=23,xmult=1}})},'green416',{public_before_shuffle=true}))
local b=s.public_joker_belief
local first={kind='play',action={kind='play',indices={5}},immediate_clear_all_worlds=true}
-- Check the actual two orders independently before asking for a certificate.
s.blind.chips=100
for wi,world in ipairs(b.worlds) do
 local actual=F.copy(s);actual.jokers={};for slot,ordinal in ipairs(world) do actual.jokers[slot]=F.copy(b.inventory[ordinal]) end
 check(raw.lower_bound(actual,{5}).score>=100,'every initial public order clears')
 actual=assert(raw.after_discard(actual,{1}))
 check((raw.lower_bound(actual,{4}).score>=100)==(wi==1),'only the later world loses after Green decrement')
end
local choice,work,why=m.acorn_discard.retained(s,b,first,raw,raw,m.acorn_belief,m,{max_evaluations=12})
check(not choice and not why.complete and why.reason=='A later public order loses the retained clear.','one later public order losing its clear vetoes the common discard: '..m.snapshot.fingerprint(why))
check(work<=12,'negative all-order proof stays bounded')
local missing,used=m.acorn_discard.retained(fixture(60),fixture(60).public_joker_belief,first,raw,raw,m.acorn_belief,m,{max_evaluations=2})
check(not missing and used==0,'one missing world allowance starts no certificate')
print('Acorn discard416: '..checks..' checks passed')
