-- Explicit controls for a bounded searched normal Gold run. Drawing the page
-- does not start a worker, replace a run or change recorded sticker progress.
local B=Brainstorm
local quiet={text='Search is idle. Starting replaces the current run.'}
local function options()
  local advisor=B.config.advisor
  if type(advisor.gold_run)~='table' then advisor.gold_run={} end
  local q=advisor.gold_run
  local defaults={deck_name='Red Deck',interchangeable_copies=true,minimum_distinct=0,
    first_ante=1,last_ante=8,budget_ms=30000,max_runs=25}
  for key,value in pairs(defaults) do if q[key]==nil then q[key]=value end end
  -- 302 stored only a count. Preserve positive requests. Its unset/zero
  -- default becomes Auto on this explicit-start page; strict Off is durable.
  if q.quota_mode==nil then q.quota_mode=type(q.minimum_distinct)=='number' and q.minimum_distinct>0 and 'strict' or 'auto' end
  return q
end
local function row(text,colour,scale)
  return {n=G.UIT.R,config={align='cm',padding=.015,maxw=7.7},nodes={
    {n=G.UIT.T,config={text=text,colour=colour or G.C.WHITE,scale=scale or .25}}}}
end
local function button(label,callback,width)
  return UIBox_button({label={label},button=callback,col=true,minw=width or 3.4,minh=.38,scale=.25})
end
local function refresh()
  if B.showCollectionRunPage then B.showCollectionRunPage() end
end
local function changed()
  if B.AutoRun then B.AutoRun:stop('Search options changed.') end
  if B.CollectionSearchProduct then B.CollectionSearchProduct.stop('Search options changed.') end
  B.writeConfig();refresh()
end
G.FUNCS.brainstorm_collection_deck=function()
  local q=options();q.deck_name=q.deck_name=='Red Deck' and 'Zodiac Deck' or 'Red Deck';changed()
end
G.FUNCS.brainstorm_collection_copy=function()
  local q=options();q.interchangeable_copies=not q.interchangeable_copies;changed()
end
G.FUNCS.brainstorm_collection_count=function()
  local q=options()
  if q.quota_mode=='auto' then q.quota_mode='strict';q.minimum_distinct=0
  elseif (tonumber(q.minimum_distinct) or 0)>=5 then q.quota_mode='auto';q.minimum_distinct=0
  else q.quota_mode='strict';q.minimum_distinct=(tonumber(q.minimum_distinct) or 0)+1 end
  changed()
end
G.FUNCS.brainstorm_collection_after=function()
  local q=options();q.first_ante=(tonumber(q.first_ante) or 1)%8+1
  q.last_ante=math.max(q.first_ante,tonumber(q.last_ante) or 8);changed()
end
G.FUNCS.brainstorm_collection_through=function()
  local q=options();q.last_ante=(tonumber(q.last_ante) or 8)+1
  if q.last_ante>8 then q.last_ante=q.first_ante end;changed()
end
G.FUNCS.brainstorm_collection_runs=function()
  local q=options();local choices={5,10,25,50,100};local next_value=5
  for i,n in ipairs(choices) do if n==q.max_runs then next_value=choices[i%#choices+1] end end
  q.max_runs=next_value;changed()
end
G.FUNCS.brainstorm_collection_search_start=function()
  if not B.CollectionSearchProduct then quiet.text='Bounded search is unavailable.';return end
  local ok,reason=B.CollectionSearchProduct.start_manual(options())
  quiet.text=ok and 'Searching; Stop or a manual input cancels.' or tostring(reason or 'Search could not start.')
end
G.FUNCS.brainstorm_collection_auto_start=function()
  if not B.AutoRun then quiet.text='Auto-run is unavailable.';return end
  local ok,reason=B.AutoRun:start(options())
  quiet.text=ok and 'Auto-run started. Any manual input stops it.' or tostring(reason or 'Auto-run could not start.')
end
G.FUNCS.brainstorm_collection_stop=function()
  if B.AutoRun then B.AutoRun:stop('Stopped by the user.') end
  if B.CollectionSearchProduct then B.CollectionSearchProduct.stop('Stopped by the user.') end
  quiet.text='Stopped. An active native worker is allowed to finish cancellation.';refresh()
end
function B.createCollectionRunPage()
  local q=options()
  local product=B.CollectionSearchProduct
  local status=product and product.status or quiet.text
  local title=B.AutoRun and 'Completionist++ auto-run' or 'Quick Gold run'
  local nodes={row(title,G.C.GREEN,.38),
    row('Yorick + Perkeo: starting Charm. Burnt + copy: by Ante 5.',nil,.25),
    {n=G.UIT.R,config={align='cm',padding=.03},nodes={
      button(q.deck_name..' / Gold','brainstorm_collection_deck'),
      button(q.interchangeable_copies and 'Blueprint or Brainstorm' or 'Brainstorm only','brainstorm_collection_copy')}},
    {n=G.UIT.R,config={align='cm',padding=.03},nodes={
      button('Missing: '..(q.quota_mode=='auto' and 'Auto' or q.minimum_distinct==0 and 'Off' or tostring(q.minimum_distinct)),'brainstorm_collection_count',2.2),
      button('After Ante '..tostring(q.first_ante-1),'brainstorm_collection_after',2.2),
      button('Through Ante '..tostring(q.last_ante),'brainstorm_collection_through',2.2)}},
    row('No perishable targets. Maximum native CPU. Search limit: 30 seconds.',nil,.24),
    row('Missing counts are distinct conditional offers, not purchases or wins.',nil,.24),
    row('Auto requires one reachable missing Joker; Off adds no missing-target condition.',nil,.22),
    row('Starting a searched run replaces the current run.',G.C.ORANGE,.26)}
  local controls={button('Search and start new run','brainstorm_collection_search_start',3.3)}
  if B.AutoRun then
    controls[#controls+1]=button('Start auto-run + logging','brainstorm_collection_auto_start',3.3)
    nodes[#nodes+1]={n=G.UIT.R,config={align='cm',padding=.02},nodes={
      button('Session limit: '..q.max_runs..' runs','brainstorm_collection_runs',3.4)}}
  end
  nodes[#nodes+1]={n=G.UIT.R,config={align='cm',padding=.03},nodes=controls}
  nodes[#nodes+1]={n=G.UIT.R,config={align='cm',padding=.02},nodes={button('Stop','brainstorm_collection_stop',3.4)}}
  local text=tostring(B.AutoRun and B.AutoRun.status_text or status or quiet.text)
  for start=1,math.min(#text,140),70 do nodes[#nodes+1]=row(text:sub(start,start+69),nil,.23) end
  nodes[#nodes+1]=row('The game awards stickers. Unknown progress prevents an automatic start.',nil,.23)
  return {n=G.UIT.ROOT,config={align='cm',colour=G.C.CLEAR,padding=.04},nodes=nodes}
end
return {options=options}
