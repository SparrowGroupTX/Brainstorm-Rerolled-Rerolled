"""Detached M13-grounded startup fix. No source/native execution or installs."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
HELPER = '''-- Original boot_timer retains G.LOADING={font=Font} after startup.
-- It is display cache, not active loading. Unknown shapes and true still block.
local function loading_pending(value)
  if value==nil or value==false then return false end
  if type(value)~='table' or getmetatable(value)~=nil then return true end
  local font=rawget(value,'font')
  if type(font)~='userdata' and type(font)~='table' then return true end
  for key in next,value do if key~='font' then return true end end
  return false
end
'''


def change(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new, 1)


def main():
    names = ('Brainstorm/Core/collection_search_product.lua', 'Brainstorm/Core/auto_run_product.lua',
             'tests/advisor_collection_product.lua', 'tests/advisor_auto_run_product.lua')
    before = {}
    for name in names:
        path = ROOT/name; before[name] = hashlib.sha256(path.read_bytes()).hexdigest()
        text = path.read_text(encoding='utf-8')
        if name == names[0]:
            text = change(text, 'local M={}\n', 'local M={}\n'+HELPER)
            text = change(text, '      g.SAVING or g.LOADING then return nil,\'A save or checkpoint operation is pending.\' end',
                "      g.SAVING then return nil,'Save/checkpoint pending.' end\n    if loading_pending(g.LOADING)then return nil,'Game loading is active.' end")
            text = change(text, "        if why then api.status=why end", "        if why then api.status=why end")
            text = change(text, "      local allowed=safe(game())\n      if allowed", "      local allowed,why=safe(game())\n      if not allowed then api.status='Waiting: '..tostring(why) end\n      if allowed")
        elif name == names[1]:
            text = change(text, 'local M={}\n', 'local M={}\n'+HELPER)
            old = '''  local function busy(g,ignore_overlay)
    if not g or not g.GAME or not g.STATE_COMPLETE or g.screenwipe or (g.GAME.STOP_USE or 0)>0 then return true end
    if not ignore_overlay and (g.OVERLAY_MENU or (g.SETTINGS or {}).paused)then return true end
    local c=g.CONTROLLER or {}
    if c.locked or c.text_input_hook or c.dragging and c.dragging.target then return true end
    for _,v in pairs(c.locks or {})do if v then return true end end
    if g.play and g.play.cards and #g.play.cards>0 then return true end
    if B.Checkpoints and (B.Checkpoints.pending or B.Checkpoints.saving) or B.save_pending or B.checkpoint_busy or g.SAVING or g.LOADING then return true end
    return false
  end'''
            new = '''  local function busy(g,ignore_overlay)
    if not g or not g.GAME then return true,'Game unavailable.' end
    if not g.STATE_COMPLETE then return true,'Game transition incomplete.' end
    if g.screenwipe then return true,'Screen transition active.' end
    if (g.GAME.STOP_USE or 0)>0 then return true,'Card action pending.' end
    if not ignore_overlay and g.OVERLAY_MENU then return true,'Menu is still open.' end
    if not ignore_overlay and (g.SETTINGS or {}).paused then return true,'Game is paused.' end
    local c=g.CONTROLLER or {}
    if c.locked then return true,'Controls are settling.' end
    if c.text_input_hook then return true,'Finish text entry.' end
    if c.dragging and c.dragging.target then return true,'Release the dragged card.' end
    for _,v in pairs(c.locks or {})do if v then return true,'Input lock is active.' end end
    if g.play and g.play.cards and #g.play.cards>0 then return true,'Played cards are settling.' end
    if B.Checkpoints and (B.Checkpoints.pending or B.Checkpoints.saving) or B.save_pending or B.checkpoint_busy or g.SAVING then return true,'Save/checkpoint pending.' end
    if loading_pending(g.LOADING)then return true,'Game loading is active.' end
    return false
  end'''
            text = change(text, old, new)
            text = change(text, "if pending then state.state='arming';state.busy=true;state.reason='Waiting for the menu to close.'end",
                "if pending then state.state='arming';state.busy=true;state.reason=pending.reason or 'Menu is closing.'end")
            text = change(text, "pending and 'Auto-run is waiting for the menu to close.' or",
                "pending and ('Waiting: '..tostring(pending.reason or 'Menu is closing.')) or")
            text = change(text, "      if not g.OVERLAY_MENU and not (g.SETTINGS or {}).paused and not busy(g,false)then",
                "      local blocked,reason=busy(g,false);pending.reason=reason\n      if not blocked then")
        elif name == names[2]:
            text = change(text, "local path='Brainstorm/Core/'", "local path='tools/advisor_eval/development300/startup_loading_fix/Brainstorm/Core/'")
        elif name == names[3]:
            text = change(text, "dofile('Brainstorm/Core/auto_run_product.lua')", "dofile('tools/advisor_eval/development300/startup_loading_fix/Brainstorm/Core/auto_run_product.lua')")
        out = HERE/name; out.parent.mkdir(parents=True, exist_ok=True)
        with out.open('x', encoding='utf-8', newline='\n') as stream:
            stream.write(text)
    with (HERE/'original_hashes.json').open('x', encoding='utf-8') as stream:
        json.dump(before, stream, indent=2); stream.write('\n')
    print('Prepared detached persistent boot-cache fix; no runtime staging or source execution.')


if __name__ == '__main__':
    main()
