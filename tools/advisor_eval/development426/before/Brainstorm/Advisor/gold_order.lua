-- Pure bounded physical copy-target rows. This enumerates legal permutations
-- only to choose one canonical copy-maximizing row per physical target. It is
-- not a score search, a free reorder, or proof of an eventual blind clear.
local M={}
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function integer(v)return finite(v) and v>=0 and v%1==0 end
local function plain(v)return type(v)=='table' and getmetatable(v)==nil end
local function array(v,cap)
 if not plain(v) or #v>cap then return false end
 local n=0;for k in pairs(v)do if not integer(k) or k<1 or k>#v then return false end;n=n+1 end
 return n==#v
end
local function copy(v,seen)
 if type(v)~='table' then return v end
 seen=seen or {};if seen[v]then return seen[v]end
 local r={};seen[v]=r;for k,x in pairs(v)do r[k]=copy(x,seen)end;return r
end
local function id(v)return type(v)=='string' and v~='' or finite(v)end
local function token(v)return type(v)=='number' and 'n'..string.format('%.17g',v)..';' or 's'..#v..':'..v end
local function pinned(j)return j.pinned==true or j.ability.pinned==true end
local function active(j)
 local a=j.ability
 return not j.debuff and not a.perma_debuff and not (a.perishable and a.perish_tally<=0)
end
local function copying(j)return j.key=='j_blueprint' or j.key=='j_brainstorm'end
local function shape(s)
 if not plain(s) or s.phase~='shop' or not array(s.jokers,6) or #s.jokers<1 or s.blind~=nil and not plain(s.blind) or
   s.ordering_safe==false or s.jokers_shuffling or s.dragging or s.jokers_dragging or
   (s.blind or {}).shuffle_pending then return nil,'A settled visible shop row of one through six Jokers is required.'end
 -- Visibility is checked for the entire row before reading identity fields.
 for _,j in ipairs(s.jokers)do
  if not plain(j) or j.face_down or j.identity_redacted or j.concealed or j.unknown or
    j.facing=='back' or j.sprite_facing=='back' or j.getting_sliced or j.dragging or
    j.states~=nil and not plain(j.states) or
    j.states and j.states.drag~=nil and not plain(j.states.drag) or
    j.states and j.states.drag and j.states.drag.is then
   return nil,'Every physical Joker must be public and settled before making an order family.'
  end
 end
 local ids,seen,metadata={},{},{}
 for i,j in ipairs(s.jokers)do
  local a=j.ability
  if not id(j.id) or seen[tostring(j.id)] or not plain(a) or a.set~='Joker' or
    type(a.name)~='string' or a.name=='' or type(j.key)~='string' or j.name~=nil and type(j.name)~='string' or
    type(j.debuff)~='boolean' or type(j.blueprint_compat)~='boolean' then
   return nil,'Distinct physical IDs and exact public Joker activity/copy metadata are required.'
  end
  for _,v in ipairs({{j,'pinned'},{a,'pinned'},{a,'eternal'},{a,'perishable'},{a,'rental'},{a,'perma_debuff'}})do
   local value=v[1][v[2]]
   if value~=nil and type(value)~='boolean'then return nil,'Unknown pin or activity metadata prevents physical row enumeration.'end
  end
  if a.perishable and not integer(a.perish_tally)then return nil,'Unknown perish timing prevents copy resolution.'end
  local expected=j.key=='j_blueprint' and 'Blueprint' or j.key=='j_brainstorm' and 'Brainstorm' or nil
  if expected and (a.name~=expected or j.name~=nil and j.name~=expected) or
    not expected and (a.name=='Blueprint' or a.name=='Brainstorm' or j.name=='Blueprint' or j.name=='Brainstorm')then
   return nil,'Copy-key and source-name identities must agree.'
  end
  seen[tostring(j.id)]=true;ids[i]=j.id
  metadata[#metadata+1]=table.concat({token(j.id),token(j.key),token(a.name),j.name and token(j.name)or'nil',
   tostring(j.debuff),tostring(j.blueprint_compat),tostring(pinned(j)),tostring(a.perma_debuff==true),
   tostring(a.perishable==true),a.perishable and tostring(a.perish_tally)or'-'},'|')
 end
 local signature={};for _,value in ipairs(ids)do signature[#signature+1]=token(value)end
 return {ids=ids,key=table.concat(signature,'|'),metadata_key=table.concat(metadata,'||')}
end
local function legal(s,order)
 if not array(order,6) or #order~=#s.jokers then return false end
 local seen={};for position,index in ipairs(order)do
  if not integer(index) or index<1 or not s.jokers[index] or seen[index] or
    pinned(s.jokers[index]) and position~=index then return false end
  seen[index]=true
 end
 return true
end
local function identity(s)local order={};for i=1,#s.jokers do order[i]=i end;return order end
local function resolve(s,order,position,seen)
 local index=order[position];local j=index and s.jokers[index]
 if not j or not active(j) or seen[position]then return nil end
 seen[position]=true
 local target=j.key=='j_blueprint' and position+1 or j.key=='j_brainstorm' and 1 or nil
 if not target then return index end
 local next_index=order[target];local next_card=next_index and s.jokers[next_index]
 if not next_card or next_card.blueprint_compat~=true then return nil end
 return resolve(s,order,target,seen)
end
local function metrics(s,order)
 local counts={}
 for position in ipairs(order)do
  local target=resolve(s,order,position,{})
  if target then counts[target]=(counts[target]or 0)+1 end
 end
 local moved=0;local keys={}
 for i,index in ipairs(order)do
  if i~=index then moved=moved+1 end
  keys[#keys+1]=token(s.jokers[index].id)
 end
 return counts,moved,table.concat(keys,'|')
end
function M.family(s,modules)
 local original,why=shape(s);if not original then return nil,why end
 local gold=modules and modules.gold_goal
 if not gold or type(gold.stable_card)~='function'then return nil,'The supported Gold row classifier is required.'end
 for _,j in ipairs(s.jokers)do
  if not gold.stable_card(j,modules.gold_perkeo,s)then return nil,'An unsupported startup/destruction Joker cannot enter this shop order family.'end
 end
 local targets,copies={},0
 for i,j in ipairs(s.jokers)do
  if copying(j)and active(j)then copies=copies+1
  elseif not copying(j)and active(j)and j.blueprint_compat then targets[#targets+1]=i end
 end
 table.sort(targets,function(a,b)return token(s.jokers[a].id)<token(s.jokers[b].id)end)
 local current=identity(s)
 local counts,moved,key=metrics(s,current)
 local rows,by_key={},{}
 local function add(order,count_map,move_count,row_key)
  if by_key[row_key]then return by_key[row_key]end
  local ids={};for i,index in ipairs(order)do ids[i]=s.jokers[index].id end
  local row={schema=1,order=copy(order),physical_ids=ids,input_ids=copy(original.ids),input_key=original.key,input_metadata_key=original.metadata_key,
   key=row_key,moved=move_count,action_count=move_count>0 and 1 or 0,covered_targets={},resolved_counts={}}
  for target,n in pairs(count_map)do row.resolved_counts[token(s.jokers[target].id)]=n end
  if move_count>0 then row.action={kind='reorder_jokers',area='jokers',order=copy(order)}end
  rows[#rows+1]=row;by_key[row_key]=row;return row
 end
 add(current,counts,moved,key)
 local best={};for _,target in ipairs(targets)do best[target]={order=current,count=counts[target]or 0,moved=moved,key=key,counts=counts}end
 local visited=0
 local function candidate(order)
  visited=visited+1
  local values,moves,signature=metrics(s,order)
  for _,target in ipairs(targets)do
   local old=best[target];local n=values[target]or 0
   if n>old.count or n==old.count and signature<old.key then
    best[target]={order=copy(order),count=n,moved=moves,key=signature,counts=values}
   end
  end
 end
 if copies>0 and #targets>0 then
  local order,used={},{}
  local function visit(position)
   if position>#s.jokers then candidate(order);return end
   local fixed=pinned(s.jokers[position])and position or nil
   if fixed then order[position]=fixed;used[fixed]=true;visit(position+1);used[fixed]=nil
   else
    for index,j in ipairs(s.jokers)do if not used[index]and not pinned(j)then
     order[position]=index;used[index]=true;visit(position+1);used[index]=nil
    end end
   end
  end
  visit(1)
 else visited=1 end
 local receipts={}
 if copies>0 then for _,target in ipairs(targets)do
  local selected=best[target];local row=add(selected.order,selected.counts,selected.moved,selected.key)
  local target_id=s.jokers[target].id
  row.covered_targets[#row.covered_targets+1]=target_id
  receipts[#receipts+1]={id=target_id,index=target,key=s.jokers[target].key,
   current_effects=counts[target]or 0,maximum_effects=selected.count,selected_row_key=row.key}
 end end
 if visited>720 or #rows>6 then return nil,'The complete physical order family exceeded its fixed bound.'end
 return {schema=1,complete=true,score_calls=0,permutation_count=visited,rows=rows,targets=receipts,
  input_key=original.key,input_ids=copy(original.ids),copy_jokers=copies,max_rows=6,max_permutations=720,
  scope='Current row plus one complete compatible-copy-count maximizer per active physical non-copy target; ties use stable physical-ID order independent of current movable positions.',
  score_optimized=false,all_scoring_orders_enumerated=false,requires_explicit_reorder=true,
  future_exit_order_assumed=false,terminal_evidence=false}
end
function M.apply(s,row)
 local original,why=shape(s);if not original then return nil,why end
 if not plain(row)or row.schema~=1 or row.input_key~=original.key or row.input_metadata_key~=original.metadata_key or not array(row.input_ids,6)or
   #row.input_ids~=#original.ids or not legal(s,row.order)then return nil,'The candidate does not name this exact legal current physical row.'end
 for i,value in ipairs(original.ids)do if row.input_ids[i]~=value then return nil,'The candidate physical-ID mapping is stale.'end end
 local _,moved,key=metrics(s,row.order)
 if row.key~=key or row.moved~=moved or row.action_count~=(moved>0 and 1 or 0)or
   not array(row.physical_ids,6)or #row.physical_ids~=#original.ids then return nil,'The candidate order receipt is inconsistent.'end
 for i,index in ipairs(row.order)do if row.physical_ids[i]~=s.jokers[index].id then return nil,'The target physical-ID mapping is inconsistent.'end end
 if moved==0 then
  if row.action~=nil then return nil,'The current row must not name a reorder action.'end
 else
  local a=row.action
  if not plain(a)or a.kind~='reorder_jokers'or a.area~='jokers'or not array(a.order,6)or #a.order~=#row.order then
   return nil,'The explicit reorder action does not match the candidate row.'
  end
  for i,index in ipairs(row.order)do if a.order[i]~=index then return nil,'The explicit reorder action has a different physical mapping.'end end
 end
 local result=copy(s);result.jokers={}
 for i,index in ipairs(row.order)do result.jokers[i]=copy(s.jokers[index])end
 return result
end
return M
