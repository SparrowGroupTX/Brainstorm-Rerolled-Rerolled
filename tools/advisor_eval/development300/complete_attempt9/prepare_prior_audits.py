"""Bind compact references to existing audits; no evaluation or source access."""
import json
from register import prior_audit_receipts,HERE,sha
value=prior_audit_receipts()
with (HERE/'prior_audits.json').open('x',encoding='utf-8') as f:json.dump(value,f,indent=2);f.write('\n')
print(json.dumps({'prior_audits_sha256':sha(HERE/'prior_audits.json'),'full_audits_copied':0}))
