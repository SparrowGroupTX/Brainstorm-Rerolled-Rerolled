-- Manufactured data only; compare complete serialized events and callback
-- behavior with the preserved 334 baseline, while counting avoided work.
local base='tools/advisor_eval/development335/runtime_component/'
local baseline=dofile(base..'player_journal.base.lua')
local candidate=dofile(base..'player_journal.lua')
local snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local hooks=dofile('Brainstorm/Advisor/callback_hooks.lua')
local checks=0
local function check(value,message)assert(value,message);checks=checks+1 end
local function packed(...)return {n=select('#',...),...}end
local function same(a,b,message)check(baseline.encode(a)==baseline.encode(b),message)end

local function scenario(M,mode)
  local count={capture=0,fingerprint=0,details=0,callback=0}
  local lines={}
  local cards={{id='first'},{id='second'}}
  local highlighted={cards[2]}
  local hand=setmetatable({cards=cards},{__index=function(_,key)
    if key=='highlighted' then count.details=count.details+1;return highlighted end
  end})
  local g={GAME={round=1,pseudorandom={seed='MANUFACTURED'},stake=8},SETTINGS={profile=1},
    STATE=1,STATES={GAME_OVER=9,NEW_ROUND=10},STATE_COMPLETE=true,CONTROLLER={locks={}},hand=hand,FUNCS={}}
  local live={phase='hand',dollars=7,hand={{id='first',rank=13},{id='second',rank=14}},
    deck={{id='third',rank=12,face_down=true}},playing_cards={{id='third',rank=12}},
    shop_forecast={pools={{{key='j_manufactured'}}}}}
  local key=snapshot.fingerprint(live)
  local A={snapshot={capture=function()count.capture=count.capture+1;return snapshot.copy(live)end,
    fingerprint=function(s)count.fingerprint=count.fingerprint+1;return snapshot.fingerprint(s)end},
    published_key=key,published_game=g.GAME,result={action={kind='discard',indices={2}}},
    display={title='Discard'},lines={'Manufactured recommendation'},callback_hooks=hooks.new()}
  local B={VERSION='manufactured',config={advisor={player_logging=mode~='disabled'}}}
  if mode=='no_key' or mode=='computing' or mode=='unavailable' then A.published_key=nil end
  if mode=='computing' then A.result=nil;A.worker={} end
  if mode=='unavailable' then A.result=nil end
  if mode=='different_game' then A.published_game={} end
  if mode=='mismatch' then A.published_key='different' end
  g.FUNCS.play_cards_from_highlighted=function(e,a,b)
    count.callback=count.callback+1
    check(e.config.id=='play' and a=='middle' and b==nil,'callback arguments survive '..mode)
    live.dollars=live.dollars+1
    return nil,'second',nil
  end
  g.FUNCS.sell_card=function()count.callback=count.callback+1;error('manufactured callback error',0)end
  g.FUNCS.use_card=function()count.callback=count.callback+1;return false,'declined',nil end
  local J=M.attach(A,B,{game=function()return g end,append=function(bytes)lines[#lines+1]=bytes;return true end,
    clock=function()return 100 end,now=function()return 'fixed' end})
  J:install_hooks(g)
  local wrapper=g.FUNCS.play_cards_from_highlighted
  for _=1,20 do J:install_hooks(g) end
  check(g.FUNCS.play_cards_from_highlighted==wrapper,'unchanged callback installation stable '..mode)
  if mode=='suppressed' then J.suppressed=1 end
  if mode=='stopped' then J.error='manufactured write failure';J.status='Recording stopped: manufactured write failure' end
  local result=packed(g.FUNCS.play_cards_from_highlighted({config={id='play',ref_table={config={center={key='j_test'}}}}},'middle',nil))
  check(result.n==3 and result[1]==nil and result[2]=='second' and result[3]==nil,'exact trailing nil tuple '..mode)
  local rejected=packed(g.FUNCS.use_card())
  check(rejected.n==3 and rejected[1]==false and rejected[2]=='declined' and rejected[3]==nil,'explicit rejection tuple '..mode)
  local ok,err=pcall(g.FUNCS.sell_card)
  check(not ok and err=='manufactured callback error','exact exception '..mode)
  g.CONTROLLER.locked=true
  local before=#lines;J:update(g)
  check(#lines==before,'busy update retains pending observation '..mode)
  g.CONTROLLER.locked=false;J:update(g)
  if mode~='disabled' and mode~='suppressed' and mode~='stopped' then
    check(#lines==7,'three request/result pairs and one settled event '..mode)
    check(lines[1]:find('"selected":[2]',1,true)~=nil,'selection order preserved '..mode)
    check(lines[1]:find('"dollars":7',1,true)~=nil and lines[7]:find('"dollars":8',1,true)~=nil,
      'fresh detached pre and settled snapshots preserved '..mode)
    check(not lines[1]:find('j_manufactured',1,true),'catalog remains omitted '..mode)
    local expected=mode=='current' and 'current' or mode=='computing' and 'computing' or mode=='unavailable' and 'unavailable' or 'stale'
    check(lines[1]:find('"status":"'..expected..'"',1,true)~=nil,'correct first advice status '..mode)
  else check(#lines==0,'nonrecording callbacks produce no events '..mode)end
  return {lines=lines,result=result,rejected=rejected,error=err,status=J.status,sequence=J.sequence,
    events=J.events,pending=J.pending_state,bytes=J.bytes,physical_bytes=J.physical_bytes},count
end

local saved_details,saved_fingerprints=0,0
for _,mode in ipairs({'disabled','suppressed','stopped','no_key','different_game','mismatch','current','computing','unavailable'})do
  local b,bc=scenario(baseline,mode)
  local c,cc=scenario(candidate,mode)
  same(c,b,'complete bytes, links, counters and callback outcomes equal '..mode)
  check(cc.capture==bc.capture,'all full observations preserved '..mode)
  check(cc.callback==bc.callback and cc.callback==3,'exact callback count '..mode)
  local recording=mode~='disabled' and mode~='suppressed' and mode~='stopped'
  check(cc.details==(recording and bc.details or 0),'request details gated only when unused '..mode)
  local needs_key=mode=='mismatch' or mode=='current'
  check(cc.fingerprint==(needs_key and bc.fingerprint or 0),'only potentially current advice fingerprints '..mode)
  saved_details=saved_details+bc.details-cc.details
  saved_fingerprints=saved_fingerprints+bc.fingerprint-cc.fingerprint
end

-- A registered outer observer and a later third-party replacement preserve
-- callback ancestry, exact events, nested suppression and the new fast gates.
local function nested(M)
  local output,count={},0
  local g={GAME={},STATE_COMPLETE=true,CONTROLLER={locks={}},FUNCS={},hand={cards={},highlighted={}}}
  local A={snapshot={capture=function()return {phase='hand',hand={}}end,fingerprint=function()return 'key'end},
    published_key='key',published_game=g.GAME,callback_hooks=hooks.new()}
  local B={config={advisor={player_logging=true}}}
  local J
  g.FUNCS.use_card=function()count=count+1;return 'inner',nil end
  g.FUNCS.buy_from_shop=function()
    count=count+1;J.suppressed=J.suppressed+1
    local values=packed(g.FUNCS.use_card())
    J.suppressed=J.suppressed-1
    return unpack(values,1,values.n)
  end
  J=M.attach(A,B,{game=function()return g end,append=function(bytes)output[#output+1]=bytes;return true end,
    clock=function()return 100 end,now=function()return 'fixed'end})
  J:install_hooks(g)
  local journal_wrapper=g.FUNCS.buy_from_shop
  local outer=function(...)return journal_wrapper(...)end
  A.callback_hooks:record(outer,journal_wrapper);g.FUNCS.buy_from_shop=outer
  for _=1,50 do J:install_hooks(g)end
  check(g.FUNCS.buy_from_shop==outer,'registered outer hook does not acquire a new journal wrapper')
  local first=packed(g.FUNCS.buy_from_shop())
  check(first.n==2 and first[1]=='inner' and first[2]==nil and count==2,'nested suppression preserves callbacks')
  check(#output==2,'nested owner emits one request and one result')
  local replacement=function()count=count+1;return 'replacement',nil end
  g.FUNCS.buy_from_shop=replacement;J:install_hooks(g)
  local replaced=g.FUNCS.buy_from_shop
  check(replaced~=replacement and replaced~=outer,'external replacement is wrapped once')
  J:install_hooks(g);check(g.FUNCS.buy_from_shop==replaced,'replacement installation stable')
  local second=packed(g.FUNCS.buy_from_shop())
  check(second.n==2 and second[1]=='replacement' and count==3,'replacement callback honored')
  check(#output==4,'replacement emits one request and one result')
  -- Toggling modes takes effect on the next callback, without reinstalling.
  B.config.advisor.player_logging=false;g.FUNCS.buy_from_shop()
  B.config.advisor.player_logging=true;g.FUNCS.buy_from_shop()
  check(#output==6 and count==5,'enable transitions preserve callback and event counts')
  return output
end
same(nested(candidate),nested(baseline),'nested, registered and replacement event bytes equal')
print('journal_work335: '..checks..' checks; avoided detail gathers='..saved_details..
  '; avoided full fingerprints='..saved_fingerprints..'; all serialized event bytes equivalent')
