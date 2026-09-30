"""Write current navigation and preservation receipts for an already verified release.

Read-only with respect to the installation. Does not execute evaluations, touch
configuration/saves, or authorize experiments. Existing current documents are
copied byte-for-byte to the new evidence directory before updating navigation.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]
EVAL = ROOT / 'tools/advisor_eval'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'),
                      parse_constant=lambda x: (_ for _ in ()).throw(ValueError('Nonfinite JSON')))


def experiment_context(path):
    """Validate an immutable current-cycle snapshot, without granting authority."""
    if path is None:
        return None
    path = Path(path).resolve(); path.relative_to(ROOT.resolve())
    value = read(path)
    if (value.get('schema') != 1 or value.get('kind') != 'checkpoint_experiment_context' or
            value.get('status') not in ('ACTIVE', 'CLOSED')):
        raise ValueError('Require an explicit current experiment context snapshot')
    for key in ('summary', 'outcome_summary', 'limits_summary', 'budget_summary'):
        if not isinstance(value.get(key), str) or not value[key].strip():
            raise ValueError('Experiment context requires ' + key)
    keys = {'source_components', 'captured_pair_jobs', 'captured_policy_evaluations', 'search_workers', 'complete_attempts'}
    counts = value.get('counts', {})
    if set(counts) != keys or any(type(v) is not int or v < 0 for v in counts.values()):
        raise ValueError('Experiment counts must be explicit nonnegative integers')
    scope = value.get('counts_scope')
    if scope is not None:
        release_counts = value.get('release_counts')
        if (scope != 'historical_closed_cycle' or value['status'] != 'CLOSED' or
                not isinstance(release_counts, dict) or set(release_counts) != keys or
                any(type(v) is not int or v != 0 for v in release_counts.values())):
            raise ValueError('Historical counts require a closed cycle and explicit all-zero release counts')
    elif 'release_counts' in value:
        raise ValueError('Release counts require an explicit historical counts scope')
    outcome_keys = {'win', 'loss', 'error', 'timeout', 'unsupported', 'censored', 'running', 'not_started'}
    outcomes = value.get('complete_attempt_outcomes', {})
    if set(outcomes) != outcome_keys or any(type(v) is not int or v < 0 for v in outcomes.values()):
        raise ValueError('Every complete-attempt disposition must remain explicit')
    if sum(v for k, v in outcomes.items() if k != 'not_started') != counts['complete_attempts']:
        raise ValueError('Complete-attempt counts and dispositions disagree')
    if type(value.get('verified_complete_win')) is not bool or value['verified_complete_win'] and outcomes['win'] == 0:
        raise ValueError('Verified-win status requires a recorded win disposition')
    expected_capacity = 'retained_under_existing_authority' if value['status'] == 'ACTIVE' else 'closed'
    if value.get('unused_capacity') != expected_capacity or value['status'] == 'CLOSED' and outcomes['running']:
        raise ValueError('Cycle closure and remaining authority disagree')
    refs = value.get('evidence', {})
    if set(refs) != {'authority', 'outcomes', 'budget', 'limits'}:
        raise ValueError('Require authority, outcomes, budget and limits evidence references')
    verified_refs = {}
    for role, ref in refs.items():
        reference = Path(ref['path'])
        reference = (ROOT / reference).resolve() if not reference.is_absolute() else reference.resolve()
        reference.relative_to(ROOT.resolve())
        if not re.fullmatch('[0-9a-f]{64}', ref.get('sha256', '')) or sha(reference) != ref['sha256']:
            raise ValueError('Experiment evidence changed: ' + role)
        verified_refs[role] = {'path': str(reference.relative_to(ROOT)), 'sha256': ref['sha256']}
    return {'path': str(path.relative_to(ROOT)), 'sha256': sha(path), 'snapshot': value,
            'verified_evidence': verified_refs}


def experiment_sections(context):
    if context is None:
        return {
            'outcomes': 'No verified complete Jokerless win. The historical twelve selected synthetic-profile attempts remain ten losses, one error and one unsupported result. Furthest policy 274 lost final Ante 8 Cerulean Bell with 38,802/100,000; GAME.won=true does not override GAME_OVER and the unmet threshold. Policies 281 onward have no complete-attempt outcome in this release. Current/projected numerical win odds and measured completion-time gains are unknown.',
            'budget': 'All historical experiment allowances remain closed. This release used routine synthetic fixtures/regressions and read-only analysis only: zero source workers/components, captured-state replays, searches and complete attempts. No executable ZIP or saves were read, no live game was controlled and no automation was created. A fresh experiment needs a concrete hypothesis/caps/total cost, fresh authorization and prospective frozen provenance with one-use limits before execution. Unused old mechanical quotas cannot become attempts.',
            'navigation': '',
            'handoff': 'No new source/search/replay/complete experiment. Historical budgets closed; no verified win.',
            'headline': 'No verified Jokerless win or numerical win odds. All old budgets remain closed.'}
    value = context['snapshot']
    state = ('The current authorized cycle remains active; this installation does not close its existing unused jobs or grant additional jobs.'
             if value['status'] == 'ACTIVE' else
             'The current cycle is closed; its unused capacity remains closed and this installation grants no additional jobs.')
    block = '\n\n'.join((value['summary'], value['outcome_summary'], value['limits_summary'], value['budget_summary'], state,
                         'Exact current-cycle evidence and authority references: `' + context['path'] + '`.'))
    return {'outcomes': value['outcome_summary'] + '\n\n' + value['limits_summary'],
            'budget': value['budget_summary'] + '\n\n' + state + '\n\nAll historical allowances remain closed; this checkpoint creates no experiment authority.',
            'navigation': block,
            'handoff': block,
            'headline': value['outcome_summary'] + ' All historical allowances remain closed.'}


def experiment_json(context):
    if context is None:
        return {'new_experiments': 0, 'historical_budgets': 'closed', 'complete_win': False}, {
            'historical_authority': 'closed', 'new_source_components': 0, 'captured_replays': 0,
            'searches': 0, 'complete_attempts': 0}
    value = context['snapshot']; historical = value.get('counts_scope') == 'historical_closed_cycle'
    counts = value['release_counts'] if historical else value['counts']
    total = sum(counts[k] for k in ('source_components', 'captured_pair_jobs', 'search_workers', 'complete_attempts'))
    shared = {'experiment_context': context, 'cycle_status': value['status'],
              'unused_capacity': value['unused_capacity'], 'complete_attempt_outcomes': value['complete_attempt_outcomes']}
    if historical:
        shared.update(counts_scope='historical_closed_cycle', release_counts=counts,
                      historical_counts=value['counts'], outcomes_scope='historical_closed_cycle',
                      historical_verified_complete_win=value['verified_complete_win'])
    return {'new_experiments': total, 'historical_budgets': 'closed',
            'complete_win': False if historical else value['verified_complete_win'], **shared}, {
        'historical_authority': 'closed', 'new_source_components': counts['source_components'],
        'captured_pair_jobs': counts['captured_pair_jobs'], 'captured_policy_evaluations': counts['captured_policy_evaluations'],
        'captured_evaluation_scope': 'detached public decisions, not source future replays',
        'searches': counts['search_workers'], 'complete_attempts': counts['complete_attempts'], **shared}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--release', type=int, required=True)
    parser.add_argument('--prefix', required=True, help='Fresh runs/ directory prefix')
    parser.add_argument('--component', required=True, help='Existing component note under advisor_eval')
    parser.add_argument('--related', action='append', default=[], help='Additional completed notes to bind in the verification receipt')
    parser.add_argument('--summary', required=True)
    parser.add_argument('--previous', type=int, required=True)
    parser.add_argument('--candidate-suffix', default='_candidate', help='Preserve failed candidates; select the passing fresh freeze')
    parser.add_argument('--candidate-validation-name', default='validation', help='Select a fresh regression record after a fixture-only repair; preserve earlier failures')
    parser.add_argument('--experiment-context', type=Path, help='Immutable current-cycle status/evidence JSON; grants no authority')
    parser.add_argument('--priorities-note', help='Current remaining-work note under advisor_eval, replacing generic priority text')
    parser.add_argument('--objective-note', help='Current user objective and enduring bounds under advisor_eval, replacing the historical objective paragraph')
    parser.add_argument('--architecture-note', help='Current source/test navigation under advisor_eval; links to preserved history instead of duplicating it')
    parser.add_argument('--resume-note', help='Complete continuation prompt under advisor_eval; bind the exact text in the final verification receipt')
    args = parser.parse_args()
    context = experiment_context(args.experiment_context)
    experiment = experiment_sections(context)
    session_experiment, budget_experiment = experiment_json(context)
    if not re.fullmatch(r'[a-z0-9_]+', args.prefix):
        raise ValueError('Expected a contained evidence prefix')
    if not re.fullmatch(r'_candidate[0-9]*', args.candidate_suffix):
        raise ValueError('Expected a contained candidate suffix')
    if not re.fullmatch(r'validation[0-9]*', args.candidate_validation_name):
        raise ValueError('Expected a contained candidate validation directory')
    component = (EVAL / args.component).resolve()
    component.relative_to(EVAL.resolve())
    if not component.is_file():
        raise ValueError('A completed component note is required')
    related = []
    for name in args.related:
        path = (EVAL / name).resolve()
        path.relative_to(EVAL.resolve())
        if not path.is_file():
            raise ValueError('A completed related note is required')
        related.append(path)
    priorities_note = None
    if args.priorities_note:
        path = (EVAL / args.priorities_note).resolve()
        path.relative_to(EVAL.resolve())
        priorities_note = path.read_text(encoding='utf-8')
        if not priorities_note.strip():
            raise ValueError('The remaining-work note must be nonempty')
        if path not in related:
            related.append(path)
    objective_note = None
    if args.objective_note:
        path = (EVAL / args.objective_note).resolve()
        path.relative_to(EVAL.resolve())
        objective_note = path.read_text(encoding='utf-8')
        if not objective_note.strip():
            raise ValueError('The current-objective note must be nonempty')
        if path not in related:
            related.append(path)
    architecture_note = None
    if args.architecture_note:
        path = (EVAL / args.architecture_note).resolve()
        path.relative_to(EVAL.resolve())
        architecture_note = path.read_text(encoding='utf-8')
        if not architecture_note.strip():
            raise ValueError('The architecture navigation note must be nonempty')
        if path not in related:
            related.append(path)
    resume_note = None
    if args.resume_note:
        path = (EVAL / args.resume_note).resolve()
        path.relative_to(EVAL.resolve())
        resume_note = path.read_text(encoding='utf-8')
        if not resume_note.strip():
            raise ValueError('The continuation prompt must be nonempty')
        if path not in related:
            related.append(path)
    n = args.release
    base = EVAL / 'runs' / args.prefix
    installed = read(str(base) + '_installed/record.json')
    candidate_report = Path(str(base) + args.candidate_suffix) / args.candidate_validation_name / 'report.json'
    candidate = read(candidate_report)
    validation = read(str(base) + '_installed_validation/report.json')
    manifest = read(installed['deployment_manifest'])
    assert installed['version'] == manifest['version'] == f'2.{n - 200}.0-alpha'
    assert installed['all_repository_files_match'] and candidate['passed'] and validation['passed']
    assert candidate['policy_digest'] == validation['policy_digest'] == installed['policy']['policy_digest']
    assert candidate['test_files'] == validation['test_files']
    current_tests = {str(p.relative_to(ROOT)): sha(p) for p in sorted((ROOT / 'tests').rglob('*'))
                     if p.is_file() and (p.suffix == '.lua' or p.name.startswith('test_advisor_') and p.suffix == '.py')}
    assert current_tests == validation['test_files'], 'The complete test/dependency inventory changed after validation'
    target = Path(installed['installed'])
    assert all(sha(ROOT / p) == h == sha(target.parent / p)
               for p, h in installed['policy']['policy_files'].items())
    # Runtime bytes are frozen, but the user may legitimately change settings
    # while the running game remains open. The installer verified preservation
    # at deployment; finalization records later settings without restoring them.
    config_observed = sha(target / 'config.lua')
    config_at_install = manifest['configSHA256'].lower()
    assert re.fullmatch('[0-9a-f]{64}', config_at_install)
    for filename, expected in {
        'Immolate-v2.16.dll': '34598478571391d272c1e1a837832061bd767a09ab552bb61ef3458e24e9d751',
        'Immolate-advisor-a569e1cb834352c23fed5eac3db30059279a57fe1eaf46e71cc8a594b672f885.dll':
            'a569e1cb834352c23fed5eac3db30059279a57fe1eaf46e71cc8a594b672f885',
    }.items():
        assert sha(target / filename) == expected == sha(ROOT / 'Brainstorm' / filename)
    previous_record = read(EVAL / f'SESSION_RESET_{args.previous}.json')['installed']
    previous_natives = {p: h for p, h in previous_record['policy']['policy_files'].items() if p.endswith('.dll')}
    for path, expected in previous_natives.items():
        assert sha(ROOT / path) == expected == sha(target.parent / path), 'Existing native dependency changed'
    from install_slice import loader_name
    active_native = loader_name((target / 'Core/Brainstorm.lua').read_text(encoding='utf-8'))
    active_hash = sha(target / active_native)
    assert active_hash == sha(ROOT / 'Brainstorm' / active_native)
    sidecar = re.fullmatch(r'Immolate-advisor-([0-9a-f]{64})\.dll', active_native)
    if sidecar:
        assert sidecar[1] == active_hash
    native_unchanged = previous_natives.get('Brainstorm/' + active_native) == active_hash
    native_evidence = manifest.get('nativeEvidence')
    if not native_unchanged:
        assert native_evidence and sha(native_evidence['path']) == native_evidence['sha256']
        bound_native = read(native_evidence['path'])
        assert bound_native['dll'] == {'path': 'Brainstorm/' + active_native, 'sha256': active_hash}
        assert bound_native['runtime_files']['Brainstorm/Core/Brainstorm.lua'] == sha(target / 'Core/Brainstorm.lua')
    lua = (Path(str(base) + '_installed_validation') / 'lua.log').read_text(encoding='utf-8')
    py = (Path(str(base) + '_installed_validation') / 'python.log').read_text(encoding='utf-8')
    lua_count = int(re.search(r'(\d+)/(\d+) fixtures passed', lua)[1])
    py_count = int(re.search(r'Ran (\d+) tests', py)[1])
    receipt = Path(str(base) + '_final')
    receipt.mkdir(exist_ok=False)
    previous = receipt / 'previous_documentation'
    previous.mkdir()
    preserved_experiment = {}
    if context is not None:
        saved_context = receipt / 'experiment_context'; saved_context.mkdir()
        frozen_refs = {'context': {'path': context['path'], 'sha256': context['sha256']},
                       **context['verified_evidence']}
        for role, ref in frozen_refs.items():
            source = ROOT / ref['path']; copy = saved_context / (role + source.suffix)
            shutil.copy2(source, copy)
            if sha(copy) != ref['sha256'] or sha(source) != ref['sha256']:
                raise ValueError('Experiment evidence changed while archiving: ' + role)
            preserved_experiment[str(copy.relative_to(ROOT))] = ref['sha256']
    current = [ROOT / name for name in ('ADVISOR_START_HERE.md', 'ADVISOR_HANDOFF.md', 'ADVISOR_RESUME_PROMPT.md')]
    for path in current:
        shutil.copy2(path, previous / path.name)
    digest = installed['policy']['policy_digest']
    facts = f'''Installed checkpoint: **2.{n - 200}.0-alpha**, {installed['installed_at']}.
All {len(manifest['files'])} deployment and {len(installed['policy']['policy_files'])} frozen product/dependency files match repository and installation.
Candidate and exact-installed full regression: **{lua_count} Lua fixtures / {py_count} Python tests pass**, unchanged frozen policy and tests; 60s cap per suite.
Policy digest: `{digest}`.
Backup: `{installed['backup']}`.
Current settings and every existing native DLL were preserved. Active native file: `{active_native}`. Activation of this installation has not been confirmed; it waits for the user's normal restart. Any earlier observed loaded version is recorded separately in the component evidence.
'''
    limits = (experiment['navigation'] if context is not None else
              experiment['outcomes'] + '\n\n' + experiment['budget']) + '''

Preserve every tracked and untracked change on codex/exact-search-speedups. No commit/reset/clean/deletion/PR. Tools must never launch Balatro.exe, foreground/restart/stop/control the running game, execute live gameplay, or read/evaluate player saves. Product save/load remains user-keyed. Product autonomous execution requires an explicit user-started mode, with a stop control; installing an update does not activate it. Never restore old settings. Preserve existing native DLLs; changed native work requires its existing sidecar/evidence gate. No neural/GPU training or scheduled tasks. Retry 270 keeps its persistent five-report protection; metadata restoration or changing marks never renews the count. Source evaluation keeps retries disabled and clean.

'''
    limits += '\n\n' + (objective_note or 'The objective remains minimum expected real time to finish all 20 challenges, including failures, retries, opening/filter costs, computation and user actions. Jokerless is primary and Knife\'s Edge secondary. Neither 50% nor 75% per-challenge target is demonstrated. Preserve deterministic common-world comparisons, 140000 ordinary/50000 shop/25000 consumable budgets and 70-score fast clear, Glass/population conservation, whole-inventory Perkeo/Negative/Observatory, Kings Strength/Death, exact Yorick/Burnt and safe growth. Unsupported mechanics remain explicit.') + '\n'
    evidence = f'''Evidence: `runs/{args.prefix}{args.candidate_suffix}/{args.candidate_validation_name}/report.json`, `runs/{args.prefix}_installed/record.json` and `policy/`, `runs/{args.prefix}_installed_validation/report.json`, and `runs/{args.prefix}_final/final_verification.json`. Exact current checkpoint hashes are also in `SESSION_RESET_{n}.json`.
'''
    session = f'# Current checkpoint — installed 2.{n - 200}.0-alpha\n\n{facts}\n{args.summary}\n\nComponent/source/test scope: `{args.component}`.\n\n{evidence}\n{limits}'
    (EVAL / f'SESSION_RESET_{n}.md').write_text(session, encoding='utf-8')
    priorities = f'''# Next priorities after {n}

{args.summary}

{experiment['navigation']}

1. Use preserved development post-mortems to repair complete resource comparisons: early play versus discard timing; later observed redraws; owned HangedMan/Moon use versus hold across the same hands/discards. Keep unsupported scope explicit. No named-hand forcing or score-cap increase substitutes for the missing comparison.
2. Finish opening-route viability: actual cash thresholds, slots, pack opportunity costs, Blue generation, deck development and known boss restrictions. Catalog matches are not affordable acquisition or survival.
3. After separately authorized prospective experiments, inspect exact first divergences and observed-information counterfactuals. Selected source05/06/10 and source11 are development data, never untouched holdouts. See `POSTMORTEM_METHOD_282.md` and `runs/postmortem282_readonly/` for read-only audits; already fixed 275 Planet preparation and 278 Fool are not new work.
4. Preregister stable paired seed cohorts, full outcome accounting, progression milestones and real-time costs; separate development, model selection and untouched terminal confirmation. Mean failure depth alone can reward losing slowly. Test interactions before tuning the six existing heuristic weights. No win odds, player qualification or stronger-than-human performance follows from four common worlds or passing fixtures.
5. Keep the twenty-challenge roadmap, Knife's Edge work and unfinished expanded Legendary route evaluation visible. Old weakness263 paperwork was consumed by weakness266's 16-worker pilot (6 losses / 5 timeouts / 5 unsupported); it is not authority.

Read `SESSION_RESET_{n}.md`, relevant `ARCHITECTURE_MAP_{n}.md` sections and `{args.component}`. All old budgets are closed; no source/search/replay/complete worker is authorized by this document. Routine fixtures and read-only analysis remain authorized.
'''
    if priorities_note is not None:
        priorities = f'''# Next priorities after {n}

{args.summary}

{experiment['navigation']}

{priorities_note}

Read `SESSION_RESET_{n}.md`, relevant `ARCHITECTURE_MAP_{n}.md` sections and `{args.component}`. This note grants no experiment authority. Routine fixtures and read-only analysis remain authorized.
'''
    (EVAL / f'NEXT_PRIORITIES_{n}.md').write_text(priorities, encoding='utf-8')
    architecture = (EVAL / f'ARCHITECTURE_MAP_{args.previous}.md').read_text(encoding='utf-8')
    (EVAL / f'ARCHITECTURE_MAP_{n}.md').write_text(f'''# Current architecture update {n}

This leading update supersedes current-state or pending wording in the preserved navigation below. Current checkpoint: `SESSION_RESET_{n}.md`; priorities: `NEXT_PRIORITIES_{n}.md`.

{facts}
{args.summary}

{experiment['navigation']}

Current changed-source/test/component map: `{args.component}`. The earlier component map remains useful for unchanged areas; its version and evidence claims are historical. No new experiment authority follows from this map.

---

'''+architecture, encoding='utf-8')
    if architecture_note is not None:
        (EVAL / f'ARCHITECTURE_MAP_{n}.md').write_text(f'''# Current architecture —{n}

Current installation, outcomes, exact hashes and authority: `SESSION_RESET_{n}.md`
and `.json`. Current work: `NEXT_PRIORITIES_{n}.md`. Later status supersedes
historical pending wording. This navigation grants no experiment authority.

Changed-source/test/component scope: `{args.component}`.

{architecture_note}

Preserved earlier navigation: `ARCHITECTURE_MAP_{args.previous}.md`; read only
relevant sections. Earlier documents and their verification receipts remain
intact. They are not current installation or experiment authority.
''', encoding='utf-8')
    start = f'''# Balatro advisor — start here

**Current checkpoint: installed 2.{n - 200}.0-alpha.** Read in order:

1. `tools/advisor_eval/SESSION_RESET_{n}.md` — current installation, outcomes and boundaries.
2. `tools/advisor_eval/NEXT_PRIORITIES_{n}.md` — concrete remaining work.
3. Relevant `tools/advisor_eval/ARCHITECTURE_MAP_{n}.md` sections — source/test/component navigation.

Full continuation prompt: `ADVISOR_RESUME_PROMPT.md`. Exact hashes: `tools/advisor_eval/SESSION_RESET_{n}.json` and `tools/advisor_eval/runs/{args.prefix}_final/final_verification.json`.

{args.summary}

{facts}
Current outcomes, limitations and the exact active-or-closed experiment ledger
are in the session record above. No navigation document grants experiment
authority. Preserve all dirty/untracked work and current settings; do not
commit, reset, clean, delete or create a PR. Keep the running game undisturbed.
'''
    (ROOT / 'ADVISOR_START_HERE.md').write_text(start, encoding='utf-8')
    handoff = (ROOT / 'ADVISOR_HANDOFF.md').read_bytes()
    (ROOT / 'ADVISOR_HANDOFF.md').write_bytes((f'# {str(installed["installed_at"])[:10]} — installed {n} checkpoint\n\n{facts}\n{args.summary}\n\n{evidence}\n{experiment["handoff"]} Full boundaries: `tools/advisor_eval/SESSION_RESET_{n}.md`.\n\n').encode('utf-8') + handoff)
    resume = f'''Continue development in C:\\Users\\trevo\\Documents\\GitHub\\Brainstorm-Rerolled-Rerolled.

Read ADVISOR_START_HERE.md first, then tools/advisor_eval/SESSION_RESET_{n}.md and NEXT_PRIORITIES_{n}.md; use relevant ARCHITECTURE_MAP_{n}.md sections. Read only relevant dated ADVISOR_HANDOFF.md sections. Later status supersedes historical pending/unchecked wording. Do not consume the whole historical handoff or depend on old chat/subagent/tool memory.

{facts}
{args.summary}

Component details: tools/advisor_eval/{args.component}.
{evidence}
{limits}
Read the original twelve-outcome audit in runs/jokerless271_push_20260912_214242/FINAL_SOURCE_EVIDENCE_280.md and JSON if needed. Preserve original errors/timeouts/unsupported/censored results, source traces and synthetic all_unlocked_discovered_v1 qualification limits. Read-only post-mortems are in POSTMORTEM_METHOD_282.md and runs/postmortem282_readonly/. They propose counterfactuals without proving a rescued run. Do not repeat completed fixes or use inspected dependent seeds as unseen holdouts. Existing Reddit/wiki hypotheses are documented in JOKERLESS_RESEARCH_277.md and JOKERLESS_SOURCE_MECHANICS_277.md; do not convert them into win rates or hardcode challenge-name recommendations.

Resume useful analysis and coherent implementation autonomously, with concise candid updates. Install each appropriately tested runtime slice using tools/advisor_eval/install_slice.py with explicit files, backups, current settings/save protection and verified hashes. Freeze exact installed bytes and run bounded final regression; preserve any earlier failed evidence separately. Maintain current checkpoint/priority/architecture navigation, ADVISOR_START_HERE.md, ADVISOR_HANDOFF.md, this prompt and evidence/budget ledgers.
'''
    (ROOT / 'ADVISOR_RESUME_PROMPT.md').write_text(resume_note or resume, encoding='utf-8')
    dump = lambda path, data: path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    dump(EVAL / f'SESSION_RESET_{n}.json', {'release': n, 'installed': installed,
         'candidate': candidate, 'validation': validation, **session_experiment})
    dump(receipt / 'runtime_slices.json', {'release': n, 'installed_record': str(base) + '_installed/record.json',
         'component': args.component, 'policy_digest': digest, 'summary': args.summary,
         'experiment_context': context})
    dump(receipt / f'FINAL_BUDGET_{n}.json', {'release': n, **budget_experiment,
         'routine_validation': candidate['runs'] + validation['runs']})
    docs = current + [EVAL / f'{prefix}_{n}.{suffix}' for prefix, suffix in
        [('SESSION_RESET','md'), ('SESSION_RESET','json'), ('NEXT_PRIORITIES','md'), ('ARCHITECTURE_MAP','md')]] + [component] + related
    dump(receipt / 'final_verification.json', {'verified_at_utc': datetime.now(timezone.utc).isoformat(),
         'version': manifest['version'], 'policy_digest': digest, 'installed_matches': True,
         'config_sha256_observed': config_observed,
         'config_sha256_at_install': config_at_install,
         'config_changed_since_install': config_observed != config_at_install,
         'config_restored_or_modified_by_finalizer': False, 'native_unchanged': native_unchanged,
         'active_native_file': active_native, 'active_native_sha256': active_hash,
         'existing_native_files_preserved': previous_natives, 'native_evidence': native_evidence,
         'documents': {str(p.relative_to(ROOT)): sha(p) for p in docs},
         'preserved_documents': {str(p.relative_to(ROOT)): sha(p) for p in previous.iterdir()},
         'candidate_report': sha(candidate_report),
         'installed_report': sha(str(base) + '_installed_validation/report.json'),
         'experiment_context': context, 'preserved_experiment_evidence': preserved_experiment})
    print(json.dumps({'release': n, 'lua': lua_count, 'python': py_count, 'policy_digest': digest,
                      'receipt': str(receipt)}))


if __name__ == '__main__':
    main()
