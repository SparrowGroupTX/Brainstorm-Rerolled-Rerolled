# Primary correctness review

Reviewed consent, bounded start accounting and receipt transitions. Only the new
collection UI start passes retire_unsupported=true. Existing ordinary API starts
and saved preferences retain prior behavior; teacher remains its existing explicit
win-first preset. Product retirement retains busy/worker/execution/search/terminal/
logging guards. Normal collection emits collection_run_retired, never teacher
labels or false terminal wins/losses. All future launches occur on later fresh
ticks, after owned search; actual start allowance is consumed before dispatch,
including uncertain starts. Resume cannot reset it. Completionist goal completion,
search/log/identity failures, action/time caps and ordinary execution errors stop.

Review found normal retirement must not outrun an unobserved prior execution.
A normal-retirement-only settlement gate now records the changed fresh observation
before retirement; otherwise the existing thirty-second action-observation stop
applies. Manufactured tests cover both branches plus Stop/Resume, terminal priority,
receipts, logging failure, pending product execution and ten unsupported starts.
Teacher behavior remains unchanged and its existing fixture passes.

The first new stall fixture accidentally retained an executable action token
while claiming no advice. Preserved targeted02 failure exposed the fixture mismatch;
removing the token correctly represents no advice. targeted03 then passes139 checks.
No production gate was relaxed to satisfy it. Original baseline rejects retirement.

Acorn admission uses existing exact/floor scorer only, does not forecast Gold/Blue/
Purple future rewards, and retains all-world/candidate preflight. Larger concealed
hands keep identical sampled worlds for all candidates (11:1023x7;12:1585x5).
Explicit oversized sample requests fail before scoring. No new future-tree scope,
hidden identity reads, population edits or cap increase. Existing tests changing
scope expectations preserve unknown-seal/card and thirteen-card rejection tests.
No additional reviewer agent was used.
