-- At 64x and the two fastest menu speeds, let native event passes keep pace with
-- simulated time without running more than one pass per game update.
local M = {}
local NATIVE_DT = 1/60

local function finite(value)
  return type(value) == 'number' and value == value and value >= 0 and value < math.huge
end

local function target(g)
  if type(g) ~= 'table' or type(g.SETTINGS) ~= 'table' or type(g.STAGES) ~= 'table'
    or g.STAGES.RUN == nil or g.STAGE ~= g.STAGES.RUN or g.SETTINGS.paused ~= false
    or g.screenwipe or g.OVERLAY_MENU then return nil end
  local speed = g.SETTINGS.GAMESPEED
  if speed == 64 then return 1/120 end
  if speed == 128 then return 1/120 end
  if speed == 256 then return 1/240 end
end

function M.new()
  local state
  local api = {}

  local function rebase(manager)
    if finite(manager.queue_timer) then manager.queue_last_processed = manager.queue_timer end
  end

  local function release(current)
    local manager = current.manager
    if current.owned and manager.queue_dt == current.target then
      manager.queue_dt = current.base
      rebase(manager)
    end
    current.owned, current.target = false, nil
  end

  function api:update(g)
    local manager = type(g) == 'table' and g.E_MANAGER or nil
    if state and state.manager ~= manager then release(state); state = nil end
    if type(manager) ~= 'table' or type(manager.queues) ~= 'table' then
      if state and state.owned then release(state) end
      return false
    end
    if not state then
      state = {manager = manager, base = manager.queue_dt, foreign = manager.queue_dt ~= NATIVE_DT}
    end
    if state.foreign then return false end
    if state.owned then
      if manager.queue_dt ~= state.target then
        -- Another mod now owns this manager. Never overwrite its cadence.
        state.owned, state.foreign = false, true
        return false
      end
    elseif manager.queue_dt ~= state.base then
      state.foreign = true
      return false
    end

    local requested = target(g)
    if not requested then
      if state.owned then release(state) end
      return false
    end
    if not finite(manager.queue_timer) or not finite(manager.queue_last_processed) then
      if state.owned then release(state) end
      return false
    end
    if not state.owned or state.target ~= requested then
      manager.queue_dt = requested
      rebase(manager)
      state.owned, state.target = true, requested
    elseif manager.queue_last_processed > manager.queue_timer
      or manager.queue_timer - manager.queue_last_processed > requested then
      -- Native advances its last-pass clock by only queue_dt. At <target FPS,
      -- that creates unlimited debt; cap it before a later high-FPS period.
      rebase(manager)
    end
    return true
  end

  return api
end

return M
