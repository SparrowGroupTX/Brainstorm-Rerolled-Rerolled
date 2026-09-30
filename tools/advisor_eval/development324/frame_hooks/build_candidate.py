"""Prepare detached frame timing hooks from exact preserved current bases."""
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def base(name, relative):
    path = HERE / name
    if not path.exists():
        path.write_bytes((ROOT / relative).read_bytes())
    return path.read_text(encoding='utf-8')


core = base('Brainstorm.base.lua', 'Brainstorm/Core/Brainstorm.lua')
old = '''function Game:update(dt)
  update_ref(self, dt)
  if Brainstorm.Checkpoints then Brainstorm.Checkpoints:update(dt) end
  if Brainstorm.CollectionSearchProduct then Brainstorm.CollectionSearchProduct.update() end
  if Brainstorm.Advisor and Brainstorm.Advisor.player_log then
    Brainstorm.Advisor.player_log:install_hooks(G)
    Brainstorm.Advisor.player_log:update(G)
  end
'''
new = '''function Game:update(dt)
  local P=Brainstorm.Advisor and Brainstorm.Advisor.performance
  local frame_start,gap
  if P then frame_start,gap=P:begin_frame(dt) end
  local mark=frame_start
  update_ref(self, dt)
  if mark then mark=P:finish('game_update',mark) end
  if Brainstorm.Checkpoints then Brainstorm.Checkpoints:update(dt) end
  if mark then mark=P:finish('checkpoint_update',mark) end
  if Brainstorm.CollectionSearchProduct then Brainstorm.CollectionSearchProduct.update() end
  if mark then mark=P:finish('search_update',mark) end
  if Brainstorm.Advisor and Brainstorm.Advisor.player_log then
    Brainstorm.Advisor.player_log:install_hooks(G)
    Brainstorm.Advisor.player_log:update(G)
  end
  if mark then mark=P:finish('journal_update',mark) end
'''
assert core.count(old) == 1
core = core.replace(old,new)
old = '''  if Brainstorm.AutoRun then Brainstorm.AutoRun:update(dt) end

  if Brainstorm.ar_active then'''
new = '''  if mark then mark=P:finish('advisor_update',mark) end
  local auto_status
  if Brainstorm.AutoRun then auto_status=Brainstorm.AutoRun:update(dt) end
  if mark then mark=P:finish('auto_update',mark) end

  if Brainstorm.ar_active then'''
assert core.count(old) == 1
core = core.replace(old,new)
old = '''  end
end

function Brainstorm.autoReroll()'''
new = '''  end
  if mark then P:finish('legacy_reroll',mark) end
  if frame_start then
    -- Only scalar public flags: no snapshot, status callback or identity copy.
    local g=G or {};local game=g.GAME or {};local settings=g.SETTINGS or {}
    local controller=g.CONTROLLER or {};local advisor=Brainstorm.Advisor
    local flags={paused=settings.paused==true,
      dragging=not not (controller.dragging and controller.dragging.target),
      advisor_worker=not not (advisor and advisor.worker)}
    local function number(key,value)
      if type(value)=='number' and value==value and value~=math.huge and value~=-math.huge then flags[key]=value end
    end
    number('state',g.STATE);number('stage',g.STAGE)
    number('ante',(game.round_resets or {}).ante);number('round',game.round)
    number('game_speed',settings.GAMESPEED)
    if type(auto_status)=='table' and type(auto_status.active)=='boolean' then flags.auto_active=auto_status.active end
    -- update_total excludes the trailing bounded emission; performance_emit
    -- is recorded separately by the collector for the following window.
    P:end_frame(frame_start,gap,flags)
    P:flush(advisor and advisor.player_log,flags)
  end
end

function Brainstorm.autoReroll()'''
assert core.count(old) == 1
core = core.replace(old,new)
(HERE / 'Brainstorm.lua').write_text(core,encoding='utf-8')

ui = base('advisor.base.lua','Brainstorm/UI/advisor.lua')
old = '''  function Game:draw(...)
    draw(self, ...)
    if Brainstorm.Advisor then Brainstorm.Advisor.draw() end
  end'''
new = '''  function Game:draw(...)
    local P=Brainstorm.Advisor and Brainstorm.Advisor.performance
    local started=P and P:now()
    local mark=started
    draw(self, ...)
    if mark then mark=P:finish('original_draw',mark) end
    if Brainstorm.Advisor then Brainstorm.Advisor.draw() end
    if mark then P:finish('advisor_hud_draw',mark) end
    if started then P:finish('draw_total',started) end
  end'''
assert ui.count(old) == 1
ui = ui.replace(old,new)
(HERE / 'advisor.lua').write_text(ui,encoding='utf-8')
print('Detached Core and UI hooks written; root sources untouched.')
