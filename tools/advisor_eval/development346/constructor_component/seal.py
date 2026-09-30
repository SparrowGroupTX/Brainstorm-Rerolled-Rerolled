from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,difflib
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert not(OUT/'component_report.json').exists()
modules=['Brainstorm/Advisor/gold_tarot_hold.lua','Brainstorm/Advisor/perkeo_inventory.lua']
changes={}
for path in modules:
 before=OUT/'before'/path;after=OUT/path
 patch=OUT/(Path(path).name+'.patch')
 patch.write_text(''.join(difflib.unified_diff(before.read_text(encoding='utf-8').splitlines(True),after.read_text(encoding='utf-8').splitlines(True),fromfile='before/'+path,tofile=path)),encoding='utf-8')
 changes[path]={'before_sha256':sha(before),'after_sha256':sha(after),'runtime_unchanged_by_component':sha(ROOT/path)==sha(before),'patch_sha256':sha(patch)}
source={
 'tools/advisor_eval/runs/chicot_order_source1/source/functions/common_events.lua':{
  'lines':['375','1934','2126-2132','2156-2181'],
  'use':'Both general create_card and named-card constructor pass selected_back.pos as bypass_back. Playing-card constructor identity remains disallowed. copy_card transfers other.params then sets params.playing_card to the supplied nil/nonplaying identity.'},
 'tools/advisor_eval/runs/chicot_order_source1/source/card.lua':{
  'lines':['5-31','168-174','213','233','564-640','4632','4664'],
  'use':'Card:init preserves raw params, consumes Boolean viewed_back/discovery/lock controls and playing_card identity. bypass_back is only read for a back Sprite atlas position. Card serialization stores/restores the same params. Neither constructor display flag affects held scoring, size or add-to-deck inventory mechanics.'}}
for path,row in source.items():row['sha256']=sha(ROOT/path)
files=[*sorted((OUT/'Brainstorm/Advisor').glob('*.lua')),*sorted((OUT/'before/Brainstorm/Advisor').glob('*.lua')),
 *sorted((OUT/'tests').glob('*.lua')),OUT/'validation_01.json',OUT/'related_validation.json',OUT/'validate.py',OUT/'validate_related.py']
report={'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),
 'scope':'Staged narrow constructor repair and manufactured validation. No original-source execution or player-policy replay.',
 'changes':changes,'source_provenance':source,
 'finding':'Both Tarot and Planet parameter whitelists rejected source-native bypass_back. The previous fixtures omitted the real create_card parameter; nilpin repair alone could not qualify these real inputs.',
 'parameter_audit':{
  'existing_supported_boolean_fields':['discover','bypass_discovery_center','bypass_discovery_ui','bypass_lock'],
  'additional_supported_boolean':'viewed_back, read only to select Card.back for visual display',
  'additional_supported_shape':'bypass_back, absent or a plain exact{x,y} table of finite nonnegative integers',
  'still_rejected':'Any playing_card field, unknown key, malformed Boolean, extra coordinate key, missing coordinate, negative/noninteger/nonfinite coordinate, metatable, cycle, function or arbitrary object.',
  'identity_and_conservation':'Capture stores all original parameters unchanged. Source certificates revalidate them; copy projection retains the same metadata and every original card. No hidden record is inspected before visibility guards.'},
 'diagnostics':'Tarot capture returns small stable reason_code strings for visibility, constructor identity, center, params, front, base, ability, physical state, prices and edition. No raw rejected parameters are serialized into diagnostic reasons.',
 'validation':'Independent installed345 Tarot and Planet failures reproduced. Candidate passes206 constructor/copy/certificate checks. Nine existing manufactured fixtures pass unchanged against staged modules, including the stronger actual production acquisition, Cartomancer/final-Leaf and retention fixtures using corrected create_card-shaped parameters.',
 'files':{str(p.relative_to(ROOT)):sha(p)for p in files},
 'limits':'No installation, source worker, captured-policy replay, seed search, complete attempt, game control or save/profile file access by this component. This repairs admission; it doesnot establish run rescue or sticker progress.'}
with(OUT/'component_report.json').open('x',encoding='utf-8')as f:json.dump(report,f,indent=2);f.write('\n')
print(json.dumps({'path':str(OUT/'component_report.json'),'sha256':sha(OUT/'component_report.json'),'changes':changes}))
