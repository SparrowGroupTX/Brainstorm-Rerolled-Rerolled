"""Detached input/UI changes. Exact bases preserve all existing work."""
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
files={'Brainstorm.lua':'Brainstorm/Core/Brainstorm.lua','advisor.lua':'Brainstorm/UI/advisor.lua',
       'collection_run.lua':'Brainstorm/UI/collection_run.lua','runtime.lua':'Brainstorm/Advisor/runtime.lua',
       'checkpoint_runtime.lua':'Brainstorm/Core/checkpoint_runtime.lua'}


def replace(text,old,new,count=1):
    assert text.count(old)==count,(old,text.count(old))
    return text.replace(old,new)


for name,path in files.items():
    saved=HERE/(name[:-4]+'.base.lua')
    if not saved.exists():saved.write_bytes((ROOT/path).read_bytes())
    text=saved.read_text(encoding='utf-8')
    if name=='Brainstorm.lua':
        for reason in ('Keyboard input.','Mouse input.'):
            old="if Brainstorm.CollectionSearchProduct then Brainstorm.CollectionSearchProduct.stop('"+reason+"') end"
            new="if Brainstorm.CollectionSearchProduct and not (Brainstorm.AutoRun and Brainstorm.AutoRun.engaged and Brainstorm.AutoRun:engaged()) then Brainstorm.CollectionSearchProduct.stop('"+reason+"') end"
            text=replace(text,old,new)
        text=replace(text,"            Brainstorm.ar_hotkey_down = true\n            if Brainstorm.native_search_busy then",
            "            Brainstorm.ar_hotkey_down = true\n            -- An engaged auto session owns its search; this hotkey cannot\n            -- cancel it, renew its budget or start an overlapping reroll.\n            if Brainstorm.AutoRun and Brainstorm.AutoRun.engaged and Brainstorm.AutoRun:engaged() then return end\n            if Brainstorm.native_search_busy then")
        text=replace(text,'-- Actual player input interrupts an explicitly armed run before its callback.',
            '-- Actual input invalidates auto action context without stopping its session.')
    elif name=='runtime.lua':
        text=replace(text,"  if Brainstorm.CollectionSearchProduct and not (Brainstorm.AutoRun and Brainstorm.AutoRun:owned()) then",
            "  if Brainstorm.CollectionSearchProduct and not (Brainstorm.AutoRun and\n    (Brainstorm.AutoRun:owned() or Brainstorm.AutoRun.engaged and Brainstorm.AutoRun:engaged())) then")
    elif name=='checkpoint_runtime.lua':
        for action in ('save','load'):
            text=replace(text,"    if B.CollectionSearchProduct then B.CollectionSearchProduct.stop('Checkpoint "+action+" requested.') end",
                "    if B.CollectionSearchProduct and not (B.AutoRun and B.AutoRun.engaged and B.AutoRun:engaged()) then B.CollectionSearchProduct.stop('Checkpoint "+action+" requested.') end")
        text=replace(text,"    if B.AutoRun and B.AutoRun.stop then B.AutoRun:stop('Checkpoint load requested.') end\n",'')
        text=replace(text,"        if B.Advisor and B.Advisor.settings_changed then B.Advisor.settings_changed() end\n        alert(self.status);log('checkpoint_loaded'",
            "        if B.Advisor and B.Advisor.settings_changed then B.Advisor.settings_changed() end\n        if B.AutoRun and B.AutoRun.manual then B.AutoRun:manual('Checkpoint loaded.','checkpoint_loaded') end\n        alert(self.status);log('checkpoint_loaded'")
    elif name=='collection_run.lua':
        text=replace(text,"  if B.AutoRun then B.AutoRun:stop('Search options changed.') end\n  if B.CollectionSearchProduct then B.CollectionSearchProduct.stop('Search options changed.') end",
            "  -- These controls configure a future explicit start; the active\n  -- session keeps its copied request and original limits.\n  if B.CollectionSearchProduct and not (B.AutoRun and B.AutoRun.engaged and B.AutoRun:engaged()) then\n    B.CollectionSearchProduct.stop('Search options changed.')\n  end")
        text=replace(text,"  if not B.CollectionSearchProduct then quiet.failure='Bounded search is unavailable.';request_failure('manual',quiet.failure);refresh();return end",
            "  if B.AutoRun and B.AutoRun.engaged and B.AutoRun:engaged() then\n    quiet.failure='An auto-run session already owns this run. Use Resume to continue it.'\n    request_failure('manual',quiet.failure);refresh();return\n  end\n  if not B.CollectionSearchProduct then quiet.failure='Bounded search is unavailable.';request_failure('manual',quiet.failure);refresh();return end")
        text=replace(text,"  quiet.text=ok and 'Auto-run started. Any manual input stops it.' or tostring(reason or 'Auto-run could not start.')",
            "  quiet.text=ok and 'Auto-run started. Use Stop to pause; ordinary input keeps the session.' or tostring(reason or 'Auto-run could not start.')")
        text=replace(text,"G.FUNCS.brainstorm_collection_stop=function()",
            "G.FUNCS.brainstorm_collection_resume=function()\n  quiet.owner='auto';quiet.failure=nil\n  if not B.AutoRun or type(B.AutoRun.resume)~='function' then\n    quiet.failure='Resume is unavailable.';request_failure('auto',quiet.failure);refresh();return\n  end\n  local ok,reason=B.AutoRun:resume()\n  quiet.text=ok and 'Resuming the existing run and session.' or tostring(reason or 'This session cannot resume.')\n  if not ok then quiet.failure=quiet.text;request_failure('auto',quiet.failure);refresh()end\nend\nG.FUNCS.brainstorm_collection_stop=function()")
        text=replace(text,"  if B.AutoRun then B.AutoRun:stop('Stopped by the user.') end\n  if B.CollectionSearchProduct then B.CollectionSearchProduct.stop('Stopped by the user.') end",
            "  local engaged=B.AutoRun and B.AutoRun.engaged and B.AutoRun:engaged()\n  if B.AutoRun then B.AutoRun:stop('Stopped by the user.') end\n  if B.CollectionSearchProduct and not engaged then B.CollectionSearchProduct.stop('Stopped by the user.') end")
        text=replace(text,"    row('Starting a searched run replaces the current run.',G.C.ORANGE,.26)}",
            "    row('Start searches a new run. Resume keeps the current run.',G.C.ORANGE,.24)}")
        text=replace(text,"  nodes[#nodes+1]={n=G.UIT.R,config={align='cm',padding=.02},nodes={\n    button('Stop','brainstorm_collection_stop',3.4),button('Full status','brainstorm_search_status_open',3.4)}}",
            "  local session_controls={}\n  if B.AutoRun then session_controls[#session_controls+1]=button('Resume','brainstorm_collection_resume',2.2) end\n  session_controls[#session_controls+1]=button('Stop','brainstorm_collection_stop',B.AutoRun and 2.2 or 3.4)\n  session_controls[#session_controls+1]=button('Full status','brainstorm_search_status_open',B.AutoRun and 2.2 or 3.4)\n  nodes[#nodes+1]={n=G.UIT.R,config={align='cm',padding=.02},nodes=session_controls}")
    elif name=='advisor.lua':
        text=replace(text,"  return {requested=value.requested==true,busy=value.busy==true,owner=owner,",
            "  return {requested=value.requested==true,busy=value.busy==true,owner=owner,\n    resume_available=value.resume_available==true,resume_pending=value.resume_pending==true,")
        text=replace(text,"  local active=auto and auto.busy and auto or manual and manual.busy and manual",
            "  local active=auto and (auto.busy or auto.resume_available or auto.resume_pending) and auto or manual and manual.busy and manual")
        text=replace(text,"  A.hud_bounds,A.execute_bounds,A.hud_action_key,A.hud_auto_stop,A.hud_search_stop,A.hud_status_only=nil,nil,nil,nil,nil,nil",
            "  A.hud_bounds,A.execute_bounds,A.hud_action_key,A.hud_auto_stop,A.hud_search_stop,A.hud_status_only,A.hud_auto_resume=nil,nil,nil,nil,nil,nil,nil")
        text=replace(text,"  A.hud_auto_stop=diagnostic and diagnostic.busy and diagnostic.owner=='auto' or false",
            "  A.hud_auto_resume=diagnostic and diagnostic.owner=='auto' and diagnostic.resume_available and not diagnostic.busy and not diagnostic.resume_pending or false\n  A.hud_auto_stop=diagnostic and diagnostic.owner=='auto' and (diagnostic.busy or diagnostic.resume_pending) or false")
        text=replace(text,"  local heading=(A.hud_auto_stop and 'AUTO-RUN' or diagnostic and 'SEARCH' or 'ADVISOR')..' / '..version()",
            "  local heading=(diagnostic and diagnostic.owner=='auto' and 'AUTO-RUN' or diagnostic and 'SEARCH' or 'ADVISOR')..' / '..version()")
        text=replace(text,"  local stop=A.hud_auto_stop or A.hud_search_stop\n  local execute_ready=stop or not diagnostic and A.can_execute and A.can_execute()",
            "  local stop=A.hud_auto_stop or A.hud_search_stop\n  local resume=A.hud_auto_resume\n  local execute_ready=stop or resume or not diagnostic and A.can_execute and A.can_execute()")
        text=replace(text,"  graphics.printf(stop and 'STOP' or diagnostic and 'STATUS' or execute_ready and 'EXECUTE' or 'WAIT',",
            "  graphics.printf(stop and 'STOP' or resume and 'RESUME' or diagnostic and 'STATUS' or execute_ready and 'EXECUTE' or 'WAIT',")
        text=replace(text,"  graphics.printf(stop and (A.hud_search_stop and 'Cancel search' or 'Keep this run') or\n    diagnostic and 'Click details' or execute_ready and 'One action' or 'Fresh advice',",
            "  graphics.printf(stop and (A.hud_search_stop and 'Cancel search' or 'Keep this run') or\n    resume and 'Same session' or diagnostic and 'Click details' or execute_ready and 'One action' or 'Fresh advice',")
        text=replace(text,"        if Brainstorm.AutoRun then Brainstorm.AutoRun:manual('HUD Stop clicked.') end",
            "        if Brainstorm.AutoRun then Brainstorm.AutoRun:stop('HUD Stop clicked.') end")
        text=replace(text,"        if Brainstorm.CollectionSearchProduct then Brainstorm.CollectionSearchProduct.stop('HUD Search Stop clicked.') end",
            "        if Brainstorm.CollectionSearchProduct and not (Brainstorm.AutoRun and Brainstorm.AutoRun.engaged and Brainstorm.AutoRun:engaged()) then\n          Brainstorm.CollectionSearchProduct.stop('HUD Search Stop clicked.')\n        end")
        text=replace(text,"      if advisor.hud_status_only then advisor.open_search_status();return end",
            "      if advisor.hud_auto_resume then\n        if Brainstorm.AutoRun and type(Brainstorm.AutoRun.resume)=='function' then\n          local ok,reason=Brainstorm.AutoRun:resume()\n          if not ok then advisor.note_search_notice('auto',reason or 'This session cannot resume.') end\n        end\n        return\n      end\n      if advisor.hud_status_only then advisor.open_search_status();return end")
    (HERE/name).write_text(text,encoding='utf-8')
print('Five detached runtime/UI candidates written; root files unchanged.')
