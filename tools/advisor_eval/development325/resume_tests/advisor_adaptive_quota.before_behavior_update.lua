-- Pure loaded-metadata/query/UI scenarios. No native, game or source actions.
local base=''
local M=dofile(base..'Brainstorm/Advisor/collection_search.lua')
local Gold=dofile('Brainstorm/Advisor/gold_stickers.lua')
local Search=dofile('Brainstorm/Advisor/gold_search.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(value,why)checks=checks+1;assert(value,why)end
local function goal(missing)
  local keep={};for _,key in ipairs(missing or Gold.target_keys())do keep[key]=true end
  local out={schema=1,goal='gold_stickers',profile_id=1,metadata_status='complete',catalog_status='complete',stake_status='complete',
      counts={total=150,complete=0,missing=0,unknown=0},by_key={}}
  for _,key in ipairs(Gold.target_keys())do
    local status=keep[key]and'missing'or'complete';out.by_key[key]={key=key,status=status};out.counts[status]=out.counts[status]+1
  end
  return out
end
local function includes(q,name)
  for part in (q.missing_names..'\31'):gmatch('([^\31]*)\31')do if part==name then return true end end
  return false
end
local fresh=goal();local before=Snapshot.fingerprint(fresh)
local auto=assert(M.prepare(fresh,Search,{quota_mode='auto'}))
check(auto.minimum_distinct==1 and auto.quota_mode=='auto','automatic collection requires at least one reachable missing offer')
check(auto.supported_missing_count==141 and #auto.excluded_missing_keys==9 and #auto.excluded_missing_reasons==9,
    'fixed route excludes six prerequisite and three unmodeled Legendary identities')
check(includes(auto,'Yorick')and includes(auto,'Perkeo')and not includes(auto,'Canio')and
    not includes(auto,'Triboulet')and not includes(auto,'Chicot'),'only actual fixed-opening Legendaries can contribute')
check(auto.budget_ms==30000 and auto.reject_perishable_targets and auto.interchangeable_copies,'automatic mode preserves existing search safeguards')
check(Snapshot.fingerprint(fresh)==before,'query preparation never changes collection progress')
for _,options in ipairs({{}, {minimum_distinct=0}, {quota_mode='strict',minimum_distinct=0}})do
  local q=assert(M.prepare(fresh,Search,options))
  check(q.quota_mode=='strict'and q.minimum_distinct==0,'standalone manual/explicit strict zero remains unconstrained')
end
local late=assert(M.prepare(fresh,Search,{quota_mode='auto',first_ante=2,last_ante=8}))
check(late.supported_missing_count==139 and #late.excluded_missing_keys==11 and
    not includes(late,'Yorick')and not includes(late,'Perkeo'),'Ante window excludes opening-only targets after Ante1')
for _,key in ipairs({'j_caino','j_triboulet','j_chicot','j_stone','j_steel_joker','j_glass','j_ticket','j_lucky_cat','j_cavendish'})do
  local g=goal({key});local value,why=M.prepare(g,Search,{quota_mode='auto'})
  check(value==nil and why:find('no reachable missing Jokers',1,true),'unmodeled singleton stops before dispatch: '..key)
  local off=assert(M.prepare(g,Search,{quota_mode='strict',minimum_distinct=0}))
  check(off.minimum_distinct==0 and off.supported_missing_count==0 and #off.excluded_missing_reasons==1,
      'explicit Off remains available and preserves excluded reason: '..key)
end
for _,key in ipairs({'j_yorick','j_perkeo'})do
  local g=goal({key});local q=assert(M.prepare(g,Search,{quota_mode='auto'}))
  check(q.minimum_distinct==1 and q.supported_missing_count==1,'mandatory missing opening target naturally satisfies automatic minimum')
  check(M.prepare(g,Search,{quota_mode='auto',first_ante=2})==nil,'same target becomes unavailable when its only source is outside window')
end
local remaining=goal({'j_joker','j_brainstorm','j_blueprint'})
local first=assert(M.prepare(remaining,Search,{quota_mode='auto',first_ante=4,last_ante=8}))
check(first.minimum_distinct==1 and first.supported_missing_count==3,'automatic mode still seeks progress after opening pair completed')
check(includes(first,'Brainstorm')and includes(first,'Blueprint'),'copy alternatives remain distinct actual missing identities')
remaining.by_key.j_blueprint.status='complete';remaining.counts.missing=2;remaining.counts.complete=148
local next_run=assert(M.prepare(remaining,Search,{quota_mode='auto',first_ante=4,last_ante=8}))
check(next_run.supported_missing_count==2 and not includes(next_run,'Blueprint')and includes(next_run,'Brainstorm'),
    'fresh next-run metadata removes newly completed targets without conflating copy identities')
local only=goal({'j_joker'})
local strict,reason=M.prepare(only,Search,{quota_mode='strict',minimum_distinct=4})
check(strict==nil and reason:find('strict count is 4',1,true),'strict explicit quota never silently relaxes below requested four')
local one=assert(M.prepare(only,Search,{quota_mode='auto',minimum_distinct=4}))
check(one.minimum_distinct==1 and one.requested_minimum_distinct==4,'explicit Auto resolves independently while retaining numeric setting metadata')
check(M.prepare(goal({}),Search,{quota_mode='auto'})==nil,'completed collection stops without redundant search')
local unknown=goal({'j_joker'});unknown.by_key.j_joker.status='unknown';unknown.counts.missing=0;unknown.counts.unknown=1
check(M.prepare(unknown,Search,{quota_mode='auto'})==nil,'automatic quota never imputes unknown status')
for _,mode in ipairs({'AUTO','',false,17,{}})do
  check(M.prepare(fresh,Search,{quota_mode=mode})==nil,'invalid automatic-mode selector fails closed')
end

local function ui(config)
  local writes,manual,automatic,stops=0,nil,nil,0
  Brainstorm={config={advisor={gold_run=Snapshot.copy(config)}},writeConfig=function()writes=writes+1 end,
    CollectionSearchProduct={stop=function()stops=stops+1 end,start_manual=function(options)manual=Snapshot.copy(options);return true end},
    AutoRun={stop=function()stops=stops+1 end,start=function(_,options)automatic=Snapshot.copy(options);return true end,status_text='Idle'}}
  G={FUNCS={},UIT={ROOT='ROOT',R='R',T='T'},C={CLEAR={},GREEN={},WHITE={},ORANGE={}}}
  UIBox_button=function(args)return{n='BUTTON',config=args}end
  local module=dofile(base..'Brainstorm/UI/collection_run.lua')
  return {options=module.options,page=function()return Brainstorm.createCollectionRunPage()end,
    click=function()G.FUNCS.brainstorm_collection_count()end,
    manual=function()G.FUNCS.brainstorm_collection_search_start();return manual end,
    auto=function()G.FUNCS.brainstorm_collection_auto_start();return automatic end,
    writes=function()return writes end,stops=function()return stops end}
end
local x=ui(nil);local page=x.page()
check(x.options().quota_mode=='auto'and x.writes()==0,'new page defaults to Auto without writing configuration or starting work')
check(x.manual().quota_mode=='auto'and x.auto().quota_mode=='auto','explicit Start uses the mode actually displayed for both buttons')
local labels={}
local function walk(node)
  if node.n=='BUTTON'then labels[node.config.label[1]]=true end
  for _,child in ipairs(node.nodes or {})do walk(child)end
end
walk(page);check(labels['Missing: Auto'],'default label describes the requested mode plainly')
x.click();check(x.options().quota_mode=='strict'and x.options().minimum_distinct==0,'Auto cycles to explicit Off')
check(x.manual().quota_mode=='strict'and x.auto().quota_mode=='strict','explicit Off remains Off for either Start button')
for n=1,5 do x.click();check(x.options().quota_mode=='strict'and x.options().minimum_distinct==n,'numeric quota cycle '..n)end
x.click();check(x.options().quota_mode=='auto'and x.options().minimum_distinct==0,'five cycles back to automatic quota')
check(x.writes()==7 and x.stops()==14,'each explicit choice saves once and stops both search owners')
local zero=ui({minimum_distinct=0});check(zero.options().quota_mode=='auto','old302 default zero without explicit mode migrates on the opt-in page')
local numeric=ui({minimum_distinct=4});check(numeric.options().quota_mode=='strict'and numeric.options().minimum_distinct==4,'existing positive numeric setting remains strict')
local off=ui({minimum_distinct=0,quota_mode='strict'});check(off.options().quota_mode=='strict','new explicit strict zero remains durable across page reloads')
local final=ui(nil)
local q=assert(M.prepare(goal({'j_joker'}),Search,final.auto()))
check(q.minimum_distinct==1,'actual UI Auto request reaches one-target query semantics')
check(q.burnt_fallback==true and q.burnt_required==true,'new explicit-start page prefers strict Burnt with bounded fallback enabled')
G.FUNCS.brainstorm_collection_burnt()
local required=final.manual()
check(required.burnt_fallback==false,'explicit Required selection disables manual fallback')
check(final.auto().burnt_fallback==false,'explicit Required selection also survives automatic Start')
local preserved=ui({burnt_fallback=false,quota_mode='strict',minimum_distinct=0})
check(preserved.options().burnt_fallback==false,'explicit Burnt-required setting persists after page reload')
Brainstorm.CollectionSearchProduct.status='Searching without required Burnt; same total time limit.'
preserved.manual();local manual_text={}
local function texts(node)
  if node.config and node.config.text then manual_text[node.config.text]=true end
  if node.config and node.config.ref_table then manual_text[node.config.ref_table[node.config.ref_value]]=true end
  for _,child in ipairs(node.nodes or {})do texts(child)end
end
texts(preserved.page())
check(manual_text['Searching without required Burnt; same total time limit.'],
    'manual search page shows its actual relaxed-phase status instead of idle auto-run status')
print('advisor_adaptive_quota: '..checks..' checks passed')
