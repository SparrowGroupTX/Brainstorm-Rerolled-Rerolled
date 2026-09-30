from cycle import ROOT,BASE,register,create,read
import sys

previous=BASE/'M03';r=read(previous/'registration.json')
create(previous/'audit.json',{'status':'failed_fixture_dependency','complete_attempt':False,
 'synthetic_checks_passed':41,'legacy_api':'failed: required anchor index files absent beside frozen DLL',
 'v9_calls_executed':0,'qualification':False,'spent_preserved':True})
files={relative:previous/relative for relative in r['files']}
build=ROOT/'Immolate/build-collection300-4'
for p in build.iterdir():
    if p.is_file() and (p.suffix=='.ids' or p.name.endswith('.manifest.json')):files['bin/'+p.name]=p
meta=dict(r['metadata']);meta['hypothesis']='With all exact native index dependencies frozen beside the DLL, legacyAPI and additivev9 mechanical contracts pass without fallback from missing assets.'
meta['previous_failure']='M03 retained as spent missing-fixture-dependency failure; no v9 calls ran there.'
register('M04',files,[sys.executable,'-B','-u','{job}/native_validation_component.py',
 '--dll','{job}/bin/Immolate.dll','--api','{job}/bin/brainstorm_api_regression.exe',
 '--synthetic','{job}/bin/brainstorm_collection_targets_regression.exe','--output','{job}/validation'],meta)
print(BASE/'M04/registration.json')
