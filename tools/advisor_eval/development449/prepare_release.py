from pathlib import Path
H=Path(__file__).resolve().parent;E=H.parent
s=(E/'development448/freeze.py').read_text().replace('expired Riff-raff repair','Idol product-floor repair')
s=s.replace('len(tests)==380','len(tests)==381').replace('advisor_expired_riff448.lua','advisor_idol_product449.lua')
s=s.replace('repair448_candidate1','repair449_candidate1').replace('2.223.0-alpha','2.224.0-alpha')
with(H/'freeze.py').open('x')as f:f.write(s)
I=H/'install';I.mkdir(exist_ok=False)
s=(E/'development446/install/release.py').read_text()
s=s.replace('repair446_candidate2','repair449_candidate1').replace('repair446_installed','repair449_installed')
s=s.replace('development446/install/LATEST.json','development449/LATEST.json').replace('INSTALLED_CHECKPOINT_444','INSTALLED_CHECKPOINT_446')
start=s.index("    repair = read(HERE.parent / 'repair_prework.json')")
end=s.index("    for rel, h in read(HERE.parent / 'FINAL_VERIFICATION.json')",start)
s=s[:start]+s[end:]
s=s.replace('changed_from_installed444','changed_from_installed446').replace('len(delta) == 8','len(delta) == 4')
s=s.replace("== 378","== 381").replace('2.221.0-alpha','2.224.0-alpha')
s=s.replace('already validated combined 446 candidate','already validated combined 449 candidate')
s=s.replace('User: Copy the full 10-run session now and install the new update; standing passive-absence authorization.',
 'Standing user authorization: install whenever ready after passive absence; current full session preserved, no normal-exit inference.')
with(I/'release.py').open('x')as f:f.write(s)
