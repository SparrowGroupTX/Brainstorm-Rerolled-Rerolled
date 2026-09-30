"""Freeze an isolated six-case original cash-out probe without executing Lua."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import zipfile

from tools.advisor_eval.discard_source_parity import function_source

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
PRIOR = HERE.parent / "development455"
INSTALL = Path("C:/Program Files (x86)/Steam/steamapps/common/Balatro")
ARCHIVE_SHA256 = "0d75fe164accf3312734d4b37ac98788dd15f0b8e4f9bb8b7f90c4e59de93f47"
MEMBERS = {
    "functions/button_callbacks.lua": "c88a74ca3a8fa8ace0ce46ad10a97238f347c292842c9164d11136fe9952c101",
    "functions/common_events.lua": "522ea0810101de1004685e13e7ed05a750b4e115e5231dca2cbc97aeb8c3e5fc",
    "engine/event.lua": "98d4e954397b9ddc81c6ec8eadae257960d1cc0ba10e9993f4b241c5dd15159e",
    "game.lua": "bbc67bd3fbadd1ea3f3f0aba07ef8596118d89ff1e9758718f9e17c07a96e912",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


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
        return "{" + ",".join(to_lua(item) for item in value) + "}"
    if isinstance(value, dict):
        return "{" + ",".join("[" + to_lua(key) + "]=" + to_lua(item)
                              for key, item in value.items()) + "}"
    raise TypeError(type(value).__name__)


def main() -> None:
    fixtures = json.loads((PRIOR / "fixtures.json").read_text(encoding="utf-8"))
    cases = fixtures["cases"]
    if len(cases) != 6 or len({case["id"] for case in cases}) != 6:
        raise RuntimeError("Expected six unique frozen cash-out cases")
    archive_path = INSTALL / "Balatro.exe"
    if sha(archive_path) != ARCHIVE_SHA256:
        raise RuntimeError("Original source archive drift")
    with zipfile.ZipFile(archive_path) as archive:
        source = {}
        for name, expected in MEMBERS.items():
            raw = archive.read(name)
            if hashlib.sha256(raw).hexdigest() != expected:
                raise RuntimeError("Original source member drift: " + name)
            source[name] = raw.decode("utf-8")

    chunks = ["G = {FUNCS = {}}"]
    chunks.append(function_source(source["functions/button_callbacks.lua"],
                                  "G.FUNCS.cash_out = function(e)"))
    chunks.append("source_cash_out = G.FUNCS.cash_out")
    chunks.append(function_source(source["functions/common_events.lua"],
                                  "function ease_dollars("))
    chunks.append(function_source(source["functions/common_events.lua"],
                                  "function reset_blinds("))
    chunks.append("PROBE_CASES = " + to_lua(cases))
    chunks.append((HERE / "probe_body.lua").read_text(encoding="utf-8"))
    probe = HERE / "prepared_source_probe.lua"
    probe.write_text("\n".join(chunks) + "\n", encoding="utf-8")

    dependencies = {
        "prepared_source_probe.lua": probe,
        "probe_body.lua": HERE / "probe_body.lua",
        "prepare_source_probe.py": HERE / "prepare_source_probe.py",
        "run_source_probe.py": HERE / "run_source_probe.py",
        "ACCEPTANCE.md": HERE / "ACCEPTANCE.md",
        "SOURCE_EXECUTION_PROPOSAL.md": HERE / "SOURCE_EXECUTION_PROPOSAL.md",
        "tools/advisor_eval/development455/fixtures.json": PRIOR / "fixtures.json",
        "tools/advisor_eval/development455/MANUFACTURED_COMPARISONS.json": PRIOR / "MANUFACTURED_COMPARISONS.json",
        "tools/advisor_eval/development455/BASELINE_COMPARISONS.json": PRIOR / "BASELINE_COMPARISONS.json",
        "tools/advisor_eval/discard_source_parity.py": ROOT / "tools/advisor_eval/discard_source_parity.py",
        "tools/advisor_learning/lifecycle_455.py": ROOT / "tools/advisor_learning/lifecycle_455.py",
        "tools/advisor_learning/lifecycle_reference_455.py": ROOT / "tools/advisor_learning/lifecycle_reference_455.py",
        "tools/advisor_learning/test_lifecycle_455.py": ROOT / "tools/advisor_learning/test_lifecycle_455.py",
        "tools/advisor_learning/simulator_patches.py": ROOT / "tools/advisor_learning/simulator_patches.py",
        "tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/game.py": ROOT / "tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/game.py",
        "tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/economy.py": ROOT / "tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/economy.py",
        "tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/shop.py": ROOT / "tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/shop.py",
        "tests/run_lua_tests.py": ROOT / "tests/run_lua_tests.py",
        "lua51.dll": INSTALL / "lua51.dll",
    }
    manifest = {
        "schema": "cash_out_source_probe_prepared_v1",
        "prepared_only": True,
        "source_executed": False,
        "source_archive": str(archive_path),
        "source_archive_sha256": ARCHIVE_SHA256,
        "source_member_sha256": MEMBERS,
        "case_ids": [case["id"] for case in cases],
        "dependencies_sha256": {name: sha(path) for name, path in dependencies.items()},
    }
    (HERE / "SOURCE_PROBE_PREPARED.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
