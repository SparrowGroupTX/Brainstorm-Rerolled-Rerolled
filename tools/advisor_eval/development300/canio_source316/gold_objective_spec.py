"""Explicit experimental objective context; no game, profile or source I/O."""
from __future__ import annotations

MODES = ('off', 'synthetic_fresh_all_missing_v1', 'synthetic_only_canio_missing_v1')


def build(args):
    mode = getattr(args, 'gold_objective', 'off')
    if mode not in MODES:
        raise ValueError('Unknown source Gold objective mode')
    if mode == 'off':
        return {'schema': 1, 'mode': 'off', 'enabled': False,
                'qualification': False, 'actual_player_profile': False}
    if (getattr(args, 'episode', False) is not True or
            getattr(args, 'deck', None) not in ('b_red', 'b_zodiac') or
            type(getattr(args, 'stake', None)) is not int or args.stake != 8 or
            getattr(args, 'unlock_profile', None) != 'all_unlocked_discovered_v1' or
            not getattr(args, 'normal_filter_recipe', None) or
            not getattr(args, 'seed_selection_evidence', None) or
            any(getattr(args, field, None) for field in (
                'replay_trace', 'override', 'test_scenario', 'profile_only',
                'jokerless_opening_recipe', 'opening_targets'))):
        raise ValueError('Gold objective requires a fresh declared normal filtered Gold episode and all_unlocked_discovered_v1; replay/scenario/player history is unsupported')
    result = {'schema': 1, 'mode': mode, 'enabled': True,
            'profile': 'all_unlocked_discovered_v1',
            'initial_history': 'natural_empty_loaded_joker_usage',
            'initial_counts': {'total': 150, 'complete': 0, 'missing': 150, 'unknown': 0},
            'missing_population': 'all_150_vanilla_jokers',
            'capture': 'frozen_gold_stickers.capture_loaded_profile',
            'policy_context': 'completionist_goal',
            'collection_policy': 'frozen_gold_goal',
            'metadata_failure': 'explicit_unsupported_error_before_next_action',
            'profile_writes': 'none_by_objective_adapter; original source callbacks only',
            'qualification': False, 'actual_player_profile': False}
    if mode == 'synthetic_only_canio_missing_v1':
        result.update(initial_history='explicit_synthetic_149_gold_rows_before_first_decision',
            initial_counts={'total':150,'complete':149,'missing':1,'unknown':0},
            missing_population='only_j_caino',missing_keys=['j_caino'],
            synthetic_history_row={'count':1,'order':'canonical_key_order_1_based','wins':{'8':1},'losses':{}},
            source_history_mutation='once_in_memory_after_natural_empty_history_and_loaded_catalog_verification',
            profile_writes='in_memory_synthetic_joker_usage_initialization_only; later original source callbacks',
            synthetic_gameplay_wins_created=False,player_achievement_credit=False)
    return result
