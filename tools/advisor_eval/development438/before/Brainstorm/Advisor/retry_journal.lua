-- Bounded metadata only. IO is injected; this module never opens game saves.
-- An interrupted update leaves a guard and disables retries, never restores an
-- older counter. The codec parses plain data and cannot execute journal text.
local J={MAX_BYTES=16777216,MAX_RUNS=64}
local function plain(v) return type(v)=='table' and getmetatable(v)==nil end
local function encode(value)
  local seen,nodes={},0
  local function visit(v,depth)
    nodes=nodes+1;assert(nodes<=32768 and depth<=16,'Journal structure exceeds its bound.')
    if type(v)=='boolean' then return v and 'b1' or 'b0' end
    if type(v)=='number' then
      assert(v==v and math.abs(v)<math.huge,'Invalid number.')
      return 'n'..string.format('%.17g',v)..';'
    end
    if type(v)=='string' then assert(#v<=131072,'String exceeds bound.');return 's'..#v..':'..v end
    assert(plain(v) and not seen[v],'Expected acyclic plain data.')
    seen[v]=true;local keys,out={}, {'{'}
    for k in pairs(v) do
      assert(type(k)=='string' or type(k)=='number' and k%1==0 and k>=1 and k<=32768,'Invalid key.')
      keys[#keys+1]=k
    end
    table.sort(keys,function(a,b) if type(a)~=type(b) then return type(a)<type(b) end;return a<b end)
    for _,k in ipairs(keys) do out[#out+1]=visit(k,depth+1);out[#out+1]=visit(v[k],depth+1) end
    out[#out+1]='}';seen[v]=nil;return table.concat(out)
  end
  local result='BR-RETRY-1\n'..visit(value,0)
  assert(#result<=J.MAX_BYTES,'Journal byte allowance exhausted.')
  return result
end
function J.encode(value) local ok,result=pcall(encode,value);if ok then return result end;return nil,tostring(result) end
function J.decode(bytes)
  if type(bytes)~='string' or #bytes>J.MAX_BYTES or bytes:sub(1,11)~='BR-RETRY-1\n' then return nil,'Invalid journal header or size.' end
  local pos,nodes=12,0
  local function parse(depth)
    nodes=nodes+1;assert(nodes<=32768 and depth<=16,'Journal structure exceeds its bound.')
    local token=bytes:sub(pos,pos);pos=pos+1
    if token=='b' then
      local b=bytes:sub(pos,pos);pos=pos+1;assert(b=='0' or b=='1','Invalid boolean.');return b=='1'
    elseif token=='n' then
      local last=bytes:find(';',pos,true);assert(last and last-pos<=32,'Invalid number length.')
      local n=tonumber(bytes:sub(pos,last-1));pos=last+1
      assert(n and n==n and math.abs(n)<math.huge,'Invalid number.');return n
    elseif token=='s' then
      local last=bytes:find(':',pos,true);assert(last and last-pos<=6,'Invalid string length.')
      local n=tonumber(bytes:sub(pos,last-1))
      assert(n and n%1==0 and n>=0 and n<=131072 and last+n<=#bytes,'Invalid string.')
      pos=last+n+1;return bytes:sub(last+1,last+n)
    elseif token=='{' then
      local out={}
      while bytes:sub(pos,pos)~='}' do
        assert(pos<=#bytes,'Unclosed table.')
        local k=parse(depth+1)
        assert(type(k)=='string' or type(k)=='number' and k%1==0 and k>=1 and k<=32768,'Invalid key.')
        assert(out[k]==nil,'Duplicate key.');out[k]=parse(depth+1)
      end
      pos=pos+1;return out
    end
    error('Unknown journal token.')
  end
  local ok,result=pcall(parse,0)
  if not ok or pos~=#bytes+1 then return nil,'Malformed journal data.' end
  local canonical=J.encode(result)
  if canonical~=bytes then return nil,'Noncanonical journal data.' end
  return result
end
function J.new(io,memory)
  local store={}
  local function failure(reason) store.error='Retry memory unavailable: '..tostring(reason);return nil,store.error end
  local function read(which)
    local ok,data,reason=pcall(io.read,which,J.MAX_BYTES)
    if not ok then return nil,tostring(data) end
    return data,reason
  end
  local function validate(catalog)
    if not plain(catalog) or catalog.schema~=1 or not plain(catalog.runs) then return nil,'Invalid catalog.' end
    for k in pairs(catalog) do if k~='schema' and k~='runs' then return nil,'Unknown catalog field.' end end
    local out={schema=1,runs={}};local count=0
    for id,ledger in pairs(catalog.runs) do
      count=count+1;if count>J.MAX_RUNS then return nil,'Run metadata allowance exhausted.' end
      local safe,reason=memory.import(ledger,id);if not safe then return nil,reason end;out.runs[id]=safe
    end
    return out
  end
  function store:load()
    if self.error then return nil,self.error end
    if self.catalog then return self.catalog end
    local guard,gr=read('guard')
    if guard~=nil and guard~='' or guard==nil and gr~='missing' then return failure(gr or 'Interrupted journal update.') end
    local bytes,reason=read('data')
    if bytes==nil then
      if reason~='missing' then return failure(reason) end
      if guard~=nil then return failure('Missing data beside an existing journal guard.') end
      self.catalog={schema=1,runs={}};return self.catalog
    end
    if guard==nil then return failure('Missing journal guard.') end
    local raw,why=J.decode(bytes);if not raw then return failure(why) end
    local valid;valid,why=validate(raw);if not valid then return failure(why) end
    self.catalog=valid;return valid
  end
  function store:get(id)
    local catalog,reason=self:load();if not catalog then return nil,reason end
    if catalog.runs[id] then return memory.import(catalog.runs[id],id) end
    return memory.new(id)
  end
  function store:put(ledger)
    local catalog,reason=self:load();if not catalog then return nil,reason end
    local safe;safe,reason=memory.export(ledger);if not safe then return nil,reason end
    local previous=catalog.runs[safe.run_id]
    if previous then
      if safe.reloads_used<previous.reloads_used or safe.marks<previous.marks then return nil,'Retry counters cannot move backwards.' end
      for i,report in ipairs(previous.reports) do
        local next_report=safe.reports[i]
        if not next_report or next_report.checkpoint_sequence~=report.checkpoint_sequence or next_report.action_key~=report.action_key then
          return nil,'Recorded reload history cannot be replaced.'
        end
      end
      if safe.marks==previous.marks and previous.checkpoint then
        local old,cp=previous.checkpoint,safe.checkpoint
        if not cp or cp.key~=old.key or cp.sequence~=old.sequence then return nil,'Checkpoint identity cannot change without a new mark.' end
        for i,action in ipairs(old.attempts) do
          if cp.attempts[i]~=action then return nil,'Recorded first actions cannot be removed.' end
        end
        if old.pending and cp.pending~=old.pending then
          local report=safe.reports[previous.reloads_used+1]
          if not report or report.action_key~=old.pending or report.checkpoint_sequence~=old.sequence then
            return nil,'A pending line needs an explicit loss report.'
          end
        end
      end
    end
    local candidate={schema=1,runs={}}
    for id,entry in pairs(catalog.runs) do candidate.runs[id]=entry end
    candidate.runs[safe.run_id]=safe
    candidate,reason=validate(candidate);if not candidate then return nil,reason end
    local bytes;bytes,reason=J.encode(candidate);if not bytes then return nil,reason end
    local function verified_write(which,data)
      local ok,success,why=pcall(io.write,which,data)
      if not ok or not success then return nil,why or success or 'Journal write failed.' end
      local written,err=read(which)
      if written~=data then return nil,err or 'Journal verification failed.' end
      return true
    end
    local ok;ok,reason=verified_write('guard','update pending')
    if not ok then return failure(reason) end
    ok,reason=verified_write('data',bytes)
    if not ok then return failure(reason) end
    ok,reason=verified_write('guard','')
    if not ok then return failure(reason) end
    self.catalog=candidate;return memory.import(safe,safe.run_id)
  end
  return store
end
return J
