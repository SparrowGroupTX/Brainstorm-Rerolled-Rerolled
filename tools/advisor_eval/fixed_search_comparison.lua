-- Pure search only: the Python coordinator freezes and bounds this one-use job.
local model, catalog, job = assert(SEARCH_MODEL), assert(SEARCH_CATALOG), assert(SEARCH_JOB)
local function quote(value)
  return '"'..value:gsub('[%z\1-\31\\"]',function(c)
    return string.format('\\u%04x',string.byte(c))
  end)..'"'
end
local function json(value)
  local kind=type(value)
  if kind=='nil' then return 'null' end
  if kind=='boolean' then return tostring(value) end
  if kind=='number' then assert(value==value and math.abs(value)<math.huge);return string.format('%.17g',value) end
  if kind=='string' then return quote(value) end
  assert(kind=='table','Unsupported output type')
  local array=true;local count=0
  for key in pairs(value) do count=count+1;if type(key)~='number' or key%1~=0 or key<1 then array=false end end
  local out={}
  if array and count==#value then
    for i=1,#value do out[#out+1]=json(value[i]) end
    return '['..table.concat(out,',')..']'
  end
  local keys={};for key in pairs(value) do assert(type(key)=='string');keys[#keys+1]=key end;table.sort(keys)
  for _,key in ipairs(keys) do out[#out+1]=quote(key)..':'..json(value[key]) end
  return '{'..table.concat(out,',')..'}'
end
local function emit(value) io.stdout:write(json(value),'\n');io.stdout:flush() end
local cursor,finish=job.start,job.start+job.limit
while cursor<finish do
  local requested=math.min(job.batch_limit,finish-cursor)
  local began=os.clock()
  local result,reason=model.search(catalog,{start=cursor,limit=requested,max_matches=job.match_cap,
    min_blue=2,min_steel=1,require_telescope=true,require_planet=job.target_planet,
    target_hand=job.target_planet=='c_mars' and 'Four of a Kind' or 'Flush'})
  if not result then error(reason or 'Search returned no supported result') end
  emit({kind='batch',start=cursor,requested=requested,result=result,os_clock_seconds=os.clock()-began})
  if result.status=='unsupported' then return end
  assert(type(result.tested)=='number' and result.tested>0 and result.tested<=requested,'Invalid tested count')
  assert(result.next_index==cursor+result.tested,'Noncontiguous next cursor')
  cursor=result.next_index
end
emit({kind='done',next_index=cursor})
