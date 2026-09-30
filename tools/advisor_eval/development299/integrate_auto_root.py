"""One-use root hooks for the explicit product controller; never starts it."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
def edit(name,replacements):
    p=ROOT/name;s=p.read_text(encoding='utf-8')
    for old,new in replacements:
        assert s.count(old)==1,(name,old[:80]);s=s.replace(old,new)
    p.write_text(s,encoding='utf-8',newline='\n')
edit('Brainstorm/Core/Brainstorm.lua',[
 ('  assert(load(nfs.read(Brainstorm.PATH .. "/UI/advisor.lua")))()',
 '''  local auto_controller=assert(load(nfs.read(Brainstorm.PATH .. "/Advisor/auto_run.lua")))()
  local auto_terminal=assert(load(nfs.read(Brainstorm.PATH .. "/Core/auto_terminal.lua")))()
  local auto_product=assert(load(nfs.read(Brainstorm.PATH .. "/Core/auto_run_product.lua")))()
  auto_product.attach(Brainstorm,{controller=auto_controller,terminal=auto_terminal})
  assert(load(nfs.read(Brainstorm.PATH .. "/UI/advisor.lua")))()''')])
edit('Brainstorm/Advisor/runtime.lua',[
 ('function A.settings_changed()\n','''function A.settings_changed()
  if Brainstorm.AutoRun then Brainstorm.AutoRun:manual('Advisor settings changed.','settings') end
  if Brainstorm.CollectionSearchProduct and not (Brainstorm.AutoRun and Brainstorm.AutoRun:owned()) then
    Brainstorm.CollectionSearchProduct.stop('Advisor settings changed.')
  end
'''),
 ('function A.execute(shown_key,shown_generation)\n','''function A.execute(shown_key,shown_generation)
  if Brainstorm.AutoRun then Brainstorm.AutoRun:manual('Manual Execute requested.') end
'''),
 ('local function retry_mutation(method,token)\n','''local function retry_mutation(method,token)
  if Brainstorm.AutoRun then Brainstorm.AutoRun:manual('Manual checkpoint advice changed.','checkpoint') end
''')])
edit('Brainstorm/Core/checkpoint_runtime.lua',[
 ('  function R:save(slot)\n','''  function R:save(slot)
    if B.AutoRun and B.AutoRun.manual then B.AutoRun:manual('Checkpoint save requested.','checkpoint') end
    if B.CollectionSearchProduct then B.CollectionSearchProduct.stop('Checkpoint save requested.') end
'''),
 ('  function R:load(slot)\n','''  function R:load(slot)
    if B.AutoRun and B.AutoRun.manual then B.AutoRun:manual('Checkpoint load requested.','checkpoint') end
    if B.CollectionSearchProduct then B.CollectionSearchProduct.stop('Checkpoint load requested.') end
''')])
edit('Brainstorm/UI/ui.lua',[
 ('  "Quick Gold run",','  "Gold auto-run",'),
 ("if label=='Quick Gold run' then","if label=='Gold auto-run' then")])
print('Explicit auto-run hooks written; no activation or configuration write.')
