"""Seal passive evidence/release notes with explicit fresh, unspent authority."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
EVAL = ROOT / 'tools/advisor_eval'

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def ref(path):
    return {'path': path.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}

def write(name, value):
    with (HERE / name).open('x', encoding='utf-8', newline='\n') as output:
        json.dump(value, output, indent=2)
        output.write('\n')

authority_path = EVAL / 'runs/loss328_validation_20260915/authority.json'
status_path = EVAL / 'runs/loss328_validation_20260915/status_initial.json'
historical_path = EVAL / 'development327/release_final/context.json'
authority, status, old = read(authority_path), read(status_path), read(historical_path)
assert ref(authority_path)['sha256'] == '7bd5086a7de41d3f1150727fb7fad4075dc9fa7f92e4c2b249abaf0e1b7ce0e2'
assert ref(status_path)['sha256'] == '70e000b2efb2fae5df72e4eedfa365ac9bd54ddb0730bbd9893e5d6208b5e081'
assert status['status'] == 'ACTIVE' and not any(status['counts'].values())
assert not status['registered_jobs'] and not status['launched_jobs']
assert authority['limits']['total_worker_seconds'] == 1260

summary = ('Release328 restores an existing complete remaining-blind comparison when an active Purple card is retained. '
           'Exact after_discard preparation already excludes selected Purple generation requiring an unknown Tarot, '
           'and the continuation never discards again. Approximate scorers retain the blanket blocker. '
           'A manufactured Banner/retained-Purple case changes discard to play: all eight play-first worlds clear '
           'the constructed800 threshold and all eight discard-first worlds fail, in1233 scores under140000. '
           'This is a local regression result, not a replayed Pillar rescue. Generated candidate/installed records '
           'own final tests and installation. No new authorized experiment has been registered or launched at this checkpoint snapshot.')
outcomes = ('The fresh loss328 validation batch has zero registered or executed jobs and no terminal outcome. '
            'Historical C01 frozenpolicy300 remains one selected synthetic win; historical C03/C05/C08 are losses '
            'and C02/C04/C06/C07 are timeouts. Those outcomes belong to the closed gold299 cycle, not the new batch. '
            'The selected passive loaded2.126 suffix has three threshold-consistent losses: Pillar592/600, '
            'Ante5Big18340/37500 and Ante8AmberAcorn98808/400000. Its earlier aggregate win lies outside the '
            'inspected suffix and remains unaudited. No328 terminal rescue, new win or Gold award is inferred.')
limits_summary = ('Selected dependent development seeds and manufactured fixtures are not representative calibration '
                  'or unseen holdouts. No verified complete Jokerless win, numerical player win odds, fifty/seventy-five '
                  'percent per-challenge target, achievement completion or human superiority is demonstrated. '
                  'Use only redacted public snapshots and recorded advice/action metadata; old raw internal fingerprint '
                  'text may contain concealed identities. Preserve all original logs, failures, unsupported/timeouts '
                  'and censored outcomes. No saves/profiles for evaluation, seed search, game control, native changes, '
                  'training or automation. Installed activation remains a normal user restart. Existing score, '
                  'population, inventory, retry and session safeguards remain unchanged.')
budget = ('Fresh user authorization permits up to six detached public-state baseline/candidate comparison jobs '
          'at30 seconds each and six complete simulated attempts at180 seconds each,1260 seconds of total reserved '
          'worker caps. At this snapshot zero jobs are registered/launched and zero seconds are reserved/spent. '
          'Root must prospectively freeze/register exact policy, adapter, profile, source and runtime provenance '
          'with one-use limits before execution. No search or other source component is authorized. All old quotas '
          'remain CLOSED, including the gold299 cycle38 spent jobs and22 closed unused slots; no old capacity is reopened.')
for old_text, new_text in [('Release328', 'Release 328'), ('constructed800', 'constructed 800'), ('in1233', 'in 1233'),
                         ('under140000', 'under 140000'), ('frozenpolicy300', 'frozen policy300'), ('loaded2.126', 'loaded 2.126'),
                         ('Pillar592', 'Pillar 592'), ('Ante5Big18340', 'Ante 5 Big 18340'), ('Ante8AmberAcorn98808', 'Ante 8 Amber Acorn 98808'),
                         ('No328', 'No 328'), ('at30', 'at 30'), ('at180', 'at 180'), ('cycle38', 'cycle 38'), ('and22', 'and 22')]:
    summary, outcomes, budget = [text.replace(old_text, new_text) for text in (summary, outcomes, budget)]

limits = {'schema': 1, 'kind': 'release328_fresh_loss_validation_limits', 'status': 'ACTIVE',
          'fresh_authority': ref(authority_path), 'initial_status': ref(status_path),
          'historical_context': ref(historical_path), 'historical_authority': 'CLOSED',
          'counts': status['counts'], 'complete_attempt_outcomes': status['complete_attempt_outcomes'],
          'registered_jobs': 0, 'launched_jobs': 0, 'reserved_worker_seconds': 0, 'actual_worker_seconds': 0,
          'fresh_limits': authority['limits'], 'remaining_authority_seconds': 1260,
          'unused_capacity': 'retained_under_existing_authority',
          'release_scope': 'Public-only preserved-log postmortem, repository implementation and manufactured regression; no experiment job.',
          'score_caps': {'ordinary': 140000, 'shop': 50000, 'consumable': 25000, 'fast_clear': 70},
          'component_manifest': ref(EVAL / 'development328/pillar_component/integration_manifest.json'),
          'component_report': ref(EVAL / 'development328/pillar_component/report.json'),
          'public_trace': ref(EVAL / 'development328/public_trace/run3.json'),
          'outcome_limits': limits_summary,
          'unchanged': ['Deterministic complete common-world comparisons', 'Whole inventory and capacity',
                        'Population and Glass safeguards', 'Perkeo/Observatory/Negative handling',
                        'Current settings and native DLLs', 'Persistent manual retry and product session caps',
                        'Original current logs and historical evidence']}
write('limits.json', limits)
context = {'schema': 1, 'kind': 'checkpoint_experiment_context', 'status': 'ACTIVE',
           'created_at_utc': datetime.now(timezone.utc).isoformat(), 'release': 328,
           'summary': summary, 'outcome_summary': outcomes, 'limits_summary': limits_summary, 'budget_summary': budget,
           'counts': status['counts'], 'complete_attempt_outcomes': status['complete_attempt_outcomes'],
           'verified_complete_win': False, 'unused_capacity': 'retained_under_existing_authority',
           'remaining_authority_seconds': 1260,
           'evidence': {'authority': ref(authority_path), 'outcomes': ref(status_path), 'budget': ref(status_path),
                        'limits': ref(HERE / 'limits.json')},
           'historical_closed_context': ref(historical_path),
           'historical_closed_counts': old['counts'], 'historical_closed_outcomes': old['complete_attempt_outcomes'],
           'diagnostic_evidence': {'component': ref(EVAL / 'development328/pillar_component/report.json'),
                                   'manifest': ref(EVAL / 'development328/pillar_component/integration_manifest.json'),
                                   'trace': ref(EVAL / 'development328/public_trace/run3.json')},
           'preparation_status': 'documentation_inputs_only_final_validation_and_install_owned_by_generated_records'}
write('context.json', context)
files = [EVAL / 'PURPLE_CONTINUATION_328.md'] + sorted(p for p in HERE.iterdir() if p.is_file())
write('manifest.json', {'schema': 1, 'preparation_only': True, 'files': [ref(p) for p in files]})
print(json.dumps({'status': context['status'], 'jobs': 0, 'remaining_authority_seconds': 1260,
                  'context': ref(HERE / 'context.json'), 'manifest': ref(HERE / 'manifest.json')}))
