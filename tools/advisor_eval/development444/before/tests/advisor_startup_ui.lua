-- Manufactured UI/time/controller doubles only; no source, native jobs or player files.
local P='Brainstorm/UI/'
local checks=0
local function check(v,label)checks=checks+1;assert(v,label)end
local function environment()
  local e={now=0,drawn={},stops=0,auto_stops=0,executes=0,passed=0,moves=0,starts=0,refreshes=0,writes=0,active=false}
  e.manual={requested=false,busy=false,phase='idle',text='Search is idle.',owner='manual'}
  e.auto={requested=false,busy=false,phase='idle',text='Auto-run is off.',owner='auto'}
  local A={display={title='Play a Pair',status='One action'},lines={'Ordinary advice.'},page=1,
    active=function()return e.active end,defaults=function()end,refresh=function()e.refreshes=e.refreshes+1 end,
    settings_changed=function()end,can_execute=function()return true end,
    execute=function()e.executes=e.executes+1 end,published_key='fixture-key',published_generation=1}
  Brainstorm={VERSION='Brainstorm v2.116.0-alpha',Advisor=A,config={advisor={enabled=true,hud=false}},
    writeConfig=function()e.writes=e.writes+1 end}
  Brainstorm.CollectionSearchProduct={status='Search is idle.',
    status_report=function()return e.manual end,
    stop=function(reason)e.stops=e.stops+1;e.manual.busy=false;e.manual.phase='stopped';e.manual.text=reason end,
    start_manual=function()e.starts=e.starts+1;return false,e.reject or 'Manual request rejected.' end}
  Brainstorm.AutoRun={status_text='Auto-run is off.',
    status_report=function()return e.auto end,status=function()error('UI must use pure status_report, not status()')end,
    stop=function(_,reason)e.auto_stops=e.auto_stops+1;e.auto.busy=false;e.auto.phase='stopped';e.auto.text=reason end,
    manual=function(_,reason)e.auto_stops=e.auto_stops+1;e.auto.busy=false;e.auto.phase='stopped';e.auto.text=reason end,
    start=function()e.starts=e.starts+1;return false,e.reject or 'Automatic request rejected.' end}
  local graphics={}
  for _,k in ipairs({'push','pop','origin','setFont','setColor','rectangle'})do graphics[k]=function()end end
  graphics.getDimensions=function()return 1600,900 end
  graphics.newFont=function(size)return {getWidth=function(_,text)return #text*size*.5 end}end
  graphics.print=function(text)e.drawn[#e.drawn+1]=text end;graphics.printf=graphics.print
  love={graphics=graphics,timer={getTime=function()return e.now end},
    mousepressed=function()e.passed=e.passed+1 end,mousemoved=function()e.moves=e.moves+1 end}
  Game={draw=function()end}
  G={STAGE=0,STAGES={RUN=1},SETTINGS={},FUNCS={},UIT={ROOT='ROOT',R='R',C='C',T='T',O='O'},
    C={GREEN={},WHITE={},CLEAR={},ORANGE={}}}
  UIBox_button=function(args)return{n='BUTTON',config=args}end
  create_toggle=function(args)return{n='TOGGLE',config=args}end
  create_UIBox_generic_options=function(args)return args end
  Moveable=function()return{remove=function()end}end
  UIBox=function(args)
    e.last_contents=args.definition
    local object={definition=args.definition,elements={}}
    function object:remove()end;function object:recalculate()end
    function object:get_UIE_by_ID(id)return self.elements[id]end
    local function scan(v)
      if v.config and v.config.id then object.elements[v.config.id]={config=v.config,UIBox=object}end
      for _,child in ipairs(v.nodes or v.contents or {})do scan(child)end
    end
    scan(args.definition);return object
  end
  G.FUNCS.overlay_menu=function(args)G.OVERLAY_MENU=UIBox(args)end
  G.FUNCS.exit_overlay_menu=function()G.OVERLAY_MENU=nil;G.SETTINGS.paused=false end
  dofile(P..'advisor.lua');dofile(P..'collection_run.lua')
  Brainstorm.showCollectionRunPage=function()e.page=Brainstorm.createCollectionRunPage()end
  function e.draw()e.drawn={};A.draw();return table.concat(e.drawn,'\n')end
  function e.click()local b=A.execute_bounds;assert(b);love.mousepressed(b.x+1,b.y+1,1)end
  function e.text(tree)
    local out={};local function walk(n)
      local c=n.config or {}
      if c.text then out[#out+1]=c.text elseif c.ref_table and c.ref_value then
        if c.func then G.FUNCS[c.func]()end;out[#out+1]=c.ref_table[c.ref_value]
      end
      for _,child in ipairs(n.nodes or {})do walk(child)end
    end
    walk(tree);return table.concat(out,'\n')
  end
  return e,A
end
do
  local e,A=environment()
  check(e.draw()=='' and not A.hud_bounds,'idle main menu does not gain an unsolicited HUD')
  e.manual.requested=true;e.manual.busy=true;e.manual.phase='waiting'
  e.manual.text='Waiting: controller frame_set lock remains true while the starting menu closes.'
  local text=e.draw()
  check(A.hud_search_stop and A.hud_status_only and A.hud_bounds.h==110,'explicit manual request appears on main menu despite HUD disabled')
  check(text:find(Brainstorm.VERSION,1,true),'HUD shows loaded global version')
  check(text:find('frame_set',1,true) and text:find('menu closes.',1,true),'waiting reason wraps without losing its conclusion')
  check(not A.hud_action_key,'search display carries no Execute token')
  for _=1,3 do e.draw();love.mousemoved(5,5);A.search_diagnostics(true)end
  check(e.stops==0 and e.auto_stops==0 and e.starts==0 and e.executes==0,'draw, read and hover never stop/start/execute')
  check(e.moves==3,'mouse motion still reaches existing handler')
  love.mousepressed(5,5,1);check(e.passed==1,'unrelated click passes through original handler')
  e.manual.busy=false;e.manual.phase='cancelled'
  e.click()
  check(e.stops==1 and e.executes==0,'stale manual Stop remains Stop and never Execute')
  e.draw();check(not A.hud_search_stop and A.hud_status_only,'stopped message occupies a non-executing status button')
  e.now=14.9;check(e.draw()~='','stopped notice lasts15seconds')
  e.active=true;Brainstorm.config.advisor.hud=true;e.now=15.1
  check(e.draw():find('Play a Pair',1,true) and A.hud_bounds.h==82 and not A.hud_status_only,'ordinary unchanged-size HUD returns after expiry')
  e.click();check(e.executes==1,'ordinary Execute returns only after a fresh normal draw')
end
do
  local e,A=environment()
  e.auto.requested=true;e.auto.busy=true;e.auto.phase='waiting';e.auto.text='Waiting: overlay menu is closing.'
  check(e.draw():find('AUTO-RUN',1,true) and A.hud_auto_stop,'auto pending visible outside normal advisor activity')
  e.auto.busy=false;e.click()
  check(e.auto_stops==1 and e.executes==0,'stale automatic Stop retains established behavior')
  e.draw();G.OVERLAY_MENU={};check(e.draw()=='' and not A.execute_bounds,'overlays hide status HUD and stale hitboxes')
  G.OVERLAY_MENU=nil;G.SETTINGS.paused=true;check(e.draw()=='' and not A.hud_bounds,'paused state hides status HUD')
  G.SETTINGS.paused=false;e.auto.busy=true;e.auto.phase='playing';e.draw()
  G.screenwipe=true;check(e.draw()=='' and not A.hud_bounds,'screen transition hides status HUD')
end
do
  local e,A=environment()
  e.manual.requested=true;e.manual.busy=true;e.manual.phase='waiting';e.draw()
  e.manual.busy=false;e.manual.phase='started';e.manual.text='Started searched run.'
  check(e.draw()=='' and not A.search_diagnostics(true),'successful manual launch clears previous request notice immediately')
  e.reject='Cannot start: loaded collection metadata is unavailable.'
  G.FUNCS.brainstorm_collection_search_start()
  check(e.starts==1 and e.draw():find('collection metadata',1,true),'first rejected request is visible even with requested false or previously started')
  check(e.text(Brainstorm.createCollectionRunPage()):find('v2.116.0-alpha',1,true),'search page shows loaded version without extra row')
  e.now=16;check(e.draw()=='' and A.search_diagnostics(true),'expired rejected notice remains accessible in explicit details')
  e.active=true;A.open()
  local ordinary=e.text(e.last_contents)
  check(e.refreshes==1 and ordinary:find('Ordinary advice.',1,true) and not ordinary:find(e.reject,1,true),
    'ordinary Ctrl+H-style open refreshes and displays advice after notice expiry')
  G.FUNCS.brainstorm_advisor_close()
  G.FUNCS.brainstorm_search_status_open()
  check(e.refreshes==1 and e.text(e.last_contents):find(e.reject,1,true),
    'explicit Full status still shows the old reason without refreshing advice')
  G.FUNCS.brainstorm_advisor_close()
  A.open()
  check(e.refreshes==2 and not A.search_detail_mode and e.text(e.last_contents):find('Ordinary advice.',1,true),
    'closing explicit diagnostics never makes the next ordinary open persistent')
  G.FUNCS.brainstorm_advisor_close()
  local message=string.rep('Missing metadata needs a loaded profile record. ',8)..'END-OF-REASON'
  A.note_search_notice('manual',message);e.draw()
  check(e.drawn[5]:sub(-3)=='...','long HUD text explicitly truncates after four metric-wrapped lines')
  A.open()
  local detail=e.text(e.last_contents)
  check(detail:find('END-OF-REASON',1,true) and detail:find(Brainstorm.VERSION,1,true),'details preserve the complete bounded reason and loaded version')
  check(e.refreshes==2,'opening active diagnostics does not start advisor refresh work')
  G.FUNCS.brainstorm_advisor_close()
  A.note_search_notice('auto',string.rep('x',700));local value=A.search_diagnostics(true)
  check(#value.text==512 and value.text:sub(-3)=='...','untrusted status text has explicit512byte bound')
end
do
  local e,A=environment()
  local page=Brainstorm.createCollectionRunPage();local original=#page.nodes
  local status_rows=0
  for _,node in ipairs(page.nodes)do for _,leaf in ipairs(node.nodes or {})do
    if leaf.config and leaf.config.func=='brainstorm_collection_status' then status_rows=status_rows+1 end
  end end
  check(status_rows==3,'page reserves three compact live status rows')
  e.manual.requested=true;e.manual.busy=true;e.manual.phase='waiting';e.manual.text=string.rep('longword ',80)
  local changed=Brainstorm.createCollectionRunPage()
  check(#changed.nodes==original,'long status does not add menu nodes or unbounded height')
  local text=e.text(changed)
  check(text:find('More: Full status.',1,true),'overlong page text directs to complete details')
  check(e.starts==0 and e.stops==0 and e.auto_stops==0 and e.writes==0,'page construction/status refresh is read-only')
end
print('startup_ui316: '..checks..' synthetic checks passed')
