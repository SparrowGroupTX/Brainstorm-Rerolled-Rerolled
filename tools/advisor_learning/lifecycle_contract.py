"""Pure, JSON-shaped comparison for bounded lifecycle evidence.

This module does not import a simulator or expose private test state to policy.
"""
from __future__ import annotations

from copy import deepcopy
from typing import Any


def _first_difference(expected: Any, actual: Any, path: str) -> dict[str, Any] | None:
    if type(expected) is not type(actual):
        return {"field": path, "expected": expected, "actual": actual}
    if isinstance(expected, dict):
        for key in sorted(set(expected) | set(actual)):
            child = f"{path}.{key}"
            if key not in expected or key not in actual:
                return {"field": child, "expected": expected.get(key, "<missing>"),
                        "actual": actual.get(key, "<missing>")}
            difference = _first_difference(expected[key], actual[key], child)
            if difference:
                return difference
    elif isinstance(expected, list):
        for index in range(min(len(expected), len(actual))):
            difference = _first_difference(expected[index], actual[index], f"{path}[{index}]")
            if difference:
                return difference
        if len(expected) != len(actual):
            return {"field": f"{path}.length", "expected": len(expected),
                    "actual": len(actual)}
    elif expected != actual:
        return {"field": path, "expected": expected, "actual": actual}
    return None


def compare_lifecycle(
    case_id: str,
    manifest: dict[str, Any],
    expected: dict[str, Any],
    actual: dict[str, Any],
    reproduction: dict[str, Any],
    *,
    classification: str = "manufactured",
) -> dict[str, Any]:
    """Return the first ordered-event difference, then the settled-state difference."""
    events_expected = expected["events"]
    events_actual = actual["events"]
    first = _first_difference(events_expected, events_actual, "events")
    if first is None:
        first = _first_difference(expected["state"], actual["state"], "state")
    prefix = 0
    for left, right in zip(events_expected, events_actual):
        if left != right:
            break
        prefix += 1
    return {
        "case_id": case_id,
        "manifest": deepcopy(manifest),
        "classification": classification,
        "agreement": first is None,
        "first_difference": deepcopy(first),
        "common_event_prefix": deepcopy(events_expected[:prefix]),
        "minimization_status": "manufactured_minimal" if case_id == "rental_juggler_last_tally" else "not_minimized",
        "reproduction": deepcopy(reproduction),
    }
