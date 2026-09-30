local M=dofile('Brainstorm/Core/checkpoint_runtime.lua')
local Store=dofile('Brainstorm/Core/checkpoint_store.lua')
local codec=dofile('Brainstorm/Advisor/retry_journal.lua')
local checks=0;local function check(v,m)assert(v,m);checks=checks+1 end
local function fixture()
  local files,alerts,events,faults={},{},{},{}
  local g={STAGE=1,STAGES={RUN=1},STATES={SELECTING_HAND=1,SHOP=2},STATE=1,STATE_COMPLETE=true,
    SETTINGS={profile=1},CONTROLLER={locks={}},GAME={round=3,round_resets={ante=2},pseudorandom={seed='NOW'},stake=8}}
  local refreshed,deleted,started,invalidated=0,0,0,0
  local B={VERSION='test',Advisor={player_log={event=function(_,kind,details)events[#events+1]={kind,details} end},
    settings_changed=function()invalidated=invalidated+1 end},retry_counter=5}
  function g:delete_run()deleted=deleted+1 end
  function g:start_run(args)started=started+1;self.GAME=args.savetext.GAME;self.STATE=args.savetext.STATE end
  local fs={getInfo=function(path)return files[path] and {size=#files[path],type='file'} end,
    read=function(path)return files[path] end,write=function(path,bytes)if faults.write then return false,'disk full' end;files[path]=bytes;return true end}
  local d={game=function()return g end,fs=fs,store=Store,codec=codec,
    alert=function(s)alerts[#alerts+1]=s end,hash=function(s)return string.rep(string.format('%08x',#s),8)end,
    compress=function(s)return 'zip'..s end,decompress=function(s)assert(s:sub(1,3)=='zip','bad zip');return s:sub(4) end,
    pack=function(s)return assert(codec.encode(s))end,unpack=function(s)return assert(codec.decode(s))end,
    refresh=function()
      refreshed=refreshed+1;if faults.refresh then return end
      g.ARGS.save_run={GAME={round=g.GAME.round,round_resets={ante=g.GAME.round_resets.ante},pseudorandom={seed=g.GAME.pseudorandom.seed}},
        cardAreas={},BLIND={},BACK={},STATE=g.STATE}
    end,is_down=function()return false end}
  local r=M.attach(B,d)
  return r,g,B,files,alerts,faults,function()return refreshed,deleted,started,invalidated end,d,events
end
local r,g,B,f,alerts,faults,counts,d,events=fixture()
check(r:save('1'),'fresh save succeeds even G.ARGS missing after restart')
local refreshed,deleted,started=counts();check(refreshed==1 and deleted==0 and started==0,'save refresh only, no load actions')
check(alerts[#alerts]:find('Saved and verified',1,true),'verified save message')
g.GAME.round=4;g.GAME.pseudorandom.seed='NEW'
r=M.attach(B,d);check(r:save('1'),'restart instance refreshes stale G.ARGS')
check(r:load('1'),'verified load requested');check(alerts[#alerts]:find('waiting',1,true),'load success waits for settled state')
r:update(0.1);check(alerts[#alerts]:find('Loaded slot',1,true),'restored identity completion recorded')
local _,deletes,starts,invalidated=counts();check(deletes==1 and starts==1 and invalidated==1,'successful load invalidates advisor once')
check(B.retry_counter==5,'checkpoint restoration never changes retry count')
check(not r:load('5'),'empty slot fails');local _,afterdeletes=counts();check(afterdeletes==deletes,'invalid load never deletes run')
faults.refresh=true;local before=alerts[#alerts];check(not r:save('2'),'no refreshed G.ARGS does not reuse old run')
check(alerts[#alerts]:find('failed',1,true) and alerts[#alerts]~=before,'failure clearly visible');faults.refresh=nil
faults.write=true;check(not r:save('2'),'write failure surfaced');check(alerts[#alerts]:find('failed',1,true),'no success toast after disk failure');faults.write=nil
g.STATE_COMPLETE=false;check(not r:save('1') and not r:load('1'),'busy save and load rejected');g.STATE_COMPLETE=true
check(not r:save('../bad'),'invalid slot rejected')
local saves=counts();check(r:hotkey('3',true,false,false),'save hotkey consumed')
check(r:hotkey('3',true,false,false),'held key consumed without repeating');check(counts()==saves+1,'one save per keypress')
r:update(0.1);r:hotkey('3',true,false,false);check(counts()==saves+2,'key release re-arms next explicit save')
check(not r:hotkey('4',true,false,true),'text input does not save')
local found=false;for _,e in ipairs(events)do if e[1]=='checkpoint_saved' and e[2].receipt.identity.seed=='NEW' then found=true end end
check(found,'receipt logging ties slot to new run identity')
-- Decodable legacy checkpoints remain available, with honest unknown timestamp.
f['1/saveState4.jkr']='zip'..assert(codec.encode(g.ARGS.save_run))
check(r:load('4'),'legacy slot preflight supported');r:update(0.1)
check(alerts[#alerts]:find('legacy slot',1,true),'legacy receipt limitation visible')
print('advisor_checkpoint_runtime: '..checks..' checks passed')
