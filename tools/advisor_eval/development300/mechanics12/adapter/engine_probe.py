#!/usr/bin/env python3
"""Read-only headless feasibility probe of the user's actual Balatro engine.

Loads original Lua directly from the installed executable ZIP into its bundled
LuaJIT library. Does not run Balatro.exe, create windows, or read/write saves.
The optional episode driver is experimental and does not establish validated
benchmark evidence. Unsupported engine/policy surfaces fail closed.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
from pathlib import Path
import struct
import time
import zipfile

from benchmark import ORDINARY_START, digest, policy_hashes
from opening_support import native_search, opening_sources
from normal_recipe import load as normal_recipe_record


PROFILE_NAMES = ('source_defaults_v1', 'all_unlocked_discovered_v1')

def selection_record(path,seed):
    """Bind disclosed external seed selection without changing original rules."""
    if path is None: return None
    raw=Path(path).read_bytes();record=json.loads(raw)
    if (not isinstance(record,dict) or record.get('schema')!=1 or
            record.get('kind')!='declared_selected_development_seed' or record.get('seed')!=seed or
            record.get('qualification') is not False):
        raise ValueError('Selected development evidence has inconsistent seed/schema/qualification')
    return {'spec':record,'evidence_digest':hashlib.sha256(raw).hexdigest(),
            'selection_executed_by_adapter':False,'qualification':False}

def jokerless_recipe_record(path,seed):
    if path is None:return None
    raw=Path(path).read_bytes();record=json.loads(raw)
    if (not isinstance(record,dict) or record.get('schema')!=1 or
            record.get('mode')!='jokerless_coupon_blue_v1' or record.get('qualification') is not False or
            not isinstance(record.get('recipe'),dict) or record['recipe'].get('seed')!=seed):
        raise ValueError('Jokerless opening recipe has inconsistent seed/schema/qualification')
    recipe=record['recipe']
    initial_planets={'c_pluto':'High Card','c_mercury':'Pair','c_uranus':'Two Pair',
        'c_venus':'Three of a Kind','c_saturn':'Straight','c_jupiter':'Flush',
        'c_earth':'Full House','c_mars':'Four of a Kind','c_neptune':'Straight Flush'}
    if ('target_planet' in recipe or 'target_hand' in recipe) and (
            recipe.get('target_planet') not in initial_planets or
            initial_planets.get(recipe.get('target_planet'))!=recipe.get('target_hand')):
        raise ValueError('Jokerless opening target Planet/hand binding is inconsistent or initially unavailable')
    return {'spec':record,'recipe_digest':hashlib.sha256(raw).hexdigest(),'qualification':False,
            'execution':'frozen_product_advice_with_public_validation','hand_policy':'unchanged_autonomous_advisor'}


def retry_context_spec():
    """The source dispatcher has no manual checkpoint or external journal path."""
    return {'schema': 1, 'mode': 'disabled_clean_attempt_v1', 'journal_access': 'none',
            'checkpoint_restore': 'unsupported', 'initial_memory': 'empty',
            'max_checkpoint_reloads': 0, 'retry_advice_evaluated': False}


def retry_context_record():
    spec = retry_context_spec()
    return {'type': 'engine_probe_retry_context', 'retry_context_spec': spec,
            'retry_context_spec_digest': digest(spec), 'checkpoint_reloads_observed': 0,
            'initialized_before_decision': True, 'qualification_compatible': False}


def validate_retry_spec(value, claimed_digest):
    # Canonical JSON comparison distinguishes false from zero and rejects extra
    # fields, nonfinite values and other unsupported claims without guessing.
    expected = retry_context_spec()
    if not isinstance(value, dict) or digest(value) != digest(expected) or claimed_digest != digest(expected):
        raise ValueError('Unsupported or inconsistent retry context specification')
    return expected


def applied_retry_context(rows, provenance, expected=None):
    """Legacy absence stays unreported; new declarations require actual evidence."""
    fields = ('retry_context_spec', 'retry_context_spec_digest')
    declared = any(key in provenance for key in fields)
    records = [row for row in rows if row.get('type') == 'engine_probe_retry_context']
    if any(str(row.get('type', '')).startswith(('engine_retry_', 'engine_checkpoint_reload')) for row in rows):
        raise ValueError('Checkpoint/retry events are unsupported in clean-attempt evidence')
    if expected is None:
        if declared or records:
            raise ValueError('Retry context was not bound by this historical registration')
        return {'mode': 'historical_unreported', 'retry_advice_evaluated': False,
                'interpretation': 'Historical absence does not establish checkpoint or retry support'}
    expected = validate_retry_spec(expected, digest(expected))
    if not declared:
        raise ValueError('Missing declared retry context')
    validate_retry_spec(provenance.get(fields[0]), provenance.get(fields[1]))
    if len(records) != 1 or digest(records[0]) != digest(retry_context_record()):
        raise ValueError('Require one matching applied clean-attempt retry context')
    index = next(i for i, row in enumerate(rows) if row.get('type') == 'engine_probe_retry_context')
    if any(str(row.get('type', '')).startswith('engine_episode_') for row in rows[:index]):
        raise ValueError('Retry context must be initialized before episode decisions')
    return {'mode': expected['mode'], 'retry_context_spec_digest': digest(expected),
            'checkpoint_reloads_observed': 0, 'retry_advice_evaluated': False}


def profile_spec(name):
    """Declare a reproducible in-memory population, never infer a user's save."""
    if name not in PROFILE_NAMES:
        raise ValueError('Unknown source-defined unlock profile')
    return {'schema': 1, 'name': name, 'scope': ['P_CENTERS', 'P_TAGS', 'P_SEALS', 'P_BLINDS'],
            'transform': 'preserve_source_flags' if name == PROFILE_NAMES[0] else 'set_unlock_and_discovery_true',
            'progress': 'fresh_in_memory_no_completed_challenges', 'user_profile': False,
            'qualification_compatible': False}


def profile_record(name, data):
    spec = profile_spec(name)
    inventory = []
    for line in data.decode('utf-8').splitlines():
        scope, key, unlocked, discovered = line.split(':')
        if scope not in spec['scope'] or unlocked not in ('nil', 'true', 'false') or discovered not in ('nil', 'true', 'false'):
            raise ValueError('Malformed applied source profile inventory')
        inventory.append({'scope': scope, 'key': key, 'unlocked': unlocked, 'discovered': discovered})
    identities = [(row['scope'], row['key']) for row in inventory]
    if not inventory or len(set(identities)) != len(identities) or identities != sorted(identities):
        raise ValueError('Applied source profile inventory must be nonempty, unique and sorted')
    if {row['scope'] for row in inventory} != set(spec['scope']):
        raise ValueError('Applied source profile inventory omits a declared scope')
    if spec['transform'] == 'set_unlock_and_discovery_true' and any(
            row['unlocked'] != 'true' or row['discovered'] != 'true' for row in inventory):
        raise ValueError('Declared full source profile was not applied')
    return {'type': 'engine_probe_profile', 'profile': name, 'profile_spec': spec,
            'profile_spec_digest': digest(spec), 'unlock_profile_digest': hashlib.sha256(data).hexdigest(),
            'inventory': inventory, 'emitted_before_episode': True, 'declared_scope_verified': True,
            'qualification_compatible': False,
            'description': 'Declared original-source flag population; fresh in-memory progress; no user save read'}


def literal(data: bytes) -> bytes:
    separator = b"="
    while b"]" + separator + b"]" in data:
        separator += b"="
    return b"[" + separator + b"[" + data + b"]" + separator + b"]"


def lua_value(value):
    if value is None:
        return b"nil"
    if isinstance(value, bool):
        return b"true" if value else b"false"
    if isinstance(value, str):
        return literal(value.encode())
    if isinstance(value, (int, float)):
        return str(value).encode()
    if isinstance(value, list):
        return b"{" + b",".join(lua_value(item) for item in value) + b"}"
    return b"{" + b",".join(b"[ " + lua_value(key) + b" ]=" + lua_value(item)
                             for key, item in value.items()) + b"}"


def verified_replay(trace_path, source_root, provenance, challenge, seed, boundary):
    """Admit only complete, fingerprinted source prefixes from a frozen product.

    A candidate may differ from this source product, but both identities remain
    explicit. Runtime checks still compare each actual source state and effect.
    """
    if type(boundary) is not int or not 1 <= boundary <= 500:
        raise ValueError('Replay decision boundary must be 1..500')
    rows = [json.loads(line) for line in trace_path.read_text(encoding='utf-8-sig').splitlines()
            if line.lstrip().startswith('{')]
    def unique(kind):
        found = [row for row in rows if row.get('type') == kind]
        if len(found) != 1:
            raise ValueError('Replay requires one ' + kind)
        return found[0]
    original = unique('engine_probe_provenance')
    profile = unique('engine_probe_profile')
    if original.get('start_distribution') != ORDINARY_START or original.get('opening_policy_loaded'):
        raise ValueError('Replay requires an ordinary opening trace')
    if original.get('counterfactual') or original.get('followed_advice') is False:
        raise ValueError('Replay source must follow its recorded policy')
    applied_retry_context(rows, original, original.get('retry_context_spec'))
    for key, expected in {'challenge': challenge, 'seed': seed, **{
            key: provenance[key] for key in ('rules_digest', 'runtime_digest', 'adapter_digest')}}.items():
        if original.get(key) != expected:
            raise ValueError('Replay mismatch: ' + key)
    source_files = policy_hashes(source_root)
    if original.get('policy_files') != source_files or original.get('policy_digest') != digest(source_files):
        raise ValueError('Replay source policy differs from frozen provenance')
    if not source_files.get('Brainstorm/Advisor/snapshot.lua'):
        raise ValueError('Replay source policy lacks its canonical snapshot module')
    profile_digest = profile.get('unlock_profile_digest')
    if not isinstance(profile_digest, str) or len(profile_digest) != 64:
        raise ValueError('Replay lacks the source unlock profile fingerprint')
    if original.get('profile_spec'):
        expected_spec = profile_spec(original['profile_spec']['name'])
        if (original['profile_spec'] != expected_spec or original.get('profile_spec_digest') != digest(expected_spec)
                or profile.get('profile_spec') != expected_spec or profile.get('profile_spec_digest') != digest(expected_spec)
                or profile.get('declared_scope_verified') is not True):
            raise ValueError('Replay declared source profile is inconsistent')
        if provenance.get('profile_spec') and provenance['profile_spec'] != expected_spec:
            raise ValueError('Replay mismatch: declared source profile')
    actions, resolved, checkpoints = {}, {}, {}
    for row in rows:
        kind = row.get('type')
        target = actions if kind == 'engine_episode_action' else resolved if kind == 'engine_episode_resolved' else (
            checkpoints if kind == 'engine_episode_checkpoint' else None)
        if target is not None:
            step = row.get('step')
            if type(step) is not int or step in target:
                raise ValueError('Replay has invalid or duplicate action/checkpoint steps')
            target[step] = row
    expected_prefix = set(range(1, boundary))
    if not expected_prefix.issubset(actions) or not expected_prefix.issubset(resolved):
        raise ValueError('Replay prefix is incomplete')
    destination = actions.get(boundary) or checkpoints.get(boundary)
    if not destination:
        raise ValueError('Replay lacks the requested decision checkpoint')
    prefix = {}
    for step in range(1, boundary + 1):
        row = actions[step] if step < boundary else destination
        fingerprint = row.get('state_fingerprint')
        if row.get('fingerprint_schema') != 'source_decision_v1' or not isinstance(fingerprint, str) or len(fingerprint) != 64:
            raise ValueError('Replay requires source_decision_v1 state fingerprints')
        if step < boundary:
            after = resolved[step]
            if not isinstance(after.get('state_fingerprint'), str) or len(after['state_fingerprint']) != 64:
                raise ValueError('Replay lacks a resolved state fingerprint')
            if not isinstance(row.get('action'), dict) or not isinstance(row.get('phase'), str):
                raise ValueError('Replay lacks an action or phase')
            if row['action'].get('kind') == 'play' and not isinstance(row.get('score_prediction'), dict):
                raise ValueError('Replay play lacks score prediction metadata')
            prefix[step] = {'before': row, 'after': after}
    return {'prefix': prefix, 'checkpoint': destination, 'unlock_profile_digest': profile_digest,
            'source_trace_digest': hashlib.sha256(trace_path.read_bytes()).hexdigest(),
            'source_policy_digest': original['policy_digest'], 'source_adapter_digest': original['adapter_digest'],
            'source_snapshot_digest': source_files.get('Brainstorm/Advisor/snapshot.lua')}


def main() -> int:
    started = time.perf_counter()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install", type=Path, default=Path(
        "C:/Program Files (x86)/Steam/steamapps/common/Balatro"))
    parser.add_argument("--challenge", default="c_omelette_1", help="Challenge ID or one-based index")
    parser.add_argument("--seed", default="ADVISOR1")
    parser.add_argument("--deck", choices=("b_red", "b_zodiac"))
    parser.add_argument("--stake", type=int, choices=range(1,9), default=8)
    parser.add_argument('--seed-selection-evidence',type=Path,
                        help='Frozen disclosed development seed-selection evidence; no rule/action override')
    parser.add_argument('--jokerless-opening-recipe',type=Path,
                        help='Frozen explicit product Coupon/Blue opening recipe; original source actions remain advisor-selected')
    parser.add_argument('--normal-filter-recipe',type=Path,
                        help='Frozen explicit normal filtered product metadata; no embedded seed search')
    parser.add_argument('--unlock-profile', choices=PROFILE_NAMES, default=PROFILE_NAMES[0],
                        help='Explicit source-defined flag population; never an actual user profile')
    parser.add_argument('--profile-only', action='store_true', help='Stop after durable profile inventory, before challenge setup')
    parser.add_argument("--episode", action="store_true", help="Continue into the experimental real-engine episode adapter")
    parser.add_argument("--policy-root", type=Path, default=Path(__file__).resolve().parents[2],
                        help="Repository or frozen policy root containing Brainstorm/Advisor")
    parser.add_argument("--debug-decisions", action="store_true", help="Emit detached snapshots and complete decision results")
    parser.add_argument("--replay-trace", type=Path, help="Development-only recorded action prefix before an override")
    parser.add_argument("--override", type=Path, help="Development-only JSON with step and action; requires --replay-trace")
    parser.add_argument('--replay-until-step', type=int, help='Replay earlier actions, then evaluate this recorded decision')
    parser.add_argument('--replay-policy-root', type=Path, help='Frozen source product for the replay trace; defaults to policy-root')
    parser.add_argument('--replay-evaluate-prefix', action='store_true', help='Parity diagnostic: run advisor during verified prefix')
    parser.add_argument('--stop-at-replay-decision', action='store_true', help='Evaluate the replay boundary without applying its action')
    parser.add_argument('--stop-at-decision', choices=('blind', 'shop', 'tactical_shop', 'pack', 'growth', 'reroll'), help='Capture a meaningful decision before applying its action')
    parser.add_argument('--decision-occurrence', type=int, default=1, help='Stop at this matching decision occurrence')
    parser.add_argument("--stop-after-step", type=int, help="Development-only action limit; not a terminal episode")
    parser.add_argument("--stop-on-round-end", type=int, help="Development-only round-completion boundary")
    parser.add_argument("--test-scenario", choices=("dagger_preblind", "score_floor_play", "terminal_win_final", "terminal_loss_final",
                        "empty_hand_refill", "empty_hand_zero_limit", "selected_action_play", "terminal_saved_final", "terminal_unsaved_final", "failure_context", "forced_selection", "ui_object_lifecycle", "collection_product_startup"),
                        help="Explicit synthetic source-parity fixture; never ordinary episode evidence")
    parser.add_argument('--opening-targets', help='Enable the separate native two-Soul route; CSV keys, empty means Any')
    parser.add_argument('--opening-search-limit', type=int, default=1, help='Native candidate cap; outer process timeout is still required')
    parser.add_argument('--stop-on-opening-complete', action='store_true', help='Development setup boundary, never a terminal win')
    parser.add_argument('--opening-only-actions',action='store_true',help='Mechanical boundary: only skip Small and choose visible Souls; never select/play a blind')
    args = parser.parse_args()
    if args.deck:
        if args.opening_targets is not None or args.jokerless_opening_recipe or args.replay_trace:
            parser.error("Normal deck requires its separately declared route, not challenge/replay hooks")
        args.challenge="normal"
    if args.stop_after_step is not None and args.stop_after_step < 1:
        parser.error("--stop-after-step must be positive")
    if args.decision_occurrence < 1:
        parser.error('--decision-occurrence must be positive')
    if args.profile_only and (args.episode or args.replay_trace or args.opening_targets is not None):
        parser.error('--profile-only cannot combine with episode, replay or filtered setup')
    if (args.override or args.replay_until_step or args.replay_policy_root or args.replay_evaluate_prefix or args.stop_at_replay_decision) and not args.replay_trace:
        parser.error('Replay options require --replay-trace')
    filtered = args.opening_targets is not None
    selection=selection_record(args.seed_selection_evidence,args.seed)
    jokerless_recipe=jokerless_recipe_record(args.jokerless_opening_recipe,args.seed)
    normal_recipe=normal_recipe_record(args.normal_filter_recipe,args.seed,args.deck,args.stake)
    if normal_recipe and (not args.deck or not args.episode or args.test_scenario or args.replay_trace or not selection):
        parser.error('Normal filtered setup requires its deck, episode and disclosed external seed selection')
    if args.deck and args.episode and not args.test_scenario and not normal_recipe:
        parser.error('Normal complete attempts require separately registered product filter metadata')
    if selection and (filtered or not args.episode or args.replay_trace or args.test_scenario):
        parser.error('Selected clean development seeds cannot combine with filtered hooks, replay or source scenarios')
    if jokerless_recipe and (not selection or args.challenge!='c_jokerless_1'):
        parser.error('Jokerless route requires disclosed seed selection and its source challenge')
    if filtered and (not args.episode or args.test_scenario or args.replay_trace):
        parser.error('Filtered openings require an episode and cannot combine with synthetic scenarios or replay')
    if args.stop_on_opening_complete and not (filtered or normal_recipe):
        parser.error('--stop-on-opening-complete requires a declared opening route')
    if args.opening_only_actions and (not normal_recipe or not args.stop_on_opening_complete or args.stop_after_step!=10):
        parser.error('Opening-only qualification requires normal recipe, opening stop and exact ten-step cap')
    executable = args.install / "Balatro.exe"
    with zipfile.ZipFile(executable) as archive:
        sources = {name: archive.read(name) for name in archive.namelist()
                   if name.endswith(".lua")}
        dimensions = {}
        for name in archive.namelist():
            if name.endswith(".png"):
                with archive.open(name) as image:
                    header = image.read(24)
                if header[:8] == b"\x89PNG\r\n\x1a\n":
                    dimensions[name] = struct.unpack(">II", header[16:24])
    core_names = ["game.lua", "globals.lua", "card.lua", "cardarea.lua", "blind.lua",
                  "back.lua", "tag.lua", "challenges.lua", "engine/event.lua",
                  "functions/state_events.lua", "functions/common_events.lua",
                  "functions/button_callbacks.lua", "functions/misc_functions.lua"]
    print(json.dumps({"type": "engine_probe_sources", "source": str(executable),
                      "lua_modules": len(sources), "source_sha256": {
                          name: hashlib.sha256(sources[name]).hexdigest()
                          for name in core_names}}), flush=True)
    provenance = {"rules_digest": hashlib.sha256(executable.read_bytes()).hexdigest(),
                  "runtime_digest": hashlib.sha256((args.install / "lua51.dll").read_bytes()).hexdigest()}
    adapter_files = {name: hashlib.sha256(Path(__file__).with_name(name).read_bytes()).hexdigest()
                     for name in ("engine_probe.py", "engine_probe.lua", "engine_run.lua", "engine_contract.lua", "opening_support.py", "benchmark.py", "normal_recipe.py", "normal_terminal.lua", "startup_fixture.lua", "startup_receipt.py")}
    provenance["adapter_digest"] = hashlib.sha256(json.dumps(
        adapter_files, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    provenance['profile_spec'] = profile_spec(args.unlock_profile)
    provenance['profile_spec_digest'] = digest(provenance['profile_spec'])
    provenance['retry_context_spec'] = retry_context_spec()
    provenance['retry_context_spec_digest'] = digest(provenance['retry_context_spec'])
    if args.deck: provenance["normal_run"]={"deck":args.deck,"stake":args.stake,"qualification":False}
    if selection: provenance['seed_selection']=selection
    if jokerless_recipe:provenance['jokerless_opening']=jokerless_recipe
    if normal_recipe:provenance['normal_filtered_opening']=normal_recipe
    chunks = [b"PROBE_PNG={}", b'PROBE_HOST_STARTED=' + lua_value(started),
              b'PROBE_PROFILE_SPEC=' + lua_value(provenance['profile_spec'])]
    run_seed = args.seed
    if normal_recipe:
        sources, opening_module, charm_hook, hook_hashes = opening_sources(args.policy_root, sources)
        provenance['normal_filtered_opening']['hook_hashes']=hook_hashes
        chunks += [b'package.preload.probe_challenge_opening=assert(loadstring(' + literal(opening_module) + b",'@frozen_challenge_opening.lua'))",
                   b'PROBE_CHARM_HOOK=' + literal(charm_hook),
                   b'PROBE_NORMAL_FILTER_RECIPE='+lua_value(normal_recipe['spec']),
                   b'PROBE_NORMAL_FILTER_DIGEST='+lua_value(normal_recipe['recipe_digest']),
                   b'PROBE_STOP_ON_OPENING_COMPLETE='+lua_value(args.stop_on_opening_complete)]
    if filtered:
        frozen_before = policy_hashes(args.policy_root)
        sources, opening_module, charm_hook, hook_hashes = opening_sources(args.policy_root, sources)
        opening_result, opening_raw, opening_meta = native_search(args.policy_root, args.seed, args.challenge,
                                                                 args.opening_targets, args.opening_search_limit)
        assert frozen_before == policy_hashes(args.policy_root), 'Opening product changed during search'
        provenance['opening'] = {**opening_meta, 'targets': args.opening_targets, 'hook_hashes': hook_hashes,
                                 'result': opening_result, 'seed_role': 'native_search_start',
                                 'initialization_route': 'original_start_run_on_native_found_seed_no_live_run_disposal'}
        print(json.dumps({'type': 'engine_opening_search_result', **provenance['opening']}), flush=True)
        if opening_result.get('status') == 'found':
            run_seed = opening_result['seed']
        else:
            provenance.update(policy_digest=digest(frozen_before), policy_files=frozen_before,
                              start_distribution={'kind': 'filtered_two_soul_native_v1', 'targets': args.opening_targets},
                              opening_policy_loaded=False, run_seed=None)
            print(json.dumps({'type': 'engine_probe_provenance', 'challenge': args.challenge, 'seed': args.seed,
                              'validation': 'experimental', **provenance}), flush=True)
            print(json.dumps({'type': 'engine_episode_stopped', 'outcome': 'censored',
                              'reason': 'development_opening_' + opening_result.get('status', 'error'), 'decisions': 0}), flush=True)
            print(json.dumps({'type': 'engine_probe_timing', 'elapsed_seconds': time.perf_counter() - started}), flush=True)
            return 0 if opening_result.get('status') == 'not_found' else 1
        chunks += [b'package.preload.probe_challenge_opening=assert(loadstring(' + literal(opening_module) + b",'@frozen_challenge_opening.lua'))",
                   b'PROBE_CHARM_HOOK=' + literal(charm_hook), b'PROBE_OPENING_RAW=' + literal(opening_raw.encode()),
                   b'PROBE_OPENING_TARGETS=' + lua_value(args.opening_targets), b'PROBE_OPENING_SEARCH_SECONDS=' + lua_value(opening_meta['search_seconds']),
                   b'PROBE_STOP_ON_OPENING_COMPLETE=' + lua_value(args.stop_on_opening_complete)]
        provenance['run_seed'] = run_seed
    for name, (width, height) in dimensions.items():
        chunks.append(b"PROBE_PNG[ " + literal(name.encode()) + b" ]={"
                      + str(width).encode() + b"," + str(height).encode() + b"}")
    for name, source in sources.items():
        module = name[:-4].encode()
        chunks.append(b"package.preload[ " + literal(module) + b" ]=assert(loadstring("
                      + literal(source) + b"," + literal(b"@installed/" + name.encode()) + b"))")
    chunks.append(b"PROBE_CHALLENGE=" + literal(args.challenge.encode()))
    chunks.append(b"PROBE_SEED=" + literal(run_seed.encode()))
    chunks.append(b"PROBE_DECK=" + lua_value(args.deck))
    chunks.append(b"PROBE_STAKE=" + lua_value(args.stake))
    if jokerless_recipe:
        chunks.append(b'PROBE_JOKERLESS_RECIPE='+lua_value(jokerless_recipe['spec']['recipe']))
        chunks.append(b'PROBE_JOKERLESS_RECIPE_DIGEST='+lua_value(jokerless_recipe['recipe_digest']))
    chunks.append(b"PROBE_DEBUG_DECISIONS=" + lua_value(args.debug_decisions))
    chunks.append(b"PROBE_STOP_AFTER_STEP=" + lua_value(args.stop_after_step))
    chunks.append(b'PROBE_OPENING_ONLY_ACTIONS='+lua_value(args.opening_only_actions))
    chunks.append(b"PROBE_STOP_ON_ROUND_END=" + lua_value(args.stop_on_round_end))
    chunks.append(b"PROBE_TEST_SCENARIO=" + lua_value(args.test_scenario))
    chunks.append(b'PROBE_PROFILE_ONLY=' + lua_value(args.profile_only))
    chunks.append(b'PROBE_STOP_AT_DECISION=' + lua_value(args.stop_at_decision))
    chunks.append(b'PROBE_DECISION_OCCURRENCE=' + lua_value(args.decision_occurrence))
    chunks.append(b"package.preload.probe_engine_contract=assert(loadstring(" + literal(
        Path(__file__).with_name('engine_contract.lua').read_bytes()) + b",'@engine_contract.lua'))")
    chunks.append(b"package.preload.probe_normal_terminal=assert(loadstring(" + literal(
        Path(__file__).with_name('normal_terminal.lua').read_bytes()) + b",'@normal_terminal.lua'))")
    if args.test_scenario:
        assert args.episode and not args.replay_trace, "Source scenarios require --episode and cannot replay actions"
        provenance["test_scenario"] = args.test_scenario
        provenance["counterfactual"] = True
        provenance["followed_advice"] = False
    if args.replay_trace or args.override:
        assert args.episode, 'Replay requires --episode'
        override = json.loads(args.override.read_text(encoding='utf-8-sig')) if args.override else None
        boundary = args.replay_until_step or (override and override.get('step'))
        if override and (override.get('step') != boundary or not isinstance(override.get('action'), dict)):
            raise ValueError('Override must provide the replay boundary step and action')
        replay = verified_replay(args.replay_trace, args.replay_policy_root or args.policy_root,
                                 provenance, args.challenge, args.seed, boundary)
        source_snapshot_path = (args.replay_policy_root or args.policy_root) / 'Brainstorm' / 'Advisor' / 'snapshot.lua'
        source_snapshot = source_snapshot_path.read_bytes()
        if hashlib.sha256(source_snapshot).hexdigest() != replay['source_snapshot_digest']:
            raise ValueError('Replay source snapshot differs from frozen provenance')
        chunks.append(b"package.preload.probe_replay_snapshot=assert(loadstring(" + literal(source_snapshot)
                      + b",'@replay_source/snapshot.lua'))")
        chunks.append(b'PROBE_VERIFIED_REPLAY=' + lua_value(replay))
        chunks.append(b'PROBE_REPLAY_BOUNDARY=' + lua_value(boundary))
        chunks.append(b'PROBE_REPLAY_EVALUATE_PREFIX=' + lua_value(args.replay_evaluate_prefix))
        chunks.append(b'PROBE_STOP_AT_REPLAY_DECISION=' + lua_value(args.stop_at_replay_decision))
        chunks.append(b'PROBE_ACTION_OVERRIDE=' + lua_value(override and override['action']))
        provenance['replay'] = {key: replay[key] for key in ('source_trace_digest', 'source_policy_digest', 'source_adapter_digest', 'source_snapshot_digest')}
        provenance['replay'].update(boundary_step=boundary, skipped_prefix_advisor=not args.replay_evaluate_prefix)
        provenance["counterfactual"] = True
        provenance["followed_advice"] = False
    if args.episode:
        policy_files = sorted((args.policy_root / "Brainstorm" / "Advisor").glob("*.lua"))
        assert policy_files, "No advisor sources in policy root"
        product_hashes = policy_hashes(args.policy_root)
        for source in policy_files:
            content = source.read_bytes()
            assert hashlib.sha256(content).hexdigest() == product_hashes[source.relative_to(args.policy_root).as_posix()], "Policy changed during loading"
            chunks.append(b"package.preload[ " + literal(b"probe_policy_" + source.stem.encode())
                          + b" ]=assert(loadstring(" + literal(content) + b","
                          + literal(b"@policy/" + source.name.encode()) + b"))")
        jokerless_path=args.policy_root/'Brainstorm'/'Core'/'jokerless_opening.lua'
        if jokerless_path.is_file():
            content=jokerless_path.read_bytes()
            assert hashlib.sha256(content).hexdigest()==product_hashes[jokerless_path.relative_to(args.policy_root).as_posix()]
            chunks.append(b'package.preload.probe_jokerless_opening=assert(loadstring('+literal(content)+b",'@frozen_jokerless_opening.lua'))")
            chunks.append(b'PROBE_JOKERLESS_MODULE_DIGEST='+lua_value(hashlib.sha256(content).hexdigest()))
        elif jokerless_recipe:raise ValueError('Frozen product lacks its declared Jokerless opening module')
        if args.test_scenario == 'collection_product_startup':
            from startup_receipt import load_observed_receipt
            observed = load_observed_receipt(Path(__file__).parent/'evidence'/'S05')
            chunks.append(b'PROBE_COLLECTION_OBSERVED_RECEIPT=' + lua_value(observed))
            source = args.policy_root/'Brainstorm'/'Core'/'collection_search_product.lua'
            content = source.read_bytes()
            assert hashlib.sha256(content).hexdigest() == product_hashes[source.relative_to(args.policy_root).as_posix()]
            chunks.append(b'package.preload.probe_collection_search_product=assert(loadstring(' + literal(content) + b",'@policy/Core/collection_search_product.lua'))")
            fixture = Path(__file__).with_name('startup_fixture.lua').read_bytes()
            chunks.append(b'package.preload.probe_collection_startup_fixture=assert(loadstring(' + literal(fixture) + b",'@mechanical/startup_fixture.lua'))")
            provenance['collection_startup_mechanical'] = {
                'scope': 'Authentic source Game.delete_run/start_run and Back via frozen product facade; zero advisor actions',
                'observed_receipt': observed['binding'], 'native_search_executed': False,
                'search_runtime': 'Declared observed-S05 receipt stand-in; no worker/thread/native invocation',
                'bootstrap_seed': args.seed, 'requested_seed': observed['result']['seed'],
                'inactive_query_difference': 'The actual loaded synthetic missing-name list is present; S05 had an empty list. minimum_distinct=0 disables this field in both queries.',
                'qualification': False}
        assert product_hashes == policy_hashes(args.policy_root), "Product changed during loading"
        provenance["policy_digest"] = digest(product_hashes)
        provenance["policy_files"] = product_hashes
        provenance["product_manifest_scope"] = "runtime_and_native_dependencies_v1"
        provenance["start_distribution"] = ({'kind':'normal_filtered_product_v1','seed_selection':'declared_development_selection',
                                             'selection_evidence_digest':selection['evidence_digest'],'recipe_digest':normal_recipe['recipe_digest']}
                                            if normal_recipe else
                                            {'kind':'jokerless_coupon_blue_v1','seed_selection':'declared_development_selection',
                                             'selection_evidence_digest':selection['evidence_digest'],'recipe_digest':jokerless_recipe['recipe_digest']}
                                            if jokerless_recipe else
                                            {'kind': 'filtered_two_soul_native_v1', 'targets': args.opening_targets} if filtered else
                                            {"kind": "source_parity_fixture", "scenario": args.test_scenario}
                                            if args.test_scenario else
                                            {'kind':'ordinary','seed_selection':'declared_development_selection',
                                             'selection_evidence_digest':selection['evidence_digest']}
                                            if selection else dict(ORDINARY_START))
        provenance["opening_policy_loaded"] = filtered or jokerless_recipe is not None or normal_recipe is not None
        chunks.append(b"PROBE_EPISODE=" + literal(Path(__file__).with_name("engine_run.lua").read_bytes()))
    print(json.dumps({"type": "engine_probe_provenance", "challenge": args.challenge,
                      "seed": args.seed, "validation": "experimental", **provenance}), flush=True)
    chunks.append(Path(__file__).with_suffix(".lua").read_bytes())
    code = b"\n".join(chunks)
    library = ctypes.CDLL(str((args.install / "lua51.dll").resolve()))
    library.luaL_newstate.restype = ctypes.c_void_p
    library.luaL_openlibs.argtypes = [ctypes.c_void_p]
    library.luaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p,
                                      ctypes.c_size_t, ctypes.c_char_p]
    library.luaL_loadbuffer.restype = ctypes.c_int
    library.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    library.lua_pcall.restype = ctypes.c_int
    library.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int,
                                     ctypes.POINTER(ctypes.c_size_t)]
    library.lua_tolstring.restype = ctypes.c_void_p
    library.lua_close.argtypes = [ctypes.c_void_p]
    library.lua_getfield.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_char_p]
    library.lua_pushnumber.argtypes = [ctypes.c_void_p, ctypes.c_double]
    library.lua_pushlstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t]
    lua_callback = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_void_p)
    library.lua_pushcclosure.argtypes = [ctypes.c_void_p, lua_callback, ctypes.c_int]
    library.lua_setfield.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_char_p]
    @lua_callback
    def monotonic_seconds(lua_state):
        library.lua_pushnumber(lua_state, time.perf_counter())
        return 1
    @lua_callback
    def sha256(lua_state):
        length = ctypes.c_size_t()
        pointer = library.lua_tolstring(lua_state, 1, ctypes.byref(length))
        value = hashlib.sha256(ctypes.string_at(pointer, length.value)).hexdigest().encode()
        library.lua_pushlstring(lua_state, value, len(value))
        return 1
    profile_errors = []
    @lua_callback
    def record_profile(lua_state):
        # Emit before any episode action, so killed/unsupported attempts retain
        # their actual population. Do not print a duplicate record on shutdown.
        length = ctypes.c_size_t()
        pointer = library.lua_tolstring(lua_state, 1, ctypes.byref(length))
        try:
            record = profile_record(args.unlock_profile, ctypes.string_at(pointer, length.value))
            print(json.dumps(record), flush=True)
        except (ValueError, UnicodeError) as error:
            profile_errors.append(str(error))
            print(json.dumps({'type': 'engine_probe_profile_error', 'reason': str(error)}), flush=True)
        library.lua_pushnumber(lua_state, 0 if profile_errors else 1)
        return 1
    state = library.luaL_newstate()
    if not state:
        raise RuntimeError("Cannot allocate Lua state")
    try:
        library.luaL_openlibs(state)
        library.lua_pushcclosure(state, monotonic_seconds, 0)
        library.lua_setfield(state, -10002, b"PROBE_MONOTONIC_SECONDS")
        library.lua_pushcclosure(state, sha256, 0)
        library.lua_setfield(state, -10002, b'PROBE_SHA256')
        library.lua_pushcclosure(state, record_profile, 0)
        library.lua_setfield(state, -10002, b'PROBE_RECORD_PROFILE')
        startup_seconds = time.perf_counter() - started
        print(json.dumps({"type": "engine_probe_startup", "startup_seconds": startup_seconds}), flush=True)
        lua_started = time.perf_counter()
        status = library.luaL_loadbuffer(state, code, len(code), b"@engine_probe")
        if status == 0:
            status = library.lua_pcall(state, 0, 0, 0)
        # Copy the Lua error before inspecting globals changes the stack top.
        reason = None
        if status:
            length = ctypes.c_size_t()
            message = library.lua_tolstring(state, -1, ctypes.byref(length))
            reason = ctypes.string_at(message, length.value).decode("utf-8", "replace")
            # Capture the detached source state after retaining the original
            # error. A second diagnostic error must never replace its cause.
            diagnostic = b'if PROBE_EXPORT_FAILURE_CONTEXT and not PROBE_FAILURE_CONTEXT_EMITTED then print(PROBE_EXPORT_FAILURE_CONTEXT()); PROBE_FAILURE_CONTEXT_EMITTED=true end'
            context_status = library.luaL_loadbuffer(state, diagnostic, len(diagnostic), b'@failure_context')
            if context_status == 0:
                context_status = library.lua_pcall(state, 0, 0, 0)
            if context_status:
                print(json.dumps({'type': 'engine_episode_failure_context_unavailable',
                                  'reason': 'Detached source context could not be captured after the original error'}), flush=True)
        lua_seconds = time.perf_counter() - lua_started
        print(json.dumps({"type": "engine_probe_timing",
                          "elapsed_seconds": round(time.perf_counter() - started, 3),
                          "startup_seconds": startup_seconds, "lua_seconds": lua_seconds}), flush=True)
        if status:
            print(json.dumps({"type": "engine_probe_blocked", "full_episode": False,
                              "reason": reason}), flush=True)
            return 1
        return 0
    finally:
        library.lua_close(state)


if __name__ == "__main__":
    raise SystemExit(main())
