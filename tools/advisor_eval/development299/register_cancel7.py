from cycle import ROOT,BASE,register,read
import sys
prior=BASE/'M04';r=read(prior/'registration.json')
files={rel:prior/rel for rel in r['files']}
files['native_cancel_component.py']=ROOT/'tools/advisor_eval/development300/native_cancel_component.py'
register('M07',files,[sys.executable,'-B','-u','{job}/native_cancel_component.py','--dll','{job}/bin/Immolate.dll','--output','{job}/validation'],{
 'hypothesis':'Active v9 native cancellation stops the actual two-thread worker promptly and reports cancelled rather than not_found.',
 'scope':'One intentionally nonmatching missing-Perkeo Ante8 offer query; max1billion indices/1000ms, cancel10ms afterworkerentry, require latencyunder250ms,30s outercap.',
 'profile':'native_complete_unlock_assumption','qualification':False,'complete_attempt':False,
 'prior_M04':'short smoke completed before cancellation; this fresh separate lease exercises cancellation while active.'})
print(BASE/'M07/registration.json')
