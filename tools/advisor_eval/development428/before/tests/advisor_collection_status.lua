-- Synthetic UI callback and live text binding checks. No game, native or save access.
local path='Brainstorm/UI/collection_run.lua'
local checks=0
local function check(value,label)checks=checks+1;assert(value,label)end
local function env()
  local e={redraws=0,manual=0,auto=0,writes=0}
  Brainstorm={config={advisor={}},writeConfig=function()e.writes=e.writes+1 end,
    CollectionSearchProduct={status='Search is idle.',stop=function(reason)Brainstorm.CollectionSearchProduct.status=reason end,
      start_manual=function()
        e.manual=e.manual+1
        if e.manual_error then return false,e.manual_error end
        Brainstorm.CollectionSearchProduct.status='Waiting: Controls are settling.';return true
      end},
    AutoRun={status_text='Auto-run is off.',stop=function(_,reason)Brainstorm.AutoRun.status_text='Auto-run stopped: '..reason end,
      start=function()
        e.auto=e.auto+1
        if e.auto_error then return false,e.auto_error end
        Brainstorm.AutoRun.status_text='Waiting: Menu is closing.';return true
      end}}
  G={FUNCS={},UIT={ROOT='ROOT',R='R',T='T'},C={CLEAR={},GREEN={},WHITE={},ORANGE={}}}
  UIBox_button=function(args)return{n='BUTTON',config=args}end
  dofile(path)
  Brainstorm.showCollectionRunPage=function()e.redraws=e.redraws+1;e.page=Brainstorm.createCollectionRunPage()end
  e.page=Brainstorm.createCollectionRunPage()
  function e.text()
    local lines={}
    local function walk(node)
      local c=node.config or {}
      if c.ref_table then
        if c.func then assert(G.FUNCS[c.func])()end
        lines[#lines+1]=c.ref_table[c.ref_value]
      end
      for _,child in ipairs(node.nodes or {})do walk(child)end
    end
    walk(e.page);return table.concat(lines)
  end
  return e
end
do
  local e=env();check(e.text()=='Auto-run is off.','initial page shows current automatic status')
  for _,reason in ipairs({'Loaded collection metadata is incomplete.','The strict count is 4 but only 1 target is reachable.'})do
    e.manual_error=reason;local before=e.redraws
    G.FUNCS.brainstorm_collection_search_start()
    check(e.redraws==before+1 and e.text()==reason,'manual pre-dispatch error redraws immediately: '..reason)
    Brainstorm.AutoRun.status_text='Unrelated auto status';Brainstorm.CollectionSearchProduct.status='Unrelated manual status'
    check(e.text()==reason,'immediate manual failure survives unrelated status refresh')
    e.page=Brainstorm.createCollectionRunPage();check(e.text()==reason,'manual failure survives reopening the page')
  end
  e.manual_error=nil;G.FUNCS.brainstorm_collection_search_start()
  check(e.text()=='Waiting: Controls are settling.','successful manual request clears prior rejection and selects its owner')
  Brainstorm.CollectionSearchProduct.status='Searching without required Burnt; same total time limit.'
  check(e.text()=='Searching without required Burnt; same total time limit.','existing live text nodes follow manual phase changes without page rebuild')
  check(e.manual==3 and e.auto==0 and e.writes==0,'status polling and redraw never dispatch or persist options')
end
do
  local e=env();e.auto_error='Player logging is unavailable.'
  G.FUNCS.brainstorm_collection_auto_start()
  check(e.redraws==1 and e.text()==e.auto_error,'automatic pre-dispatch logging failure redraws instead of showing off status')
  Brainstorm.AutoRun.status_text='Auto-run is off.';check(e.text()==e.auto_error,'automatic immediate failure has priority over stale owner status')
  e.auto_error=nil;G.FUNCS.brainstorm_collection_auto_start()
  check(e.text()=='Waiting: Menu is closing.','successful automatic request clears prior rejection')
  Brainstorm.AutoRun.status_text='Searching with Burnt first (9s).';Brainstorm.CollectionSearchProduct.status='Unrelated manual status'
  check(e.text()=='Searching with Burnt first (9s).','automatic owner exposes active search status without manual masking')
  Brainstorm.AutoRun.status_text='Auto-run stopped: source unsupported.'
  check(e.text()=='Auto-run stopped: source unsupported.','automatic terminal reason remains visible after its request stops')
end
do
  local e=env();Brainstorm.CollectionSearchProduct=nil
  G.FUNCS.brainstorm_collection_search_start()
  check(e.redraws==1 and e.text()=='Bounded search is unavailable.','absent manual implementation exposes its failure')
  Brainstorm.AutoRun=nil;G.FUNCS.brainstorm_collection_auto_start()
  check(e.redraws==2 and e.text()=='Auto-run is unavailable.','absent automatic implementation exposes its failure')
  G.FUNCS.brainstorm_collection_stop()
  check(e.text():find('Stopped.',1,true)==1,'Stop clears stale failure even without either facade')
end
do
  local e=env();e.manual_error='Rejected request';G.FUNCS.brainstorm_collection_search_start()
  G.FUNCS.brainstorm_collection_count()
  check(e.text()=='Search options changed.','explicit option change clears the previous request rejection')
  e.manual_error=nil;G.FUNCS.brainstorm_collection_search_start()
  Brainstorm.CollectionSearchProduct.status=string.rep('x',350)
  local text=e.text();check(#text<=240 and text:find('... More: Full status.',1,true),'long diagnostics are bounded to three compact rows with details link')
  Brainstorm.CollectionSearchProduct.status='Line one\nLine two\tready'
  check(e.text()=='Line one Line two ready','live diagnostics cannot create unbounded extra rows')
  G.FUNCS.brainstorm_collection_stop()
  check(e.text()=='Stopped by the user.','Stop exposes current selected-owner status')
end
do
  local e=env();local cleared=0
  Brainstorm.Advisor={player_log={clear_logs=function()cleared=cleared+1;return true,{deleted_files={}}end}}
  Brainstorm.AutoRun.engaged=function()return false end
  Brainstorm.CollectionSearchRuntime={busy=function()return false end}
  G.FUNCS.brainstorm_collection_clear_logs()
  check(cleared==1 and e.text()=='Auto-run logs cleared. Manual runs retained. No run started.','separate clear succeeds visibly')
  check(e.auto==0 and e.manual==0 and e.writes==0,'clear starts no run/search and writes no settings')
  Brainstorm.AutoRun.engaged=function()return true end
  G.FUNCS.brainstorm_collection_clear_logs();check(cleared==1 and e.text():find('resumable',1,true),'engaged session preserved')
  Brainstorm.AutoRun.engaged=function()return false end
  Brainstorm.CollectionSearchRuntime.busy=function()return true end
  G.FUNCS.brainstorm_collection_clear_logs();check(cleared==1 and e.text():find('worker',1,true),'search prevents clearing')
  Brainstorm.CollectionSearchRuntime.busy=function()return false end
  Brainstorm.Advisor.execution_key='pending'
  G.FUNCS.brainstorm_collection_clear_logs();check(cleared==1 and e.text():find('settle',1,true),'queued action prevents clearing')
  Brainstorm.Advisor.execution_key=nil
  Brainstorm.Advisor.player_log.clear_logs=function()return nil,'manufactured filesystem failure'end
  G.FUNCS.brainstorm_collection_clear_logs();check(e.text():find('manufactured filesystem failure',1,true),'failure visible')
  local labels={}
  local function walk(node)
    for _,text in ipairs((node.config or {}).label or {})do labels[text]=true end
    for _,child in ipairs(node.nodes or {})do walk(child)end
  end
  walk(Brainstorm.createCollectionRunPage())
  check(labels['Clear auto logs'] and labels['Clear auto logs + 10 win-first runs'] and labels['Start collection marathon'],'separate controls and unambiguous runs label')
end

do
 local e=env();local request
 Brainstorm.AutoRun.start=function(_,q)request=q;return true end
 G.FUNCS.brainstorm_collection_auto_start()
 check(request and request.retire_unsupported==true and request.teacher_batch~=true,'UI explicitly requests collection retirement without teacher mode')
 check(Brainstorm.config.advisor.collection_run_options==nil or Brainstorm.config.advisor.collection_run_options.retire_unsupported==nil,'Click does not silently rewrite saved options')
end
print('advisor_collection_status: '..checks..' checks passed')
