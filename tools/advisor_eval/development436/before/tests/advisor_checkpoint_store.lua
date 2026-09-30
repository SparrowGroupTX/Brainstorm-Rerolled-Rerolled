local M=dofile('Brainstorm/Core/checkpoint_store.lua')
local codec=dofile('Brainstorm/Advisor/retry_journal.lua')
local checks=0;local function check(v,m)assert(v,m);checks=checks+1 end
local function hash(s)local n=0;for i=1,#s do n=(n*31+s:byte(i))%4294967296 end;return string.rep(string.format('%08x',n),8) end
local function fixture()
  local files,fault={},{}
  local io={read=function(name,limit)
    if fault.read==name then return nil,'read failed' end
    local value=files[name];if not value then return nil,'missing' end
    if #value>limit then return nil,'too large' end
    if fault.stale==name then return 'stale' end;return value
  end,write=function(name,bytes)
    if fault.write==name then return false,'write failed' end
    if fault.silent~=name then files[name]=bytes end
    if fault.clear==name and bytes=='' then files[name]='save pending';return false,'clear failed' end
    return true
  end}
  return M.new(io,codec,hash),files,fault,io
end
local s,f,fault,io=fixture();f.legacy='original save'
local first=assert(s:save('slot','new-one',{seed='RUN1'}))
check(first.bank=='a' and first.sequence==1,'first checkpoint bank and sequence')
local bytes,meta=s:load('slot');check(bytes=='new-one' and meta.identity.seed=='RUN1','load committed slot')
local restarted=M.new(io,codec,hash)
local second=assert(restarted:save('slot','new-two',{seed='RUN2'}))
check(second.bank=='b' and second.sequence==2 and f['slot.a.jkr']=='new-one','restart appends new bank while preserving old payload')
check(f.legacy=='original save','legacy checkpoint preserved')
check(restarted:load('slot')=='new-two','fresh restarted checkpoint selected')
for _,name in ipairs({'slot.guard','slot.a.jkr','slot.index'}) do
  local copy={};for k,v in pairs(f)do copy[k]=v end
  fault.write=name
  local saved,reason=s:save('slot','new-three',{seed='RUN3'})
  check(not saved and reason:find('write failed',1,true),'write failure is not success: '..name)
  check(f['slot.b.jkr']=='new-two','last good payload preserved after '..name)
  check(not s:load('slot'),'failed save cannot silently load old checkpoint in session, even when guard write failed')
  for k in pairs(f)do f[k]=nil end;for k,v in pairs(copy)do f[k]=v end;fault.write=nil;s=M.new(io,codec,hash)
end
fault.silent='slot.a.jkr';check(not s:save('slot','new-three',{}),'silent stale write detected by readback')
check(not s:load('slot'),'stale saved file not loaded as fresh')
fault.silent=nil;check(s:save('slot','new-three',{}),'explicit save retries an incomplete save safely')
fault.clear='slot.guard';check(not s:save('slot','new-four',{}),'guard-clear failure not called success')
check(not s:load('slot'),'incomplete final commit blocks load');fault.clear=nil
check(s:save('slot','new-five',{}),'fresh save can repair a pending commit')
local _,current=s:load('slot');f['slot.'..current.bank..'.jkr']='corrupted'
check(not s:load('slot'),'payload tampering detected')
local a,af,ax=fixture();ax.write='slot.a.jkr';check(not a:save('slot','first',{}),'failed very first save')
ax.write=nil;check(a:save('slot','recovered',{}),'first save after restart can recover pending first write')
af['slot.guard']=nil;check(not a:load('slot'),'missing guard never falls through to legacy')
local b,bf=fixture();bf['slot.index']='broken';local _,why=b:load('slot')
check(why~='missing','corrupt commit with missing guard never falls through to old legacy')
check(not b:save('slot','payload',{}),'corrupt index not overwritten blindly')
check(not b:save('slot','',{}),'empty payload rejected')
print('advisor_checkpoint_store: '..checks..' checks passed')
