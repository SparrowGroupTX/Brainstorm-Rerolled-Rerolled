-- Detached reporting only. No policy/scorer execution; full certificates stay
-- internal. Typed graph frames avoid expanding the complete nested comparison
-- into one bounded player-journal event. No fields or worlds are truncated.
local M={schema='advisor_evidence_graph_v1'}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function scalar(v)
 local t=type(v)
 if t=='string'then assert(#v<=262144,'Evidence string exceeds bound')
 elseif t=='number'then assert(finite(v),'Nonfinite evidence')
 else assert(t=='boolean'or t=='nil','Unsupported evidence value')end
 return {kind=t,value=v}
end
function M.frames(value,encode)
 local ok,frames=pcall(function()
  local nodes,ids,active,entries={},{},{},0
  local visit
  visit=function(v,depth)
   if type(v)~='table'then return scalar(v)end
   assert(depth<=64 and not getmetatable(v),'Unsupported evidence depth/metatable')
   assert(not active[v],'Cyclic evidence');if ids[v]then return {kind='ref',id=ids[v]}end
   assert(#nodes<25000,'Evidence node budget exceeded')
   local id=#nodes+1;local node={id=id,fields={}};nodes[id]=node;ids[v]=id;active[v]=true
   local keys={};for k in pairs(v)do
    assert(type(k)=='string'or finite(k),'Unsupported evidence key');keys[#keys+1]=k
   end
   assert(#keys<=2048,'Evidence table field bound exceeded')
   table.sort(keys,function(a,b)return type(a)..tostring(a)<type(b)..tostring(b)end)
   for _,k in ipairs(keys)do
    entries=entries+1;assert(entries<=500000,'Evidence entry budget exceeded')
    node.fields[#node.fields+1]={key=scalar(k),value=visit(v[k],depth+1)}
   end
   active[v]=nil;return {kind='ref',id=id}
  end
  local root=visit(value,0);local output={};local bytes=0
  local function add(frame)
   local raw,why=encode(frame);assert(raw,why or 'Evidence frame encoding failed')
   bytes=bytes+#raw;assert(bytes<=67108864,'Evidence byte budget exceeded');output[#output+1]=raw
  end
  add({schema=M.schema,kind='header',root=root,node_count=#nodes,entry_count=entries,fields_omitted=0})
  for start=1,#nodes,16 do
   local group={};for i=start,math.min(start+15,#nodes)do group[#group+1]=nodes[i]end
   add({schema=M.schema,kind='nodes',first=start,nodes=group})
  end
  add({schema=M.schema,kind='end',complete=true,node_count=#nodes,entry_count=entries})
  return output
 end)
 if not ok then return nil,tostring(frames)end
 return frames
end
-- A reader receives decoded frames. Reject incomplete/out-of-order pages and
-- dangling references instead of reconstructing a partial comparative result.
function M.restore(frames)
 local ok,result=pcall(function()
  local head=frames[1];assert(head and head.schema==M.schema and head.kind=='header','Missing evidence header')
  assert(finite(head.node_count)and head.node_count%1==0 and head.node_count>=0 and head.node_count<=25000,'Invalid node count')
  assert(head.fields_omitted==0 and finite(head.entry_count)and head.entry_count%1==0 and head.entry_count>=0 and head.entry_count<=500000,'Invalid entry count')
  local nodes,records={},{};local count=0
  for i=1,head.node_count do nodes[i]={}end
  for fi=2,#frames-1 do
   local page=frames[fi];assert(page.schema==M.schema and page.kind=='nodes'and page.first==#records+1,'Out-of-order evidence page')
   assert(#page.nodes>=1 and #page.nodes<=16,'Invalid evidence page size')
   for _,node in ipairs(page.nodes)do assert(node.id==#records+1 and nodes[node.id],'Invalid node ID');records[#records+1]=node end
  end
  local tail=frames[#frames]
  assert(tail and tail.schema==M.schema and tail.kind=='end'and tail.complete and #records==head.node_count and
   tail.node_count==head.node_count and tail.entry_count==head.entry_count,'Incomplete evidence')
  local function decode(v)
   assert(type(v)=='table','Invalid typed evidence value')
   if v.kind=='ref'then assert(nodes[v.id],'Dangling evidence reference');return nodes[v.id]end
   if v.kind=='nil'then assert(v.value==nil,'Invalid nil');return nil end
   assert(v.kind==type(v.value)and(v.kind=='string'or v.kind=='number'or v.kind=='boolean'),'Invalid scalar tag')
   scalar(v.value);return v.value
  end
  for _,node in ipairs(records)do
   assert(type(node.fields)=='table'and #node.fields<=2048,'Invalid evidence fields')
   local seen={};for _,field in ipairs(node.fields)do
    count=count+1;assert(count<=500000,'Evidence entry budget exceeded')
    local k=decode(field.key);assert(type(k)=='string'or finite(k),'Invalid restored key')
    assert(not seen[k],'Duplicate restored key');seen[k]=true;nodes[node.id][k]=decode(field.value)
   end
  end
  assert(count==head.entry_count,'Evidence entry count mismatch')
  local active,visited={},{}
  local function validate(v,depth)
   if v.kind~='ref'then return end
   assert(depth<=64 and not active[v.id],'Cyclic or excessively deep evidence')
   if visited[v.id]then return end
   active[v.id]=true
   for _,field in ipairs(records[v.id].fields)do validate(field.value,depth+1)end
   active[v.id]=nil;visited[v.id]=true
  end
  validate(head.root,0)
  for id in ipairs(records)do assert(visited[id],'Unreachable evidence node')end
  return decode(head.root)
 end)
 if not ok then return nil,tostring(result)end
 return result
end
function M.unsupported(phase,reason,actual)
 local r={schema=1,phase=phase,status='unsupported',code='transition_unavailable'}
 if type(reason)=='string'then r.reason=reason:sub(1,4096)end
 if type(actual)=='table'then
  r.legal=actual.legal;r.uncertain=actual.uncertain
  if finite(actual.score)then r.score=actual.score end
  if type(actual.hand)=='string'then r.hand=actual.hand end
  r.warnings={};for i,w in ipairs(actual.warnings or{})do if i>32 then r.warnings_truncated=true;break end
   if type(w)=='string'then r.warnings[#r.warnings+1]=w:sub(1,4096)end
  end
  if actual.legal==false then r.code='illegal_or_unsupported_play'
  elseif actual.uncertain then r.code='unresolved_scoring_or_growth' end
  if not r.reason and type(actual.reason)=='string'then r.reason=actual.reason:sub(1,4096)end
  if type(actual.uncertainty)=='table'then
   r.uncertainty={};for _,k in ipairs({'lucky','lucky_cat','other'})do if actual.uncertainty[k]then r.uncertainty[k]=true end end
  end
 end
 r.reason=r.reason or 'The transition did not produce a fully supported conditional result.'
 return r
end
return M
