"""Root-only prospective freeze; no source or policy execution."""
from pathlib import Path
import json,sys
import validation_cycle as v
import stdout_transport
def freeze(job):
    assert job in {f'C{i:02}' for i in range(1,7)}
    prepared=Path(__file__).with_name('validation_adapter')/'prepared'
    spec=json.loads((prepared/(job+'.json')).read_text())
    assert all(v.sha(source)==spec['expected_files'][name] for name,source in spec['files'].items())
    assert all(v.sha(p)==h for p,h in spec['external_sha256'].items())
    files=dict(spec['files'])
    files['supervisor_source.py']=str(Path(v.__file__).resolve())
    files['audit_definition.py']=str(Path(__file__).with_name('audit_attempt.py').resolve())
    files['stdout_transport.py']=str(Path(stdout_transport.__file__).resolve())
    files['prepared_registration_inputs.json']=str((prepared/(job+'.json')).resolve())
    metadata=dict(spec['metadata'])
    metadata['supervisor_sha256']=v.sha(files['supervisor_source.py'])
    metadata['prospective_audit_sha256']=v.sha(files['audit_definition.py'])
    metadata['stdout_capture']=stdout_transport.CONTRACT
    metadata['transport_comparison_limit']='C01 used raw stdout; C02-C06 use lossless gzip with prospective byte caps. Worker timing is not a paired live-speed estimate.'
    if job=='C06':
        plan=Path(__file__).with_name('followup_plan_after_C04.json')
        assert plan.exists()
        metadata.update(pair_id='observed_run5_development',paired_job=None,
            preregistered_pair_order='C06 is a single candidate329 attempt; the prepared C05 baseline was never registered and is superseded by the House follow-up.',
            hypothesis='Check the retained-Perkeo/shop repairs on the disclosed late-loss seed YAEARC31. This is a selected dependent single-arm development attempt, not a fresh exact policy pair or holdout; concealed Joker decisions stop unsupported. No terminal result is assumed.')
        files['prospective_followup_plan.json']=str(plan.resolve())
    print(v.register(job,files,spec['command'],metadata,spec['external']))
if __name__=='__main__':freeze(sys.argv[1])
