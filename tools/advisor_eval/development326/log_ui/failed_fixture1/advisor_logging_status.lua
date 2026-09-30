-- Actual UI with manufactured callbacks only; no player files or live game.
local checks=0
local function check(v,label)checks=checks+1;assert(v,label)end
local function equal(a,b,label)check(a==b,label..': '..tostring(a)..' ~= '..tostring(b))end
local f=assert(io.open('tests/advisor_startup_ui.lua','rb'));local source=f:read('*a');f:close()
source=source:gsub('\r\n','\n')
local helpers=source:sub(1,assert(source:find('\ndo\n',1,true))-1)
local environment=assert(loadstring(helpers..'\nreturn environment'))()
local function buttons(tree)
  local out={};local function visit(n)
    if n.config and n.config.button then out[n.config.button]=true end
    for _,child in ipairs(n.nodes or {})do visit(child)end
  end;visit(tree);return out
end
local function all_pages(e,A)
  local out={};local pages=A.menu_page_count
  for i=1,pages do
    equal(A.page,i,'details advance through their own actual page count')
    out[#out+1]=e.text(e.last_contents)
    for _,row in ipairs(e.last_contents.nodes or {})do for _,node in ipairs(row.nodes or {})do
      if node.config and type(node.config.text)=='string' then
        check(#node.config.text<=78,'each rendered detail text fits its bounded row')
        check(not node.config.text:find('[%z\1-\31]'),'detail rows contain no control characters')
      end
    end end
    G.FUNCS.brainstorm_advisor_page()
  end
  equal(A.page,1,'last details page wraps to first');return table.concat(out,'\n')
end
do
  local e,A=environment();local error_text='C:/fixture/'..string.rep('long_path_',35)..':149: Total observation byte limit reached; existing logs are preserved.'
  A.player_log={status='Recording stopped: '..error_text,error=error_text,
    event=function()error('status inspection must never append or reset the recorder')end}
  local page=Brainstorm.createAdvisorPage();local text=e.text(page)
  check(text:find('Recording stopped: log storage is full.',1,true),'settings show readable storage failure at idle menu')
  check(not text:find('C:/fixture',1,true),'settings do not put long source errors on one row')
  check(buttons(page).brainstorm_recording_status_open,'persistent Recording status control exists in settings')
  local settings_nodes=#page.nodes
  equal(settings_nodes,15,'replacement status control keeps settings page compact')
  e.now=10000;G.FUNCS.brainstorm_recording_status_open()
  check(A.logging_detail_mode and not A.search_detail_mode,'dedicated recording mode opens after popup expiration')
  equal(e.refreshes,0,'recording inspection does not calculate advice')
  text=all_pages(e,A)
  check(text:find('Total observation byte limit reached;',1,true),'full underlying byte-limit reason remains readable')
  check(text:find('advisor_player_log_v1 and advisor_player_log_v2',1,true),'details name both counted storage folders')
  check(text:find('Both folders count toward the same storage limit.',1,true),'details explain one combined limit')
  equal(A.player_log.error,error_text,'inspection preserves sticky underlying recording error')
  equal(e.starts+e.executes+e.stops+e.auto_stops+e.writes,0,'read-only details never start execute stop or write configuration')
  G.FUNCS.brainstorm_advisor_close();check(not A.logging_detail_mode,'closing clears recording mode')
  G.FUNCS.brainstorm_search_status_open();text=all_pages(e,A)
  check(text:find('Total observation byte limit reached;',1,true),'Full status includes recorder failure even with no search request')
  equal(e.refreshes,0,'Full status with recording error does not calculate advice')
  equal(A.player_log.error,error_text,'Full status cannot clear recording error')
  G.FUNCS.brainstorm_advisor_close();e.active=true;A.lines={'Current playable advice'};A.open()
  check(not A.logging_detail_mode and e.text(e.last_contents):find('Current playable advice',1,true),'ordinary advisor returns after recording details')
end
do
  local e,A=environment();A.lines={'Only one old advice line'}
  local body='ERROR_START '..string.rep('x',700)..'\0\n'..string.rep('detail ',470)..' ERROR_END'
  check(#body<4096,'fixture complete error fits declared bound')
  A.player_log={status='Recording stopped.',error=body};A.selection={kind='discard'}
  A.retry_status=function()error('recording details must not expose retry controls')end
  e.active=true;G.FUNCS.brainstorm_recording_status_open()
  check(A.menu_page_count>2,'long actual errors paginate independently from old advice')
  local text=all_pages(e,A)
  check(text:find('ERROR_START',1,true)and text:find('ERROR_END',1,true),'all error content within bound remains reachable')
  check(not buttons(e.last_contents).brainstorm_advisor_select,'recording page cannot select a stale action')
  e.auto.requested=true;e.auto.busy=true;e.auto.phase='playing';e.auto.text='Running normally'
  G.FUNCS.brainstorm_search_status_open();text=all_pages(e,A)
  check(text:find('Running normally',1,true)and text:find('ERROR_END',1,true),'active Full status retains both search and complete error')
  equal(e.starts+e.executes+e.stops+e.auto_stops,0,'active status inspection preserves auto-run')
end
do
  local e,A=environment();A.player_log={status='Recording stopped.',error=string.rep('z',5000)..'OMIT_ME'}
  G.FUNCS.brainstorm_recording_status_open();local text=all_pages(e,A)
  check(text:find('...',1,true)and not text:find('OMIT_ME',1,true),'oversized error explicitly truncates at bounded detail size')
  check(A.menu_page_count<=7,'oversized error cannot create unlimited pages')
  equal(#A.player_log.error,5007,'display bound never changes original error')
end
do
  local e,A=environment();A.player_log={status='Recording 8 events; 12345 stored bytes.'}
  G.FUNCS.brainstorm_recording_status_open();local text=all_pages(e,A)
  check(text:find('Recording 8 events;',1,true)and not text:find('Last recording error:',1,true),'healthy recorder has accurate nonerror status')
  equal(e.refreshes,0,'healthy recording inspection stays read-only')
  G.FUNCS.brainstorm_advisor_close();A.player_log=nil;G.FUNCS.brainstorm_recording_status_open()
  check(e.text(e.last_contents):find('Recording is unavailable.',1,true),'absent optional recorder remains inspectable')
end
do
  local e,A=environment();local character='\195\169'
  A.player_log={status='Recording stopped.',error=string.rep(character,2100)}
  G.FUNCS.brainstorm_recording_status_open();local text=all_pages(e,A)
  -- Every two-byte fixture character remains a complete pair after wrapping.
  local stripped=text:gsub(character,'e')
  check(not stripped:find('[\128-\255]'),'UTF-8 error truncation and long-word wrapping preserve character boundaries')
end
print('advisor_logging_status: '..checks..' checks passed')
