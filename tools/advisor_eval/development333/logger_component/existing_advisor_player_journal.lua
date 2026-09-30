local M=dofile('tools/advisor_eval/development333/logger_component/player_journal.lua')
local checks=0;local function check(v,m)assert(v,m);checks=checks+1 end
local lines,enabled,notices={},false,{}
local live={phase='hand',dollars=5,hand={{id='a',rank=13}},deck={{id='b',rank=14,face_down=true}},
  playing_cards={{id='a',rank=13},{id='b',rank=14,face_down=true},{id='c',rank=10,face_down=false}},shop_forecast={private_unused_catalog=true}}
local safe=M.public_snapshot(live)
check(safe.deck[1].rank==14 and safe.playing_cards[3].rank==10,'ordinary draw/discard backs preserve public known identities')
check(not safe.shop_forecast and live.shop_forecast,'large catalog omitted without mutation')
live.hand[1].face_down=true;safe=M.public_snapshot(live)
check(not safe.hand[1].rank and not safe.playing_cards[1].rank,'concealed identity redacted consistently across areas')
check(not safe.deck[1].rank and not safe.playing_cards[2].rank,'concealed identity cannot be recovered by subtracting exact draw assignment')
check(safe.playing_cards[3].rank==10 and live.hand[1].rank==13,'public discarded card remains and input unchanged')
local j=M.new({enabled=function()return enabled end,now=function()return 'fixed' end,
  observe=function()return {snapshot=M.public_snapshot(live),advice={status='current',action={kind='discard'}}}end,
  append=function(bytes)lines[#lines+1]=bytes;return true end,notice=function(s)notices[#notices+1]=s end})
check(not j:event('disabled') and #lines==0,'opt-in off produces no writes')
enabled=true;local sequence=j:before('discard',{indices={1,2,3,4,5}})
check(sequence==1 and #lines==1 and lines[1]:find('"status":"current"',1,true),'pre-action observation includes current advice')
live.dollars=99;j:after(sequence,true)
check(#lines==2 and lines[2]:find('"action_sequence":1',1,true),'callback outcome links original observation')
check(lines[1]:find('"dollars":5',1,true),'serialized pre-action snapshot immutable after action')
j.suppressed=1;check(not j:before('nested',{}) and #lines==2,'advisor execution suppresses duplicate callback observation');j.suppressed=0
local encoded=assert(M.encode({text='quote" slash\\ line\n',array={1,false,'x'}}))
check(encoded:find('quote\\" slash\\\\ line\\n',1,true),'JSON escaping')
local cycle={};cycle.self=cycle;check(not M.encode(cycle),'cycles rejected')
check(not M.encode({bad=0/0}),'nonfinite data rejected')
local failed=M.new({enabled=function()return true end,now=function()return 1 end,observe=function()return {}end,
  append=function()return false,'disk full' end,notice=function(s)notices[#notices+1]=s end})
check(not failed:event('fail') and failed.error=='disk full','write failure stops recorder with visible status')
check(not failed:event('again') and #notices==1,'failed recorder does not spam or pretend to record')
-- Real hook integration: player callbacks, returns, exceptions and current/stale advice.
local callbacks,observed={},{}
local g={GAME={round=1,pseudorandom={seed='TEST'},stake=8},SETTINGS={profile=1},STATE=1,STATES={},STATE_COMPLETE=true,
  CONTROLLER={locks={}},hand={cards={{},{}},highlighted={}},FUNCS={}}
g.hand.highlighted={g.hand.cards[2]}
g.FUNCS.play_cards_from_highlighted=function(a,b)callbacks[#callbacks+1]={a,b};return nil,'second',nil end
g.FUNCS.sell_card=function()error('rejected')end
local A={snapshot={capture=function()return {phase='hand',dollars=5,hand={}}end,fingerprint=function()return 'live'end},
  published_key='live',published_game=g.GAME,result={action={kind='discard'}},display={title='Discard'},lines={'Grow Yorick'}}
local B={VERSION='test',config={advisor={player_logging=true}}}
local log=M.attach(A,B,{game=function()return g end,append=function(bytes)observed[#observed+1]=bytes;return true end,now=function()return 123 end})
log:install_hooks(g);local old=g.FUNCS.play_cards_from_highlighted;log:install_hooks(g)
check(old==g.FUNCS.play_cards_from_highlighted,'hook installation idempotent')
local one,two,three=g.FUNCS.play_cards_from_highlighted('arg',42)
check(one==nil and two=='second' and three==nil and #callbacks==1,'callback args and nil return tuple preserved')
check(observed[1]:find('"selected":[2]',1,true) and observed[1]:find('"status":"current"',1,true),'manual selected indices paired with advice')
A.published_key='stale';local ok=pcall(g.FUNCS.sell_card)
check(not ok and observed[#observed]:find('"callback_returned":false',1,true),'exception preserved and callback failure logged')
check(observed[#observed-1]:find('"status":"stale"',1,true),'stale recommendation honestly labelled')
log:update(g);check(observed[#observed]:find('"kind":"state_after_actions"',1,true),'first settled post-action state captured')
do
  local previous=saveManagerAlert;local popup
  saveManagerAlert=function(text)popup=text end
  local reason='Advisor/player_log_archive.lua:149: Total observation byte limit reached; existing logs are preserved.'
  local attached=M.attach({},B,{game=function()return g end,observe=function()return {}end,
    append=function()return false,reason end,now=function()return 'fixed'end})
  check(not attached:event('failure'),'real default notice path observes write failure')
  check(popup=='Recording stopped. Open Advisor > Recording status.','popup remains short with a persistent-details destination')
  check(attached.error==reason and attached.status:find(reason,1,true),'full original failure remains available after popup')
  popup=nil;attached:event('again');check(popup==nil,'persistent error does not produce repeated popups')
  saveManagerAlert=previous
end
print('advisor_player_journal: '..checks..' checks passed')
