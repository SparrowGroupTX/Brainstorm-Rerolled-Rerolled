"""Manufactured CPU forward checks only; no training, simulator or game access."""

import unittest

import torch

try:
    from .model import PublicCandidatePolicy
except ImportError:
    from model import PublicCandidatePolicy


class PublicCandidatePolicyTests(unittest.TestCase):
    def setUp(self):
        torch.manual_seed(355)
        self.model = PublicCandidatePolicy(8, 6, 10, width=32, heads=4, depth=2).eval()
        self.global_features = torch.randn(2, 8)
        self.entities = torch.randn(2, 4, 6)
        self.entity_mask = torch.tensor([[True, True, False, False], [True, True, True, False]])
        self.candidates = torch.randn(2, 5, 10)
        self.candidate_mask = torch.tensor([[True, True, True, False, False], [True, True, True, True, False]])

    def forward(self, **overrides):
        inputs = dict(global_features=self.global_features, entities=self.entities,
                      entity_mask=self.entity_mask, candidates=self.candidates,
                      candidate_mask=self.candidate_mask)
        inputs.update(overrides)
        with torch.inference_mode():
            return self.model(**inputs)

    def test_shapes_mask_and_legal_probability(self):
        logits, value = self.forward()
        self.assertEqual(tuple(logits.shape), (2, 5))
        self.assertEqual(tuple(value.shape), (2,))
        self.assertEqual(logits.dtype, torch.float32)
        self.assertEqual(value.dtype, torch.float32)
        self.assertTrue(torch.isfinite(logits[self.candidate_mask]).all())
        self.assertTrue(torch.isneginf(logits[~self.candidate_mask]).all())
        probabilities = self.model.distribution(logits).probs
        torch.testing.assert_close(probabilities.sum(-1), torch.ones(2))
        self.assertTrue((probabilities[~self.candidate_mask] == 0).all())

    def test_candidate_permutation_and_dynamic_count(self):
        original, value = self.forward()
        order = torch.tensor([3, 1, 4, 0, 2])
        permuted, new_value = self.forward(candidates=self.candidates[:, order],
                                           candidate_mask=self.candidate_mask[:, order])
        torch.testing.assert_close(permuted, original[:, order])
        torch.testing.assert_close(new_value, value)
        # Exceed a fixed 500-action output vocabulary without changing model.
        large = torch.randn(2, 513, 10)
        logits, _ = self.forward(candidates=large, candidate_mask=torch.ones(2, 513, dtype=torch.bool))
        self.assertEqual(tuple(logits.shape), (2, 513))

    def test_padding_payload_and_length_do_not_change_real_outputs(self):
        logits, value = self.forward()
        entities = self.entities.clone()
        entities[~self.entity_mask] = torch.nan
        candidates = self.candidates.clone()
        candidates[~self.candidate_mask] = torch.inf
        padded_logits, padded_value = self.forward(
            entities=torch.cat((entities, torch.full((2, 3, 6), torch.nan)), dim=1),
            entity_mask=torch.cat((self.entity_mask, torch.zeros(2, 3, dtype=torch.bool)), dim=1),
            candidates=torch.cat((candidates, torch.full((2, 2, 10), torch.nan)), dim=1),
            candidate_mask=torch.cat((self.candidate_mask, torch.zeros(2, 2, dtype=torch.bool)), dim=1),
        )
        torch.testing.assert_close(padded_logits[:, :5], logits)
        torch.testing.assert_close(padded_value, value)

    def test_entity_storage_permutation_preserves_explicit_slot_features(self):
        logits, value = self.forward()
        order = torch.tensor([2, 0, 3, 1])
        changed, changed_value = self.forward(entities=self.entities[:, order],
                                              entity_mask=self.entity_mask[:, order])
        torch.testing.assert_close(changed, logits)
        torch.testing.assert_close(changed_value, value)

    def test_empty_entity_rows_and_zero_length_match(self):
        masked_logits, masked_value = self.forward(entity_mask=torch.zeros_like(self.entity_mask))
        empty_logits, empty_value = self.forward(entities=self.entities[:, :0],
                                                 entity_mask=self.entity_mask[:, :0])
        torch.testing.assert_close(masked_logits, empty_logits)
        torch.testing.assert_close(masked_value, empty_value)
        self.assertTrue(torch.isfinite(empty_value).all())

    def test_replay_and_serialized_architecture_are_deterministic(self):
        first = self.forward()
        second = self.forward()
        for left, right in zip(first, second):
            torch.testing.assert_close(left, right, rtol=0, atol=0)
        restored = PublicCandidatePolicy.from_metadata(self.model.metadata()).eval()
        restored.load_state_dict(self.model.state_dict(), strict=True)
        with torch.inference_mode():
            replay = restored(self.global_features, self.entities, self.entity_mask,
                              self.candidates, self.candidate_mask)
        for left, right in zip(first, replay):
            torch.testing.assert_close(left, right, rtol=0, atol=0)

    def test_fp32_final_projections_under_cpu_bf16_forward(self):
        with torch.autocast(device_type="cpu", dtype=torch.bfloat16):
            logits, value = self.forward()
        self.assertEqual(logits.dtype, torch.float32)
        self.assertEqual(value.dtype, torch.float32)
        self.assertTrue(torch.isfinite(logits[self.candidate_mask]).all())
        self.assertTrue(torch.isfinite(value).all())

    def test_configuration_shape_and_mask_errors(self):
        with self.assertRaises(ValueError):
            PublicCandidatePolicy(8, 6, 10, width=33, heads=4)
        with self.assertRaises(ValueError):
            PublicCandidatePolicy(8, 6, 10, depth=0)
        with self.assertRaises(ValueError):
            self.forward(candidate_mask=self.candidate_mask.float())
        with self.assertRaises(ValueError):
            self.forward(candidates=self.candidates[:, :0], candidate_mask=self.candidate_mask[:, :0])
        with self.assertRaises(ValueError):
            PublicCandidatePolicy.from_metadata({"architecture": "other", "config": {}})

    def test_default_capacity_is_substantial_and_configurable(self):
        # Constructing the model checks capacity; no optimization or training.
        model = PublicCandidatePolicy(80, 64, 160)
        parameters = model.metadata()["parameter_count"]
        self.assertGreaterEqual(parameters, 1_000_000)
        self.assertLessEqual(parameters, 5_000_000)
        wider = PublicCandidatePolicy(80, 64, 160, width=384)
        self.assertGreater(wider.metadata()["parameter_count"], parameters)

    def test_catalog_identity_decodes_as_shared_category_embedding(self):
        model = PublicCandidatePolicy(80, 64, 160, width=32, heads=4,
                                      catalog_size=10, catalog_embedding_dim=8).eval()
        entity = torch.zeros(1, 2, 64)
        candidate = torch.zeros(1, 2, 160)
        entity[0, :, 9] = torch.tensor([1.0 / 11.0, 10.0 / 11.0])
        candidate[0, :, 30] = entity[0, :, 9]
        with torch.inference_mode():
            entity_features = model._catalog_features(entity, 9, 24)
            candidate_features = model._catalog_features(candidate, 30, 45)
        torch.testing.assert_close(entity_features[..., -8:], candidate_features[..., -8:])
        torch.testing.assert_close(entity_features[0, 0, -8:], model.catalog_embedding.weight[1])
        torch.testing.assert_close(entity_features[0, 1, -8:], model.catalog_embedding.weight[10])
        self.assertTrue((entity_features[..., 9] == 0.0).all())
        self.assertTrue((candidate_features[..., 30] == 0.0).all())
        self.assertFalse(torch.equal(entity_features[0, 0, -8:], entity_features[0, 1, -8:]))
        unknown = model._catalog_features(torch.zeros(1, 1, 64), 9, 24)
        self.assertTrue((unknown[..., -8:] == 0.0).all())

    def test_catalog_model_forward_padding_autocast_and_metadata(self):
        model = PublicCandidatePolicy(80, 64, 160, width=32, heads=4,
                                      catalog_size=10, catalog_embedding_dim=8).eval()
        global_features = torch.zeros(2, 80)
        entities = torch.zeros(2, 3, 64)
        candidates = torch.zeros(2, 4, 160)
        entities[..., 9] = 3.0 / 11.0
        candidates[..., 30] = 8.0 / 11.0
        entity_mask = torch.tensor([[True, False, False], [True, True, False]])
        candidate_mask = torch.tensor([[True, True, False, False], [True, True, True, False]])
        entities[~entity_mask] = torch.nan
        candidates[~candidate_mask] = torch.nan
        with torch.inference_mode(), torch.autocast("cpu", dtype=torch.bfloat16):
            logits, value = model(global_features, entities, entity_mask, candidates, candidate_mask)
        self.assertEqual(logits.dtype, torch.float32)
        self.assertTrue(torch.isfinite(logits[candidate_mask]).all())
        self.assertTrue(torch.isfinite(value).all())
        restored = PublicCandidatePolicy.from_metadata(model.metadata())
        restored.load_state_dict(model.state_dict(), strict=True)
        self.assertEqual(restored.config.catalog_size, 10)

    def ordered_card_fixture(self):
        model = PublicCandidatePolicy(80, 64, 160, width=32, heads=4,
                                      catalog_size=10, catalog_embedding_dim=8).eval()
        entities = torch.zeros(1, 4, 64)
        entities[0, :3, 0] = 1.0  # three hand entities
        entities[0, :3, 7] = 1.0
        entities[0, :3, 8] = torch.tensor([1.0, 2.0, 3.0]) / 128.0
        entities[0, :3, 9] = torch.tensor([2.0, 4.0, 6.0]) / 11.0
        entities[0, 0, 29] = 1.0  # different seal/enhancement descriptions
        entities[0, 1, 30] = 1.0
        entities[0, 2, 24] = 6.0 / 11.0
        mask = torch.tensor([[True, True, True, False]])
        candidates = torch.zeros(1, 4, 160)
        candidates[0, 0, 149:151] = torch.tensor([1.0, 2.0]) / 128.0
        candidates[0, 1, 149:151] = torch.tensor([2.0, 1.0]) / 128.0
        candidates[0, 2, 149] = 3.0 / 128.0
        return model, entities, mask, candidates

    def test_selected_cards_preserve_ordered_death_targets(self):
        model, entities, mask, candidates = self.ordered_card_fixture()
        with torch.inference_mode():
            features = model._selected_card_features(entities, mask, candidates)
        self.assertFalse(torch.allclose(features[:, 0], features[:, 1]))
        # No selected target produces zero contribution, not a learned bias.
        self.assertTrue((features[:, 3] == 0).all())
        self.assertTrue(model.config.selected_card_encoding)
        disabled = PublicCandidatePolicy(80, 64, 160, width=32, heads=4,
                                         catalog_size=10, selected_card_encoding=False)
        self.assertIsNone(disabled.selected_card_encoder)

    def test_selected_branch_changes_only_candidates_referencing_changed_card(self):
        model, entities, mask, candidates = self.ordered_card_fixture()
        changed = entities.clone()
        changed[0, 2, 32] = 1.0
        with torch.inference_mode():
            before = model._selected_card_features(entities, mask, candidates)
            after = model._selected_card_features(changed, mask, candidates)
        # Full logits also legitimately depend on global entity context; this
        # isolates the ordered selected-card contribution to the candidate.
        torch.testing.assert_close(before[:, :2], after[:, :2], rtol=0, atol=0)
        torch.testing.assert_close(before[:, 3], after[:, 3], rtol=0, atol=0)
        self.assertFalse(torch.allclose(before[:, 2], after[:, 2]))

    def test_selected_slots_respect_area_padding_and_storage_permutation(self):
        model, entities, mask, candidates = self.ordered_card_fixture()
        entities[0, 3] = torch.nan
        with torch.inference_mode():
            original = model._selected_card_features(entities, mask, candidates)
            order = torch.tensor([2, 3, 1, 0])
            permuted = model._selected_card_features(entities[:, order], mask[:, order], candidates)
        torch.testing.assert_close(original, permuted)
        # A shop entity at slot3 must not resolve as hand slot3.
        entities[0, 2, 0] = 0.0
        entities[0, 2, 3] = 1.0
        with torch.inference_mode():
            nonhand = model._selected_card_features(entities, mask, candidates)
        self.assertTrue((nonhand[:, 2] == 0).all())

    def test_selected_redacted_cards_and_empty_entities_are_finite(self):
        model, entities, mask, candidates = self.ordered_card_fixture()
        # A hidden card contains only its public area/slot. No identity or
        # physical-ID input exists in the model interface.
        entities[0, 0] = 0.0
        entities[0, 0, 0] = 1.0
        entities[0, 0, 8] = 1.0 / 128.0
        with torch.inference_mode(), torch.autocast("cpu", dtype=torch.bfloat16):
            logits, value = model(torch.zeros(1, 80), entities, mask,
                                  candidates, torch.ones(1, 4, dtype=torch.bool))
            empty = model._selected_card_features(entities[:, :0], mask[:, :0], candidates)
        self.assertTrue(torch.isfinite(logits).all())
        self.assertTrue(torch.isfinite(value).all())
        self.assertTrue((empty == 0).all())

    def completionist_fixture(self):
        model = PublicCandidatePolicy(530, 67, 163, width=32, heads=4,
                                      catalog_size=10, catalog_embedding_dim=8,
                                      goal_schema="completionist_distinct_v1").eval()
        global_features = torch.zeros(1, 530)
        global_features[:, 80:].reshape(1, 150, 3)[..., 2] = 1.0  # unknown is explicit
        entities = torch.zeros(1, 2, 67)
        entities[..., 1] = 1.0  # public Joker row
        entities[..., 7] = 1.0
        entities[0, :, 8] = torch.tensor([1.0, 2.0]) / 128.0
        entities[0, :, 9] = torch.tensor([2.0, 4.0]) / 11.0
        entities[..., 12] = 1.0
        entities[..., 66] = 1.0
        candidates = torch.zeros(1, 2, 163)
        candidates[..., 9] = 1.0  # sell-Joker candidates for different cards
        candidates[..., 21:85] = entities[..., :64]
        candidates[..., 162] = 1.0
        return model, global_features, entities, candidates

    def test_completionist_goal_schema_has_explicit_typed_metadata(self):
        model, _, _, _ = self.completionist_fixture()
        metadata = model.metadata()
        self.assertEqual(metadata["config"]["goal_schema"], "completionist_distinct_v1")
        self.assertEqual(metadata["goal_observation"]["status_order"], ["missing", "gold", "unknown"])
        self.assertEqual(metadata["goal_observation"]["global_status_offset"], 80)
        self.assertTrue(model.config.selected_card_encoding)
        restored = PublicCandidatePolicy.from_metadata(metadata)
        restored.load_state_dict(model.state_dict(), strict=True)
        self.assertEqual(restored.metadata(), metadata)
        for dimensions in [(80, 64, 160), (530, 64, 163), (530, 67, 160)]:
            with self.assertRaises(ValueError):
                PublicCandidatePolicy(*dimensions, goal_schema="completionist_distinct_v1")
        with self.assertRaises(ValueError):
            PublicCandidatePolicy(530, 67, 163, goal_schema="unknown_goal")

    def test_completionist_global_goal_changes_relative_action_preferences(self):
        model, global_features, entities, candidates = self.completionist_fixture()
        changed_goal = global_features.clone()
        changed_goal[0, 80:83] = torch.tensor([1.0, 0.0, 0.0])
        entity_mask = torch.ones(1, 2, dtype=torch.bool)
        candidate_mask = torch.ones(1, 2, dtype=torch.bool)
        with torch.inference_mode():
            original_logits, original_value = model(global_features, entities, entity_mask, candidates, candidate_mask)
            changed_logits, changed_value = model(changed_goal, entities, entity_mask, candidates, candidate_mask)
        # Only objective history changed: same publicly observed physical cards
        # and candidates, with no extra seed or hidden-identity input.
        original_margin = original_logits[0, 0] - original_logits[0, 1]
        changed_margin = changed_logits[0, 0] - changed_logits[0, 1]
        self.assertGreater(float((original_margin - changed_margin).abs()), 1e-7)
        self.assertFalse(torch.equal(original_value, changed_value))

    def test_completionist_target_status_distinguishes_missing_gold_unknown(self):
        model, global_features, entities, candidates = self.completionist_fixture()
        # Three alternatives describe the same public card with different
        # explicit objective status, isolating the status encoder's capacity.
        statuses = candidates[:, :1].expand(1, 3, 163).clone()
        statuses[0, :, 160:163] = torch.eye(3)
        with torch.inference_mode():
            logits, value = model(global_features, entities, torch.ones(1, 2, dtype=torch.bool),
                                  statuses, torch.ones(1, 3, dtype=torch.bool))
        self.assertTrue(torch.isfinite(logits).all())
        self.assertTrue(torch.isfinite(value).all())
        self.assertGreater(float(logits.std()), 1e-7)


if __name__ == "__main__":
    unittest.main()
