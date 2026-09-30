"""Manufactured CPU forward migration checks; no training or simulator use."""

from copy import deepcopy
import unittest

import torch

from .migration import migrate_to_completion
from .model import PublicCandidatePolicy


class CompletionistMigrationTests(unittest.TestCase):
    def setUp(self):
        torch.manual_seed(355)
        self.source = PublicCandidatePolicy(80, 64, 160, width=32, heads=4,
                                           catalog_size=10, catalog_embedding_dim=8).eval()
        self.target = PublicCandidatePolicy(530, 67, 163, width=32, heads=4,
                                           catalog_size=10, catalog_embedding_dim=8,
                                           goal_schema="completionist_distinct_v1").eval()
        self.checkpoint = {
            "model": deepcopy(self.source.state_dict()),
            "dimensions": [80, 64, 160], "width": 32,
            "model_metadata": self.source.metadata(),
            "environment_sha256": "manufactured-only",
            "transitions": 0, "updates": 0,
        }

    def inputs(self):
        g = torch.randn(2, 80)
        e = torch.randn(2, 4, 64)
        e[..., 0] = torch.tensor([1.0, 1.0, 0.0, 0.0])
        e[..., 8] = torch.tensor([1.0, 2.0, 1.0, 0.0]) / 128.0
        e[..., 9] = torch.tensor([2.0, 4.0, 6.0, 0.0]) / 11.0
        c = torch.randn(2, 5, 160)
        c[..., 30] = torch.tensor([2.0, 4.0, 6.0, 2.0, 0.0]) / 11.0
        c[..., 149:154] = 0.0
        c[:, 0, 149:151] = torch.tensor([1.0, 2.0]) / 128.0
        c[:, 1, 149:151] = torch.tensor([2.0, 1.0]) / 128.0
        em = torch.tensor([[True, True, True, False], [True, True, False, False]])
        cm = torch.tensor([[True, True, True, False, False], [True, True, True, True, False]])
        return g, e, em, c, cm

    def test_actor_matches_for_arbitrary_appended_goal_statuses_and_value_is_zero(self):
        report = migrate_to_completion(self.target, self.checkpoint)
        g, e, em, c, cm = self.inputs()
        with torch.inference_mode():
            baseline_logits, _ = self.source(g, e, em, c, cm)
            for _ in range(3):
                expanded_g = torch.cat((g, torch.randn(2, 450)), dim=-1)
                expanded_e = torch.cat((e, torch.randn(2, 4, 3)), dim=-1)
                expanded_c = torch.cat((c, torch.randn(2, 5, 3)), dim=-1)
                logits, value = self.target(expanded_g, expanded_e, em, expanded_c, cm)
                torch.testing.assert_close(logits, baseline_logits, rtol=1e-5, atol=1e-7)
                torch.testing.assert_close(value, torch.zeros_like(value), rtol=0, atol=0)
        self.assertTrue(report["all_source_and_target_tensors_accounted"])
        self.assertEqual(report["tensor_count"], len(self.source.state_dict()))
        self.assertEqual(report["optimizer_state"], "not_loaded; fresh_optimizer_required")

    def test_every_tensor_accounted_and_new_columns_zero(self):
        report = migrate_to_completion(self.target, self.checkpoint)
        states = self.target.state_dict()
        mappings = {"global_encoder.0.weight": (80, 450),
                    "entity_encoder.0.weight": (64, 3),
                    "candidate_encoder.0.weight": (160, 3),
                    "selected_card_encoder.0.weight": (64, 3)}
        for name, (base, added) in mappings.items():
            self.assertTrue((states[name][:, base:base + added] == 0).all())
            torch.testing.assert_close(states[name][:, :base], self.checkpoint["model"][name][:, :base], rtol=0, atol=0)
            torch.testing.assert_close(states[name][:, base + added:], self.checkpoint["model"][name][:, base:], rtol=0, atol=0)
        names = [item["tensor"] for item in report["tensor_accounting"]]
        self.assertEqual(set(names), set(self.source.state_dict()))
        self.assertEqual(len(names), len(set(names)))

    def test_catalog_architecture_and_tensor_identity_mismatches_reject_without_mutation(self):
        corruptions = [
            lambda cp: cp.update(dimensions=[530, 67, 163]),
            lambda cp: cp.update(width=64),
            lambda cp: cp["model_metadata"]["config"].update(catalog_size=11),
            lambda cp: cp["model_metadata"].update(catalog_encoding="different_catalog_identity"),
            lambda cp: cp["model"].update(unexpected_tensor=torch.zeros(1)),
            lambda cp: cp["model"].pop("policy_head.bias"),
            lambda cp: cp["model"].update({"global_encoder.0.weight": torch.zeros(32, 79)}),
            lambda cp: cp["model"].update({"policy_head.bias": cp["model"]["policy_head.bias"].double()}),
            lambda cp: cp["model"]["policy_head.bias"].fill_(float("nan")),
        ]
        original = deepcopy(self.target.state_dict())
        for change in corruptions:
            with self.subTest(corruption=change):
                checkpoint = deepcopy(self.checkpoint)
                change(checkpoint)
                with self.assertRaises(ValueError):
                    migrate_to_completion(self.target, checkpoint)
                for name, value in self.target.state_dict().items():
                    torch.testing.assert_close(value, original[name], rtol=0, atol=0)
        with self.assertRaises(ValueError):
            migrate_to_completion(self.source, self.checkpoint)

    def test_migration_does_not_consume_rng_or_mutate_source(self):
        rng = torch.get_rng_state().clone()
        original = deepcopy(self.checkpoint["model"])
        migrate_to_completion(self.target, self.checkpoint)
        self.assertTrue(torch.equal(rng, torch.get_rng_state()))
        for name, value in original.items():
            torch.testing.assert_close(value, self.checkpoint["model"][name], rtol=0, atol=0)


if __name__ == "__main__":
    unittest.main()
