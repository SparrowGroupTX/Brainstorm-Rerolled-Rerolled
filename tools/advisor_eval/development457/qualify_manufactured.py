"""Freeze independent manufactured booster-slot comparisons; no source execution."""
from __future__ import annotations

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import zipfile

from tools.advisor_learning import simulator_patches as patches
from tools.advisor_learning.lifecycle_contract import compare_lifecycle
from tools.advisor_learning.lifecycle_reference_457 import source_rule_open, source_rule_stock
from tools.advisor_learning.test_lifecycle_457 import (
    SIM, candidate_open, candidate_stock, cases, compare_stock, manifest,
)


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
ARCHIVE = Path("C:/Program Files (x86)/Steam/steamapps/common/Balatro/Balatro.exe")
EXPECTED_ARCHIVE = "0d75fe164accf3312734d4b37ac98788dd15f0b8e4f9bb8b7f90c4e59de93f47"


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> None:
    patches.apply_patches(SIM)
    archive_hash = digest(ARCHIVE)
    if archive_hash != EXPECTED_ARCHIVE:
        raise RuntimeError("Original source archive changed")
    with zipfile.ZipFile(ARCHIVE) as source:
        source_members = {
            name: hashlib.sha256(source.read(name)).hexdigest()
            for name in ("game.lua", "card.lua", "functions/button_callbacks.lua",
                         "functions/common_events.lua")
        }
    if source_members["game.lua"] != "bbc67bd3fbadd1ea3f3f0aba07ef8596118d89ff1e9758718f9e17c07a96e912":
        raise RuntimeError("Original game.lua changed")
    if source_members["functions/button_callbacks.lua"] != "c88a74ca3a8fa8ace0ce46ad10a97238f347c292842c9164d11136fe9952c101":
        raise RuntimeError("Original button_callbacks.lua changed")

    fixtures = cases()
    baseline = [compare_stock(fixture, baseline=True) for fixture in fixtures]
    repaired = [compare_stock(fixture) for fixture in fixtures]
    if any(item["agreement"] for item in baseline):
        raise RuntimeError("Expected every unpatched stock case to expose a difference")
    if any(not item["agreement"] for item in repaired):
        raise RuntimeError("A repaired stock case differs from source-rule model")

    opening_fixture = fixtures[0]
    expected_open = source_rule_open(source_rule_stock(opening_fixture), 0)
    opening_baseline = compare_lifecycle(
        opening_fixture["id"] + "_open_baseline",
        manifest(opening_fixture, baseline=True), expected_open,
        candidate_open(opening_fixture, 0, baseline=True),
        {"command": "python -B -m tools.advisor_eval.development457.qualify_manufactured"},
    )
    opening_repaired = compare_lifecycle(
        opening_fixture["id"] + "_open",
        manifest(opening_fixture), expected_open,
        candidate_open(opening_fixture, 0),
        {"command": "python -B -m tools.advisor_eval.development457.qualify_manufactured"},
    )
    if opening_baseline["agreement"] or not opening_repaired["agreement"]:
        raise RuntimeError("Booster opening comparison changed unexpectedly")

    expected_stock = source_rule_stock(opening_fixture)
    actual_stock, _ = candidate_stock(opening_fixture)
    wrong_position = deepcopy(actual_stock)
    wrong_position["events"][0]["slot"] = 1
    negative_control = compare_lifecycle(
        opening_fixture["id"] + "_wrong_position", manifest(opening_fixture),
        expected_stock, wrong_position,
        {"mutation": "change offered physical slot from 2 to 1"},
    )
    if negative_control["agreement"] or negative_control["first_difference"]["field"] != "events[0].slot":
        raise RuntimeError("Position negative control was not detected")

    provenance = {
        "schema": "manufactured_booster_slot_qualification_457_v1",
        "original_source_executed": False,
        "source_archive_sha256": archive_hash,
        "source_member_sha256": source_members,
        "runner_before_sha256": digest(HERE.parent / "development456/frozen/run_lua_tests.py"),
        "runner_after_sha256": digest(ROOT / "tests/run_lua_tests.py"),
        "old_integration_sha256": digest(HERE.parent / "development456/frozen/simulator_patches.py"),
        "qualification_script_sha256": digest(Path(__file__)),
    }
    (HERE / "BASELINE_COMPARISONS.json").write_text(
        json.dumps({**provenance, "comparisons": baseline + [opening_baseline]},
                   indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (HERE / "MANUFACTURED_COMPARISONS.json").write_text(
        json.dumps({**provenance, "comparisons": repaired + [opening_repaired],
                    "negative_control": negative_control},
                   indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"{len(repaired)} stock and 1 opening comparisons agree; "
          f"{len(baseline)} stock and 1 opening baseline differences preserved")


if __name__ == "__main__":
    main()
