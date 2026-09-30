from pathlib import Path
import hashlib,json,difflib,subprocess,sys,time
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3]
MODULE='Brainstorm/Advisor/gold_tarot_hold.lua'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert not (OUT/'component_report.json').exists()
wrapper=OUT/'existing_fixtures.lua'
with wrapper.open('x',encoding='utf-8') as f:
    f.write("local open,dof=io.open,dofile\nlocal path='tools/advisor_eval/development345/tarot_scope_component/Brainstorm/Advisor/gold_tarot_hold.lua'\n")
    f.write("io.open=function(p,...) return open(p=='Brainstorm/Advisor/gold_tarot_hold.lua' and path or p,...) end\n")
    f.write("dofile=function(p) return dof(p=='Brainstorm/Advisor/gold_tarot_hold.lua' and path or p) end\n")
    f.write("dofile('tests/advisor_gold_tarot_hold.lua')\ndofile('tools/advisor_eval/development345/pin_component/tests/advisor_gold_tarot_hold_pin.lua')\ndofile('tools/advisor_eval/development345/pin_component/tests/advisor_gold_acquisition_runtime.lua')\n")
start=time.monotonic();command=[sys.executable,'tests/run_lua_tests.py',str(wrapper.relative_to(ROOT))]
r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
validation={'command':command,'max_seconds':60,'seconds':time.monotonic()-start,'exit_code':r.returncode,'stdout':r.stdout,'stderr':r.stderr}
(OUT/'existing_validation.json').write_text(json.dumps(validation,indent=2)+'\n',encoding='utf-8')
print(json.dumps(validation));assert r.returncode==0
before=(OUT/'before'/MODULE).read_text(encoding='utf-8');after=(OUT/MODULE).read_text(encoding='utf-8')
(OUT/'gold_tarot_hold.lua.patch').write_text(''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='pin_normalized_before',tofile='tarot_scope_after')),encoding='utf-8')
source={
 'tools/advisor_eval/runs/chicot_order_source1/source/card.lua':{'lines':['273-309','564-640','2413-2428','4167-4174'],'use':'Generic constructor zero score/size defaults, exact Negative slot contribution, named Joker-only add effects, copying, and non-scoring Temperance money display.'},
 'tools/advisor_eval/runs/chicot_order_source1/source/functions/common_events.lua':{'lines':['2156-2183'],'use':'Copy entire ability/params/base; retain nil pin.'},
 'Brainstorm/Advisor/consumables.lua':{'lines':['45-63'],'use':'Existing vanilla Tarot source key/name identities; use models are not invoked.'},
 'Brainstorm/Advisor/scoring.lua':{'lines':['514','542-547'],'use':'Tarot use count is independent of held inventory; held scoring depends on editions/Planet Observatory only.'}}
for p,row in source.items():row['sha256']=sha(ROOT/p)
files=[OUT/MODULE,OUT/'before'/MODULE,*sorted((OUT/'tests').glob('*.lua')),OUT/'validation.json',OUT/'existing_validation.json',OUT/'gold_tarot_hold.lua.patch']
report={'schema':1,'scope':'Staged unused Tarot score-equivalence broadening and manufactured fixtures only.',
 'before_sha256':sha(OUT/'before'/MODULE),'after_sha256':sha(OUT/MODULE),
 'base_includes_pin_component':True,'row_names_unchanged':True,
 'change':'All22 vanilla Tarot identities qualify only when public constructor data is consistent and all score/hand/discard defaults are zero. Magician/Hermit remain strict exact configs. Other use data is plain, fully retained and never used/valued. Temperance money is a finite bounded display value and receives no payout credit.',
 'proof':'No admitted Tarot name triggers a named Card:add_to_deck Joker side effect. Withzero h_size/d_size and a forced Negative edition, every new nonplaying Tarot only adds one consumable and one capacity slot. Neither held Tarot identities nor their unused effect/config data enter first-hand scoring; Observatory only recognizes Planets, and Fortune Teller counts uses, which do notoccur. Existing originals stay preserved in the comparison; this is explicitly not exact future inventory or money-display reconstruction.',
 'source_provenance':source,'files':{str(p.relative_to(ROOT)):sha(p) for p in files},
 'validation':'Old pin-fixed helper fails first Temperance fixture; expanded helper passes508 checks across20 newidentity constructors, all common guards and score-dependency examples. Existing70-check helper fixture,52-check pin fixture and67-check productionDecision sale→fresh-buy fixture also pass.',
 'limits':'Fixed row and hold-all first hand only. No Tarot use, arbitrarymodcallback, futureutility, sourceworker, capturedreplay, livegamecontrol, search, attempt, save/profileaccess or terminalwin claim.'}
with (OUT/'component_report.json').open('x',encoding='utf-8') as f:json.dump(report,f,indent=2);f.write('\n')
print(json.dumps({'path':str(OUT/'component_report.json'),'sha256':sha(OUT/'component_report.json')}))
