"""Public-observation policy/value network for variable legal candidate sets.

The environment owns observation semantics and legality. This module consumes
only its numeric public features; it never reads game state or invents actions.
Entity role and physical row position must be explicit input features. Padding
may be reordered or extended without changing the represented observation.

Training is intended for CUDA with caller-controlled autocast. The final policy
and value projections run in FP32, even inside a BF16 autocast context. There is
no dropout or hidden recurrent state, so replaying a batch is deterministic on
the same backend subject to that backend's deterministic-kernel settings.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
import math
from typing import Any, Mapping

import torch
from torch import Tensor, nn
from torch.nn import functional as F


ARCHITECTURE = "public_candidate_policy_v1"
COMPLETIONIST_GOAL_SCHEMA = "completionist_distinct_v1"


@dataclass(frozen=True)
class ModelConfig:
    global_dim: int
    entity_dim: int
    candidate_dim: int
    width: int = 256
    heads: int = 8
    depth: int = 2
    expansion: int = 2
    catalog_size: int = 0
    catalog_embedding_dim: int = 64
    selected_card_encoding: bool = False
    selected_card_width: int = 32
    goal_schema: str | None = None

    def __post_init__(self) -> None:
        for name, value in asdict(self).items():
            if name == "goal_schema":
                if value is not None and value != COMPLETIONIST_GOAL_SCHEMA:
                    raise ValueError("Unsupported goal schema")
                continue
            if name == "selected_card_encoding":
                if not isinstance(value, bool):
                    raise ValueError("selected_card_encoding must be bool")
                continue
            minimum = 0 if name == "catalog_size" else 1
            if isinstance(value, bool) or not isinstance(value, int) or value < minimum:
                raise ValueError(f"{name} must be a positive integer")
        if self.width % self.heads:
            raise ValueError("width must be divisible by heads")
        if self.catalog_size and (self.entity_dim < 25 or self.candidate_dim < 46):
            raise ValueError("Catalog embeddings require the public entity/target feature offsets")
        if self.selected_card_encoding and (self.entity_dim < 64 or self.candidate_dim < 160):
            raise ValueError("Selected-card encoding requires the public hand-slot feature schema")
        if self.goal_schema == COMPLETIONIST_GOAL_SCHEMA and (
            self.global_dim, self.entity_dim, self.candidate_dim
        ) != (530, 67, 163):
            raise ValueError("completionist_distinct_v1 requires global530/entity67/candidate163")


class _ResidualMLP(nn.Module):
    def __init__(self, width: int, expansion: int, residual_scale: float) -> None:
        super().__init__()
        self.norm = nn.LayerNorm(width)
        self.up = nn.Linear(width, width * expansion)
        self.down = nn.Linear(width * expansion, width)
        self.residual_scale = residual_scale

    def forward(self, features: Tensor) -> Tensor:
        residual = self.down(F.silu(self.up(self.norm(features))))
        return features + self.residual_scale * residual


def _blocks(width: int, expansion: int, depth: int) -> nn.Sequential:
    return nn.Sequential(*[
        _ResidualMLP(width, expansion, 1.0 / math.sqrt(depth))
        for _ in range(depth)
    ])


def _fp32_projection(layer: nn.Linear, features: Tensor) -> Tensor:
    # A cast after an autocast Linear would retain the lower-precision dot
    # product. Disable autocast for the actual final accumulation instead.
    with torch.autocast(device_type=features.device.type, enabled=False):
        bias = layer.bias.float() if layer.bias is not None else None
        return F.linear(features.float(), layer.weight.float(), bias)


class PublicCandidatePolicy(nn.Module):
    """Score each supplied candidate and estimate the state's terminal value.

    Inputs are ``global_features[B,G]``, ``entities[B,N,E]``,
    ``entity_mask[B,N]``, ``candidates[B,A,C]`` and ``candidate_mask[B,A]``.
    Masks are bool, with True meaning a real entity / admitted legal candidate.
    Output is ``logits[B,A], value[B]`` in FP32. Invalid candidate logits are
    negative infinity. The collector/collator must ensure at least one legal
    candidate per nonterminal row; terminal states are not policy inputs.

    There is no fixed entity/action output vocabulary or candidate-count cap.
    The environment's explicit observation bounds remain authoritative. Model
    width controls capacity independently of those bounds. No tensor-content
    validation in forward forces a CUDA synchronization on each policy call.
    """

    def __init__(
        self,
        global_dim: int,
        entity_dim: int,
        candidate_dim: int,
        width: int = 256,
        heads: int = 8,
        depth: int = 2,
        expansion: int = 2,
        catalog_size: int = 0,
        catalog_embedding_dim: int = 64,
        selected_card_encoding: bool | None = None,
        selected_card_width: int = 32,
        goal_schema: str | None = None,
    ) -> None:
        super().__init__()
        if selected_card_encoding is None:
            selected_card_encoding = catalog_size > 0 and entity_dim >= 64 and candidate_dim >= 160
        self.config = ModelConfig(global_dim, entity_dim, candidate_dim,
                                  width, heads, depth, expansion, catalog_size, catalog_embedding_dim,
                                  selected_card_encoding, selected_card_width, goal_schema)
        self.catalog_embedding = nn.Embedding(catalog_size + 1, catalog_embedding_dim, padding_idx=0) if catalog_size else None
        categorical_width = catalog_embedding_dim if catalog_size else 0
        self.global_encoder = nn.Sequential(
            nn.Linear(global_dim, width), nn.SiLU(),
            _blocks(width, expansion, depth), nn.LayerNorm(width),
        )
        self.entity_encoder = nn.Sequential(
            nn.Linear(entity_dim + categorical_width, width), nn.SiLU(),
            _blocks(width, expansion, 1), nn.LayerNorm(width),
        )
        self.query = nn.Linear(width, width)
        self.key_value = nn.Linear(width, 2 * width)
        self.attention_output = nn.Linear(width, width)
        self.context = nn.Sequential(
            nn.Linear(3 * width, 2 * width), nn.SiLU(),
            nn.Linear(2 * width, width), nn.LayerNorm(width),
        )
        self.candidate_encoder = nn.Sequential(
            nn.Linear(candidate_dim + categorical_width, width), nn.SiLU(),
        )
        self.selected_card_encoder = nn.Sequential(
            nn.Linear(entity_dim + categorical_width, selected_card_width), nn.SiLU(),
            nn.Linear(selected_card_width, selected_card_width), nn.SiLU(),
        ) if selected_card_encoding else None
        self.selected_card_projection = nn.Linear(5 * selected_card_width, width, bias=False) if selected_card_encoding else None
        self.candidate_condition = nn.Linear(width, 2 * width)
        self.candidate_blocks = _blocks(width, expansion, depth)
        self.candidate_norm = nn.LayerNorm(width)
        self.policy_head = nn.Linear(width, 1)
        self.value_body = nn.Sequential(
            nn.Linear(width, width), nn.SiLU(), nn.LayerNorm(width),
        )
        self.value_head = nn.Linear(width, 1)
        self.apply(self._initialize)
        nn.init.orthogonal_(self.policy_head.weight, gain=0.01)
        nn.init.orthogonal_(self.value_head.weight, gain=1.0)

    @staticmethod
    def _initialize(module: nn.Module) -> None:
        if isinstance(module, nn.Linear):
            nn.init.xavier_uniform_(module.weight)
            if module.bias is not None:
                nn.init.zeros_(module.bias)
        elif isinstance(module, nn.LayerNorm):
            nn.init.ones_(module.weight)
            nn.init.zeros_(module.bias)
        elif isinstance(module, nn.Embedding):
            nn.init.normal_(module.weight, mean=0.0, std=0.1)
            if module.padding_idx is not None:
                with torch.no_grad():
                    module.weight[module.padding_idx].zero_()

    def metadata(self) -> dict[str, Any]:
        """JSON-compatible architecture metadata; observation schema is external."""
        config = asdict(self.config)
        # Keep generic v1 metadata compatible when this optional schema is off.
        if config["goal_schema"] is None:
            del config["goal_schema"]
        result = {
            "architecture": ARCHITECTURE,
            "config": config,
            "parameter_count": sum(parameter.numel() for parameter in self.parameters()),
            "input_scope": "public_features_and_environment_legal_candidates",
            "mask_true_means": "valid",
            "output_dtype": "float32",
            "catalog_encoding": "normalized_sorted_center_id_v1" if self.config.catalog_size else None,
            "selected_card_encoding": "five_ordered_public_hand_slots_v1" if self.config.selected_card_encoding else None,
        }
        if self.config.goal_schema:
            result["goal_observation"] = {
                "schema": self.config.goal_schema,
                "joker_count": 150,
                "status_order": ["missing", "gold", "unknown"],
                "global_status_offset": 80,
                "entity_status_offset": 64,
                "candidate_target_status_offset": 160,
                "registry_order": "sorted_vanilla_joker_keys",
                "scope": "public_objective_history_not_hidden_card_identity",
            }
        return result

    @classmethod
    def from_metadata(cls, metadata: Mapping[str, Any]) -> "PublicCandidatePolicy":
        if metadata.get("architecture") != ARCHITECTURE:
            raise ValueError("Unsupported policy architecture")
        config = metadata.get("config")
        if not isinstance(config, Mapping):
            raise ValueError("Missing policy configuration")
        model = cls(**dict(config))
        if metadata.get("parameter_count", model.metadata()["parameter_count"]) != model.metadata()["parameter_count"]:
            raise ValueError("Policy parameter count disagrees with configuration")
        return model

    def _catalog_features(self, features: Tensor, center_offset: int, enhancement_offset: int) -> Tensor:
        if self.catalog_embedding is None:
            return features
        # The environment assigns (sorted center index + 1)/(catalog_size+1).
        # Decode in FP32 before indexing: nearby center IDs are categories,
        # not continuous values with an implied ordering of Joker effects.
        normalized = features[..., center_offset].float()
        decoded = torch.round(normalized * (self.config.catalog_size + 1)).long()
        valid = torch.isfinite(normalized) & (decoded >= 0) & (decoded <= self.config.catalog_size)
        indices = torch.where(valid, decoded, 0)
        embedded = self.catalog_embedding(indices)
        numeric = features.clone()
        numeric[..., center_offset] = 0.0
        numeric[..., enhancement_offset] = 0.0  # same center key for Enhanced cards
        return torch.cat((numeric, embedded.to(numeric.dtype)), dim=-1)

    def _selected_card_features(self, entities: Tensor, entity_mask: Tensor, candidates: Tensor) -> Tensor:
        """Encode selected public hand cards in the action's explicit order.

        Public schema v1 stores area-hand at entity[0], 1-based slot/128 at
        entity[8], and up to five ordered target slots/128 at candidate[149:154].
        Build a small lookup from these public coordinates, not physical IDs or
        input storage ordering. Each hand token is encoded once per state.
        """
        if self.selected_card_encoder is None or self.selected_card_projection is None:
            raise RuntimeError("Selected-card feature branch is disabled")
        batch, count, _ = entities.shape
        safe_entities = torch.where(entity_mask.unsqueeze(-1), entities, 0.0)
        card_tokens = self.selected_card_encoder(self._catalog_features(safe_entities, 9, 24))
        public_slots = torch.round(safe_entities[..., 8].float() * 128.0).long()
        hand_mask = entity_mask & (safe_entities[..., 0] > 0.5) & (public_slots > 0) & (public_slots <= 128)
        lookup_indices = torch.where(hand_mask, public_slots, 0)
        card_tokens = torch.where(hand_mask.unsqueeze(-1), card_tokens, 0.0)
        token_width = self.config.selected_card_width
        lookup = card_tokens.new_zeros((batch, 129, token_width))
        lookup = lookup.scatter_add(1, lookup_indices.unsqueeze(-1).expand(batch, count, token_width), card_tokens)
        ordered_slots = torch.round(candidates[..., 149:154].float() * 128.0).long()
        ordered_slots = torch.where((ordered_slots > 0) & (ordered_slots <= 128), ordered_slots, 0)
        gather_indices = ordered_slots.reshape(batch, -1, 1).expand(batch, -1, token_width)
        selected = lookup.gather(1, gather_indices).reshape(batch, candidates.shape[1], 5 * token_width)
        return self.selected_card_projection(selected)

    def _check_shapes(
        self,
        global_features: Tensor,
        entities: Tensor,
        entity_mask: Tensor,
        candidates: Tensor,
        candidate_mask: Tensor,
    ) -> None:
        cfg = self.config
        if global_features.ndim != 2 or global_features.shape[-1] != cfg.global_dim:
            raise ValueError("global_features must have shape [B, global_dim]")
        batch = global_features.shape[0]
        if entities.ndim != 3 or entities.shape[0] != batch or entities.shape[-1] != cfg.entity_dim:
            raise ValueError("entities must have shape [B, N, entity_dim]")
        if candidates.ndim != 3 or candidates.shape[0] != batch or candidates.shape[-1] != cfg.candidate_dim:
            raise ValueError("candidates must have shape [B, A, candidate_dim]")
        if candidates.shape[1] == 0:
            raise ValueError("Nonterminal policy input requires legal candidates")
        if entity_mask.shape != entities.shape[:2] or candidate_mask.shape != candidates.shape[:2]:
            raise ValueError("Masks must match their entity/candidate dimensions")
        if entity_mask.dtype != torch.bool or candidate_mask.dtype != torch.bool:
            raise ValueError("Masks must be bool with True meaning valid")

    def _entity_context(self, query_context: Tensor, entities: Tensor, mask: Tensor) -> tuple[Tensor, Tensor]:
        batch, count, _ = entities.shape
        if count == 0:
            empty = torch.zeros_like(query_context)
            return empty, empty

        # Ignore arbitrary padding payloads, including nonfinite sentinels,
        # before applying the encoder. They must not contaminate real tokens.
        safe_entities = torch.where(mask.unsqueeze(-1), entities, 0.0)
        encoded = self.entity_encoder(self._catalog_features(safe_entities, 9, 24))
        valid = mask.unsqueeze(-1)
        masked = torch.where(valid, encoded, 0.0)
        # FP32 accumulation improves stability for differently sized sets.
        mean = masked.float().sum(dim=1) / mask.sum(dim=1, keepdim=True).clamp_min(1).float()
        mean = mean.to(query_context.dtype)

        heads = self.config.heads
        head_dim = self.config.width // heads
        query = self.query(query_context).reshape(batch, 1, heads, head_dim).transpose(1, 2)
        key, value = self.key_value(encoded).chunk(2, dim=-1)
        key = key.reshape(batch, count, heads, head_dim).transpose(1, 2)
        value = value.reshape(batch, count, heads, head_dim).transpose(1, 2)
        attended = F.scaled_dot_product_attention(
            query, key, value, attn_mask=mask[:, None, None, :], dropout_p=0.0,
        ).transpose(1, 2).reshape(batch, self.config.width)
        attended = self.attention_output(attended)
        # SDPA handles fully masked rows; remove output bias as well so zero
        # real entities have exactly the same context as a zero-length set.
        attended = torch.where(mask.any(dim=1, keepdim=True), attended, 0.0)
        return mean, attended

    def forward(
        self,
        global_features: Tensor,
        entities: Tensor,
        entity_mask: Tensor,
        candidates: Tensor,
        candidate_mask: Tensor,
    ) -> tuple[Tensor, Tensor]:
        self._check_shapes(global_features, entities, entity_mask, candidates, candidate_mask)
        global_context = self.global_encoder(global_features)
        entity_mean, entity_attention = self._entity_context(global_context, entities, entity_mask)
        context = self.context(torch.cat((global_context, entity_mean, entity_attention), dim=-1))

        safe_candidates = torch.where(candidate_mask.unsqueeze(-1), candidates, 0.0)
        candidate_hidden = self.candidate_encoder(self._catalog_features(safe_candidates, 30, 45))
        if self.selected_card_encoder is not None:
            candidate_hidden = candidate_hidden + self._selected_card_features(entities, entity_mask, safe_candidates)
        scale, bias = self.candidate_condition(context).chunk(2, dim=-1)
        # Broadcast one context projection per state; do not allocate repeated
        # [B,A,context] tensors or encode global/entity features per action.
        candidate_hidden = candidate_hidden * (1.0 + torch.tanh(scale[:, None, :])) + bias[:, None, :]
        candidate_hidden = self.candidate_norm(self.candidate_blocks(candidate_hidden))
        logits = _fp32_projection(self.policy_head, candidate_hidden).squeeze(-1)
        logits = logits.masked_fill(~candidate_mask, -torch.inf)
        value = _fp32_projection(self.value_head, self.value_body(context)).squeeze(-1)
        return logits, value

    @staticmethod
    def distribution(logits: Tensor) -> torch.distributions.Categorical:
        """FP32 distribution over admitted candidates, preserving padding masks.

        The collector validates nonempty legal rows before the hot GPU path.
        Disabling distribution argument checks avoids hidden host synchronizes.
        """
        return torch.distributions.Categorical(logits=logits.float(), validate_args=False)


__all__ = ["ARCHITECTURE", "COMPLETIONIST_GOAL_SCHEMA", "ModelConfig", "PublicCandidatePolicy"]
