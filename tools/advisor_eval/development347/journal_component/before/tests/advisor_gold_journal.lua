-- Manufactured logger data only; no source, saved profile, live game or replay.
local M=dofile('Brainstorm/Advisor/player_journal.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,message)checks=checks+1;assert(v,message)end
local function eq(a,b,message)check(a==b,message..': '..tostring(a)..' ~= '..tostring(b))end
local function fixture()
  local captured,lines={},{}
  local g={GAME={round=22,pseudorandom={seed='MANUFACTURED'},stake=8},SETTINGS={profile=1},STATE=1,STATES={},
    STATE_COMPLETE=true,CONTROLLER={locks={}},hand={cards={},highlighted={}},FUNCS={}}
  local state={phase='shop',dollars=170,jokers={},hand={},playing_cards={},consumeables={},
    shop_forecast={pools={private='excluded_catalog'}}}
  local result={action={kind='leave_shop'},gold_acquisition_diagnostics={scope='Winning ante shop',reason='No supported missing offer',
    complete=true,projection_complete=true,evidence_complete=false,evaluations=0,comparisons=0,max_evaluations=50000,
    before_missing=0,after_missing=0,endpoints={{private='huge candidate'}},family_key='FAMILY_KEY_MUST_NOT_BE_LOGGED'},
    gold_diagnostics={complete=false,reason='Final boss not next',evaluations=123,comparisons=4},
    gold_retention_diagnostics={complete=true,reason='Keep missing cargo',evaluations=64,before_missing=0,after_missing=1,
      held_certificate={private='HOLD_CERTIFICATE_MUST_NOT_BE_LOGGED'}},
    shop_diagnostics={evaluations=456,truncated=false,unavailable_reason='Readiness unavailable',metrics={private='nested'}}}
  local A={snapshot={capture=function()return Snapshot.copy(state)end,fingerprint=Snapshot.fingerprint},
    result=result,published_key=Snapshot.fingerprint(state),published_game=g.GAME,published_generation=3,retry_generation=3,
    display={title='Leave shop'},lines={'Existing full advice line'}}
  local B={VERSION='manufactured',config={advisor={player_logging=true}}}
  local encode=M.encode
  M.encode=function(entry)captured[#captured+1]=entry;return encode(entry)end
  local J=M.attach(A,B,{game=function()return g end,append=function(bytes)lines[#lines+1]=bytes;return true end,
    now=function()return 'fixed'end,clock=function()return 10 end})
  local function record()
    check(J:before('toggle_shop',{selected={1,2}}),'manufactured original observation remains recordable')
    return captured[#captured],lines[#lines]
  end
  return {A=A,B=B,J=J,g=g,state=state,result=result,record=record,close=function()M.encode=encode end}
end
do
  local f=fixture();local before=Snapshot.fingerprint(f.result)
  local entry,bytes=f.record();local review=entry.context.advice.gold_review
  check(review,'current Gold review is recorded')
  eq(review.status,'current','compact review is explicitly current')
  eq(review.acquisition_complete,true,'complete true retained')
  eq(review.acquisition_evidence_complete,false,'explicit incomplete evidence retained')
  eq(review.acquisition_reason,'No supported missing offer','current acquisition deferral reason retained')
  eq(review.acquisition_endpoint_count,1,'only endpoint count retained')
  eq(review.acquisition_before_missing,0,'known zero missing retained')
  eq(review.acquisition_max_evaluations,50000,'declared score cap retained')
  eq(review.final_comparisons,4,'final-shop comparison count retained')
  eq(review.retention_reason,'Keep missing cargo','retention explanation retained')
  eq(review.retention_evaluations,64,'retention floor work retained')
  eq(review.retention_after_missing,1,'distinct retained cargo count retained')
  check(not bytes:find('HOLD_CERTIFICATE_MUST_NOT_BE_LOGGED',1,true),'large hold certificate remains excluded')
  eq(review.shop_evaluations,456,'shared shop score work retained')
  eq(review.shop_truncated,false,'explicit nontruncation retained')
  check(not bytes:find('FAMILY_KEY_MUST_NOT_BE_LOGGED',1,true),'memoization family key omitted')
  check(not bytes:find('huge candidate',1,true) and not bytes:find('nested',1,true),'candidate and metric payloads omitted')
  check(not bytes:find('excluded_catalog',1,true),'original public snapshot catalog exclusion preserved')
  eq(entry.context.snapshot.dollars,170,'original full public snapshot preserved')
  eq(entry.context.advice.action.kind,'leave_shop','original full advised action preserved')
  eq(entry.context.advice.lines[1],'Existing full advice line','original advice text preserved')
  eq(entry.details.input.selected[2],2,'original action request details preserved')
  eq(Snapshot.fingerprint(f.result),before,'compacting diagnostics does not mutate source result')
  for _,value in pairs(review)do check(type(value)~='table','review remains flat scalars only')end
  check(#assert(M.encode(review))<2048,'normal Gold review is compact')
  f.close()
end
do
  local cases={
    {'fingerprint changed',function(f)f.state.dollars=169 end,'stale'},
    {'game replaced',function(f)f.g.GAME={} end,'stale'},
    {'generation changed',function(f)f.A.retry_generation=4 end,'stale'},
    {'publication cleared',function(f)f.A.published_key=nil end,'stale'},
    {'computing',function(f)f.A.result=nil;f.A.worker={};f.A.published_key=nil end,'computing'},
    {'unavailable',function(f)f.A.result=nil;f.A.published_key=nil end,'unavailable'},
  }
  for _,case in ipairs(cases)do
    local f=fixture();case[2](f);local entry=f.record()
    eq(entry.context.advice.status,case[3],case[1]..' advice status is honest')
    eq(entry.context.advice.gold_review,nil,case[1]..' never attaches old diagnostics to current state')
    eq(entry.context.snapshot.dollars,f.state.dollars,case[1]..' full observation remains fresh')
    f.close()
  end
end
do
  local f=fixture();local d=f.result.gold_acquisition_diagnostics
  d.family_key=string.rep('huge',100000)
  d.endpoints={{self=nil}};d.endpoints[1].self=d.endpoints[1]
  d.private=setmetatable({},{__index=function()error('Nested payload must not be read')end})
  d.reason=string.rep('r',513);d.scope='Line\nwith\tcontrols';d.evaluations=0/0;d.comparisons=math.huge
  d.before_missing=-1;d.after_missing=151;d.complete='true';d.max_evaluations=1000000001
  d.selected={carried_missing=2,cash_after=-5,minimum_opening_score=1e20,minimum_score_delta=-123,
    key=string.rep('private',100000),nested=d}
  local entry,bytes=f.record();local review=entry.context.advice.gold_review
  check(review and review.omitted_fields==7,'oversized and invalid scalar fields are explicitly omitted')
  eq(review.acquisition_reason,nil,'oversized string never enters observation')
  eq(review.acquisition_scope,'Line with controls','bounded display string control characters normalized')
  eq(review.acquisition_evaluations,nil,'nonfinite work omitted')
  eq(review.acquisition_comparisons,nil,'infinite comparison count omitted')
  eq(review.acquisition_before_missing,nil,'negative missing count omitted')
  eq(review.acquisition_after_missing,nil,'above-catalog missing count omitted')
  eq(review.acquisition_complete,nil,'wrong-type completion omitted')
  eq(review.acquisition_endpoint_count,1,'endpoint payload cycle is never traversed')
  eq(review.acquisition_selected_carried_missing,2,'selected distinct count is scalar')
  eq(review.acquisition_selected_cash_after,-5,'finite signed endpoint cash preserved')
  eq(review.acquisition_selected_minimum_opening_score,1e20,'finite score evidence preserved')
  eq(review.acquisition_selected_minimum_score_delta,-123,'signed score tradeoff preserved')
  check(#bytes<4096,'huge and cyclic diagnostic payloads cannot bloat the event')
  check(not f.J.error,'malformed optional diagnostic never disables ordinary observation logging')
  d.endpoints={[2]={}};entry=f.record();eq(entry.context.advice.gold_review.acquisition_endpoint_count,nil,'sparse endpoint array does not invent count')
  d.endpoints={};for i=1,65 do d.endpoints[i]={} end
  entry=f.record();eq(entry.context.advice.gold_review.acquisition_endpoint_count,nil,'endpoint count walk is bounded')
  f.result.gold_diagnostics=setmetatable({},{__index=function()error('Metatable diagnostic is not plain')end})
  entry=f.record();check(entry.context.advice.gold_review.omitted_fields>0,'nonplain diagnostic rejected without callbacks')
  f.close()
end
do
  local f=fixture();f.result.gold_acquisition_diagnostics=nil;f.result.gold_retention_diagnostics=nil;f.result.gold_diagnostics=nil;f.result.shop_diagnostics=nil
  local entry=f.record();eq(entry.context.advice.gold_review,nil,'ordinary result without diagnostics keeps its existing event shape')
  f.close()
end
print('advisor_gold_journal: '..checks..' manufactured checks passed; compact current-only diagnostics, no gameplay')
