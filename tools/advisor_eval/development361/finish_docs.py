from pathlib import Path
import json
E=Path('tools/advisor_eval');out=E/'development361'
i=json.loads((E/'runs/clear361_installed/record.json').read_text())
c=json.loads((E/'runs/clear361_candidate/validation/report.json').read_text())
v=json.loads((E/'runs/clear361_installed_validation/report.json').read_text())
assert c['passed'] and v['passed'] and i['all_repository_files_match']
assert c['policy_digest']==v['policy_digest']==i['policy']['policy_digest'] and c['test_files']==v['test_files']
component=f"""# Standalone log clearing and ten-run wording —361

The user requested a Clear logs button independent of automatic play and clarified that ten runs must include losses. The existing teacher controller already counts starts, not wins. No controller quota/retirement/search behavior changed.

UI/collection_run.lua adds Clear logs beside the renamed Clear logs + play 10 runs button. The explanatory row identifies win-first strategy and says losses count. Clear logs shows success or the concrete failure without starting a run/search or writing settings. Active/resumable sessions, busy search workers and current execution block cleanup; finish the session or restart normally before clearing its history. Pending journal callbacks/settled observations also block cleanup rather than orphan links.

Advisor/player_journal.lua factors the existing archive preparation into one shared writer reset. Standalone clear uses it without entering teacher mode or enabling recording. Existing archive code validates the entire direct-file deletion set, closes its writer, removes only recognized session .brj/.jsonl files in the two owned observation directories, preserves unrelated entries, and propagates partial failure receipts. Sequence/reference/error caches reset so future ordinary logging can append safely. Saves, profiles, checkpoint data, settings and repository evidence are excluded. The user explicitly triggers deletion; page rendering does not.

Verification: teacher_journal356 passes112 in-memory checks including two real-archive clear/append cycles, disabled recording preservation and pending-receipt guards. collection_status passes29 UI callback checks. teacher_batch356 passes275, including ten losses/zero wins stopping after ten searches and starts. auto_run_product retains1147 checks. Synthetic layout passes381 checks at normal and1.08 font scales (auto page5.4900/5.6548 high within5.7). Initial targeted01 failed only added-row geometry; preserved unchanged. targeted02 passes after reusing the existing explanatory row. No tests were weakened and no live UI/game was exercised.

Full candidate and exact-installed gates pass232 Lua fixtures and391 Python tests each, unchanged frozen policy/test hashes,60s per suite. Evidence: runs/clear361_candidate/validation and runs/clear361_installed_validation. Source delta and original files: development361/runtime.diff and before/. No independent reviewer was needed for this bounded integration; no agents or experiments were spawned.

Installed2.161.0-alpha at{i['installed_at']}, explicit Advisor/player_journal.lua and UI/collection_run.lua plus two version stamps. All89 deployment files and105 frozen dependencies match. Backup:`{i['backup']}`. Digest:{i['policy']['policy_digest']}. Current config SHA256 preserved:{i['config_sha256']}. All seven native DLLs unchanged. Activation requires normal user restart and has not been confirmed.

No live logs were deleted by tools. The earlier requested shell cleanup was policy-blocked and did not run. This delivery installs a user-operated product feature; tools never click it or control gameplay. User intends to start ten logged runs themselves. Historical experiment budgets remain closed. Fresh later logs require passive inspection and version/profile confirmation; no2.161 outcome or benefit claim. Prior frozen evidence remains intact.
"""
(E/'CLEAR_LOGS_361.md').write_text(component,encoding='utf-8')
prompt=Path('ADVISOR_RESUME_PROMPT.md').read_text(encoding='utf-8')
prompt=prompt.replace('SESSION_RESET_360','SESSION_RESET_361').replace('NEXT_PRIORITIES_360','NEXT_PRIORITIES_361').replace('ARCHITECTURE_MAP_360','ARCHITECTURE_MAP_361').replace('runs/reserve360_final/final_verification.json','runs/clear361_final/final_verification.json')
prompt=prompt.replace('   tools/advisor_eval/CONSUMABLE_RESERVATION_360.md and development360/SCOPE.md.','   tools/advisor_eval/CLEAR_LOGS_361.md and development361/SCOPE.md.\n   CONSUMABLE_RESERVATION_360.md locates the unchanged previous policy slice.')
a=prompt.index('CURRENT VERIFIED CHECKPOINT');b=prompt.index('COMPLETED360 SLICE')
prompt=prompt[:a]+f"""CURRENT VERIFIED CHECKPOINT

Installed2.161.0-alpha at{i['installed_at']}.
Installation:{i['installed']}.
Backup:{i['backup']}.
Policy digest:{i['policy']['policy_digest']}.
All89 deployment and105 frozen runtime/dependency files match. Full candidate and
exact-installed gates pass232 Lua fixtures and391 Python tests, with unchanged
policy/test hashes and60s per suite. Evidence: tools/advisor_eval/runs/
clear361_candidate/validation, clear361_installed/record.json and policy,
clear361_installed_validation, clear361_final/final_verification.json.
Current settings and seven DLLs preserved; config SHA256:
{i['config_sha256']}.
Active native remains Immolate-advisor-ecf7343e5cc19be0cf10d55e04a18b54b3456134e79acbd0dc1513ad73070acf.dll.
Activation unconfirmed; normal user restart required. No361 implementation,
installation or validation is pending. Original intermediate failures preserved.

COMPLETED361 USER-REQUESTED SLICE

Standalone Clear logs button resets only owned observation journals and writer,
without starting runs, changing settings or enabling recording. It blocks active/
resumable sessions, busy searches and pending action/observation receipts. User
clicks it before a batch or after a session finishes; a normal restart permits
clearing an old resumable session without tool game control.
The existing teacher button is now Clear logs + play 10 runs. Ten means starts,
including losses, not ten wins. A new all-loss manufactured test verifies this;
controller quotas are unchanged. User plans to start ten logged runs themselves.
No live logs were deleted by tools: the earlier shell attempt was policy-blocked.
This explicit button request permits user-triggered clearing of current session
journals, not repository evidence, saves/profiles or arbitrary log purges.
Scope/source/tests/failures: CLEAR_LOGS_361.md and development361. No new agent,
source/search/captured-policy/simulation/GPU experiment or automation occurred.
Analyze later public journals passively when requested, confirming loaded version
and teacher versus normal-collection profile before attributing outcomes.

"""+prompt[b:]
prompt=prompt.replace('360 is delivered. A future continuation','361 is delivered. A future continuation')
prompt=prompt.replace('No2.160 terminal, rescued run','No2.160 or2.161 terminal, rescued run')
(out/'resume_prompt.md').write_text(prompt,encoding='utf-8')
print('Completed361 records prepared')
