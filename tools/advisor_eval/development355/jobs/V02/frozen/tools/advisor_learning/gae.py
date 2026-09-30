"""Pure GAE accounting with explicit terminal and unresolved boundaries.

This module does not import a simulator or an ML runtime. Unsupported, error,
and step-censored actions have no known successor value or terminal reward.
Their transition must be marked invalid; only the preceding observed transition
may bootstrap from the value of that unresolved action's observed pre-state.
"""

from __future__ import annotations

import math
from typing import Any


def _finite(value: Any, name: str) -> float:
    result = float(value)
    if not math.isfinite(result):
        raise ValueError(f"{name} must be finite")
    return result


def compute_gae(
    trajectory: list[dict[str, Any]],
    bootstrap: float,
    gamma: float = 0.997,
    gae_lambda: float = 0.99,
) -> list[dict[str, Any]]:
    """Return chronological shallow copies of valid entries with GAE targets.

    ``bootstrap`` is V of the observed successor after a rollout cutoff. Every
    entry supplies value, reward, valid, boundary and terminal. A true terminal
    has ``valid=True, boundary=True, terminal=True``. An unsupported/censored
    transition has ``valid=False`` and is omitted from all training targets.
    A nonterminal boundary cannot be valid without an observed successor, so
    that inconsistent encoding is rejected instead of imputing a bootstrap.

    Several episodes may occupy one worker trajectory. Recurrence resets at
    each real terminal or invalid transition and never crosses into the next
    episode. An invalid entry's finite pre-state value remains a legitimate
    bootstrap for the preceding valid transition; its reward is never read.
    """
    gamma = _finite(gamma, "gamma")
    gae_lambda = _finite(gae_lambda, "gae_lambda")
    if not 0.0 <= gamma <= 1.0 or not 0.0 <= gae_lambda <= 1.0:
        raise ValueError("gamma and gae_lambda must lie in [0, 1]")
    next_value = _finite(bootstrap, "bootstrap")
    advantage = 0.0
    reversed_results = []
    for source in reversed(trajectory):
        value = _finite(source["value"], "entry value")
        if not source["valid"]:
            # The action has an unresolved successor. Do not calculate its
            # delta or fabricate a terminal label, even if a reward is present.
            advantage = 0.0
            next_value = value
            continue
        terminal, boundary = bool(source["terminal"]), bool(source["boundary"])
        if terminal and not boundary:
            raise ValueError("A terminal transition must mark an episode boundary")
        if boundary and not terminal:
            raise ValueError("An unresolved nonterminal boundary must be invalid")
        if terminal:
            advantage = 0.0
            next_value = 0.0
        reward = _finite(source["reward"], "entry reward")
        delta = reward + gamma * next_value - value
        advantage = delta + gamma * gae_lambda * advantage
        item = dict(source)
        item["advantage"] = advantage
        item["return"] = advantage + value
        reversed_results.append(item)
        next_value = value
    reversed_results.reverse()
    return reversed_results


__all__ = ["compute_gae"]
