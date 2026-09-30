from pathlib import Path
H=Path(__file__).resolve().parent;E=H.parent;R=E.parents[1]
for rel in ('Brainstorm/Core/Brainstorm.lua','Brainstorm/steamodded_compat.lua'):
 p=R/rel;old=p.read_bytes();assert old.count(b'2.224.0-alpha')==1
 p.write_bytes(old.replace(b'2.224.0-alpha',b'2.225.0-alpha'))
s=(E/'development449/freeze2.py').read_text()
s=s.replace('Idol product-floor repair','held-Steel shortlist repair').replace('installed446','installed449')
s=s.replace("'Brainstorm/Advisor/shop_scoring.lua',",'').replace('len(tests)==381','len(tests)==382')
s=s.replace('advisor_idol_product449.lua','advisor_steel_shortlist450.lua')
s=s.replace('repair449_candidate2','repair450_candidate1').replace('2.224.0-alpha','2.225.0-alpha')
s=s.replace("'baseline_installed_checkpoint':446","'baseline_installed_checkpoint':449")
with(H/'freeze.py').open('x')as f:f.write(s)
I=H/'install';I.mkdir(exist_ok=False)
s=(E/'development449/install/release.py').read_text()
s=s.replace('repair449_candidate2','repair450_candidate1').replace('repair449_installed','repair450_installed')
s=s.replace('development449/LATEST','development450/LATEST').replace('INSTALLED_CHECKPOINT_446','INSTALLED_CHECKPOINT_449')
s=s.replace('installed446','installed449').replace('len(delta) == 4','len(delta) == 3')
s=s.replace("== 381","== 382").replace('2.224.0-alpha','2.225.0-alpha').replace('combined 449 candidate','450 candidate')
with(I/'release.py').open('x')as f:f.write(s)
