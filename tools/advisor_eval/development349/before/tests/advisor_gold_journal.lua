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
    local count=#lines
    check(J:before('toggle_shop',{selected={1,2}}),'manufactured original observation remains recordable')
    eq(#lines,count+1,'compact diagnostics add no extra journal event')
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
  d.endpoints={};for i=1,129 do d.endpoints[i]={} end
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
do
  local f=fixture();local a=f.result.gold_acquisition_diagnostics;local r=f.result.gold_retention_diagnostics
  local huge={private='ORDER_ARRAY_MUST_NOT_BE_LOGGED'};huge.cycle=huge
  a.order_family={rows={huge,huge,huge,huge,huge,huge},private=huge}
  a.order_preflight={complete=true,supported=true,fits=true,required_evaluations=6976,available_evaluations=50000,
    unique_profiles=8,private=huge}
  a.order_preflight_expanded={complete=true,supported=true,fits=false,required_evaluations=80000,
    available_evaluations=50000,unique_profiles=92,private=huge}
  a.order_fallback='current_row_before_scoring'
  a.selected={setup_actions=0,order={private=huge},receipt=huge}
  r.order_family={rows={huge,huge,huge}}
  r.preflight={complete=true,supported=true,fits=false,required_evaluations=9000,available_evaluations=8000,unique_profiles=4}
  r.fallback_preflight={complete=true,supported=true,fits=true,required_evaluations=1744,available_evaluations=8000,unique_profiles=2}
  r.order_budget_fallback=true;r.arrangement_actions=0;r.rows=1
  local entry,bytes=f.record();local out=entry.context.advice.gold_review
  eq(out.acquisition_order_rows,6,'declared order row count retained without arrays')
  eq(out.acquisition_preflight_required_evaluations,6976,'selected-family required score count retained')
  eq(out.acquisition_preflight_available_evaluations,50000,'available score budget retained')
  eq(out.acquisition_preflight_complete,true,'complete preparation is distinct from score completion')
  eq(out.acquisition_preflight_supported,true,'supported preparation retained')
  eq(out.acquisition_preflight_fits,true,'selected family fit retained')
  eq(out.acquisition_preflight_unique_profiles,8,'deduplicated work profile count retained')
  eq(out.acquisition_expanded_preflight_required_evaluations,80000,'larger rejected family cost remains visible')
  eq(out.acquisition_expanded_preflight_fits,false,'explicit expanded no-fit retained')
  eq(out.acquisition_order_fallback,'current_row_before_scoring','acquisition fallback scope retained')
  eq(out.acquisition_arrangement_actions,0,'known zero arrangement cost retained')
  eq(out.retention_order_rows,3,'retention declared family count retained')
  eq(out.retention_rows,1,'actually compared retention row count retained')
  eq(out.retention_order_budget_fallback,true,'retention budget fallback retained')
  eq(out.retention_preflight_required_evaluations,1744,'retention current preflight uses fallback receipt')
  eq(out.retention_preflight_fits,true,'retention fallback fit retained')
  eq(out.retention_expanded_preflight_required_evaluations,9000,'retention original expanded requirement retained')
  eq(out.retention_expanded_preflight_fits,false,'retention expanded no-fit retained')
  eq(out.retention_arrangement_actions,0,'retention zero setup actions retained')
  check(not bytes:find('ORDER_ARRAY_MUST_NOT_BE_LOGGED',1,true),'large cyclic order/certificate payloads never traversed or copied')
  for _,value in pairs(out)do check(type(value)~='table','expanded review remains flat scalar fields')end
  check(#assert(M.encode(out))<4096,'complete expanded diagnostic summary stays compact')
  for _,count in ipairs({65,127,128})do
    a.endpoints={};for i=1,count do a.endpoints[i]=huge end
    entry=f.record();eq(entry.context.advice.gold_review.acquisition_endpoint_count,count,'bounded expanded endpoint count is exact')
  end
  a.endpoints[129]=huge;entry=f.record()
  eq(entry.context.advice.gold_review.acquisition_endpoint_count,nil,'129th endpoint remains outside bounded journal walk')
  f.close()
end
do
  local f=fixture();local a=f.result.gold_acquisition_diagnostics;local r=f.result.gold_retention_diagnostics
  a.order_preflight={complete=false,supported=false,fits=false,required_evaluations=0,available_evaluations=8000,unique_profiles=0}
  a.order_family={rows={{},{}}};a.selected={setup_actions=1}
  r.preflight={complete=true,supported=true,fits=true,required_evaluations=0,available_evaluations=0,unique_profiles=1}
  r.arrangement_actions=1
  local entry=f.record();local out=entry.context.advice.gold_review
  eq(out.acquisition_preflight_complete,false,'unsupported preparation false remains explicit')
  eq(out.acquisition_preflight_supported,false,'unsupported family is distinguishable from budget no-fit')
  eq(out.acquisition_preflight_required_evaluations,0,'zero partial preparation work does not imply a fit')
  eq(out.acquisition_arrangement_actions,1,'one selected current-shop reorder retained')
  eq(out.retention_preflight_required_evaluations,0,'fully cached remaining requirement can be zero')
  eq(out.retention_preflight_available_evaluations,0,'zero remaining budget retained')
  eq(out.retention_preflight_fits,true,'cached fit can coexist with zero remaining budget')
  eq(out.retention_arrangement_actions,1,'retention selected reorder retained')
  eq(out.retention_expanded_preflight_fits,nil,'no expanded receipt is fabricated without fallback')
  f.close()
end
do
  local f=fixture();local a=f.result.gold_acquisition_diagnostics;local r=f.result.gold_retention_diagnostics
  local poison=setmetatable({},{__index=function()error('Diagnostic metatable must not be touched')end})
  a.order_family={rows=poison};a.order_preflight=poison
  a.order_preflight_expanded={complete='true',supported=1,fits=0,required_evaluations=math.huge,
    available_evaluations=-1,unique_profiles=129}
  a.order_fallback=string.rep('x',513);a.selected={setup_actions=2}
  r.order_family={rows={{},{},{},{},{},{},{}}};r.fallback_preflight=poison
  r.preflight={complete=true,supported=true,fits=false,required_evaluations=9000,available_evaluations=8000,unique_profiles=4}
  r.order_budget_fallback='true';r.arrangement_actions=-1;r.rows=7
  local entry=f.record();local out=entry.context.advice.gold_review
  check(out.omitted_fields>=15,'malformed optional order scalars are explicitly omitted')
  eq(out.acquisition_order_rows,nil,'nonplain row array omitted without traversal')
  eq(out.acquisition_preflight_fits,nil,'nonplain preflight omitted without callbacks')
  eq(out.acquisition_expanded_preflight_fits,nil,'wrong-type fit never becomes truthy')
  eq(out.acquisition_order_fallback,nil,'oversized fallback string omitted')
  eq(out.acquisition_arrangement_actions,nil,'out-of-family action count omitted')
  eq(out.retention_order_rows,nil,'order family row walk bounded at six')
  eq(out.retention_preflight_fits,nil,'malformed fallback does not relabel original fit as current')
  eq(out.retention_expanded_preflight_fits,false,'valid original diagnostic survives malformed optional fallback')
  eq(out.retention_order_budget_fallback,nil,'wrong-type fallback flag omitted')
  eq(out.retention_arrangement_actions,nil,'negative action count omitted')
  eq(out.retention_rows,nil,'invalid selected family size omitted')
  check(not f.J.error,'malformed optional diagnostics do not stop existing logging')
  f.close()
end
print('advisor_gold_journal: '..checks..' manufactured checks passed; compact current-only diagnostics, no gameplay')
