-- Manufactured public states and in-memory files only; never starts the game.
local Journal=dofile('Brainstorm/Advisor/player_journal.lua')
local Archive=dofile('Brainstorm/Advisor/player_log_archive.lua')
local Manual=dofile('Brainstorm/Advisor/manual_run_log.lua')
local checks=0
local function check(ok,label)checks=checks+1;assert(ok,label)end
local files,dirs,removed={},{},{}
local fs={}
function fs.getInfo(path)
  if dirs[path]then return{type='directory'}end
  if files[path]then return{type='file',size=#files[path]}end
end
function fs.createDirectory(path)dirs[path]=true;return true end
function fs.getDirectoryItems(path)
  local result={}
  for name in pairs(files)do
    if name:sub(1,#path+1)==path..'/'then result[#result+1]=name:sub(#path+2)end
  end
  table.sort(result);return result
end
function fs.append(path,raw)files[path]=(files[path]or'')..raw;return true end
function fs.read(path)return files[path]end
function fs.write(path,raw)if files[path]then return nil,'occupied'end;files[path]=raw;return true end
function fs.remove(path)
  if not files[path]then return nil,'missing'end
  removed[#removed+1]=path;files[path]=nil;return true
end
local function hash(raw)
  local n=0;for i=1,#raw do n=(n*131+raw:byte(i))%2147483647 end
  return string.format('%064x',n)
end
local function range(path,offset,length)return files[path]:sub(offset+1,offset+length)end
local g={STAGES={RUN=1},STAGE=1,STATES={GAME_OVER=99},STATE=2,STATE_COMPLETE=true,
  SETTINGS={profile=1,paused=false},PROFILES={[1]={}},CONTROLLER={locks={}},FUNCS={},
  GAME={stake=8,round=1,round_resets={ante=1},blind={boss=false,chips=300},win_ante=8,
    pseudorandom={seed='MANUFACTURED'}}}
local subscribed,engaged=false,false
local auto_games=setmetatable({},{__mode='k'})
local B={VERSION='manufactured',config={advisor={player_logging=false,manual_logging=true,
  player_log_compression=false}},AutoRun={}}
function B.AutoRun:engaged()return engaged end
function B.AutoRun:is_auto_game(current)return auto_games[current.GAME]==true end
function B.AutoRun:subscribe_terminal_source(fn)subscribed=fn end
local A={player_journal=Journal,player_log_archive=Archive,
  snapshot={capture=function()return{phase='hand',dollars=5,hand={}}end,
    fingerprint=function()return 'fresh'end}}
Journal.attach(A,B,{game=function()return g end,fs=fs,hash=hash,read_range=range,
  clock=function()return 1 end,now=function()return 'fixed'end})
local manual=Manual.attach(A,B,{game=function()return g end,fs=fs,hash=hash,read_range=range,
  clock=function()return 1 end,now=function()return 'fixed'end})
check(type(subscribed)=='function','single existing terminal observer was subscribed')
check(not A.player_log:enabled(),'auto recording toggle remains off')
check(manual:update(g)==nil and manual:is_active(g),'human run starts independently of advisor toggle')
local journal=manual:journal_for(g)
check(journal and journal.collection_mode and journal.collection_id,'manual run has a linked public schema')
check(journal:before('play_cards_from_highlighted',{selected={1}}),'manual action has a sequence')
check(not dirs.advisor_player_log_v2,'manual observation does not create auto directory')

local function new_game(n)
  g.STATE=2;g.GAME={stake=8,round=n,round_resets={ante=8},blind={boss=true,chips=100},
    chips=120,win_ante=8,pseudorandom={seed='REPEATED-SEED'},won=false}
end
local function finish(n,kind)
  new_game(n)
  manual:update(g)
  if kind=='win'then
    subscribed('end_round_entry',g)
    g.GAME.won=true
    subscribed('win_game_returned',g)
  else g.STATE=99 end
  manual:update(g)
  check(not manual.error and not manual:is_active(g),'one verified '..kind..' committed: '..tostring(manual.error or manual.status))
  local before=manual.completed[kind]
  manual:update(g)
  check(manual.completed[kind]==before,'finished GAME cannot be counted twice')
end
for i=1,11 do finish(i,'win');finish(i+100,'loss')end
local receipts={win=0,loss=0};local manual_files=0
for path,raw in pairs(files)do
  if path:match('^advisor_manual_log_v1/')then
    manual_files=manual_files+1
    if path:match('%.mrec$')then
      if raw:find('\twin\t',1,true)then receipts.win=receipts.win+1
      elseif raw:find('\tloss\t',1,true)then receipts.loss=receipts.loss+1 end
    end
  end
end
check(receipts.win==10 and receipts.loss==10,'independent trailing ten outcome receipts retained')
check(#removed==6,'eleventh win and loss remove their whole segment, receipt and durable marker each')
check(manual_files>=40,'remaining manual segments and receipts are intact')
local before=manual_files
check(A.player_log:clear_logs(),'auto clear remains usable')
local after=0;for path in pairs(files)do if path:match('^advisor_manual_log_v1/')then after=after+1 end end
check(after==before,'auto clear never visits manual namespace')

new_game(999);manual:update(g)
local prior=0;for path in pairs(files)do if path:match('^advisor_manual_log_v1/.*%.mrec$')then prior=prior+1 end end
new_game(1000);manual:update(g)
local next_count=0;for path in pairs(files)do if path:match('^advisor_manual_log_v1/.*%.mrec$')then next_count=next_count+1 end end
check(next_count==prior,'replacement preserves incomplete run without creating an outcome receipt')
engaged=true;manual:update(g)
check(not manual:is_active(g),'auto ownership retires human recorder without terminal label')
engaged=false;manual:update(g)
check(manual:is_active(g),'canceled auto ownership allows a fresh manual trace for the same GAME')
engaged=true;manual:update(g)
engaged=false;auto_games[g.GAME]=true;manual:update(g)
check(not manual:is_active(g),'completed auto-owned GAME is never relabeled as human')

-- A failed remove leaves a verified marker so a fresh process can complete
-- the exact whole-run deletion without touching the retained run.
local files2,fail_second,removes2={},true,0
local fs2={}
local dirs2={}
function fs2.getInfo(path)
  if dirs2[path]then return{type='directory'}end
  if files2[path]then return{type='file',size=#files2[path]}end
end
function fs2.createDirectory(path)dirs2[path]=true;return true end
function fs2.getDirectoryItems(path)
  local out={};for name in pairs(files2)do
    if name:sub(1,#path+1)==path..'/'then out[#out+1]=name:sub(#path+2)end
  end
  return out
end
function fs2.read(path)return files2[path]end
function fs2.write(path,raw)if files2[path]then return nil,'occupied'end;files2[path]=raw;return true end
function fs2.append(path,raw)files2[path]=(files2[path]or'')..raw;return true end
function fs2.remove(path)
  removes2=removes2+1
  if fail_second and removes2==2 then return nil,'manufactured interruption'end
  files2[path]=nil;return true
end
local directory='advisor_manual_log_v1/'
for i=1,2 do
  local name='session-manual-manufactured-'..i
  local segment=directory..name..'-000001.brj'
  files2[segment]='manufactured-'..i
  Manual.complete(fs2,hash,{paths={segment}},'win')
end
Manual.KEEP_EACH=1
check(not pcall(Manual.prune,fs2,hash),'mid-prune remove failure is surfaced')
local markers=0;for path in pairs(files2)do if path:match('%.pending$')then markers=markers+1 end end
check(markers==1,'failed prune leaves exactly one durable marker')
fail_second=false
new_game(1200)
local manual_restart=Manual.attach(A,B,{game=function()return g end,fs=fs2,hash=hash,
  read_range=function(path,offset,length)return files2[path]:sub(offset+1,offset+length)end,
  clock=function()return 2 end,now=function()return 'fixed'end})
manual_restart:update(g)
check(manual_restart:is_active(g)and not manual_restart.error,
  'fresh manual recorder recovers marked pruning before it opens a new run')
local survivor_receipts,survivor_segments,pending=0,0,0
for path in pairs(files2)do
  if path:match('%.mrec$')then survivor_receipts=survivor_receipts+1
  elseif path:match('%.brj$')then survivor_segments=survivor_segments+1
  elseif path:match('%.pending$')then pending=pending+1 end
end
check(survivor_receipts==1 and survivor_segments==2 and pending==0,
  'recovery keeps the recent complete run, permits a new incomplete run and clears the marker')
local survivor_path=directory..'session-manual-manufactured-2-000001.brj'
check(files2[survivor_path]~=nil,'recent completed segment survived restart recovery')
Manual.complete(fs2,hash,{paths={survivor_path}},'win')
local before_duplicate=removes2
check(not pcall(Manual.prune,fs2,hash),'duplicate kept/victim segment membership blocks pruning')
check(removes2==before_duplicate,'duplicate membership is rejected before any removal')
Manual.KEEP_EACH=10

local old_raw,receipt_path
for path,raw in pairs(files)do if path:match('%.mrec$')then old_raw=raw;receipt_path=path;files[path]=raw..'changed';break end end
local count=#removed
check(not pcall(Manual.prune,fs,hash),'malformed owned completion receipt blocks deletion')
check(#removed==count,'invalid retention receipt cannot discard other files')
check(old_raw~=nil,'manufactured corruption actually touched a receipt')
files[receipt_path]=old_raw
local segment_path,segment_raw
for path,raw in pairs(files)do if path:match('%.brj$')then segment_path=path;segment_raw=raw;break end end
files[segment_path]='X'..segment_raw:sub(2)
Manual.KEEP_EACH=0
check(not pcall(Manual.prune,fs,hash),'changed segment hash blocks whole-run retention pruning')
check(#removed==count,'segment corruption never causes partial pruning')
print('advisor_manual_run_log379: '..checks..' manufactured checks passed')
