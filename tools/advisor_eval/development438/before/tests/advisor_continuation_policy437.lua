local A=dofile('tests/fixtures/modules436.lua');local F=dofile('tests/fixtures/repair416.lua')
local Adapter=dofile('tools/advisor_eval/continuation_adapter.lua')
Adapter.evidence=dofile('tools/advisor_eval/continuation_evidence.lua')
local checks=0;local function check(v,m)checks=checks+1;assert(v,m)end
local s=F.state();s.blind.chips=1;local calls=0
local modules=setmetatable({decision={run=function(snapshot)
 calls=calls+1;check(snapshot.world_order==nil and snapshot.world_seed==nil,'Private world never enters policy state')
 for i=2,#snapshot.deck do check(snapshot.deck[i-1].id<snapshot.deck[i].id,'Policy only sees canonical composition order')end
 return {action={kind='play',indices={1},area='hand'},evaluations=1}
end}},{__index=A})
local ids={};for i=#s.deck,1,-1 do ids[#ids+1]=s.deck[i].id end
local input={mode='continuation',policy_first=true,world_order=ids,world_seed=437,action_cap=16,
 snapshot=s,case='manufactured',role='policy',sorting='rank'}
local r=Adapter.run(modules,input)
check(calls==1 and r.score_evaluations==1,'First production decision is invoked and charged exactly once')
check(r.status=='supported_clear'and r.full_run==false,'Actual terminal result remains a round continuation')
check(r.initial.discards_left==3 and r.discards==0 and r.cards_discarded==0 and r.remaining_discards==3,'Unspent resources remain visible for benchmark')
check(r.steps[1].intervention==nil and r.steps[1].decision.action.kind=='play','No forced first action masquerades as policy')
input.snapshot=F.copy(s);input.snapshot.jokers={{face_down=true,identity_redacted=true}}
local censored=Adapter.run(modules,input)
check(censored.status=='unsupported'and censored.unsupported.phase=='initial_public_belief','Hidden Joker transitions explicitly censored')
check(calls==1 and censored.cards_discarded==0 and not censored.final_resources_supported,'No hidden Joker is treated as inert or advanced through unqualified transition')
input.snapshot=s
input.policy_first=nil;check(not pcall(Adapter.run,modules,input),'Ordinary intervention still needs completed admission')
print('Continuation policy437: '..checks..' checks passed')
