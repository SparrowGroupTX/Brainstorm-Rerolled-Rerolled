"""Explicit actor warm start from generic v1 to completionist_distinct_v1.

This is not continued training under the old reward. It retains the generic
actor, inserts zero columns for every new public goal-status input, and resets
the scalar value head because its target changed. The caller must record and
verify the source checkpoint SHA and frozen catalog provenance. The old model
metadata records catalog size/encoding, not a catalog-key-list digest; size alone
cannot establish that a different external catalog uses the same ID ordering.
"""

from __future__ import annotations

from collections.abc import Mapping
from copy import deepcopy
import math
from typing import Any

import torch

from .model import COMPLETIONIST_GOAL_SCHEMA, PublicCandidatePolicy


def migrate_to_completion(model: PublicCandidatePolicy, checkpoint: Mapping[str, Any]) -> dict[str, Any]:
    """Audit and load a generic actor into an explicitly specialized model.

    Every state tensor and source metadata field must match the expected generic
    architecture. All validation finishes before any model tensor is changed.
    No non-strict state loading, simulator access, forward pass, optimizer step,
    or random initialization occurs in this migration.

    The source and target must share width/depth/heads, categorical vocabulary
    size/encoding, and ordered-card encoding. Only the documented observation
    dimensions and goal-schema declaration may differ. Actor equality is
    numerical within backend precision, not a bitwise cross-kernel guarantee.
    """
    if not isinstance(model, PublicCandidatePolicy):
        raise TypeError("Target must be PublicCandidatePolicy")
    if model.config.goal_schema != COMPLETIONIST_GOAL_SCHEMA:
        raise ValueError("Target must explicitly select completionist_distinct_v1")
    if not isinstance(checkpoint, Mapping):
        raise ValueError("Checkpoint must be a mapping")
    if checkpoint.get("dimensions") != [80, 64, 160]:
        raise ValueError("Source checkpoint must use generic80/64/160 observations")
    if checkpoint.get("width") != model.config.width:
        raise ValueError("Source checkpoint width differs from target")
    source = checkpoint.get("model")
    if not isinstance(source, Mapping):
        raise ValueError("Missing source model state")

    target = model.state_dict()
    if set(source) != set(target):
        missing, unexpected = sorted(set(target) - set(source)), sorted(set(source) - set(target))
        raise ValueError(f"Source tensor keys differ: missing={missing}, unexpected={unexpected}")

    # Columns preceding categorical embeddings must be shifted, not appended
    # after those embeddings. Source: [base, categorical]; target:
    # [base, three status channels, categorical]. Global adds all 450 statuses.
    input_mappings = {
        "global_encoder.0.weight": (80, 450),
        "entity_encoder.0.weight": (64, 3),
        "candidate_encoder.0.weight": (160, 3),
    }
    if model.config.selected_card_encoding:
        input_mappings["selected_card_encoder.0.weight"] = (64, 3)
    source_shapes = {}
    for name, destination in target.items():
        shape = list(destination.shape)
        if name in input_mappings:
            if len(shape) != 2:
                raise ValueError(f"Expected matrix for remapped input: {name}")
            shape[1] -= input_mappings[name][1]
        source_shapes[name] = tuple(shape)

    expected_metadata = deepcopy(model.metadata())
    expected_metadata["config"].update(global_dim=80, entity_dim=64, candidate_dim=160)
    expected_metadata["config"].pop("goal_schema", None)
    expected_metadata.pop("goal_observation", None)
    expected_metadata["parameter_count"] = sum(math.prod(shape) for shape in source_shapes.values())
    if checkpoint.get("model_metadata") != expected_metadata:
        raise ValueError("Source model metadata differs from the exact expected generic architecture/catalog encoding")

    for name, destination in target.items():
        value = source[name]
        if not isinstance(value, torch.Tensor):
            raise ValueError(f"Source model state is not a tensor: {name}")
        if tuple(value.shape) != source_shapes[name]:
            raise ValueError(f"Source tensor shape differs: {name}")
        if value.dtype != destination.dtype:
            raise ValueError(f"Source tensor dtype differs: {name}")
        if value.layout != torch.strided:
            raise ValueError(f"Unsupported source tensor layout: {name}")
        if not bool(torch.isfinite(value).all()):
            raise ValueError(f"Nonfinite source tensor: {name}")

    migrated, accounting = {}, []
    for name, destination in target.items():
        original = source[name].detach().to(device=destination.device)
        if name in {"value_head.weight", "value_head.bias"}:
            migrated[name] = torch.zeros_like(destination)
            operation = "reset_value_head_zero_for_new_objective"
        elif name in input_mappings:
            base, added = input_mappings[name]
            mapped = torch.zeros_like(destination)
            mapped[:, :base] = original[:, :base]
            mapped[:, base + added:] = original[:, base:]
            migrated[name] = mapped
            operation = f"retain_base_and_categorical_insert_{added}_zero_input_columns_at_{base}"
        else:
            migrated[name] = original
            operation = "retain_exact"
        accounting.append({"tensor": name, "operation": operation,
                           "source_shape": list(source_shapes[name]),
                           "target_shape": list(destination.shape)})

    model.load_state_dict(migrated, strict=True)
    return {
        "migration": "generic_v1_actor_to_completionist_distinct_v1",
        "compatibility_scope": "actor_only_with_zero_new_goal_inputs; value_head_reset",
        "source_dimensions": [80, 64, 160],
        "target_dimensions": [530, 67, 163],
        "source_model_metadata": deepcopy(expected_metadata),
        "target_model_metadata": model.metadata(),
        "source_environment_sha256": checkpoint.get("environment_sha256"),
        "source_transitions": checkpoint.get("transitions"),
        "source_updates": checkpoint.get("updates"),
        "all_source_and_target_tensors_accounted": True,
        "tensor_count": len(accounting),
        "tensor_accounting": accounting,
        "new_goal_input_weights": "all_zero",
        "value_head": "weight_and_bias_zero; old_win_value_not_reused",
        "optimizer_state": "not_loaded; fresh_optimizer_required",
        "source_identity_requirement": "Caller must record source checkpoint SHA and verify unchanged frozen catalog-key ordering; old metadata lacks catalog-key-list digest.",
    }


__all__ = ["migrate_to_completion"]
