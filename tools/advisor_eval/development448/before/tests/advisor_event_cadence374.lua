-- Manufactured manager/game doubles only. No Balatro source or captured state runs.
local Cadence = dofile('Brainstorm/Core/event_cadence.lua')
local checks = 0
local function check(value, label) checks = checks + 1; assert(value, label) end
local function near(a, b, label)
  check(type(a) == 'number' and math.abs(a - b) < 1e-9, label..': '..tostring(a)..' ~= '..tostring(b))
end
local function setup(speed, dt)
  local manager = {queues = {}, queue_dt = dt or 1/60, queue_timer = 2, queue_last_processed = 2}
  local game = {E_MANAGER = manager, SETTINGS = {GAMESPEED = speed, paused = false},
    STAGES = {RUN = 4}, STAGE = 4, marker = {unchanged = true}}
  return Cadence.new(), game, manager
end

for _, pair in ipairs({{64, 1/120}, {128, 1/120}, {256, 1/240}}) do
  local cadence, game, manager = setup(pair[1])
  local queues, marker = manager.queues, game.marker
  check(cadence:update(game), 'eligible speed requests faster cadence')
  near(manager.queue_dt, pair[2], 'requested interval')
  near(manager.queue_last_processed, manager.queue_timer, 'entry clock rebased to manager')
  check(manager.queues == queues and game.marker == marker and game.SETTINGS.GAMESPEED == pair[1],
    'queue/game data remains untouched')
  manager.queue_timer = manager.queue_timer + .018
  check(cadence:update(game), 'eligible mode remains enabled')
  near(manager.queue_last_processed, manager.queue_timer, 'scheduler debt capped')
  game.SETTINGS.GAMESPEED = 32
  check(not cadence:update(game), 'ordinary speed exits')
  near(manager.queue_dt, 1/60, 'ordinary speed restores native cadence')
  near(manager.queue_last_processed, manager.queue_timer, 'exit rebases clock')
end

do
  local cadence, game, manager = setup(128)
  check(cadence:update(game), '128x setup for live speed transition')
  manager.queue_timer = 3
  game.SETTINGS.GAMESPEED = 256
  check(cadence:update(game), '128x to 256x transition accepted')
  near(manager.queue_dt, 1/240, '256x interval follows selection')
  near(manager.queue_last_processed, 3, 'speed transition clears old cadence debt')
  game.SETTINGS.GAMESPEED = 128
  check(cadence:update(game), '256x to 128x transition accepted')
  near(manager.queue_dt, 1/120, '128x interval restored')
  game.SETTINGS.GAMESPEED = 32
  check(not cadence:update(game), 'transition sequence exits')
  near(manager.queue_dt, 1/60, 'transition sequence restores exact native interval')
end

for _, case in ipairs({
  {'pause', function(g) g.SETTINGS.paused = true end},
  {'overlay', function(g) g.OVERLAY_MENU = {} end},
  {'screenwipe', function(g) g.screenwipe = {} end},
  {'leave run', function(g) g.STAGE = 2 end},
  {'missing stage', function(g) g.STAGES = nil end},
  {'missing settings', function(g) g.SETTINGS = nil end},
}) do
  local cadence, game, manager = setup(256)
  check(cadence:update(game), case[1]..' setup enabled')
  manager.queue_timer = 2.1
  case[2](game)
  check(not cadence:update(game), case[1]..' disables')
  near(manager.queue_dt, 1/60, case[1]..' restores native interval')
  near(manager.queue_last_processed, 2.1, case[1]..' restores clock from manager')
end

do
  local cadence, game, original = setup(128)
  check(cadence:update(game), 'original manager enabled')
  original.queue_timer = 5
  local replacement = {queues = {}, queue_dt = 1/60, queue_timer = 9, queue_last_processed = 8}
  game.E_MANAGER = replacement
  check(cadence:update(game), 'new native manager enabled')
  near(original.queue_dt, 1/60, 'old manager restored on replacement')
  near(original.queue_last_processed, 5, 'old manager clock rebased')
  near(replacement.queue_dt, 1/120, 'replacement manager accelerated independently')
  near(replacement.queue_last_processed, 9, 'replacement clock rebased to itself')
  game.E_MANAGER = nil
  check(not cadence:update(game), 'missing replacement safely exits')
  near(replacement.queue_dt, 1/60, 'replacement restored on removal')
end

for _, unfamiliar in ipairs({1/75, 1/120, 0, -1, math.huge, 0/0}) do
  local cadence, game, manager = setup(256)
  manager.queue_dt = unfamiliar
  check(not cadence:update(game), 'unfamiliar manager refuses takeover')
  check(manager.queue_dt == unfamiliar or (unfamiliar ~= unfamiliar and manager.queue_dt ~= manager.queue_dt),
    'unfamiliar cadence preserved')
  game.SETTINGS.GAMESPEED = 64
  check(not cadence:update(game), 'unfamiliar manager remains unowned')
end

do
  local cadence, game, manager = setup(256)
  check(cadence:update(game), 'external ownership setup')
  manager.queue_dt = 1/100
  check(not cadence:update(game), 'external cadence change detected')
  near(manager.queue_dt, 1/100, 'external cadence not overwritten')
  game.SETTINGS.GAMESPEED = 64
  check(not cadence:update(game), 'external ownership survives exit')
  near(manager.queue_dt, 1/100, 'external cadence survives exit')
  manager.queue_dt = 1/60
  game.SETTINGS.GAMESPEED = 128
  check(not cadence:update(game), 'previously external manager not recaptured')
  near(manager.queue_dt, 1/60, 'former external manager remains untouched')
end
do
  local cadence, game, manager = setup(128)
  check(cadence:update(game), 'queue-shape change setup')
  manager.queue_timer = 7
  manager.queues = nil
  check(not cadence:update(game), 'invalid queue shape refuses next pass')
  near(manager.queue_dt, 1/60, 'invalid queue shape restores owned native cadence')
  near(manager.queue_last_processed, 7, 'invalid queue shape clears owed clock')
end

for _, invalid in ipairs({nil, {}, {E_MANAGER = {}}, {E_MANAGER = {queues = {}}}}) do
  local cadence = Cadence.new()
  check(not cadence:update(invalid), 'malformed game or manager refuses safely')
end
do
  local cadence, game, manager = setup(128)
  manager.queue_timer = 0/0
  check(not cadence:update(game), 'invalid manager clock blocks takeover')
  near(manager.queue_dt, 1/60, 'invalid clock keeps native cadence')
  manager.queue_timer = 2
  manager.queue_last_processed = math.huge
  check(not cadence:update(game), 'invalid last-pass clock blocks takeover')
  near(manager.queue_dt, 1/60, 'invalid last-pass clock keeps native cadence')
end

-- A minimal clock mimics only the documented one-pass cadence gate; no
-- callbacks, event ordering, original source or game state are executed.
local function count_passes(speed, fps, seconds)
  local cadence, game, manager = setup(speed)
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
for _, speed in ipairs({64, 128, 256}) do
  local target = speed == 256 and 240 or 120
  for _, fps in ipairs({60, 120, 240, 500}) do
    local count = count_passes(speed, fps, 3)
    local expected = math.min(target, fps)*3
    check(math.abs(count - expected) <= 3,
      'one-pass frame model bounded at '..speed..'x/'..fps..'fps: '..count..' vs '..expected)
  end
end
do
  local cadence, game, manager = setup(256)
  local passes = 0
  for _ = 1, 120 do
    cadence:update(game)
    manager.queue_timer = manager.queue_timer + 1/60
    if manager.queue_timer - manager.queue_last_processed >= manager.queue_dt - 1e-12 then
      manager.queue_last_processed = manager.queue_last_processed + manager.queue_dt
      passes = passes + 1
    end
  end
  check(passes == 120, 'low-FPS interval permits only one pass per frame')
  local before = passes
  for _ = 1, 500 do
    cadence:update(game)
    manager.queue_timer = manager.queue_timer + 1/500
    if manager.queue_timer - manager.queue_last_processed >= manager.queue_dt - 1e-12 then
      manager.queue_last_processed = manager.queue_last_processed + manager.queue_dt
      passes = passes + 1
    end
  end
  check(passes - before <= 242, 'low-FPS debt never creates later unbounded burst')
end
print('advisor_event_cadence374: '..checks..' checks passed')
