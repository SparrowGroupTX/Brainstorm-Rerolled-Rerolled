from pathlib import Path
root=Path(__file__).resolve().parents[3]
draft=Path(__file__).parent/'drafts/copy_order'
for source,target in [(draft/'phase_copy.lua',root/'Brainstorm/Advisor/phase_copy.lua'),
 (draft/'advisor_phase_copy.lua',root/'tests/advisor_phase_copy.lua')]:
    assert not target.exists(),'Preserve existing work'
    data=source.read_text().replace('tools/advisor_eval/development299/drafts/copy_order/phase_copy.lua','Brainstorm/Advisor/phase_copy.lua')
    with target.open('x',encoding='utf-8') as stream:stream.write(data)
path=root/'Brainstorm/Advisor/runtime.lua';data=path.read_text();old="A.ordering = module('ordering')"
assert data.count(old)==1;path.write_text(data.replace(old,old+"\nA.phase_copy = module('phase_copy')"))
path=root/'Brainstorm/Advisor/decision.lua';data=path.read_text();old='  local result=run(snapshot,modules,yield_fn,options)'
assert data.count(old)==1
path.write_text(data.replace(old,old+"\n  if modules.phase_copy then\n    result=modules.phase_copy.apply(snapshot,modules,result,options and options.phase_copy)\n  end"))
print('Integrated phase-copy draft and fixture; no release freeze or installation.')
