-- User hotkeys only. No search, automatic checkpoint restore, profile history,
-- or retry-journal mutation. A receipt verifies disk bytes, not future survival.
local M={}
local function identity(g,version)
  local game=g.GAME or {};local back=game.selected_back and game.selected_back.effect and game.selected_back.effect.center or {}
  return {profile=tostring((g.SETTINGS or {}).profile or ''),seed=tostring((game.pseudorandom or {}).seed or ''),
    round=game.round or 0,ante=(game.round_resets or {}).ante or 1,state=g.STATE,
    deck=back.key or '',stake=game.stake or 1,version=version or '',saved_at=os.date('!%Y-%m-%dT%H:%M:%SZ')}
end
local function valid_save(value)
  return type(value)=='table' and type(value.GAME)=='table' and type(value.cardAreas)=='table' and
    type(value.STATE)=='number' and type(value.BLIND)=='table' and type(value.BACK)=='table'
end
local function settled(g)
  if not g or not g.GAME or not g.STAGES or g.STAGE~=g.STAGES.RUN or not g.STATE_COMPLETE or
    g.screenwipe or g.OVERLAY_MENU or (g.SETTINGS or {}).paused or (g.GAME.STOP_USE or 0)>0 then return false end
  local controller=g.CONTROLLER or {}
  if controller.text_input_hook or controller.locked or controller.dragging and controller.dragging.target then return false end
  for _,locked in pairs(controller.locks or {}) do if locked then return false end end
  if g.play and g.play.cards and #g.play.cards>0 then return false end
  for _,name in ipairs({'SELECTING_HAND','SHOP','BLIND_SELECT','ROUND_EVAL'}) do
    if g.STATES and g.STATES[name] and g.STATE==g.STATES[name] then return true end
  end
  return false
end
function M.attach(B,deps)
  local R={down={}};B.Checkpoints=R
  local fs=deps.fs or love.filesystem
  local function alert(text) if deps.alert then deps.alert(text) end end
  local function log(kind,details)
    if B.Advisor and B.Advisor.player_log then B.Advisor.player_log:event(kind,details) end
  end
  local function failed(kind,slot,reason)
    R.status=tostring(reason);alert('Slot ['..slot..'] '..kind..' failed: '..R.status)
    log('checkpoint_'..kind..'_failed',{slot=slot,reason=R.status});return false,R.status
  end
  local store=deps.store.new({
    read=function(path,limit)
      local info=fs.getInfo(path);if not info then return nil,'missing' end
      if info.type~='file' or not info.size or info.size>limit then return nil,'Invalid or oversized checkpoint file.' end
      return fs.read(path)
    end,write=function(path,bytes)return fs.write(path,bytes) end},deps.codec,deps.hash)
  local function paths(g,slot)
    local profile=tostring((g.SETTINGS or {}).profile or '')
    if not profile:match('^%d+$') or not tostring(slot):match('^[1-5]$') then return nil,'Invalid profile or slot.' end
    return profile..'/saveState'..slot..'.brainstorm-v2',profile..'/saveState'..slot..'.jkr'
  end
  function R:save(slot)
    if B.AutoRun and B.AutoRun.manual then B.AutoRun:manual('Checkpoint save requested.','checkpoint') end
    if B.CollectionSearchProduct then B.CollectionSearchProduct.stop('Checkpoint save requested.') end
    local g=deps.game and deps.game() or G
    if B.ar_active or self.pending or not settled(g) then return failed('save',slot,'Wait for a settled hand, shop, blind selection or cash-out screen.') end
    local prefix,why=paths(g,slot);if not prefix then return failed('save',slot,why) end
    local ok,result,meta=pcall(function()
      g.ARGS=g.ARGS or {};local old=g.ARGS.save_run;g.ARGS.save_run=nil
      local refreshed,err=pcall(deps.refresh or save_run)
      local fresh=g.ARGS.save_run
      if not refreshed or not valid_save(fresh) or fresh==old or fresh.GAME.round~=g.GAME.round or fresh.STATE~=g.STATE or
        tostring((fresh.GAME.pseudorandom or {}).seed or '')~=tostring((g.GAME.pseudorandom or {}).seed or '') then
        g.ARGS.save_run=old;error(err or 'The current state could not be freshly serialized.')
      end
      local packed=(deps.pack or STR_PACK)(fresh)
      local bytes=deps.compress(packed)
      return store:save(prefix,bytes,identity(g,B.VERSION))
    end)
    if not ok or not result then return failed('save',slot,ok and meta or result) end
    self.status='Saved and verified slot ['..slot..'] at Ante '..result.identity.ante..', round '..result.identity.round..'.'
    alert(self.status);log('checkpoint_saved',{slot=slot,receipt=result});return true,result
  end
  function R:load(slot)
    if B.AutoRun and B.AutoRun.manual then B.AutoRun:manual('Checkpoint load requested.','checkpoint') end
    if B.CollectionSearchProduct then B.CollectionSearchProduct.stop('Checkpoint load requested.') end
    local g=deps.game and deps.game() or G
    if self.pending then return failed('load',slot,'A checkpoint is already loading.') end
    if B.ar_active or g.STAGES and g.STAGE==g.STAGES.RUN and not settled(g) then
      return failed('load',slot,'Wait for the current game action to settle before loading.')
    end
    if B.AutoRun and B.AutoRun.stop then B.AutoRun:stop('Checkpoint load requested.') end
    local prefix,legacy=paths(g,slot);if not prefix then return failed('load',slot,legacy) end
    local ok,value,receipt=pcall(function()
      local bytes,meta=store:load(prefix)
      if not bytes then
        if meta~='missing' then error(meta) end
        local info=fs.getInfo(legacy)
        if not info or info.type~='file' or not info.size or info.size>deps.store.MAX_BYTES then error('No readable checkpoint exists in this slot.') end
        bytes=assert(fs.read(legacy));meta={legacy=true,identity={profile=tostring(g.SETTINGS.profile)}}
      end
      local packed=bytes:sub(1,6)=='return' and bytes or deps.decompress(bytes)
      local saved=(deps.unpack or STR_UNPACK)(packed)
      if not valid_save(saved) then error('The slot does not contain a valid run.') end
      if not meta.legacy then
        local id=meta.identity
        if id.profile~=tostring(g.SETTINGS.profile) or id.state~=saved.STATE or id.round~=(saved.GAME.round or 0) or
          id.ante~=((saved.GAME.round_resets or {}).ante or 1) or id.seed~=tostring((saved.GAME.pseudorandom or {}).seed or '') then
          error('Checkpoint identity disagrees with its receipt.')
        end
      end
      return saved,meta
    end)
    if not ok then return failed('load',slot,value) end
    log('checkpoint_load_requested',{slot=slot,receipt=receipt})
    -- Decode and verify before deleting the current run. The source start_run
    -- schedules restoration events; successful request is not loaded success.
    local started,err=pcall(function()
      g:delete_run();g.SAVED_GAME=value;g:start_run({savetext=value})
    end)
    if not started then return failed('load',slot,err) end
    self.pending={slot=slot,receipt=receipt,seed=tostring((value.GAME.pseudorandom or {}).seed or ''),
      round=value.GAME.round or 0,ante=(value.GAME.round_resets or {}).ante or 1,state=value.STATE,elapsed=0}
    self.status='Loading slot ['..slot..']; waiting for the restored state.';alert(self.status);return true
  end
  function R:update(dt)
    local g=deps.game and deps.game() or G
    if deps.is_down then for key in pairs(self.down) do if not deps.is_down(key) then self.down[key]=nil end end end
    local p=self.pending;if not p then return end;p.elapsed=p.elapsed+(dt or 0)
    if settled(g) then
      local id=identity(g,B.VERSION)
      if id.seed==p.seed and id.round==p.round and id.ante==p.ante and id.state==p.state then
        self.pending=nil;self.status='Loaded slot ['..p.slot..'] at Ante '..id.ante..', round '..id.round..
          (p.receipt.legacy and ' (legacy slot; original save time unknown).' or ' (saved '..tostring(p.receipt.identity.saved_at)..').')
        if B.Advisor and B.Advisor.settings_changed then B.Advisor.settings_changed() end
        alert(self.status);log('checkpoint_loaded',{slot=p.slot,receipt=p.receipt,observed=id});return
      end
    end
    if p.elapsed>=15 then self.pending=nil;failed('load',p.slot,'Restoration was requested but its completion could not be verified.') end
  end
  function R:hotkey(key,save_down,load_down,text_input)
    if not tostring(key):match('^[1-5]$') or text_input or not (save_down or load_down) then return false end
    if self.down[key] then return true end;self.down[key]=true
    if save_down and load_down then alert('Use one checkpoint modifier at a time.');return true end
    if save_down then self:save(key) else self:load(key) end;return true
  end
  return R
end
M.settled=settled
return M
