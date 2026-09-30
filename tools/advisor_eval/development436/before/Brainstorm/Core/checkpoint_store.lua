-- Two payload banks and a verified commit record. IO/codec/hash are injected;
-- only the user-operated checkpoint runtime supplies actual checkpoint files.
local M={MAX_BYTES=16777216}
function M.new(io,codec,hash)
  local S={failed={}}
  local function read(name,limit)
    local ok,value,reason=pcall(io.read,name,limit or M.MAX_BYTES)
    if not ok then return nil,tostring(value) end
    return value,reason
  end
  local function write(name,bytes)
    local ok,success,reason=pcall(io.write,name,bytes)
    if not ok or not success then return nil,tostring(reason or success or 'Write failed.') end
    local actual,why=read(name)
    if actual~=bytes then return nil,why or 'Written data did not pass read-back verification.' end
    return true
  end
  local function index(prefix)
    local bytes,reason=read(prefix..'.index',32768)
    if not bytes then return nil,reason end
    local meta,why=codec.decode(bytes)
    if not meta or meta.schema~=2 or (meta.bank~='a' and meta.bank~='b') or
      type(meta.sequence)~='number' or meta.sequence<1 or meta.sequence%1~=0 or
      type(meta.digest)~='string' or #meta.digest~=64 or not meta.digest:match('^[0-9a-f]+$') or
      type(meta.bytes)~='number' or meta.bytes<1 or meta.bytes>M.MAX_BYTES or
      type(meta.identity)~='table' then return nil,why or 'Invalid checkpoint commit record.' end
    return meta
  end
  function S:save(prefix,bytes,identity)
    if type(bytes)~='string' or #bytes<1 or #bytes>M.MAX_BYTES then return nil,'Checkpoint exceeds its byte limit.' end
    local previous,reason=index(prefix)
    if not previous and reason~='missing' then return nil,reason end
    local guard,gr=read(prefix..'.guard',128)
    if guard==nil and gr~='missing' then return nil,gr end
    if not previous and guard~=nil and guard~='save pending' then return nil,'The checkpoint commit record is missing.' end
    local meta={schema=2,bank=previous and (previous.bank=='a' and 'b' or 'a') or 'a',
      sequence=previous and previous.sequence+1 or 1,bytes=#bytes,digest=hash(bytes),identity=identity}
    local encoded,why=codec.encode(meta);if not encoded then return nil,why end
    -- The guard prevents a failed save from later looking like a successful old
    -- slot. The previous committed payload bank is never overwritten here.
    for _,entry in ipairs({{prefix..'.guard','save pending'},
      {prefix..'.'..meta.bank..'.jkr',bytes},{prefix..'.index',encoded},{prefix..'.guard',''}}) do
      local ok;ok,why=write(entry[1],entry[2]);if not ok then self.failed[prefix]=true;return nil,why end
    end
    self.failed[prefix]=nil
    return meta
  end
  function S:load(prefix)
    if self.failed[prefix] then return nil,'The last save in this session failed. Save successfully before loading this slot.' end
    local guard,reason=read(prefix..'.guard',128)
    if guard==nil then
      local committed,why=index(prefix)
      if committed or why~='missing' then return nil,'Checkpoint guard is missing; refusing an unverified slot.' end
      return nil,reason=='missing' and 'missing' or reason
    end
    if guard~='' then return nil,'The last save did not complete. This slot is not reported as a successful save.' end
    local meta,why=index(prefix);if not meta then return nil,why end
    local bytes;bytes,why=read(prefix..'.'..meta.bank..'.jkr')
    if not bytes or #bytes~=meta.bytes or hash(bytes)~=meta.digest then return nil,why or 'Checkpoint data differs from its verified receipt.' end
    return bytes,meta
  end
  return S
end
return M
