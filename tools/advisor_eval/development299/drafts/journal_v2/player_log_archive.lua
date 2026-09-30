-- Append-only, independently decodable segments. IO, hashing and compression
-- are injected. This module never reads saves or writes retry/profile history.
local M={MAX_EVENT_BYTES=1048576,MAX_FRAME_BYTES=3145728,MAX_SEGMENT_BYTES=8388608,
  MAX_SEGMENT_EVENTS=2048,MAX_TOTAL_BYTES=134217728,MAX_FILES=4096,MAX_SESSION_EVENTS=300000}
local function whole(n)return type(n)=='number'and n==n and n>=0 and n<math.huge and n%1==0 end
local function shallow(t)local out={};for k,v in pairs(t)do out[k]=v end;return out end
local function hex(h)return type(h)=='string'and #h==64 and not h:find('[^0-9a-f]')end
local function hash(deps,bytes)local h=deps.hash(bytes);assert(hex(h),'Invalid archive hash result.');return h end
local function encode(deps,value,frame)local raw,why=(frame and deps.encode_frame or deps.encode)(value);assert(raw,why);return raw end
local function chunks(raw)
  if #raw<=262144 then return raw end
  local out,first={},1
  while first<=#raw do
    local last=math.min(#raw,first+262143)
    while last<#raw and raw:byte(last+1)>=128 and raw:byte(last+1)<192 do last=last-1 end
    assert(last>=first,'Invalid oversized UTF-8 sequence.')
    out[#out+1]=raw:sub(first,last);first=last+1
  end
  return out
end
local function representation(deps,event,original,last)
  local snapshot=type(event.context)=='table'and event.context.snapshot
  if type(snapshot)~='table'then return {event_json=chunks(original)},last end
  local raw=encode(deps,snapshot):gsub('\n$','')
  local key=hash(deps,raw)
  local token='__BRAINSTORM_PUBLIC_SNAPSHOT_SLOT_V2__'
  while original:find('"'..token..'"',1,true)do token=token..'_';assert(#token<128,'Reserved snapshot marker collision.')end
  local replaced=shallow(event);replaced.context=shallow(event.context);replaced.context.snapshot=token
  local skeleton=encode(deps,replaced);local start,finish=skeleton:find('"'..token..'"',1,true)
  assert(start,'Snapshot substitution could not be located.')
  local prefix,suffix=skeleton:sub(1,start-1),skeleton:sub(finish+1)
  assert(prefix..raw..suffix==original,'Snapshot substitution did not preserve the exact original event.')
  local body={prefix=chunks(prefix),suffix=chunks(suffix),snapshot_id=key}
  if not last or last.key~=key then body.snapshot_json=chunks(raw)
  else assert(last.raw==raw,'Snapshot hash collision.')end
  return body,{key=key,raw=raw}
end
function M.frame(deps,event,original,state)
  assert(type(original)=='string'and #original<=M.MAX_EVENT_BYTES+1,'Original event exceeds archive bound.')
  assert(whole(event.sequence)and event.sequence>0,'Invalid event sequence.')
  local body,last=representation(deps,event,original,state.last)
  body.schema=2;body.session=state.session;body.segment=state.segment
  body.previous_frame_sha256=state.previous or '-'
  -- The wrapper quotes exact JSON byte strings; its bound is separate from
  -- the original reconstructed event's unchanged one-MiB bound.
  local raw=encode(deps,body,true)
  assert(#raw<=M.MAX_FRAME_BYTES,'Archive frame exceeds its decoded bound.')
  local payload,codec=raw,'raw'
  if deps.compress then
    local compressed=deps.compress(raw)
    assert(type(compressed)=='string'and #compressed<=M.MAX_FRAME_BYTES,'Invalid compressed archive frame.')
    assert(type(deps.decompress)=='function'and deps.decompress(compressed)==raw,'Archive compression roundtrip failed.')
    if #compressed<#raw then payload,codec=compressed,'zlib' end
  end
  local header=table.concat({'BRJ2',codec,#payload,#raw,event.sequence,hash(deps,raw),hash(deps,original)},'\t')..'\n'
  local bytes=header..payload..'\n'
  return bytes,{last=last,previous=hash(deps,bytes),sequence=event.sequence,codec=codec,decoded_bytes=#raw}
end
function M.new(deps)
  assert(type(deps)=='table'and type(deps.encode)=='function'and type(deps.encode_frame)=='function'and type(deps.hash)=='function','Archive codec is unavailable.')
  local fs=deps.fs
  local limits={}
  for key,default in pairs(M)do if type(default)=='number'then
    local value=deps.limits and deps.limits[key]or default
    assert(whole(value)and value>0 and value<=default,'Invalid archive '..key..' bound.');limits[key]=value
  end end
  local archive={events=0,physical_bytes=0,segment_events=0,segment_bytes=0,segment=0,paths={}}
  local state={};local identity,profile,path,base
  local function fail(reason)archive.error=tostring(reason);return nil,archive.error end
  local function info(name)
    local entry=fs.getInfo(name)
    if entry then assert(entry.type=='file'and whole(entry.size),'Archive catalog contains invalid file metadata.')end
    return entry
  end
  local function catalog()
    assert(fs and fs.getDirectoryItems and fs.getInfo and fs.createDirectory and fs.append,'Archive filesystem is unavailable.')
    local total,count=0,0
    for _,directory in ipairs({'advisor_player_log_v1','advisor_player_log_v2'})do
      local directory_info=fs.getInfo(directory)
      if directory_info then
        assert(directory_info.type=='directory','Archive directory metadata is invalid.')
        local names=fs.getDirectoryItems(directory);assert(type(names)=='table','Archive catalog unavailable.')
        for _,name in ipairs(names)do
          -- Count every file in these owned directories, including partial
          -- tails and unknown names. A new extension never resets storage.
          assert(type(name)=='string'and not name:find('[/\\]'),'Invalid archive catalog name.')
          local entry=info(directory..'/'..name)
          assert(entry,'An archive catalog entry disappeared.')
          count=count+1;assert(count<=limits.MAX_FILES,'Observation file-count limit reached.')
          total=total+entry.size
        end
      end
    end
    return total,count
  end
  local function segment()
    if not base then
      local label=deps.session_name and deps.session_name()or os.date('!%Y%m%dT%H%M%SZ')
      assert(type(label)=='string'and #label<=64 and label:match('^[%w%-_]+$'),'Invalid archive session identity.')
      for n=1,limits.MAX_FILES do
        local candidate='session-'..label..'-'..n
        local occupied=false
        for _,name in ipairs(fs.getDirectoryItems('advisor_player_log_v2'))do
          if name:sub(1,#candidate+1)==candidate..'-'then occupied=true;break end
        end
        if not occupied then base=candidate;break end
      end
      assert(base,'No unused archive session identity.')
    end
    archive.segment=archive.segment+1
    path='advisor_player_log_v2/'..base..'-'..string.format('%06d',archive.segment)..'.brj'
    assert(not fs.getInfo(path),'Refusing to append to an existing archive segment.')
    state.last=nil;state.session=base;state.segment=archive.segment
    archive.segment_events,archive.segment_bytes=0,0
  end
  local function range(offset,length)
    if deps.read_range then return deps.read_range(path,offset,length)end
    assert(fs.newFile,'Bounded archive readback is unavailable.')
    local file,why=fs.newFile(path,'r');assert(file,why)
    local ok,value=pcall(function()
      assert(file:seek(offset),'Archive readback seek failed.')
      local raw=file:read(length);assert(type(raw)=='string'and #raw==length,'Archive readback length failed.');return raw
    end)
    local closed=file:close()
    assert(ok,value);assert(closed~=false,'Archive readback close failed.');return value
  end
  function archive:rotate(reason)
    self.rotate_reason=reason or 'Explicit boundary';path=nil;return true
  end
  function archive:append(event,original)
    if self.error then return nil,self.error end
    local ok,result=pcall(function()
      assert(self.events<limits.MAX_SESSION_EVENTS,'Archive session event limit reached.')
      assert(not state.sequence or event.sequence==state.sequence+1,'Archive event sequence is discontinuous.')
      local next_identity,next_profile
      if deps.identity then next_identity,next_profile=deps.identity()end
      if next_identity~=identity or next_profile~=profile then path=nil;identity,profile=next_identity,next_profile end
      local total,count=catalog()
      local created,why=fs.createDirectory('advisor_player_log_v2');assert(created,why)
      if not path or self.segment_events>=limits.MAX_SEGMENT_EVENTS then segment()end
      local bytes,next_state=M.frame(deps,event,original,state)
      if self.segment_bytes>0 and self.segment_bytes+#bytes>limits.MAX_SEGMENT_BYTES then
        segment();bytes,next_state=M.frame(deps,event,original,state)
      end
      assert(#bytes<=limits.MAX_SEGMENT_BYTES,'One archive frame exceeds the segment byte limit.')
      local before=info(path)
      assert((before and before.size or 0)==self.segment_bytes,'Archive segment changed outside this writer.')
      assert(count+(before and 0 or 1)<=limits.MAX_FILES,'Observation file-count limit reached.')
      assert(total+#bytes<=limits.MAX_TOTAL_BYTES,'Total observation byte limit reached; existing logs are preserved.')
      local appended,error=fs.append(path,bytes);assert(appended,error or 'Archive append failed.')
      local after=info(path)
      assert(after and after.size==self.segment_bytes+#bytes,'Archive append length could not be verified.')
      assert(range(self.segment_bytes,#bytes)==bytes,'Archive append bytes could not be verified.')
      if self.segment_events==0 then self.paths[#self.paths+1]=path end
      self.events=self.events+1;self.segment_events=self.segment_events+1;self.segment_bytes=self.segment_bytes+#bytes
      self.physical_bytes=total+#bytes;self.path=path;self.codec=next_state.codec
      state.last,state.previous,state.sequence=next_state.last,next_state.previous,next_state.sequence
      return true
    end)
    if not ok then return fail(result)end
    return result
  end
  return archive
end
return M
