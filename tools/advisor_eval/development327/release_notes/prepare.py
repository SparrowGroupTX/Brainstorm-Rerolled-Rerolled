"""Prepare diagnostic-release context from existing receipts; no experiment or game access."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
EVAL = ROOT/'tools/advisor_eval'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def reference(path):
    return {'path': path.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def write(name, value):
    with (HERE/name).open('x', encoding='utf-8', newline='\n') as output:
        json.dump(value, output, indent=2)
        output.write('\n')


def main():
    previous = read(EVAL/'development326/release_notes/context.json')
    previous_limits = read(EVAL/'development326/release_notes/limits.json')
    audit_path = EVAL/'development327/audit.json'
    audit = read(audit_path)
    measurement_path = EVAL/'development327/archive_codec/prospective_export_size.json'
    measurement = read(measurement_path)
    assert not audit['errors'] and audit['actual']['events'] == 1831
    assert measurement['complete'] and not measurement['errors'] and measurement['events'] == 1831
    assert all(row['declared_transform_only_verified'] for row in measurement['files'])
    release_counts = {key: 0 for key in previous['release_counts']}
    evidence = {
        'authority': previous['evidence']['authority'],
        'outcomes': previous['evidence']['outcomes'],
        'budget': previous['evidence']['budget'],
        'previous_final': reference(EVAL/'runs/storage326_final/final_verification.json'),
        'read_plan': reference(EVAL/'development327/read_plan.json'),
        'capture': reference(EVAL/'development327/capture.json'),
        'analysis_plan': reference(EVAL/'development327/analysis_plan.json'),
        'public_log_audit': reference(audit_path),
        'public_log_index': reference(EVAL/'development327/events_index.json'),
        'refresh_fix': reference(EVAL/'development327/refresh_fix/manifest.json'),
        'fingerprint_fix': reference(EVAL/'development327/fingerprint_fix/manifest.json'),
        'compact_inspection': reference(EVAL/'development327/context_reader/manifest_final.json'),
        'prospective_export_size': reference(measurement_path),
        'deferred_brj3_compatibility': reference(EVAL/'development327/context_reader/brj3_followup_deferred/manifest.json'),
    }
    limits = {
        'schema': 1, 'kind': 'release327_closed_historical_limits', 'status': 'CLOSED',
        'counts_scope': 'historical_closed_cycle', 'release_counts': release_counts,
        'historical_counts': previous['counts'],
        'historical_complete_attempt_outcomes': previous['complete_attempt_outcomes'],
        'historical_budget': previous_limits['historical_budget'],
        'original_cycle_expires_at_utc': previous_limits['original_cycle_expires_at_utc'],
        'closure_written_at_utc': previous_limits['closure_written_at_utc'],
        'remaining_authority_seconds': 0, 'unused_capacity': 'closed',
        'C09': 'never_registered_reserved_or_run', 'closed_unused_slots': previous_limits['closed_unused_slots'],
        'evidence': evidence,
        'release_scope': 'User-authorized passive public-log capture/review, repository implementation, manufactured regression and bounded offline archive/export transformations. Zero original-source, captured-state policy, search or complete-attempt jobs. No game control, save/profile evaluation or executable reads.',
        'storage_scope': {'total_allowance_bytes': 1073741824, 'legacy_v1_and_v2_counted_together': True,
                          'automatic_deletion': False, 'current_logs_deleted_or_rewritten': False,
                          'prior_cleanup_326': 'Completed one-time deletion; not continuing authority.',
                          'format_shipped': 'BRJ2', 'brj3_scope': 'Detached development evidence only.'},
        'public_log_scope': {'selected_files': 8, 'selected_events': 1831, 'declared_loaded_version': '2.126.0-alpha',
                             'loaded_hash_attestation': False, 'prior_prefix_audited': False,
                             'first_predecessor_verified': False, 'losses_consistent_with_threshold_and_terminal': 3,
                             'verified_wins_from_this_tail': 0, 'aggregate_prior_win': 'Outside selected suffix; unaudited.'},
        'prospective_transform': {'originals_unchanged': True, 'raw_internal_identity_text_retained': False,
                                  'all_other_decoded_values_unchanged': True,
                                  'semantics': 'Public export redaction plus opaque identity metadata; not lossless replacement of historical raw internal export.'},
        'performance_limits': ['Cooperative scheduling does not bound each operation to four milliseconds.',
                               'Elapsed timings overlap and are not CPU utilization.',
                               'Selected-data export size is not live throughput or measured post-install speedup.',
                               'Dropped, incomplete, corrupt, unflushed and out-of-tail observations are not imputed.'],
        'outcome_limits': 'No new policy complete attempt, verified Jokerless win, representative win rate, 50%/75% per-challenge target, achievement completion or stronger-than-human result.',
        'ordinary_score_caps': {'ordinary': 140000, 'shop': 50000, 'consumable': 25000, 'fast_clear': 70},
        'current_settings_native_files_retry_and_session_limits': 'Preserved; no cap renewal or native changes.',
    }
    write('limits.json', limits)
    evidence = {**evidence, 'limits': reference(HERE/'limits.json')}
    context = {
        'schema': 1, 'kind': 'checkpoint_experiment_context', 'status': 'CLOSED',
        'created_at_utc': datetime.now(timezone.utc).isoformat(), 'release': 327,
        'summary': 'Release 327 diagnoses current public-log overhead and repairs cooperative pack/blind scheduling plus repeated full runtime snapshots outside decision phases. It corrects prospective auto-run exports that serialized internal fingerprint/before/after state and could bypass public concealed-identity redaction, replacing those identity strings with opaque SHA256/length metadata while retaining the redacted public observation and exact internal freshness checks. It keeps BRJ2 and adds a strict 16 KiB inspection index with exact hash-bound selected-event extraction. The selected loaded-2.126 suffix contains 1831 events in eight stable files, 16074649 stored bytes and 303399440 expanded bytes. A bounded offline prospective export comparison changed only 951 declared identity fields and produced 5085667 stored /130016334 expanded bytes with all other decoded values unchanged; captured originals remain preserved. These are diagnostic and serialization results, not measured live post-install speed or new policy terminal validation. Generated records own final testing and installation facts; the original cycle remains CLOSED with zero release-327 experiment jobs.',
        'outcome_summary': 'Historical complete-attempt outcomes remain one selected synthetic win (C01, frozen policy300), three losses (C03/C05/C08) and four timeouts (C02/C04/C06/C07), with zero errors, unsupported or separately labeled censored results. C01 won Red Gold final Cerulean Bell 705600/400000 in 172.14000000001397 seconds, with 225 actions, 28 exact plays and 13 preserved ordinary score-cap overruns. C07 retained all163 shared C06 inputs/actions; C08 lost Pillar592/600 with all22 C05 inputs/actions unchanged. C09 was never registered, reserved or run. Policies321 through327 have no complete-attempt result. Separate release327 passive observations declare loaded2.126 and contain three threshold-consistent losses: Pillar592/600, Ante5 Big18340/37500 and final AmberAcorn98808/400000. AmberAcorn has GAME_OVER and a verified loss receipt despite incidental won_field=true. The session aggregate includes one win and four losses across five starts, but its earlier win and other earlier outcome lie outside the selected suffix and are unaudited. No new win is inferred. Current external logs and exact captured copies are preserved; the prior release326 one-time cleanup does not authorize another deletion.',
        'limits_summary': 'Historical source attempts are selected dependent synthetic all_unlocked_discovered_v1 development data, not player odds, representative cohorts, untouched holdouts or general adapter qualification. The new player-log suffix is selected passive evidence, not a representative win-rate cohort or a new source/captured gameplay experiment. No complete Jokerless win, 50%/75% per-challenge target, achievement completion or human superiority is demonstrated. Declared loaded2.126 version strings do not attest module hashes. The new release activates on the user normal restart; no tool controls the game or reads saves/profiles for evaluation. Cooperative yielding is not a hard latency bound and inclusive timings must not be added as independent CPU usage. Export-size gains on selected historical data are not measured live speedups. Summaries preserve exact retrieval, not all text in context; future public export intentionally removes raw internal identity text while preserving other observations. Invalid, incomplete, unflushed and out-of-tail evidence remains unknown. No observation, installation, resumed product search or storage change renews retry, session or historical experiment limits.',
        'budget_summary': previous['budget_summary'].replace('release-326', 'release-327'),
        'counts_scope': 'historical_closed_cycle', 'counts': previous['counts'], 'release_counts': release_counts,
        'complete_attempt_outcomes': previous['complete_attempt_outcomes'],
        'verified_complete_win': True, 'verified_complete_win_scope': 'historical_C01_policy300_only',
        'release_verified_complete_win': False, 'unused_capacity': 'closed', 'remaining_authority_seconds': 0,
        'evidence': evidence,
        'preparation_status': 'documentation_inputs_only_full_validation_install_owned_by_generated_records',
        'release_observation_scope': {'authorization': 'User asked to inspect current logs, diagnose defects and reduce context/log bulk while preserving information.',
                                     'read_only_original_capture': True, 'selected_files': 8, 'events': 1831,
                                     'stored_bytes': 16074649, 'decoded_bytes': 303399440,
                                     'first_sequence': 2629, 'last_sequence': 4459,
                                     'first_utc': '2026-09-15T17:53:55Z', 'last_utc': '2026-09-15T18:09:50Z',
                                     'version_declared': 'Brainstorm v2.126.0-alpha', 'loaded_module_hashes_attested': False,
                                     'prior_prefix_and_first_predecessor': 'Outside capture; not verified.',
                                     'source_save_profile_reads': False, 'game_control': False,
                                     'current_originals_deleted_or_rewritten': False,
                                     'offline_archive_export_transformations': 'Bounded derived artifacts only; no gameplay rescoring or new attempts.'},
    }
    # Keep inherited canonical prose readable when identifiers and numbers meet.
    for key in ('outcome_summary', 'limits_summary'):
        for old, new in [('all163', 'all 163'), ('all22', 'all 22'), ('Pillar592', 'Pillar 592'),
                         ('Policies321', 'Policies 321'), ('through327', 'through 327'), ('release327', 'release 327'),
                         ('release326', 'release 326'), ('loaded2.126', 'loaded 2.126'), ('Ante5', 'Ante 5'),
                         ('Big18340', 'Big 18340'), ('AmberAcorn98808', 'Amber Acorn 98808'), ('AmberAcorn', 'Amber Acorn')]:
            context[key] = context[key].replace(old, new)
    write('context.json', context)
    files = [EVAL/'LOG_DIAGNOSTICS_327.md'] + sorted(path for path in HERE.iterdir() if path.is_file())
    write('manifest.json', {'schema': 1, 'preparation_only': True,
                            'files': [reference(path) for path in files],
                            'full_validation_and_installed_facts': 'Owned by root generated frozen records.',
                            'new_experiment_jobs': release_counts})
    print(json.dumps(reference(HERE/'manifest.json')))


if __name__ == '__main__':
    main()
