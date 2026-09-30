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


if __name__ == "__main__":
    unittest.main()
