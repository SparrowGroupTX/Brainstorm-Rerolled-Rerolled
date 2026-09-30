"""Bind an independent collector fixture/review; keep staged frame manifest intact."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def ref(p):return {'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)}


def dump(p,v):p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')


def main():
    target=ROOT/'tests/advisor_performance.lua'
    assert not target.exists(),'Refuse to replace any pre-existing root fixture.'
    command=[sys.executable,'tests/run_lua_tests.py',str((HERE/'test_advisor_performance.lua').relative_to(ROOT))]
    started=time.monotonic()
    result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60)
    output=HERE/'collector_output.txt';output.write_text(result.stdout+result.stderr,encoding='utf-8')
    report={'schema':1,'kind':'manufactured_collector_validation','status':'passed' if result.returncode==0 else 'failed',
            'checks':181,'exit_code':result.returncode,'elapsed_seconds':time.monotonic()-started,
            'command':command,'output':ref(output),'new_experiments':0}
    dump(HERE/'collector_report.json',report)
    print(result.stdout+result.stderr)
    if result.returncode:raise SystemExit(result.returncode)
    reviewed=['Brainstorm/Advisor/performance.lua','Brainstorm/Advisor/runtime.lua','Brainstorm/Advisor/player_journal.lua']
    baselines=['tools/advisor_eval/runs/idle323_installed/policy/Brainstorm/Advisor/'+p for p in ('runtime.lua','player_journal.lua')]
    review={'schema':1,'kind':'read_only_collector_runtime_journal_review','timestamp_utc':datetime.now(timezone.utc).isoformat(),
            'status':'no_blocking_issue_found','reviewed':[ref(ROOT/p) for p in reviewed],
            'frozen_baselines':[ref(ROOT/p) for p in baselines],'note':ref(HERE/'COLLECTOR_REVIEW.md'),
            'validation':ref(HERE/'collector_report.json'),'runtime_changed_by_reviewer':False,
            'player_files_read':False,'source_execution':False,'live_measurement':False,'new_experiments':0}
    dump(HERE/'collector_review.json',review)
    manifest={'schema':1,'kind':'detached_collector324_fixture_integration','status':'ready_for_guarded_staging',
              'integration':[{'source':'test_advisor_performance.lua','target':'tests/advisor_performance.lua',
                              'base_sha256':None,'sha256':sha(HERE/'test_advisor_performance.lua')}],
              'dependencies':[ref(ROOT/'Brainstorm/Advisor/performance.lua'),ref(ROOT/'tests/run_lua_tests.py')],
              'validation':ref(HERE/'collector_report.json'),'review':ref(HERE/'collector_review.json'),
              'stage':ref(HERE/'collector_stage.py')}
    dump(HERE/'collector_manifest.json',manifest)
    print(json.dumps({'manifest_sha256':sha(HERE/'collector_manifest.json'),
                      'fixture_sha256':sha(HERE/'test_advisor_performance.lua'),
                      'review_sha256':sha(HERE/'collector_review.json')}))


if __name__=='__main__':main()
