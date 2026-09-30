"""Close this existing one-use cycle after all six registered source jobs settle."""
from pathlib import Path
from datetime import datetime, timezone
import json
import validation_cycle as v
from status_snapshot import snapshot

with v.batch_lock():
    v.authority()
    for job in [f'C{i:02}' for i in range(1,7)]+[f'P{i:02}' for i in range(1,5)]:
        folder=v.BASE/job
        record=v.read(folder/'record.json')
        assert record['worker_reaped'] and record.get('stdout_drain_completed',True)
        assert (folder/'spent.json').exists()
        if job.startswith('C'): assert (folder/'audit.json').exists()
        else:
            assert (folder/'comparison.json').exists()
            assert all((folder/(role+'_summary.json')).exists() for role in ('baseline','candidate'))
    assert not any((v.BASE/(j+'_reservation.json')).exists() for j in ('P05','P06'))
    status,status_path=snapshot('status_before_closure332')
    assert status['counts']['complete_attempts']==6 and status['counts']['captured_pair_jobs']==4
    assert status['complete_attempt_outcomes']['running']==0
    assert status['remaining_authority_seconds']==60
    def ref(path): return {'path':path.relative_to(v.ROOT).as_posix(),'sha256':v.sha(path)}
    closure={'schema':1,'kind':'loss328_authority_closure','status':'CLOSED',
        'created_at_utc':datetime.now(timezone.utc).isoformat(),
        'authority_sha256':v.AUTHORITY_SHA,'status_snapshot':ref(status_path),
        'counts':status['counts'],'complete_attempt_outcomes':status['complete_attempt_outcomes'],
        'authorized_cap_seconds':1260,'reserved_worker_seconds':status['reserved_worker_seconds'],
        'actual_worker_seconds':status['actual_worker_seconds'],
        'remaining_authority_seconds':0,'unused_capacity':'closed',
        'unused_slots_closed':['P05','P06'],'unreserved_seconds_closed':60,
        'reason':'Four useful public comparisons and all six source-attempt slots are complete. Old logs contain no new observer activation stream, so additional public pairs cannot validate the new live observation path without fabricating observations. Routine manufactured regression remains separate. No pending worker, search, installation authority extension or scheduled continuation.',
        'historical_allowances':'CLOSED; none renewed','qualification':False,
        'verified_complete_win':status['verified_complete_win']}
    v.create(v.BASE/'CLOSED.json',closure)
    v.create(v.BASE/'FINAL_BUDGET_332.json',closure|{'closure_receipt':ref(v.BASE/'CLOSED.json')})
    print(json.dumps({'closed':ref(v.BASE/'CLOSED.json'),'actual_seconds':status['actual_worker_seconds'],
        'outcomes':status['complete_attempt_outcomes']}))
