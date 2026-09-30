-- Manufactured comparison/export/diagnostic fixtures only; no saved captures.
local A=dofile('tests/fixtures/modules436.lua');local F=dofile('tests/fixtures/repair416.lua')
local E=dofile('tools/advisor_eval/continuation_evidence.lua')
local Adapter=dofile('tools/advisor_eval/continuation_adapter.lua');Adapter.evidence=E
local checks=0;local function check(v,m)checks=checks+1;assert(v,m)end
local function roundtrip(value)
 local frames={};local raw,why=E.frames(value,function(f)
  local encoded,error=A.player_journal.encode(f);if encoded then frames[#frames+1]=F.copy(f)end;return encoded,error
 end)
 check(raw~=nil,why);check(#frames==#raw,'Every frame encoded before return')
 local restored,error=E.restore(frames);check(restored~=nil,error);return restored,frames,raw
end
local s=F.state();s.phase='pack';s.pack_type='BUFFOON_PACK';s.pack_choices=1;s.pack_cards={
 F.joker('j_sly','Sly Joker',{type='Pair',t_chips=50}),F.joker('j_trio','The Trio',{type='Three of a Kind',x_mult=3})}
s.jokers={F.joker('j_yorick','Yorick',{x_mult=1,yorick_discards=15,extra={discards=23,xmult=1}}),F.joker('j_perkeo','Perkeo')}
s.hand_size=8;s.hand_limit=5;s.hand={};s.deck={};s.playing_cards={};s.active_tags={};s.round_resets={hands=4,discards=3}
s.next_blind={key='bl_goad',name='The Goad',chips=600,boss=true,debuff={suit='Spades'}};s.next_blind_chips=600
for i=1,52 do s.playing_cards[i]=F.card('card'..i,2+(i-1)%13,({'Clubs','Spades','Diamonds','Hearts'})[1+math.floor((i-1)/13)])end
local before=A.snapshot.fingerprint(s)
local r=Adapter.run(A,{mode='pack_diagnostic',snapshot=s,case='manufactured',role='comparison'})
check(r.status=='complete'and r.comparison.complete_finishing,'Real pack-to-shop comparison completes')
check(r.evaluations<=50000,'Existing shop cap maintained')
local restored,frames=roundtrip(r)
check(A.snapshot.fingerprint(restored)==A.snapshot.fingerprint(r),'Full nested certificates preserved through bounded graph')
check(A.snapshot.fingerprint(s)==before,'Export and comparison preserve input')
-- Repeated references model nested duplicated certificates: normal JSON expands
-- these past its structure bound, graph frames retain every path and alias.
local large={};for i=1,200 do large[i]={case=i,comparison=r.comparison}end
local ordinary=A.player_journal.encode(large);check(not ordinary,'Regression actually exceeds ordinary observation guard')
local x,f=roundtrip(large);check(#x==200 and x[1].comparison==x[200].comparison,'All fields and shared full certificates retained')
check(x[1].comparison.complete_finishing,'No replacement by scalar-only compact projection')
local bad=F.copy(f);table.remove(bad);check(E.restore(bad)==nil,'Missing final frame cannot look complete')
bad=F.copy(f);bad[1].entry_count=bad[1].entry_count+1;check(E.restore(bad)==nil,'Count tampering rejected')
bad=F.copy(f);bad[2].first=2;check(E.restore(bad)==nil,'Out-of-order page rejected')
bad=F.copy(f);bad[1].root={kind='ref',id=99999};check(E.restore(bad)==nil,'Dangling root rejected')
bad=F.copy(f);bad[1].fields_omitted=1;check(E.restore(bad)==nil,'Omitted fields cannot certify completeness')
local cycle={};cycle.self=cycle;check(E.frames(cycle,A.player_journal.encode)==nil,'Cycles fail closed without partial export')
check(E.frames({v=0/0},A.player_journal.encode)==nil,'Nonfinite data rejected')
local huge={};for i=1,2049 do huge[i]=i end;check(E.frames(huge,A.player_journal.encode)==nil,'Bounded graph table width enforced')
local diagnostic=E.unsupported('play',{}, {legal=true,uncertain=true,score=75,hand='High Card',
 warnings={'A random effect remains unresolved.'},uncertainty={other=true}})
check(diagnostic.code=='unresolved_scoring_or_growth'and diagnostic.warnings[1]=='A random effect remains unresolved.','Structured cause retained')
check(not A.player_journal.encode(diagnostic):find('table:',1,true),'No opaque Lua address in diagnostics')
-- Exercise the new adapter failure path using a fixed synthetic uncertain scorer.
local t=F.state();t.blind.chips=100000;local a={kind='play',area='hand',indices={1}}
local modules=setmetatable({sampled_outcomes={after_play=function()
 return nil,{opaque='not a reason'},{legal=true,uncertain=true,warnings={'Fixture unknown effect'},uncertainty={other=true}}
end}},{__index=A})
local input={mode='continuation',snapshot=t,case='manufactured',role='default',action_cap=1,
 admission={admitted=true,default=a,five=a,initial_fingerprint=A.snapshot.fingerprint(Adapter.canonical(t))}}
local out=Adapter.run(modules,input)
check(out.status=='unsupported'and out.unsupported.warnings[1]=='Fixture unknown effect','Adapter exposes actual uncertain score cause')
check(not out.final_resources_supported and not out.reason:find('table:',1,true),'Unresolved transition is censored with readable reason')
local result=Adapter.run_frames(modules,input);check(result and #result>=3,'Future adapter exposes bounded framed output')
input.action_cap=17;check(not pcall(Adapter.run,modules,input),'Caller cannot silently raise adapter action cap')
print('Continuation evidence436: '..checks..' checks passed')
