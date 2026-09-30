"""Manufactured detached public snapshots only; no game, model or episodes."""
from copy import deepcopy
import json
import math
import unittest

from .public_context import (SCHEMA, SNAPSHOT_SCHEMA, ROUTE_FEATURE_NAMES,
                             context_from_teacher_observation, encode_public_context,
                             project_route_features)


def snapshot(phase="hand"):
    return {
        "phase": phase, "ante": 4, "route_ante": 4, "blind_on_deck": "Small",
        "route_blinds": {
            "Small": {"key": "bl_small", "name": "Small Blind", "ante": 4, "state": "Current",
                      "chips": 9000, "mult": 1, "dollars": 3, "boss": False, "debuff": {}},
            "Big": {"key": "bl_big", "name": "Big Blind", "ante": 4, "state": "Upcoming",
                    "chips": 13500, "mult": 1.5, "dollars": 4, "boss": False, "debuff": {}},
            "Boss": {"key": "bl_plant", "name": "The Plant", "ante": 4, "state": "Upcoming",
                     "chips": 18000, "mult": 2, "dollars": 5, "boss": True, "debuff": {"is_face": "face"}},
        },
        "blind": {"key": "bl_small", "disabled": False, "chips": 9000, "debuff": {}},
        "hand": [{"id": "playing:2", "key": "c_base", "rank": 12, "suit": "Hearts", "face_down": False}],
        "deck": [{"id": "playing:1", "key": "c_base", "rank": 7, "suit": "Clubs", "face_down": True}],
        "playing_cards": [], "jokers": [], "consumeables": {},
        "current_round": {"hands_left": 3, "discards_left": 2},
    }


def encode(value):
    return encode_public_context(value, snapshot_schema=SNAPSHOT_SCHEMA)


def event(value):
    return {"schema": 1, "collection_schema": "teacher_collection_v1", "kind": "teacher_observation",
            "collection_id": "transport-only", "observation_id": "observation-1", "observation_sequence": 3,
            "context": {"snapshot": value, "snapshot_schema": SNAPSHOT_SCHEMA,
                        "seed": "private-provenance", "profile": "profile-1",
                        "advice": {"action": "sell_yorick", "gold_review": {"target": "j_secret"}}}}


def collection():
    return {"schema": 1, "goal": "gold_stickers", "profile_id": "never-a-feature",
            "targets": [{"key": "j_a", "status": "missing", "reason": "no_gold"},
                        {"key": "j_b", "status": "complete", "reason": "gold"},
                        {"key": "j_c", "status": "unknown", "reason": "history_unavailable"}],
            "counts": {"total": 3, "missing": 1, "complete": 1, "unknown": 1}}


class PublicContextTests(unittest.TestCase):
    def test_all_three_visible_blinds_survive_every_decision_phase(self):
        for phase in ("blind", "hand", "shop", "pack", "round"):
            with self.subTest(phase=phase):
                result = encode(snapshot(phase))
                rows = result["features"]["route_blinds"]
                self.assertEqual(result["schema"], SCHEMA)
                self.assertEqual([r["label"] for r in rows], ["Small", "Big", "Boss"])
                self.assertEqual([r["chips"]["value"] for r in rows], [9000, 13500, 18000])
                self.assertEqual(rows[2]["key"], {"known": True, "value": "bl_plant"})
                self.assertEqual(rows[2]["state"]["value"], "Upcoming")
                self.assertEqual(rows[2]["restrictions"]["value"], {"is_face": "face"})
                projection = project_route_features(result)
                self.assertEqual(len(projection["values"]), 3)
                self.assertTrue(all(len(row) == len(ROUTE_FEATURE_NAMES) == 24 for row in projection["values"]))
                self.assertEqual(projection["identity_keys"], ["bl_small", "bl_big", "bl_plant"])
                self.assertAlmostEqual(projection["values"][2][6], math.log1p(18000))

    def test_missing_target_and_restriction_are_not_observed_zero_or_empty(self):
        value = snapshot()
        del value["route_blinds"]["Boss"]["chips"]
        del value["route_blinds"]["Boss"]["debuff"]
        value["route_blinds"]["Big"]["dollars"] = 0
        rows = encode(value)["features"]["route_blinds"]
        self.assertEqual(rows[2]["chips"], {"known": False, "value": None})
        self.assertEqual(rows[2]["restrictions"], {"known": False, "value": None})
        self.assertEqual(rows[0]["restrictions"], {"known": True, "value": {}})
        self.assertEqual(rows[1]["dollars"], {"known": True, "value": 0})
        projection = project_route_features(encode(value))
        self.assertEqual(projection["values"][2][6:8], [0.0, 0.0])
        self.assertEqual(projection["values"][1][10:12], [0.0, 1.0])

    def test_no_route_fabricated_from_ante_future_schedule_or_current_blind(self):
        value = {"ante": 8, "blind": {"key": "bl_small", "chips": 200000},
                 "blind_choices": {"Boss": "bl_vessel"}, "blind_states": {"Boss": "Upcoming"},
                 "future_blinds": {"9": {"Boss": "not-public"}}, "next_blind_chips": 300000}
        boss = encode(value)["features"]["route_blinds"][2]
        self.assertFalse(boss["entry_known"])
        self.assertEqual(boss["key"]["value"], "bl_vessel")
        self.assertFalse(boss["ante"]["known"])
        self.assertFalse(boss["chips"]["known"])
        self.assertFalse(boss["restrictions"]["known"])
        self.assertNotIn("not-public", json.dumps(encode(value)))

    def test_active_boss_dynamic_restrictions_remain_separate_from_route(self):
        value = snapshot()
        value["blind"] = {"key": "bl_mouth", "only_hand": "Pair", "hands": {"Pair": True},
                          "disabled": False, "prepped": True, "hands_sub": 3, "block_play": False}
        result = encode(value)
        active = result["features"]["active_blind"]
        self.assertEqual(active["only_hand"]["value"], "Pair")
        self.assertEqual(active["hands"]["value"], {"Pair": True})
        self.assertEqual(active["hands_sub"]["value"], 3)
        self.assertEqual(result["features"]["route_blinds"][2]["key"]["value"], "bl_plant")

    def test_teacher_envelope_does_not_leak_labels_provenance_or_telemetry(self):
        first = event(snapshot())
        second = deepcopy(first)
        second["context"].update(seed="other-seed", profile="other-profile", advice={"action": "keep_yorick"},
                                  gold_review={"missing": ["j_a"]}, timing=999, fingerprint="other")
        second.update(observation_id="other", collection_id="other", observation_sequence=99)
        self.assertEqual(context_from_teacher_observation(first), context_from_teacher_observation(second))
        serialized = json.dumps(context_from_teacher_observation(first))
        for forbidden in ("private-provenance", "profile-1", "sell_yorick", "j_secret", "transport-only"):
            self.assertNotIn(forbidden, serialized)
        self.assertFalse(context_from_teacher_observation(first)["features"]["gold_collection"]["known"])

    def test_bridge_rejects_compact_or_unmarked_raw_snapshots(self):
        for mutate in (lambda e: e.update(kind="teacher_advice"),
                       lambda e: e["context"].pop("snapshot_schema"),
                       lambda e: e["context"].pop("snapshot"),
                       lambda e: e.update(collection_schema="other")):
            value = event(snapshot())
            mutate(value)
            with self.assertRaises(ValueError):
                context_from_teacher_observation(value)

    def test_physical_ids_are_action_references_not_policy_features(self):
        first = snapshot()
        second = deepcopy(first)
        second["hand"][0]["id"] = "playing:999"
        second["deck"][0]["id"] = "playing:998"
        self.assertEqual(encode(first)["features"], encode(second)["features"])
        self.assertNotEqual(encode(first)["action_references"], encode(second)["action_references"])
        self.assertNotIn("playing:2", json.dumps(encode(first)["features"]))

    def test_concealment_redacts_poison_identity_and_drawpile_subtraction(self):
        value = snapshot()
        value["hand"][0].update(face_down=True, key="concealed-key", ability=object())
        value["jokers"] = [{"identity_redacted": True, "key": "secret-joker", "ability": object()}]
        value["drawpile_identity_redacted_for_concealment"] = True
        result = encode(value)
        for area in ("hand", "jokers", "deck"):
            card = result["features"]["cards"][area]["value"][0]
            self.assertFalse(card["identity_known"])
            self.assertEqual(card["features"], {})
        self.assertNotIn("concealed-key", json.dumps(result))

    def test_known_composition_is_order_invariant_but_hand_order_is_retained(self):
        value = snapshot()
        value["deck"].append({"id": "playing:3", "key": "c_base", "rank": 10, "suit": "Diamonds", "face_down": True})
        changed = deepcopy(value)
        changed["deck"].reverse()
        self.assertEqual(encode(value)["features"], encode(changed)["features"])
        value["hand"].append({"id": "playing:4", "key": "c_base", "rank": 2, "suit": "Spades"})
        changed = deepcopy(value)
        changed["hand"].reverse()
        self.assertNotEqual(encode(value)["features"], encode(changed)["features"])

    def test_imitation_context_keeps_history_vouchers_tags_and_conditional_abilities(self):
        value = snapshot()
        value.update(used_vouchers={"v_directors_cut": True}, hands={"Pair": {"played_this_round": 2, "level": 4}},
                     active_tags=[{"key": "tag_double", "triggered": False}],
                     consumeable_usage={"c_death": {"count": 2}},
                     jokers=[{"key": "j_yorick", "ability": {"yorick_discards": 1, "extra": {"discards": 23, "xmult": 1}}}])
        result = encode(value)["features"]
        self.assertEqual(result["state"]["used_vouchers"]["value"], {"v_directors_cut": True})
        self.assertEqual(result["state"]["hands"]["value"]["Pair"]["played_this_round"], 2)
        self.assertEqual(result["cards"]["jokers"]["value"][0]["features"]["ability"]["yorick_discards"], 1)
        value["hands"]["Pair"]["played_this_round"] = 9
        self.assertEqual(result["state"]["hands"]["value"]["Pair"]["played_this_round"], 2)

    def test_collection_progress_and_objective_preserve_three_states_without_profile(self):
        for field, role in (("collection_progress", "progress_only"), ("completionist_goal", "objective")):
            with self.subTest(field=field):
                value = snapshot()
                value[field] = collection()
                value["teacher_profile"] = "perkeo_yorick_win_v1"
                result = encode(value)
                ledger = result["features"]["gold_collection"]
                self.assertTrue(ledger["known"])
                self.assertEqual(ledger["value"]["role"], role)
                self.assertEqual([t["status"] for t in ledger["value"]["targets"]], ["missing", "complete", "unknown"])
                self.assertFalse(ledger["value"]["targets"][2]["status_known"])
                self.assertNotIn("never-a-feature", json.dumps(result))
                self.assertEqual(len(ledger["value"]["targets"]), 3)

    def test_invalid_numeric_and_rng_nested_feature_data_rejected(self):
        value = snapshot()
        value["route_blinds"]["Boss"]["chips"] = float("nan")
        with self.assertRaises(ValueError):
            encode(value)
        value = snapshot()
        value["current_round"]["rng_state"] = "forbidden"
        with self.assertRaises(ValueError):
            encode(value)
        value = snapshot()
        value["pseudorandom"] = object()  # Root-level non-inputs are never inspected.
        self.assertEqual(encode(value), encode(snapshot()))


if __name__ == "__main__":
    unittest.main()
