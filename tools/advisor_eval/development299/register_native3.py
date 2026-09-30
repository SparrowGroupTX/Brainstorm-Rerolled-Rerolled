from cycle import ROOT,BASE,register
import sys

build=ROOT/'Immolate/build-collection300-4'
files={'native_validation_component.py':ROOT/'tools/advisor_eval/development300/native_validation_component.py'}
for name in ('Immolate.dll','brainstorm_api_regression.exe','brainstorm_collection_targets_regression.exe'):
    files['bin/'+name]=build/name
for name in ('libgcc_s_seh-1.dll','libstdc++-6.dll','libwinpthread-1.dll'):
    files['bin/'+name]=ROOT/'Brainstorm'/name
for p in (ROOT/'Immolate/src').rglob('*'):
    if p.is_file():files[str(p.relative_to(ROOT)).replace('\\','/')]=p
for p in (ROOT/'Immolate/tests').glob('*'):
    if p.is_file():files[str(p.relative_to(ROOT)).replace('\\','/')]=p
files['Immolate/CMakeLists.txt']=ROOT/'Immolate/CMakeLists.txt'
for p in (ROOT/'tools/advisor_eval/development300/native_collection_build4').glob('*'):
    if p.is_file():files['build_receipts/'+p.name]=p
register('M03',files,[sys.executable,'-B','-u','{job}/native_validation_component.py',
 '--dll','{job}/bin/Immolate.dll','--api','{job}/bin/brainstorm_api_regression.exe',
 '--synthetic','{job}/bin/brainstorm_collection_targets_regression.exe','--output','{job}/validation'],{
 'hypothesis':'Additive v9 maintains existing native API contracts and accepts independent user targets with distinct quota/copy alternatives, explicit invalid status and cooperative bounded cancellation.',
 'scope':'Synthetic41checks, legacyAPIregression cap22s and two v9 smoke calls100ms/50000indices each; no seed mining beyond those smoke bounds, game, saves, source execution or terminal attempt.',
 'profile':'native_complete_unlock_assumption','qualification':False,
 'native_dll_sha256':'ecf7343e5cc19be0cf10d55e04a18b54b3456134e79acbd0dc1513ad73070acf',
 'child_processes':'Only two frozen bounded native regression executables, hidden; each subprocess timeout kills/reaps its child within30s outer cap.'})
print(BASE/'M03/registration.json')
