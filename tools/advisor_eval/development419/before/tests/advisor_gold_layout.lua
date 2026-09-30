-- Synthetic UI geometry regression, not a live renderer or source execution.
-- Helper topology and dimensional contracts were inspected read-only in
-- https://github.com/Jofr3/balatro-source/blob/main/functions/UI_definitions.lua
-- and engine/ui.lua. In particular, R children consume vertical space; other
-- children consume horizontal space, irrespective of their parent's type.
-- Fonts are an explicit envelope: h=scale and monospace advance=.40*scale,
-- then repeated with both dimensions 8% larger. No installed font is loaded.
local checks = 0
local function check(value, message)
  assert(value, message)
  checks = checks + 1
end
local function near(a,b) return math.abs(a-b)<0.000001 end
local function node(kind, config, children)
  return {n=kind,config=config or {},nodes=children or {}}
end
local function text(label, scale) return node('T',{text=label,scale=scale or .3}) end
G={UIT={ROOT='ROOT',R='R',C='C',T='T',B='B',O='O',padding=0},
  C={GREEN={},WHITE={},CLEAR={},ORANGE={},UI={}},SETTINGS={},FUNCS={},P_CENTERS={}}
local status, writes
local A={defaults=function()end,settings_changed=function()end,active=function()return false end,
  gold_status=function()return status end,snapshot={fingerprint=function(v)return tostring(v)end}}
Brainstorm={Advisor=A,config={advisor={enabled=true,challenge_only=false,gold_stickers=true},ar_filters={}},
  writeConfig=function()writes=writes+1 end}
love={};Game={}

-- Freshly authored helper models retain wrappers omitted by the older UI test.
-- A button defaults to an R wrapper even when placed inside another R.
UIBox_button=function(args)
  local labels={}
  for _,label in ipairs(args.label or {'Button'}) do
    labels[#labels+1]=node('R',{minw=args.minw or 2.7,maxw=args.maxw or (args.minw or 2.7)-.2},
      {text(label,args.scale or .5)})
  end
  return node(args.col and 'C' or 'R',{}, {node('C',{
    button=args.button,padding=args.padding or 0,minh=args.minh or .9},labels)})
end
create_toggle=function(args)
  local s,w=args.scale or 1,args.w or 3
  local label=node('C',{minw=w},{text(args.label,args.label_scale or .4),node('B',{w=.1,h=.1})})
  local icon=node('C',{padding=.03,minw=.4*s,minh=.4*s,button='toggle_button'},
    {node('B',{w=.5*s,h=.5*s})})
  local result=node(args.col and 'C' or 'R',{padding=.1},
    {label,node('C',{minw=.3*w},{node('C',{}, {icon})})})
  if args.info then
    local info={result};for _,line in ipairs(args.info)do info[#info+1]=node('R',{minh=.05},{text(line,.25)})end
    result=node(args.col and 'C' or 'R',{},info)
  end
  return result
end
local cycle_args
create_option_cycle=function(args)
  cycle_args=args
  local s=args.scale or 1
  local label=args.options[args.current_option or 1] or ''
  local center=node('C',{minw=(args.w or 2.5)*s,minh=(args.h or .8)*s,padding=.05,emboss=.1},
    {node('R',{}, {node('R',{}, {text(label,(args.text_scale or .5)*s)}),node('R',{minh=.05})})})
  local body=node('R',{}, {node('C',{padding=.1},{
    node('C',{minw=.6*s},{text('<',(args.text_scale or .5)*s)}),center,
    node('C',{minw=.6*s},{text('>',(args.text_scale or .5)*s)})})})
  if not args.no_pips then
    local pips={};for _=1,#args.options do pips[#pips+1]=node('B',{w=.1*s,h=.1*s})end
    local rows=center.nodes[1].nodes
    rows[#rows+1]=node('R',{padding=(#args.options>15 and .02 or .05)*s},pips)
  end
  if args.label or args.info then
    local rows={}
    if args.label then rows[#rows+1]=node('R',{}, {text(args.label,.5*s)})end
    rows[#rows+1]=body
    for _,line in ipairs(args.info or {})do rows[#rows+1]=node('R',{minh=.05},{text(line,.3*s)})end
    return node('R',{padding=.05},rows)
  end
  return body
end

-- Measures all descendants, using each child's orientation, minima, padding,
-- max-width text reduction and explicit object sizes. Buttons receive their
-- computed coordinates so a visually staggered pager is caught directly.
local function measure(tree, font_factor)
  local boxes,buttons,texts={}, {},{}
  local function size(n, factor)
    local c=n.config or {}
    if n.n=='T' then
      local label=tostring(c.text or (c.ref_table and c.ref_table[c.ref_value]) or '')
      -- UTF-8 continuation bytes do not consume an additional character cell.
      local chars=0;for byte in label:gmatch('.')do if byte:byte()<128 or byte:byte()>=192 then chars=chars+1 end end
      local scale=(c.scale or 1)*factor*font_factor
      return chars*.4*scale,scale
    elseif n.n=='B' or n.n=='O' then
      return c.w or (c.object and c.object.T.w) or 0,c.h or (c.object and c.object.T.h) or 0
    end
    local function contents(fac)
      local p=c.padding or 0
      local x,y,w,h=p,p,0,0
      local children={}
      for _,child in ipairs(n.nodes or {})do
        local cw,ch=size(child,fac)
        children[#children+1]={node=child,x=x,y=y,w=cw,h=ch}
        if child.n=='R' then
          y=y+ch+p+(child.config.emboss or 0);h=h+ch+p+(child.config.emboss or 0)
          w=math.max(w,cw+p)
        else
          x=x+cw+p;w=w+cw+p;h=math.max(h,ch+p)+(child.config.emboss or 0)
        end
      end
      return w,h,children
    end
    local w,h,children=contents(factor)
    if c.maxw and w>c.maxw then w,h,children=contents(factor*c.maxw/w)end
    if c.maxh and h>c.maxh then w,h,children=contents(factor*c.maxh/h)end
    boxes[n]={w=math.max(c.minw or 0,w+(c.padding or 0)),
      h=math.max(c.minh or 0,h+(c.padding or 0)),children=children}
    return boxes[n].w,boxes[n].h
  end
  local w,h=size(tree,1)
  local function position(n,x,y)
    local c=n.config or {};local b=boxes[n]
    if c.button then buttons[c.button]={x=x,y=y,w=b and b.w or 0,h=b and b.h or 0}end
    if n.n=='T' then texts[#texts+1]=tostring(c.text or '')end
    for _,child in ipairs(b and b.children or {})do position(child.node,x+child.x,y+child.y)end
  end
  position(tree,0,0)
  return {w=w,h=h,buttons=buttons,texts=texts}
end

local baseline=os.getenv('ADVISOR_GOLD_LAYOUT_BASELINE')=='296'
local ui_path=baseline and 'tools/advisor_eval/runs/search296_candidate/policy/Brainstorm/UI/advisor.lua' or 'Brainstorm/UI/advisor.lua'
dofile(ui_path)
A.gold_search=dofile('Brainstorm/Advisor/gold_search.lua')
local Gold=dofile('Brainstorm/Advisor/gold_stickers.lua')
local keys=Gold.target_keys()
check(#keys==150,'fixture uses the complete vanilla namespace')
for _,key in ipairs(keys)do G.P_CENTERS[key]={name=A.gold_search.name(key)}end
local function make_status(value, reason)
  local s={schema=1,goal='gold_stickers',profile_id=1,metadata_status='complete',catalog_status='complete',stake_status='complete',
    counts={total=150,complete=0,missing=0,unknown=0},targets={},by_key={},held_status='complete',held_target_count=0,
    held_target_keys={},eligibility={eligible=reason==nil,reasons=reason and {reason} or {}}}
  for _,key in ipairs(keys)do local row={key=key,status=value};s.targets[#s.targets+1]=row;s.by_key[key]=row;s.counts[value]=s.counts[value]+1 end
  return s
end
local baseline_violations,measurements=0,{}
local function bounded(label,tree,pager)
  for _,factor in ipairs({1,1.08})do
    local box=measure(tree,factor)
    measurements[#measurements+1]=string.format('%s font=%.2f w=%.4f h=%.4f',label,factor,box.w,box.h)
    local fits=box.w<=8.000001 and box.h<=5.700001
    if baseline then if not fits then baseline_violations=baseline_violations+1 end
    else check(fits,measurements[#measurements]..' exceeds reserved menu content 8 x 5.7')end
    if pager then
      local previous,next_button=box.buttons.brainstorm_gold_previous,box.buttons.brainstorm_gold_next
      check(previous and next_button,label..' exposes both pagination buttons')
      local aligned=near(previous.y,next_button.y) and previous.x+previous.w<=next_button.x
      if baseline then check(not aligned,'296 must reproduce the vertically staggered pager')
      else check(aligned,label..' pagination buttons occupy the same horizontal row without overlap')end
    end
    local prepare=box.buttons.brainstorm_gold_search_prepare or box.buttons.brainstorm_gold_search_marble
    local restore=box.buttons.brainstorm_gold_search_restore
    if prepare and restore then
      local aligned=near(prepare.y,restore.y) and prepare.x+prepare.w<=restore.x
      if baseline then check(not aligned,'296 search controls consume separate vertical rows')
      else check(aligned,label..' search buttons occupy the same horizontal row without overlap')end
    end
  end
end

writes=0
for _,value in ipairs({'unknown','missing','complete'})do
  status=make_status(value,value=='unknown' and 'unverified_metadata' or nil)
  bounded('progress '..value,Brainstorm.createGoldStickersPage(),value~='complete')
end
status=make_status('missing','seeded_run')
status.held_target_count=2;status.held_target_keys={keys[1],keys[2]}
bounded('seeded carrying',Brainstorm.createGoldStickersPage(),true)
status.held_status='unavailable'
bounded('held unavailable',Brainstorm.createGoldStickersPage(),true)
-- Every page remains bounded; no accidental expansion after repeated Next.
status=make_status('unknown','unverified_metadata')
local seen={}
for page=1,20 do
  local tree=Brainstorm.createGoldStickersPage()
  bounded('unknown page '..page,tree,true)
  local lines=measure(tree,1).texts
  local shown=0
  for _,key in ipairs(keys)do
    for _,line in ipairs(lines)do if line=='? '..G.P_CENTERS[key].name or
      (baseline and line:find('? '..G.P_CENTERS[key].name,1,true)) then
      seen[key]=true;shown=shown+1;break
    end end
  end
  if not baseline then check(shown<=8,'at most eight target labels occupy a progress page')end
  G.FUNCS.brainstorm_gold_next()
end
for _,key in ipairs(keys)do check(seen[key],'pagination makes '..key..' reachable')end
local saved_names={}
for _,key in ipairs(keys)do
  saved_names[key]=G.P_CENTERS[key].name
  G.P_CENTERS[key].name='Extended localized '..saved_names[key]..' collection name'
end
bounded('long displayed names',Brainstorm.createGoldStickersPage(),true)
for _,key in ipairs(keys)do G.P_CENTERS[key].name=saved_names[key]end
Brainstorm.config.advisor.enabled=false
bounded('advisor disabled',Brainstorm.createGoldStickersPage(),true)
Brainstorm.config.advisor.enabled=true
status=nil
bounded('tracking not enabled',Brainstorm.createGoldStickersPage(),false)
check(writes==0,'opening and paging never write player settings')

-- Search options may hold 150 choices, but render exactly one bounded cycle.
status=make_status('missing')
bounded('search all missing',Brainstorm.createGoldSearchPage(),false)
check(cycle_args and #cycle_args.options==150 and cycle_args.no_pips==true,
  '150 search choices use one no-pip cycle, not an expanded list')
local function select(key)
  local choices=A.gold_search.choices(status)
  for index,choice in ipairs(choices)do if choice.key==key then
    G.FUNCS.brainstorm_gold_search_select({to_key=index});return
  end end
  error('unknown fixture search key '..key)
end
for _,key in ipairs({'j_stone','j_steel_joker','j_glass','j_ticket','j_lucky_cat','j_cavendish','j_perkeo','j_delayed_grat'})do
  select(key)
  bounded('search '..key,Brainstorm.createGoldSearchPage(),false)
end
select('j_stone');Brainstorm.createGoldSearchPage()
G.FUNCS.brainstorm_gold_search_marble()
bounded('search Stone prerequisite prepared',Brainstorm.createGoldSearchPage(),false)
check(writes==1,'only explicit prerequisite preparation writes settings')
G.FUNCS.brainstorm_gold_search_restore()
bounded('search restored',Brainstorm.createGoldSearchPage(),false)
check(writes==2,'only explicit restoration writes settings')
status=make_status('unknown','unverified_metadata')
bounded('search unknown status',Brainstorm.createGoldSearchPage(),false)
status=make_status('complete')
bounded('search complete status',Brainstorm.createGoldSearchPage(),false)
status=nil
bounded('search disabled',Brainstorm.createGoldSearchPage(),false)

if not baseline then
  dofile('Brainstorm/UI/collection_run.lua')
  local original_writes=writes
  bounded('quick Gold run',Brainstorm.createCollectionRunPage(),false)
  Brainstorm.AutoRun={status_text=string.rep('Long status ',30)}
  bounded('auto Gold run with long status',Brainstorm.createCollectionRunPage(),false)
  local run_buttons=measure(Brainstorm.createCollectionRunPage(),1).buttons
  check(run_buttons.brainstorm_collection_search_start.y==run_buttons.brainstorm_collection_auto_start.y,
    'manual search and auto start occupy one horizontal row')
  check(writes==original_writes,'drawing the run page does not write settings or start work')
  Brainstorm.AutoRun=nil
end

if baseline then check(baseline_violations>0,'frozen296 must exceed the menu geometry budget')end
for _,line in ipairs(measurements)do print(line)end
print(string.format('advisor_gold_layout: %d checks; %d baseline bound violations; synthetic geometry only',checks,baseline_violations))
