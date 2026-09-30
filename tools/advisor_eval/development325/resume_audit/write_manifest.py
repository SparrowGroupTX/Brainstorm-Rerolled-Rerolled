"""Bind a source-only preimplementation audit. Never imports product/evaluation code."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
EXPECTED = {
    'Brainstorm/Advisor/auto_run.lua': '9d7b3734094ca7c4fd344cfe7d5be2970f3ae5c6876af2a705b17074e526a4bf',
    'Brainstorm/Core/auto_run_product.lua': 'db73ff21f768719961da9b40b3e36fb59e25496ea977c82e6e814f71eb2b5795',
    'Brainstorm/Core/auto_terminal.lua': '341f2c7e0163780aeafa6c37a727a16488402d33e1ee0abe7331a232b4fe7b00',
    'tests/advisor_auto_run.lua': 'e1a18a13f0e8c4fa9f8a42b1a6280038d2aa261ca94ab25507bc572952e88388',
    'tests/advisor_auto_run_product.lua': 'dfec9c85b2ab331c44ca829751a4fca99878aeaf85f0e9a17d5d6bedbce5e650',
    'tests/advisor_auto_observation.lua': '8bc691700b20b7956e430879200abee1e2cc5fee10866f84e3d7a7a49ca4d346',
    'Brainstorm/Core/Brainstorm.lua': '18b3fc7a2e11015aaafc6947b29851ecea74a9938fbba8d88af3f5db69413b3a',
    'Brainstorm/UI/advisor.lua': '4034c88ce8cd2fc7e4ae4da175aac63d02c9243e64f3872e75e96531d1c4c454',
    'ADVISOR_START_HERE.md': 'cc90517270e362471c6662616f145d04018ebf8ee04fba919ddfe56eff6eab15',
    'tools/advisor_eval/ARCHITECTURE_MAP_324.md': 'c01d03ee106e3f172aca843ab55de0134b1eb14764ee24e1e810e4977ec14eed',
}

def sha(data):
    return hashlib.sha256(data).hexdigest()

observed = []
for relative, digest in EXPECTED.items():
    data = (ROOT / relative).read_bytes()
    observed.append({'path': relative, 'inspected_sha256': digest,
                     'current_sha256_at_report': sha(data),
                     'still_matches_inspected_bytes': sha(data) == digest})

references = {
    'start_resets_session': ['Brainstorm/Advisor/auto_run.lua:231', 'Brainstorm/Core/auto_run_product.lua:254'],
    'stop_discards_phase_and_bindings': ['Brainstorm/Advisor/auto_run.lua:79', 'Brainstorm/Core/auto_run_product.lua:242'],
    'ordinary_input_generation_and_stop': ['Brainstorm/Core/auto_run_product.lua:246', 'Brainstorm/Advisor/auto_run.lua:117', 'Brainstorm/Core/Brainstorm.lua:1774', 'Brainstorm/Core/Brainstorm.lua:1871', 'Brainstorm/UI/advisor.lua:564'],
    'owned_cancel_drain_deadline': ['Brainstorm/Advisor/auto_run.lua:72', 'Brainstorm/Advisor/auto_run.lua:141', 'Brainstorm/Advisor/auto_run.lua:169', 'Brainstorm/Core/auto_run_product.lua:171'],
    'accepted_found_and_starting': ['Brainstorm/Advisor/auto_run.lua:166', 'Brainstorm/Advisor/auto_run.lua:198', 'Brainstorm/Advisor/auto_run.lua:293', 'Brainstorm/Core/auto_run_product.lua:195'],
    'spent_pending_action': ['Brainstorm/Advisor/auto_run.lua:311', 'Brainstorm/Advisor/auto_run.lua:339', 'Brainstorm/Core/auto_run_product.lua:148'],
    'limits_watchdogs': ['Brainstorm/Advisor/auto_run.lua:24', 'Brainstorm/Advisor/auto_run.lua:138', 'Brainstorm/Advisor/auto_run.lua:275', 'Brainstorm/Advisor/auto_run.lua:309'],
    'terminal_monitor_rearm_and_once_only': ['Brainstorm/Core/auto_terminal.lua:15', 'Brainstorm/Core/auto_terminal.lua:44', 'Brainstorm/Core/auto_terminal.lua:150', 'Brainstorm/Advisor/auto_run.lua:214', 'Brainstorm/Advisor/auto_run.lua:300'],
    'actual_run_and_profile_table_binding': ['Brainstorm/Core/auto_run_product.lua:56', 'Brainstorm/Core/auto_run_product.lua:108', 'Brainstorm/Core/auto_run_product.lua:319'],
    'existing_cancel_and_invalidation_tests': ['tests/advisor_auto_run.lua:120', 'tests/advisor_auto_run.lua:136', 'tests/advisor_auto_run_product.lua:120'],
    'existing_pending_limits_failure_tests': ['tests/advisor_auto_run.lua:106', 'tests/advisor_auto_run.lua:149', 'tests/advisor_auto_run.lua:197', 'tests/advisor_auto_run.lua:281'],
    'existing_status_input_tests_to_update': ['tests/advisor_auto_run_product.lua:272', 'tests/advisor_auto_run_product.lua:280', 'tests/advisor_auto_run_product.lua:290', 'tests/advisor_auto_observation.lua:144'],
}
report = {
    'schema': 1,
    'purpose': 'Prospective325 Stop/Resume state-machine design audit, before implementation',
    'scope': 'Read-only current source and existing manufactured test inspection; report writing only',
    'status': 'design_hazards_and_required_tests_reported; implementation_not_reviewed',
    'runtime_base': '2.124.0-alpha; currently inspected files, not loaded-game hash attestation',
    'authority': 'All historical experiment allowances CLOSED; no new experiment authority used',
    'executions': {'tests': 0, 'policy': 0, 'source': 0, 'search': 0, 'captured': 0, 'gameplay': 0},
    'external_reads': {'player_logs': 0, 'saves': 0, 'profiles': 0, 'game_executable': 0},
    'inspected_sources': observed,
    'references': references,
    'findings_file': {'path': 'AUDIT.md', 'sha256': sha((HERE / 'AUDIT.md').read_bytes())},
    'implementation_requirements': [
        'Separate Resume from Start; same session identity, recipe, counters and elapsed origins',
        'Preserve pre-stop phase, profile table, original terminal binding and pending action',
        'Ordinary input does not revoke consent/manual generation; explicit Stop has a separate path',
        'No duplicate action/start/search or implicit replacement lease on Resume',
        'Cancellation remains owned and drains; cancelled late found is never launched',
        'Retain original accepted found receipt and recognize an already-started run',
        'Preserve hard limits and uncertainty; specify benign-input versus stall-clock behavior',
        'Reject implicit profile/checkpoint/GAME replacement equivalence',
        'Terminal outcomes counted once and only from valid retained original evidence',
        'Resume failures and pure status getters preserve counters and ownership',
    ],
    'limitations': ['No implementation acceptance', 'No fixture execution', 'No terminal or performance result',
                    'No player win-rate inference', 'Source line references bind inspected hashes, not future325 edits'],
}
with (HERE / 'report.json').open('x', encoding='utf-8', newline='\n') as stream:
    json.dump(report, stream, indent=2)
    stream.write('\n')
manifest = {'schema': 1, 'files': []}
for name in ('AUDIT.md', 'report.json', 'write_manifest.py'):
    data = (HERE / name).read_bytes()
    manifest['files'].append({'path': name, 'bytes': len(data), 'sha256': sha(data)})
with (HERE / 'manifest.json').open('x', encoding='utf-8', newline='\n') as stream:
    json.dump(manifest, stream, indent=2)
    stream.write('\n')
print(json.dumps({'manifest_sha256': sha((HERE / 'manifest.json').read_bytes()),
                  'source_files_still_matching': sum(x['still_matches_inspected_bytes'] for x in observed),
                  'source_files': len(observed)}))
