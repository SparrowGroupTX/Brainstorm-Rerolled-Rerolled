"""Freeze verbatim selected original source for a future one-use probe; do not run Lua."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import zipfile

from tools.advisor_learning import simulator_patches as patches
from tools.advisor_learning.lifecycle_reference_457 import source_rule_stock
from tools.advisor_learning.lifecycle_reference_458 import source_rule_open_callback
from tools.advisor_learning.test_lifecycle_457 import SIM, candidate_stock, cases
from tools.advisor_learning.test_lifecycle_458 import callback_open


ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
PRIOR = HERE.parent / "development457"
INSTALL = Path("C:/Program Files (x86)/Steam/steamapps/common/Balatro")
ARCHIVE_SHA256 = "0d75fe164accf3312734d4b37ac98788dd15f0b8e4f9bb8b7f90c4e59de93f47"
MEMBERS = {
    "game.lua": "bbc67bd3fbadd1ea3f3f0aba07ef8596118d89ff1e9758718f9e17c07a96e912",
    "functions/button_callbacks.lua": "c88a74ca3a8fa8ace0ce46ad10a97238f347c292842c9164d11136fe9952c101",
}
STOCK_SHA256 = "0c8c06229c81c70beeb9b0ed1e478af8313be3fe85f07cab878294af05d507e1"
USE_SHA256 = "7a8d594dc42d40754adc797bd60c076f840c1f882a55f52e8a47d2ea2d3c70fa"
DLL_SHA256 = "d0039528d0c48acf9e4b93e39f929ecd8def2b08c429971b809d8751aae49fb2"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_lines(raw: bytes, start: int, end: int, expected: str) -> str:
    fragment = b"".join(raw.splitlines(keepends=True)[start - 1:end])
    if hashlib.sha256(fragment).hexdigest() != expected:
        raise RuntimeError(f"Original source fragment drift at {start}-{end}")
    return fragment.decode("utf-8")


def to_lua(value):
    if value is None:
        return "nil"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list):
        return "{" + ",".join(f"[{i}]={to_lua(item)}" for i, item in enumerate(value, 1)
                            if item is not None) + "}"
    if isinstance(value, dict):
        return "{" + ",".join("[" + to_lua(key) + "]=" + to_lua(item)
                              for key, item in value.items() if item is not None) + "}"
    raise TypeError(type(value).__name__)


def main() -> None:
    archive_path = INSTALL / "Balatro.exe"
    if sha(archive_path) != ARCHIVE_SHA256 or sha(INSTALL / "lua51.dll") != DLL_SHA256:
        raise RuntimeError("Original archive or Lua DLL drift")
    with zipfile.ZipFile(archive_path) as archive:
        source = {}
        for name, expected in MEMBERS.items():
            raw = archive.read(name)
            if hashlib.sha256(raw).hexdigest() != expected:
                raise RuntimeError("Original source member drift: " + name)
            source[name] = raw
    stock = source_lines(source["game.lua"], 3145, 3159, STOCK_SHA256)
    use = source_lines(source["functions/button_callbacks.lua"], 2241, 2247, USE_SHA256)
    if stock.splitlines()[0].strip() != "for i = 1, 2 do" or stock.splitlines()[-1].strip() != "end":
        raise RuntimeError("Stock fragment anchors changed")
    if use.splitlines()[0].strip() != "delay(0.1)" or use.splitlines()[-1].strip() != "e.config.ref_table:open()":
        raise RuntimeError("Use fragment anchors changed")

    fixtures = cases()
    if len(fixtures) != 8 or len({case["id"] for case in fixtures}) != 8:
        raise RuntimeError("Expected eight unique frozen cases")
    patches.apply_patches(SIM)
    observations = []
    for fixture in fixtures:
        candidate, _ = candidate_stock(fixture)
        reference = source_rule_stock(fixture)
        if candidate != reference:
            raise RuntimeError("Manufactured candidate/reference drift: " + fixture["id"])
        observations.append({"id": fixture["id"], "reference": reference,
                             "candidate": candidate})
    opening_fixture = fixtures[0]
    opening_reference = source_rule_open_callback(
        opening_fixture["used_packs"], slot=2,
        key="p_arcana_normal_1", cash=4, price=4)
    opening_candidate = callback_open()
    if opening_reference != opening_candidate:
        raise RuntimeError("Manufactured opening callback drift")
    expected_path = HERE / "EXPECTED_COMPARISONS.json"
    expected_path.write_text(json.dumps({
        "schema": "booster_source_expected_458_v1", "cases": observations,
        "opening": {"case_id": opening_fixture["id"],
                    "reference": opening_reference, "candidate": opening_candidate},
        "original_source_executed": False,
    }, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    probe = ("-- Prepared only. Exact original snippets below remain unexecuted.\n"
             "G = {}\nsource_stock = function()\n" + stock + "end\n"
             "source_use_booster = function(card, e)\n" + use + "end\n"
             "PROBE_CASES = " + to_lua(fixtures) + "\n"
             + (HERE / "probe_body.lua").read_text(encoding="utf-8") + "\n")
    prepared_path = HERE / "prepared_source_probe.lua"
    prepared_path.write_text(probe, encoding="utf-8")

    dependencies = {
        "ACCEPTANCE.md": HERE / "ACCEPTANCE.md",
        "SOURCE_EXECUTION_PROPOSAL.md": HERE / "SOURCE_EXECUTION_PROPOSAL.md",
        "probe_body.lua": HERE / "probe_body.lua",
        "prepared_source_probe.lua": prepared_path,
        "EXPECTED_COMPARISONS.json": expected_path,
        "prepare_source_probe.py": HERE / "prepare_source_probe.py",
        "run_source_probe.py": HERE / "run_source_probe.py",
        "test_probe_parser.py": HERE / "test_probe_parser.py",
        "qualify_manufactured.py": HERE / "qualify_manufactured.py",
        "MANUFACTURED_COMPARISONS.json": HERE / "MANUFACTURED_COMPARISONS.json",
        "tools/advisor_eval/development457/fixtures.json": PRIOR / "fixtures.json",
        "tools/advisor_eval/development457/MANUFACTURED_COMPARISONS.json": PRIOR / "MANUFACTURED_COMPARISONS.json",
        "tools/advisor_eval/development457/frozen/simulator_patches.py": PRIOR / "frozen/simulator_patches.py",
        "tools/advisor_learning/lifecycle_457.py": ROOT / "tools/advisor_learning/lifecycle_457.py",
        "tools/advisor_learning/lifecycle_458.py": ROOT / "tools/advisor_learning/lifecycle_458.py",
        "tools/advisor_learning/lifecycle_reference_457.py": ROOT / "tools/advisor_learning/lifecycle_reference_457.py",
        "tools/advisor_learning/lifecycle_reference_458.py": ROOT / "tools/advisor_learning/lifecycle_reference_458.py",
        "tools/advisor_learning/test_lifecycle_457.py": ROOT / "tools/advisor_learning/test_lifecycle_457.py",
        "tools/advisor_learning/test_lifecycle_458.py": ROOT / "tools/advisor_learning/test_lifecycle_458.py",
        "tools/advisor_learning/simulator_patches.py": ROOT / "tools/advisor_learning/simulator_patches.py",
        "tests/run_lua_tests.py": ROOT / "tests/run_lua_tests.py",
        "lua51.dll": INSTALL / "lua51.dll",
    }
    manifest = {
        "schema": "booster_source_probe_prepared_458_v1",
        "prepared_only": True, "source_executed": False,
        "source_archive": str(archive_path),
        "source_archive_sha256": ARCHIVE_SHA256,
        "source_member_sha256": MEMBERS,
        "source_fragment_sha256": {"stock": STOCK_SHA256, "use": USE_SHA256},
        "case_ids": [case["id"] for case in fixtures],
        "candidate_patch_id": patches.PATCH_ID,
        "dependencies_sha256": {name: sha(path) for name, path in dependencies.items()},
    }
    (HERE / "SOURCE_PROBE_PREPARED.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("Prepared eight-case original-source probe; no Lua or game source executed")


if __name__ == "__main__":
    main()
