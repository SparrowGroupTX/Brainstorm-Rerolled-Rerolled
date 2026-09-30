-- Human-play observations have their own bounded archive. Auto-run clearing
-- never visits this directory. Only source-confirmed terminals enter retention.
local M={DIRECTORY='advisor_manual_log_v1',MAX_TOTAL_BYTES=10737418240,KEEP_EACH=10}
local function whole(v)return type(v)=='number'and v==v and v>=0 and v<math.huge and v%1==0 end
local function hex(v)return type(v)=='string'and #v==64 and not v:find('[^0-9a-f]')end
local function safe(v)return type(v)=='string'and #v>0 and #v<=128 and v:match('^[%w%-_]+$')end
local function sorted_items(fs)
  local listed=fs.getDirectoryItems(M.DIRECTORY)
  assert(type(listed)=='table','Manual observation listing failed.')
  assert(#listed<=4096,'Manual observation file-count limit reached.')
  for _,name in ipairs(listed)do
    assert(type(name)=='string'and name~='.'and name~='..'and not name:find('[/\\]'),'Unsafe manual observation name.')
  end
  table.sort(listed);return listed
end
local function checked_file(fs,name)
  local path=M.DIRECTORY..'/'..name
  local info=fs.getInfo(path)
  assert(info and info.type=='file'and whole(info.size),'Manual observation file metadata changed.')
  return path,info.size
end
local function bounded_read(fs,path,size)
  assert(size<=8388608,'Manual observation segment exceeds its bound.')
  local raw=fs.read(path)
  assert(type(raw)=='string'and #raw==size,'Manual observation readback failed.')
  return raw
end
local function receipt_body(order,outcome,base,segments)
  local rows={tostring(order)..'\t'..outcome..'\t'..base..'\t'..tostring(#segments)}
  for _,file in ipairs(segments)do rows[#rows+1]=file.name..'\t'..file.size..'\t'..file.sha256 end
  return table.concat(rows,'\n')..'\n'
end
local function decode_receipt(fs,hash,name,source_name)
  local order_text,base=name:match('^complete%-(%d%d%d%d%d%d%d%d%d%d%d%d)%-(session%-[%w%-_]+)%.mrec$')
  if not order_text then return nil end
  local path,size=checked_file(fs,source_name or name)
  assert(size<=1048576,'Manual completion receipt exceeds its bound.')
  local raw=fs.read(path)
  assert(type(raw)=='string'and #raw==size,'Manual completion receipt readback failed.')
  local digest,body=raw:match('^MR1\t([0-9a-f]+)\n(.*)$')
  assert(hex(digest)and hash(body)==digest,'Manual completion receipt hash failed.')
  local lines={};for line in body:gmatch('([^\n]*)\n')do lines[#lines+1]=line end
  local order,status,recorded_base,declared
  if lines[1] then order,status,recorded_base,declared=lines[1]:match('^(%d+)\t([%a]+)\t([^\t]+)\t(%d+)$')end
  assert(order==tostring(tonumber(order_text))and recorded_base==base and (status=='win'or status=='loss')and
    whole(tonumber(declared))and tonumber(declared)>0 and tonumber(declared)<=2048 and
    #lines==tonumber(declared)+1,'Invalid manual completion receipt header.')
  local segments={};local seen={}
  for i=2,#lines do
    local file,size_text,sha=lines[i]:match('^([^\t]+)\t(%d+)\t([0-9a-f]+)$')
    assert(file==base..'-'..string.format('%06d',i-1)..'.brj'and
      not seen[file]and hex(sha),
      'Invalid manual completion segment membership.')
    seen[file]=true;segments[#segments+1]={name=file,size=tonumber(size_text),sha256=sha}
    assert(whole(segments[#segments].size)and segments[#segments].size<=8388608,
      'Invalid manual completion segment size.')
  end
  return {name=name,order=tonumber(order_text),outcome=status,base=base,segments=segments,
    receipt_sha256=hash(raw)}
end
local function catalog(fs)
  local files=sorted_items(fs);local total=0
  for _,name in ipairs(files)do local _,size=checked_file(fs,name);total=total+size end
  return files,total
end
local function complete(fs,hash,writer,outcome)
  assert(outcome=='win'or outcome=='loss','Invalid manual terminal outcome.')
  local paths=writer.paths
  assert(type(paths)=='table'and #paths>0 and #paths<=2048,'Manual run has no complete segment set.')
  local first=paths[1]:match('^advisor_manual_log_v1/(session%-(.*))%-%d%d%d%d%d%d%.brj$')
  assert(first and safe(first),'Invalid manual run archive identity.')
  local files,total=catalog(fs);local max_order=0
  for _,name in ipairs(files)do
    local order=name:match('^complete%-(%d%d%d%d%d%d%d%d%d%d%d%d)%-session%-[%w%-_]+%.mrec$')
    if order then max_order=math.max(max_order,tonumber(order))end
  end
  assert(max_order<999999999999,'Manual completion order exhausted.')
  local membership,segments={},{}
  for _,path in ipairs(paths)do
    local name=path:match('^advisor_manual_log_v1/([^/\\]+)$')
    assert(name==first..'-'..string.format('%06d',#segments+1)..'.brj'and not membership[name],
      'Manual run segment identity changed.')
    membership[name]=true
    local actual,size=checked_file(fs,name)
    local digest=hash(bounded_read(fs,actual,size))
    assert(hex(digest),'Manual run segment hash is invalid.')
    segments[#segments+1]={name=name,size=size,sha256=digest}
  end
  for _,name in ipairs(files)do
    if name:sub(1,#first+1)==first..'-'and name:match('%-%d%d%d%d%d%d%.brj$')then
      assert(membership[name],'Unindexed manual run segment is preserved.')
    end
  end
  local order=max_order+1
  local name='complete-'..string.format('%012d',order)..'-'..first..'.mrec'
  local body=receipt_body(order,outcome,first,segments)
  local raw='MR1\t'..hash(body)..'\n'..body
  -- Leave space for a durable pruning marker even at the namespace limit.
  assert(#raw<=1048576 and total+#raw+1048576<=M.MAX_TOTAL_BYTES and #files+1<=4096,
    'Manual completion receipt exceeds storage limits; observations are preserved.')
  local path=M.DIRECTORY..'/'..name
  assert(not fs.getInfo(path),'Refusing to overwrite a manual completion receipt.')
  local written,why=fs.write(path,raw);assert(written,why or 'Manual completion receipt write failed.')
  local after=fs.getInfo(path)
  assert(after and after.type=='file'and after.size==#raw and fs.read(path)==raw,
    'Manual completion receipt readback failed.')
  return name
end
local function verify_segment(fs,hash,segment)
  local path,size=checked_file(fs,segment.name)
  assert(size==segment.size and hash(bounded_read(fs,path,size))==segment.sha256,
    'Manual completion segment changed; pruning stopped.')
  return path
end
local function remove_checked(fs,hash,name,size,digest)
  local path,actual=checked_file(fs,name)
  assert(actual==size,'Manual prune target size changed.')
  assert(hash(bounded_read(fs,path,size))==digest,'Manual prune target hash changed.')
  local okay,why=fs.remove(path);assert(okay,why or 'Manual prune removal failed.')
  assert(not fs.getInfo(path),'Manual prune removal could not be verified.')
end
local function consume_tombstone(fs,hash,original,tombstone,receipt)
  local original_info=fs.getInfo(M.DIRECTORY..'/'..original)
  if original_info then
    local _,size=checked_file(fs,original)
    assert(hash(bounded_read(fs,M.DIRECTORY..'/'..original,size))==receipt.receipt_sha256,
      'Manual prune receipt changed after marker creation.')
  end
  for _,segment in ipairs(receipt.segments)do
    if fs.getInfo(M.DIRECTORY..'/'..segment.name)then
      remove_checked(fs,hash,segment.name,segment.size,segment.sha256)
    end
  end
  if original_info then
    local _,size=checked_file(fs,original)
    remove_checked(fs,hash,original,size,receipt.receipt_sha256)
  end
  local _,size=checked_file(fs,tombstone)
  remove_checked(fs,hash,tombstone,size,receipt.receipt_sha256)
end
local function recover_pruning(fs,hash)
  local files=catalog(fs);local pending={};local completed={};local segment_owner={}
  for _,name in ipairs(files)do
    if name:match('^complete%-')then
      local receipt=decode_receipt(fs,hash,name)
      assert(receipt,'Unknown manual completion receipt is preserved.')
      completed[name]=receipt
    elseif name:match('^prune%-')then
      local original=name:match('^prune%-(complete%-%d%d%d%d%d%d%d%d%d%d%d%d%-session%-[%w%-_]+%.mrec)%.pending$')
      assert(original,'Unknown manual prune marker is preserved.')
      local receipt=decode_receipt(fs,hash,original,name)
      assert(receipt,'Invalid manual prune marker is preserved.')
      pending[#pending+1]={original=original,name=name,receipt=receipt}
    end
  end
  -- Check every marker before resuming any interrupted deletion. Its own
  -- completion may already be gone, but another receipt may never own a target.
  local seen_pending,marked_orders,marked_bases={},{},{}
  for _,marker in ipairs(pending)do
    assert(not seen_pending[marker.original],'Duplicate manual prune markers are preserved.')
    seen_pending[marker.original]=true
    assert(not marked_orders[marker.receipt.order]and not marked_bases[marker.receipt.base],
      'Duplicate manual prune identity is preserved.')
    marked_orders[marker.receipt.order]=marker.original
    marked_bases[marker.receipt.base]=marker.original
    local ordinary=completed[marker.original]
    assert(not ordinary or ordinary.receipt_sha256==marker.receipt.receipt_sha256,
      'Manual prune marker and receipt disagree.')
    for _,segment in ipairs(marker.receipt.segments)do
      assert(not segment_owner[segment.name],'Manual prune markers share a segment.')
      segment_owner[segment.name]=marker.original
      if fs.getInfo(M.DIRECTORY..'/'..segment.name)then verify_segment(fs,hash,segment)end
    end
  end
  local ordinary_orders,ordinary_bases={},{ }
  for name,receipt in pairs(completed)do
    assert(not ordinary_orders[receipt.order]and not ordinary_bases[receipt.base],
      'Duplicate manual completion identity is preserved.')
    ordinary_orders[receipt.order]=true;ordinary_bases[receipt.base]=true
    assert((not marked_orders[receipt.order]or marked_orders[receipt.order]==name)and
      (not marked_bases[receipt.base]or marked_bases[receipt.base]==name),
      'Manual prune marker overlaps another completion identity.')
    for _,segment in ipairs(receipt.segments)do
      assert(not segment_owner[segment.name]or segment_owner[segment.name]==name,
        'Manual prune marker overlaps another completion.')
    end
  end
  local recovered=0
  for _,marker in ipairs(pending)do
    consume_tombstone(fs,hash,marker.original,marker.name,marker.receipt)
    recovered=recovered+1
  end
  return recovered
end
local function prune(fs,hash)
  local recovered=recover_pruning(fs,hash)
  local files,total=catalog(fs);local receipts={win={},loss={}}
  local orders,bases,all_segments={},{},{}
  for _,name in ipairs(files)do
    if name:match('^complete%-')then
      local receipt=decode_receipt(fs,hash,name)
      assert(receipt,'Unknown manual completion receipt is preserved.')
      assert(not orders[receipt.order],'Duplicate manual completion order is preserved.')
      assert(not bases[receipt.base],'Duplicate manual run completion is preserved.')
      orders[receipt.order]=true
      bases[receipt.base]=true
      for _,segment in ipairs(receipt.segments)do
        assert(not all_segments[segment.name],'Manual segment belongs to multiple completions.')
        all_segments[segment.name]=true
      end
      receipts[receipt.outcome][#receipts[receipt.outcome]+1]=receipt
    end
  end
  local victims={}
  for _,group in pairs(receipts)do
    table.sort(group,function(a,b)return a.order<b.order end)
    for i=1,math.max(0,#group-M.KEEP_EACH)do victims[#victims+1]=group[i]end
  end
  -- Verify every victim before the first deletion. Unknown, missing or changed
  -- segments stop pruning; they never become permission to free space.
  local seen={}
  for _,victim in ipairs(victims)do
    for _,segment in ipairs(victim.segments)do
      assert(not seen[segment.name],'Manual segments appear in multiple completion receipts.')
      seen[segment.name]=true
      verify_segment(fs,hash,segment)
    end
    local path,size=checked_file(fs,victim.name)
    assert(hash(bounded_read(fs,path,size))==victim.receipt_sha256,
      'Manual completion receipt changed; pruning stopped.')
  end
  local removed=0
  for _,victim in ipairs(victims)do
    local marker='prune-'..victim.name..'.pending'
    local marker_path=M.DIRECTORY..'/'..marker
    assert(not fs.getInfo(marker_path),'Manual prune marker already exists.')
    local raw=fs.read(M.DIRECTORY..'/'..victim.name)
    assert(type(raw)=='string'and hash(raw)==victim.receipt_sha256,
      'Manual completion receipt changed before marker creation.')
    assert(total+#raw<=M.MAX_TOTAL_BYTES and #files+1<=4096,
      'Manual prune marker exceeds storage limits; observations are preserved.')
    local okay,why=fs.write(marker_path,raw);assert(okay,why or 'Manual prune marker write failed.')
    local info=fs.getInfo(marker_path)
    assert(info and info.type=='file'and info.size==#raw and fs.read(marker_path)==raw,
      'Manual prune marker readback failed.')
    consume_tombstone(fs,hash,victim.name,marker,victim)
    total=total-#raw
    for _,segment in ipairs(victim.segments)do total=total-segment.size end
    removed=removed+#victim.segments+2
  end
  return {removed_files=removed,removed_runs=#victims+recovered,retained_wins=math.min(#receipts.win,M.KEEP_EACH),
    retained_losses=math.min(#receipts.loss,M.KEEP_EACH)}
end
M.complete=complete;M.prune=prune

function M.attach(A,B,deps)
  deps=deps or {};local fs=assert(deps.fs or love and love.filesystem,'Manual observation filesystem is unavailable.')
  local module=assert(A.player_log_archive);local journal_module=assert(A.player_journal)
  local game=deps.game or function()return G end
  local now=deps.now or function()return os.date('!%Y-%m-%dT%H:%M:%SZ')end
  local monotonic=deps.clock or function()return love.timer.getTime()end
  local hash=deps.hash or function(raw)
    return love.data.hash('sha256',raw):gsub('.',function(c)return string.format('%02x',string.byte(c))end)
  end
  local manager={status='Manual logging is ready.',completed={win=0,loss=0}}
  local active,serial
  local finished_games=setmetatable({},{__mode='k'})
  serial=0
  local function auto_owned()
    return B.AutoRun and B.AutoRun.engaged and B.AutoRun:engaged()
  end
  local function eligible(g)
    return B.config.advisor.manual_logging~=false and not auto_owned()and g and type(g.GAME)=='table'and
      not (B.AutoRun and B.AutoRun.is_auto_game and B.AutoRun:is_auto_game(g))and
      g.STAGES and g.STAGE==g.STAGES.RUN and type((g.PROFILES or {})[(g.SETTINGS or {}).profile])=='table'
  end
  function manager:is_active(g)
    g=g or game()
    return active~=nil and eligible(g)and active.game==g.GAME and
      active.profile==(g.SETTINGS or {}).profile and active.profile_table==(g.PROFILES or {})[active.profile]
  end
  local function fail(reason)
    manager.error=tostring(reason);manager.status='Manual recording stopped: '..manager.error
    if deps.notice then deps.notice(manager.status)end
    return nil,manager.error
  end
  local function finish_unknown(reason)
    if not active then return end
    local old=active
    if old.journal and not old.journal.error then
      -- Preserve the partial trace. No completion receipt or retention credit.
      old.journal:event('manual_run_interrupted',{reason=reason or 'Run context changed.'},{})
      old.journal:end_collection(reason)
    end
    if old.archive then old.archive:close()end
    active=nil
  end
  local function make_id()
    local created,why=fs.createDirectory(M.DIRECTORY);assert(created,why)
    local names=sorted_items(fs)
    local stamp=os.date('!%Y%m%dT%H%M%SZ')
    for _=1,4096 do
      serial=serial+1
      local candidate='manual-'..stamp..'-'..serial
      local used=false
      for _,name in ipairs(names)do
        if name:find('session-'..candidate..'-',1,true)then used=true;break end
      end
      if not used then return candidate end
    end
    error('No unused manual observation identity.')
  end
  local function begin(g)
    local created,why=fs.createDirectory(M.DIRECTORY);assert(created,why)
    -- A previous process may have stopped halfway through a marked prune.
    -- Recover it before a new run needs storage or a fresh identity.
    prune(fs,hash)
    local id=make_id();local entry={id=id,game=g.GAME,profile=(g.SETTINGS or {}).profile,
      profile_table=(g.PROFILES or {})[(g.SETTINGS or {}).profile]}
    local compress=deps.compress or (B.config.advisor.player_log_compression~=false and function(raw)
      return love.data.compress('string','zlib',raw,6)end)
    local decompress=deps.decompress or (B.config.advisor.player_log_compression~=false and function(raw)
      return love.data.decompress('string','zlib',raw)end)
    entry.archive=module.new({scope='manual',fs=fs,encode=journal_module.encode,
      encode_frame=journal_module.encode_frame,hash=hash,compress=compress,decompress=decompress,
      read_range=deps.read_range,limits={MAX_TOTAL_BYTES=M.MAX_TOTAL_BYTES-2097152},
      session_name=function()return id end,
      identity=function()return entry.game,entry.profile_table end})
    active=entry
    entry.journal=journal_module.new({collection_prefix='manual',archive=entry.archive,
      enabled=function()return active==entry and eligible(game())end,clock=monotonic,now=now,
      settled=function()
        local current=game();local c=current and current.CONTROLLER or {}
        if not current or not current.GAME then return false end
        if current.STATES and current.STATE==current.STATES.GAME_OVER then return true end
        if not current.STATE_COMPLETE or current.screenwipe or (current.GAME.STOP_USE or 0)>0 or
          c.locked or c.dragging and c.dragging.target or c.text_input_hook or current.OVERLAY_MENU or
          (current.SETTINGS or {}).paused then return false end
        for _,locked in pairs(c.locks or {})do if locked then return false end end
        return true
      end,
      observe=function()
        local okay,context=pcall(A.player_log_observe)
        if not okay or type(context)~='table'then
          context={version=B.VERSION,run_instance=id,actor='human',
            observation_status='unavailable',observation_error='Public capture failed; no state label is inferred.'}
        end
        context.run_instance=id;context.teacher=nil
        context.actor='human';context.manual_recording='manual_run_v1';return context
      end,
      notice=deps.notice})
    assert(entry.journal:begin_manual(id))
    entry.journal.update=A.player_log.update
    local ok,why=entry.journal:event('manual_run_started',{actor='human',
      start_scope='First observed public state; may be a midrun attachment.',
      version=B.VERSION,profile=entry.profile,stake=g.GAME.stake})
    assert(ok,why)
    return entry
  end
  function manager:journal_for(g)
    g=g or game()
    if not eligible(g)or self.error then return nil end
    if active and (active.game~=g.GAME or active.profile~=(g.SETTINGS or {}).profile or
      active.profile_table~=(g.PROFILES or {})[active.profile])then finish_unknown('Game or profile identity changed.')end
    if finished_games[g.GAME]then return nil end
    if not active then
      local okay,result=pcall(begin,g)
      if not okay then return fail(result)end
      active=result
    end
    return active.journal
  end
  function manager:on_source(kind,g)
    if not active or not g or g.GAME~=active.game or (g.SETTINGS or {}).profile~=active.profile or
      (g.PROFILES or {})[active.profile]~=active.profile_table or auto_owned()then return end
    local game_state=g.GAME
    if kind=='end_round_entry' then
      local blind=game_state.blind or {};local ante=(game_state.round_resets or {}).ante
      if blind.boss and ante==game_state.win_ante then
        active.final={round=game_state.round,ante=ante,chips=game_state.chips,target=blind.chips}
      end
    elseif kind=='end_round_saved' then
      active.saved={round=game_state.round,ante=(game_state.round_resets or {}).ante}
    elseif kind=='win_game_returned' then
      local f=active.final
      local threshold=f and type(f.chips)=='number'and type(f.target)=='number'and f.target>0 and f.chips>=f.target
      local saved=f and active.saved and active.saved.round==f.round and active.saved.ante==f.ante
      if f and game_state.won==true and (threshold or saved)then
        active.terminal={kind='win',source='original_win_callback',threshold_met=not not threshold,
          source_saved=not not saved}
      end
    elseif kind=='game_over_returned' and not active.terminal then
      if g.STATES and g.STATE==g.STATES.GAME_OVER then
        active.terminal={kind='loss',source='GAME_OVER'}
      end
    end
  end
  local function finish_terminal(entry)
    local result=entry.terminal
    local okay,why=entry.journal:event('manual_terminal',{verified=true,kind=result.kind,
      source=result.source,threshold_met=result.threshold_met,source_saved=result.source_saved},{})
    if not okay then return fail(why)end
    entry.journal:end_collection('Verified '..result.kind..' recorded.')
    if entry.journal.error then return fail(entry.journal.error)end
    local closed,close_why=entry.archive:close();if not closed then return fail(close_why)end
    local committed,name=pcall(complete,fs,hash,entry.archive,result.kind)
    if not committed then return fail(name)end
    manager.completed[result.kind]=manager.completed[result.kind]+1
    finished_games[entry.game]=true
    active=nil
    local pruned,receipt=pcall(prune,fs,hash)
    if not pruned then return fail(receipt)end
    manager.status='Manual '..result.kind..' retained; '..receipt.removed_runs..' older completed runs pruned.'
    return true
  end
  function manager:update(g)
    g=g or game()
    if self.error then return end
    if active and not eligible(g)then finish_unknown('Manual run left or auto-run took ownership.')end
    if not eligible(g)then return end
    local journal=self:journal_for(g)
    if not journal then return end
    if active and not active.terminal and g.STATES and g.STATE==g.STATES.GAME_OVER then
      active.terminal={kind='loss',source='GAME_OVER'}
    end
    if active and active.terminal then return finish_terminal(active)end
    journal:update(g)
    if journal.error then return fail(journal.error)end
  end
  if B.AutoRun and B.AutoRun.subscribe_terminal_source then
    B.AutoRun:subscribe_terminal_source(function(kind,g)manager:on_source(kind,g)end)
  end
  A.manual_log=manager;B.ManualLog=manager
  return manager
end
return M
