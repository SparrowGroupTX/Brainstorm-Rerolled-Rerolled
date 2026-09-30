-- Manufactured manager/game doubles; no game source or captured state runs.
local Cadence = dofile('Brainstorm/Core/event_cadence.lua')
local checks = 0
local function check(value, label) checks = checks + 1; assert(value, label) end
local function near(actual, expected, label)
  check(type(actual) == 'number' and math.abs(actual - expected) < 1e-9,
    label..': '..tostring(actual)..' ~= '..tostring(expected))
end
local function setup(speed)
  local manager = {queues = {base = {}}, queue_dt = 1/60,
    queue_timer = 4, queue_last_processed = 4}
  local game = {E_MANAGER = manager, SETTINGS = {GAMESPEED = speed, paused = false},
    STAGES = {RUN = 2}, STAGE = 2}
  return Cadence.new(), game, manager
end

do
  local cadence, game, manager = setup(64)
  local queues = manager.queues
  check(cadence:update(game), '64x unpaused RUN admitted')
  near(manager.queue_dt, 1/120, '64x requests 120 passes per second')
  check(manager.queues == queues, 'queue identity untouched')
  manager.queue_timer = 4.004
  manager.queue_last_processed = 4.002
  game.SETTINGS.GAMESPEED = 128
  check(cadence:update(game), '64 to 128 shares an owned interval')
  near(manager.queue_dt, 1/120, 'same target interval retained')
  near(manager.queue_last_processed, 4.002, 'same target does not spuriously rebase')
  game.SETTINGS.GAMESPEED = 256
  check(cadence:update(game), '64/128 to 256 admitted')
  near(manager.queue_dt, 1/240, '256 target preserved')
  near(manager.queue_last_processed, 4.004, 'changed target rebases')
  game.SETTINGS.GAMESPEED = 64
  check(cadence:update(game), '256 to 64 admitted')
  near(manager.queue_dt, 1/120, '64 target restored')
  near(manager.queue_last_processed, 4.004, 'changed target rebases back')
  game.SETTINGS.GAMESPEED = 32
  check(not cadence:update(game), 'ordinary speed exits')
  near(manager.queue_dt, 1/60, 'ordinary speed restores native interval')
end

for _, case in ipairs({
  {'pause', function(g) g.SETTINGS.paused = true end},
  {'overlay', function(g) g.OVERLAY_MENU = {} end},
  {'screenwipe', function(g) g.screenwipe = {} end},
  {'leave RUN', function(g) g.STAGE = 1 end},
}) do
  local cadence, game, manager = setup(64)
  check(cadence:update(game), case[1]..' initial entry')
  manager.queue_timer = 7
  case[2](game)
  check(not cadence:update(game), case[1]..' exits')
  near(manager.queue_dt, 1/60, case[1]..' native cadence restored')
  near(manager.queue_last_processed, 7, case[1]..' clock rebased')
end

do
  local cadence, game, manager = setup(64)
  manager.queue_dt = 1/100
  check(not cadence:update(game), 'foreign manager not seized at 64x')
  near(manager.queue_dt, 1/100, 'foreign interval retained')
  manager.queue_dt = 1/60
  check(not cadence:update(game), 'formerly foreign manager not recaptured')
  local replacement = {queues = {}, queue_dt = 1/60,
    queue_timer = 9, queue_last_processed = 8}
  game.E_MANAGER = replacement
  check(cadence:update(game), 'new native manager can be owned')
  near(replacement.queue_dt, 1/120, 'replacement at 64x accelerated')
  near(replacement.queue_last_processed, 9, 'replacement uses its own clock')
end

local function passes(fps, seconds)
  local cadence, game, manager = setup(64)
  local count = 0
  for _ = 1, fps*seconds do
    cadence:update(game)
    manager.queue_timer = manager.queue_timer + 1/fps
    if manager.queue_timer - manager.queue_last_processed >= manager.queue_dt - 1e-12 then
      manager.queue_last_processed = manager.queue_last_processed + manager.queue_dt
      count = count + 1
    end
  end
  return count
end
for _, fps in ipairs({60, 118, 120, 240, 500}) do
  local count = passes(fps, 3)
  local expected = math.min(120, fps)*3
  check(math.abs(count - expected) <= 3,
    '64x one-pass rate at '..fps..'fps: '..count..' vs '..expected)
end

do
  local cadence, game, manager = setup(64)
  check(cadence:update(game), 'debt setup')
  manager.queue_timer = manager.queue_timer + 0.04
  check(cadence:update(game), 'low-FPS update accepted')
  near(manager.queue_last_processed, manager.queue_timer, 'debt rebased before native pass')
  game.SETTINGS.GAMESPEED = 32
  check(not cadence:update(game), 'low-FPS exit accepted')
  near(manager.queue_dt, 1/60, 'low-FPS exit restores native')
end

print('advisor_event_cadence383: '..checks..' checks passed')
