"""Publish a new closed-cycle status; never rewrite immutable release321 evidence."""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import os
import shutil
from close_cycle import ROOT, BASE, AUTHORITY_SHA, read, sha, scan, encoded

POLICY = 'fd5c42031000f79ecba48ceee72f000aa3d1b7a0c51ed54895d36cfab53e4da5'
NAVIGATION = ('ADVISOR_START_HERE.md', 'ADVISOR_RESUME_PROMPT.md', 'ADVISOR_HANDOFF.md')
STATUS = 'tools/advisor_eval/SESSION_STATUS_321_CLOSED'
PRIORITIES = 'tools/advisor_eval/NEXT_PRIORITIES_321_CLOSED.md'


def outcomes(jobs):
    counts = dict(win=0, loss=0, error=0, timeout=0, unsupported=0, censored=0)
    for job in jobs:
        if not job['job'].startswith('C'): continue
        audit = job['audits'][job['selected_audit']]['summary']
        disposition = audit.get('disposition')
        if audit.get('status') == 'audited_selected_synthetic_original_source_win' and audit.get('observed_wins') == 1:
            disposition = 'win'
        elif audit.get('status') == 'audited_selected_synthetic_timeout_censored' and audit.get('censored_timeouts') == 1:
            disposition = 'timeout'
        assert disposition in counts, 'Explicit selected audit outcome required'
        counts[disposition] += 1
    return counts


def prepare(root=ROOT, base=BASE, closed_sha=None):
    root, base = Path(root), Path(base)
    marker = base / 'CLOSED.json'
    assert closed_sha and sha(marker) == closed_sha and read(marker)['status'] == 'CLOSED', 'Bind root-created closure first'
    closure = read(marker)
    ledger = scan(base, AUTHORITY_SHA)
    assert ledger['C09'] == 'never_registered_reserved_or_run'
    assert closure['authority_sha256'] == AUTHORITY_SHA and closure['active_workers'] == 0
    assert closure['unused_capacity'] == 'closed' and closure['spent_reserved_seconds'] == ledger['budget']['spent_reserved_seconds']
    assert set(closure['closed_unused_slots']) == set(ledger['budget']['unused_slots'])
    bound_jobs = {j['job']: j for j in closure['completed_job_records']}
    assert len(bound_jobs) == len(closure['completed_job_records']) == len(ledger['jobs'])
    for job in ledger['jobs']:
        bound = bound_jobs[job['job']]
        assert bound['record_sha256'] == job['record_sha256'] and bound['registration_sha256'] == job['registration_sha256']
        assert bound['reserved_seconds'] == job['timeout_seconds'] and bound['actual_seconds'] == float(job['elapsed_seconds_decimal'])
    final_path = root / 'tools/advisor_eval/runs/pair321_final/final_verification.json'
    final = read(final_path)
    assert final['policy_digest'] == POLICY and final['version'] == '2.121.0-alpha' and final['installed_matches'] is True
    for relative, expected in final['documents'].items():
        assert sha(root / relative) == expected, 'Preserve exact prior release document: ' + relative
    installed_path = root / 'tools/advisor_eval/runs/pair321_installed/record.json'
    installed = read(installed_path)
    assert installed['policy']['policy_digest'] == POLICY
    assert len(installed['policy']['policy_files']) == 93
    for relative, expected in installed['policy']['policy_files'].items():
        assert sha(root / relative) == expected, 'Repository policy changed'
        tail = Path(relative).relative_to('Brainstorm')
        assert sha(Path(installed['installed']) / tail) == expected, 'Installed policy changed'
    reports = {'candidate': root / 'tools/advisor_eval/runs/pair321_candidate/validation/report.json',
               'installed': root / 'tools/advisor_eval/runs/pair321_installed_validation/report.json'}
    for kind, path in reports.items():
        value = read(path)
        assert sha(path) == final[kind + '_report']
        assert value['passed'] is True and value['policy_unchanged'] is True and value['tests_unchanged'] is True
        assert value['policy_digest'] == POLICY
    c09_review = root / 'tools/advisor_eval/development300/reviews/review_c09.json'
    assert sha(c09_review) == '5a5c2f9210bdae14dcb288a5c7866f675f1471f803a968a59e838cec8bf813d5'
    counts = outcomes(ledger['jobs']); assert sum(counts.values()) == 8
    context_path = base / 'status321closed/context.json'
    archive = root / 'tools/advisor_eval/runs/status321_closed_final'
    assert not archive.exists() and not context_path.parent.exists(), 'Never overwrite an earlier end status'
    refs = {name: {'path': str(path.relative_to(root)), 'sha256': sha(path)} for name, path in
        {'closed_cycle': marker, 'installed_record': installed_path, 'immutable_release_final': final_path,
         'immutable_reset_md': root / 'tools/advisor_eval/SESSION_RESET_321.md',
         'immutable_reset_json': root / 'tools/advisor_eval/SESSION_RESET_321.json',
         'candidate_validation': reports['candidate'], 'installed_validation': reports['installed'],
         'C09_unrun_review': c09_review,
         'C07_audit': base / 'C07/audit.json', 'C08_selected_audit': base / 'C08/selected_audit.json'}.items()}
    now = datetime.now(timezone.utc).isoformat()
    context = {'schema': 1, 'kind': 'checkpoint_experiment_context_status', 'status': 'CLOSED',
        'created_at_utc': now, 'policy_digest': POLICY, 'evidence': refs, 'jobs': ledger['jobs'],
        'budget': ledger['budget'], 'closure_reported_actual_worker_seconds': closure['actual_worker_seconds'],
        'complete_attempt_outcomes': counts, 'C09': ledger['C09'],
        'remaining_authority_seconds': 0, 'unused_slots_closed': ledger['budget']['unused_slots'],
        'replacements': 0, 'renewals': 0, 'source_generator': 'Immutable v2 outcome/audit summaries extended by a separate closed status; prior contexts unchanged.',
        'tools': {Path(__file__).name: sha(Path(__file__)), 'close_cycle.py': sha(Path(__file__).with_name('close_cycle.py'))}}
    budget = ledger['budget']
    summary = f'''Installed checkpoint remains **2.121.0-alpha**, installed 2026-09-14T16:29:45.8083749-05:00. Policy digest `{POLICY}`. All 77 deployment and 93 frozen files matched at release; both full candidate and exact-installed regressions passed 170 Lua fixtures / 315 Python tests with unchanged policy/test hashes. This status refresh rechecks all 93 current repository/installed frozen files and unchanged full validation. Current settings are not read, restored or changed; all existing native DLLs remain preserved. Loaded-version activation is unknown and waits for the user's normal restart. Live 8x/16x game-speed timing remains unconfirmed.

The original cycle expired at **2026-09-14T22:40:00+00:00** and is now **CLOSED**. **C09 was never registered, reserved or run; it has no result.** Preparation/review did not consume an attempt. All {len(budget['unused_slots'])} original unused slots, including C09, are closed and cannot be renewed. {budget['spent_jobs']} jobs were spent, with {budget['spent_reserved_seconds']} seconds of registered caps and exactly {budget['actual_worker_seconds_decimal']} seconds from the decimal sum of recorded worker times. The closure's floating-point total is {closure['actual_worker_seconds']!r} seconds; both forms preserve the same individual records. Authorized total was 5400 seconds; remaining authority is zero.

Complete-attempt audited totals: {counts['win']} selected synthetic win, {counts['loss']} losses, {counts['timeout']} timeouts, {counts['error']} errors, {counts['unsupported']} unsupported and {counts['censored']} separately labeled censored outcomes. C01's win belongs to policy 300 alone. C07 policy 320 timed out; all 163 shared completed inputs/actions matched C06. C08 policy 320 lost Ante 1 Pillar, 592/600; all 22 actual inputs/actions matched C05. `C08/selected_audit.json` selects its corrected audit and preserves the earlier audit-tool errors. Release 321 has manufactured/regression evidence and **no complete-attempt result**.

These are selected dependent synthetic `all_unlocked_discovered_v1` development observations, not representative player odds, an unseen holdout or an actual achievement. No verified complete Jokerless win, 50%/75% challenge target, human superiority or general speedup is established. Source legality/scores/terminal checks do not qualify production UI, automatic search or animation behavior.

No installation, failed final regression, source/search worker or scheduled continuation is pending. The C09 preparation and unfinished audit drafts are preserved as inactive proposals requiring fresh experiment authority.
'''
    priorities = '''Read immutable `NEXT_PRIORITIES_321.md` and `REMAINING_WORK_321.md` for the fuller unresolved roadmap, including prerequisite-Joker routes. This later status supersedes their active-authority/C09-preparation wording; the implementation priorities remain available.

1. Keep release 321's current-blind paired Yorick proof and played-Steel support within documented bounds. Both costs and complete inventory/population guards remain; only the first action is recommended. No full-attempt benefit was measured for 321.
2. Further source/search/captured/complete experiments require fresh concrete authorization, caps and frozen provenance. Every original unused slot is closed; no C09 or historical allowance may be revived. Routine read-only analysis and relevant fixture/regression implementation remain possible.
3. C08's Card Sharp/Certificate choice is a real non-dominating tradeoff: all-clearing Card Sharp forecasts lose protected cash/Yorick/hand development in Certificate's successful worlds. Any change needs an explicit calibrated complete comparison, not removed guards or a forced offer based on the known loss.
4. Continue whole-inventory Perkeo support, phase-correct copying, strategic purchases/retention and meaningful outcome calibration when new evidence is authorized. Preserve the broader Jokerless/Knife's Edge and twenty-challenge roadmap. Passing features or acquiring Jokers do not establish wins or odds.
5. Await the user's normal restart and feedback for newly installed runtime/speed activation. Never launch, control, foreground, restart or stop the game through tools. Keep all tracked/untracked work, settings, saves, native files and persistent retry counts intact.
'''
    status_md = '# Current session status — installed321, experiment cycle closed\n\n' + summary
    status_md += '\nRead immutable `SESSION_RESET_321.md/json` and `runs/pair321_final/final_verification.json` for the original release checkpoint. This newer status supersedes only active-budget/C09-preparation wording. Exact fresh closure/context references are in the JSON companion.\n'
    data = {'schema': 1, 'status': 'CLOSED', 'installed_version': '2.121.0-alpha', 'policy_digest': POLICY,
        'context': {'path': str(context_path.relative_to(root)), 'sha256': hashlib.sha256(encoded(context)).hexdigest()},
        'evidence': refs, 'complete_attempt_outcomes': counts, 'budget': budget, 'C09': ledger['C09'],
        'prior_navigation_archived': {name: {'path': str((archive / 'previous_navigation' / name).relative_to(root)), 'sha256': sha(root / name)} for name in NAVIGATION}}
    new = {STATUS + '.md': status_md.encode(), STATUS + '.json': encoded(data),
           PRIORITIES: ('# Next priorities — cycle closed\n\n' + priorities).encode()}
    for relative in new: assert not (root / relative).exists(), 'Status file already exists'
    startup = f'''# Balatro advisor — start here

**Installed 2.121.0-alpha; original experiment cycle CLOSED.** Read:

1. `{STATUS}.md` and its JSON companion — latest outcomes, expired authority and exact current status.
2. `{PRIORITIES}` — remaining work.
3. Relevant `tools/advisor_eval/ARCHITECTURE_MAP_321.md` sections.

C09 was never registered/reserved/run. Release 321 has no complete-attempt result. Earlier active-cycle or C09-preparation wording in immutable `SESSION_RESET_321` is superseded by the status above. The original installed checkpoint and `pair321_final` remain intact. Full current continuation prompt: `ADVISOR_RESUME_PROMPT.md`.

{summary}
'''
    resume = f'''Continue in `C:\\Users\\trevo\\Documents\\GitHub\\Brainstorm-Rerolled-Rerolled` on `codex/exact-search-speedups`. Read `ADVISOR_START_HERE.md`, `{STATUS}.md/json`, `{PRIORITIES}` and relevant `ARCHITECTURE_MAP_321.md` sections. Preserve all dirty/untracked work; no commit/reset/clean/deletion/PR. Immutable `SESSION_RESET_321` and `pair321_final` retain exact installed-release history.

{summary}
{priorities}
The primary current product goal is an explicit user-started, stoppable normal-deck Completionist++ advisor minimizing real time, failed attempts, computation/search and user actions. The user's 6PM desired achievement was not a demonstrated capability or promise. The prior exact source setup was RedGold, Yorick/Perkeo Starting Charm, Brainstorm/Burnt by Ante 5, no perishable targets, maximum native CPU; later copy alternatives and bounded Burnt fallback are documented. No tool may activate gameplay, read/evaluate player saves or renew source retry counts. Product checkpoint/save/load and automatic execution remain user-controlled. No neural/GPU training, scheduled tasks or automations.
'''
    handoff = '# Latest session status — ' + now + '\n\n' + summary + '\nCurrent details: `' + STATUS + '.md/json`. All earlier active-cycle/C09-preparation wording below is historical and superseded.\n\n' + (root / 'ADVISOR_HANDOFF.md').read_text(encoding='utf8')
    navigation = dict(zip(NAVIGATION, (startup.encode(), resume.encode(), handoff.encode())))
    return {'root': root, 'archive': archive, 'context_path': context_path, 'context': context, 'new': new,
            'navigation': navigation, 'expected_navigation': {n: sha(root / n) for n in NAVIGATION}, 'refs': refs}


def publish(plan):
    root, archive = plan['root'], plan['archive']
    for name, expected in plan['expected_navigation'].items(): assert sha(root / name) == expected, 'Navigation changed'
    archive.mkdir(exist_ok=False)
    previous = archive / 'previous_navigation'; previous.mkdir()
    # Archive and verify all three before changing any of them.
    for name in NAVIGATION:
        shutil.copyfile(root / name, previous / name)
        assert sha(previous / name) == plan['expected_navigation'][name]
    plan['context_path'].parent.mkdir(exist_ok=False)
    with plan['context_path'].open('xb') as stream: stream.write(encoded(plan['context']))
    for relative, content in plan['new'].items():
        with (root / relative).open('xb') as stream: stream.write(content)
    for name, content in plan['navigation'].items():
        prepared = archive / (name + '.new')
        with prepared.open('xb') as stream: stream.write(content); stream.flush(); os.fsync(stream.fileno())
        assert sha(root / name) == plan['expected_navigation'][name]
        os.replace(prepared, root / name)
    for reference in plan['refs'].values():
        assert sha(root / reference['path']) == reference['sha256'], 'Immutable status evidence changed'
    receipt = {'schema': 1, 'status': 'published_closed_status_only', 'runtime_changed': False,
        'old_navigation_archives': {n: sha(previous / n) for n in NAVIGATION},
        'new_files': {p: sha(root / p) for p in [*plan['new'], *NAVIGATION]},
        'context_sha256': sha(plan['context_path']), 'immutable_evidence': plan['refs']}
    with (archive / 'status_verification.json').open('xb') as stream: stream.write(encoded(receipt))
    return receipt


def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--closed-sha256', required=True)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--preview', action='store_true'); mode.add_argument('--publish', action='store_true')
    args = parser.parse_args(); plan = prepare(closed_sha=args.closed_sha256)
    if args.preview:
        print(plan['new'][STATUS + '.md'].decode()); print(plan['new'][PRIORITIES].decode()); return
    print(json.dumps(publish(plan)))


if __name__ == '__main__': main()
