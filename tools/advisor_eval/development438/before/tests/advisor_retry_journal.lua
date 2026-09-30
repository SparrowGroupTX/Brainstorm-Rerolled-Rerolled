local J=dofile('Brainstorm/Advisor/retry_journal.lua')
local M=dofile('Brainstorm/Advisor/retry_memory.lua')
local checks=0
local function check(v,label) assert(v,label);checks=checks+1 end
local function eq(a,b,label) check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function disk(files,fail_at)
  local count=0
  return {read=function(key) if files[key]==nil then return nil,'missing' end;return files[key] end,
    write=function(key,bytes)
      count=count+1
      if count==fail_at then files[key]=bytes:sub(1,math.max(1,math.floor(#bytes/2)));return nil,'Injected partial write.' end
      files[key]=bytes;return true
    end}
end
local card={id='playing:1',key='c_base',rank=8,nominal=8,suit='Hearts',ability={}}
local s={phase='hand',ante=1,round=1,hand={card},deck={},playing_cards={card},jokers={},consumeables={}}
local initial=assert(M.new('run'));local marked=assert(M.mark(initial,'run',s))
local pending=assert(M.record(marked,'run',s,{kind='play',indices={1}}))
local failed=assert(M.failed(pending,'run',s))
do
  local files={};local store=J.new(disk(files),M)
  eq(assert(store:get('run')).reloads_used,0,'absent own metadata starts empty')
  eq(next(files),nil,'read-only context creates no files')
  check(store:put(failed),'write complete verified catalog')
  eq(files.guard,'','successful transaction clears guard')
  local restored=assert(J.new(disk(files),M):get('run'))
  eq(restored.reloads_used,1,'restart retains reload count')
  eq(restored.checkpoint.failures[1].action_key,failed.checkpoint.failures[1].action_key,'restart retains reported line')
  eq(store:put(initial),nil,'stale valid ledger cannot restore a lower counter')
  local state=assert(store:get('run'));state.reloads_used=0
  eq(assert(store:get('run')).reloads_used,1,'returned ledger is detached')
  local changed={phase='shop',ante=1,round=1,hand={card},deck={},playing_cards={card}}
  local moved=assert(M.mark(restored,'run',changed));check(store:put(moved),'new checkpoint can be stored')
  eq(assert(J.new(disk(files),M):get('run')).reloads_used,1,'checkpoint changes do not renew count')
  eq(assert(store:get('different')).reloads_used,0,'separate identity gets separate initial count')
end
do
  local files={};local store=J.new(disk(files),M)
  check(store:put(marked),'prepare checkpoint before stale pending update')
  check(store:put(pending),'record pending before stale update')
  eq(store:put(marked),nil,'same-counter stale checkpoint cannot erase a pending first action')
  check(store:put(failed),'explicit loss can close the pending action')
  eq(assert(store:get('run')).reloads_used,1,'loss closure retains count')
end
for failure=1,3 do
  local files={};check(J.new(disk(files),M):put(marked),'prepare catalog before interruption')
  local store=J.new(disk(files,failure),M)
  eq(store:put(failed),nil,'interrupted write fails '..failure)
  eq(store:get('run'),nil,'same process fails closed '..failure)
  -- Failure writing the final empty guard can still complete that exact write;
  -- it is safe on restart only if the committed catalog already has the count.
  local restored=J.new(disk(files),M):get('run')
  check(restored==nil or restored.reloads_used==1,'restart never falls back to a pre-reload count '..failure)
end
do
  local files={guard='update pending'}
  eq(J.new(disk(files),M):get('new'),nil,'pending initial transaction cannot initialize a new catalog')
  files={guard=''}
  eq(J.new(disk(files),M):get('new'),nil,'lost catalog beside existing guard cannot renew spent counters')
  files={data=assert(J.encode({schema=1,runs={}}))}
  eq(J.new(disk(files),M):get('new'),nil,'missing guard beside an existing catalog fails closed')
  files={guard='',data='os.execute("bad")'}
  eq(J.new(disk(files),M):get('new'),nil,'executable or malformed journal is never run or reset')
  local io={read=function() error('read failure') end,write=function() error('not expected') end}
  eq(J.new(io,M):get('run'),nil,'IO exceptions are contained')
end
do
  local original={schema=1,runs={['a\000b']={n=7.25,bool=false,text='{}\n:s'}}}
  local bytes=assert(J.encode(original));eq(assert(J.encode(assert(J.decode(bytes)))),bytes,'codec is deterministic and round trips delimiters')
  for _,bad in ipairs({bytes..'x',bytes:sub(1,-2),'BR-RETRY-1\n{s1:as1:bs1:as1:c}',
    'BR-RETRY-1\nnnan;','BR-RETRY-1\ns999999:x','BR-RETRY-1\n{z}',
    'BR-RETRY-1\ns01:a','BR-RETRY-1\nb2','BR-RETRY-1\nn1e999;'}) do
    eq(J.decode(bad),nil,'malformed data rejected')
  end
  local cycle={};cycle.self=cycle;eq(J.encode(cycle),nil,'cyclic data rejected')
  eq(J.encode(setmetatable({},{__index={}})),nil,'metatable rejected')
  eq(J.decode(string.rep('x',J.MAX_BYTES+1)),nil,'oversized journal rejected')
end
do
  local files={};local store=J.new(disk(files),M)
  for i=1,J.MAX_RUNS do check(store:put(assert(M.new('run'..i))),'bounded identity '..i) end
  eq(store:put(assert(M.new('overflow'))),nil,'full catalog never evicts old budgets')
  check(J.new(disk(files),M):get('run1'),'earliest identity remains after capacity refusal')
end
print('advisor_retry_journal: '..checks..' checks passed')
