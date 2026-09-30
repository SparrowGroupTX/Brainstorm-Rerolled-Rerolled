"""Freeze a read-only original-source probe; does not execute Lua.

Reads Balatro.exe strictly as a ZIP archive and verifies member hashes before
copying selected functions into an isolated Lua probe. Run is separate.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import zipfile

from tools.advisor_eval.discard_source_parity import function_source

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
INSTALL = Path("C:/Program Files (x86)/Steam/steamapps/common/Balatro")
MEMBERS = {
    "card.lua": "5073d834e08119da9516f1795a8c3d93110669aeb409c29ad1b308e0eb0be453",
    "functions/common_events.lua": "522ea0810101de1004685e13e7ed05a750b4e115e5231dca2cbc97aeb8c3e5fc",
    "functions/state_events.lua": "6c86aefb42d0323d737f87aaa84f53e42b755e72cd0bfd163b7d9cca5c0a99a9",
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
        return "{" + ",".join(to_lua(v) for v in value) + "}"
    if isinstance(value, dict):
        return "{" + ",".join("[" + to_lua(k) + "]=" + to_lua(v)
                              for k, v in value.items()) + "}"
    raise TypeError(type(value).__name__)


def source_round_loop(source: str) -> str:
    scope = source.index("function end_round(")
    start = source.index("for i = 1, #G.jokers.cards do", scope)
    end_call = source.index("G.jokers.cards[i]:calculate_perishable()", start)
    end = source.index("\n            end", end_call) + len("\n            end")
    loop = source[start:end]
    assert loop.count("calculate_rental()") == 1
    assert loop.count("calculate_perishable()") == 1
    assert loop.count("calculate_joker(") == 1
    return "function source_round_end_loop()\n local game_over = false\n" + loop + "\nend"


def main() -> None:
    fixtures = json.loads((HERE / "fixtures.json").read_text(encoding="utf-8"))
    assert len(fixtures["cases"]) == 7
    with zipfile.ZipFile(INSTALL / "Balatro.exe") as archive:
        source = {}
        for name, expected in MEMBERS.items():
            raw = archive.read(name)
            assert hashlib.sha256(raw).hexdigest() == expected, name
            source[name] = raw.decode("utf-8")
    card = source["card.lua"]
    chunks = ["Card = {}; G = {FUNCS = {}}"]
    for signature in (
        "function Card:set_debuff(", "function Card:remove_from_deck(",
        "function Card:calculate_joker(", "function Card:calculate_rental(",
        "function Card:calculate_perishable(", "function Card:calculate_dollar_bonus(",
    ):
        chunks.append(function_source(card, signature))
    chunks.append(function_source(source["functions/common_events.lua"], "function ease_dollars("))
    state = source["functions/state_events.lua"]
    chunks.append(source_round_loop(state))
    chunks.append(function_source(state, "G.FUNCS.evaluate_round = function("))
    chunks.append("source_evaluate_round = G.FUNCS.evaluate_round")
    chunks.append("PROBE_CASES = " + to_lua(fixtures["cases"]))
    chunks.append((HERE / "probe_body.lua").read_text(encoding="utf-8"))
    probe = HERE / "prepared_source_probe.lua"
    probe.write_text("\n".join(chunks) + "\n", encoding="utf-8")
    dependencies = {
        "prepared_source_probe.lua": probe,
        "fixtures.json": HERE / "fixtures.json",
        "probe_body.lua": HERE / "probe_body.lua",
        "MANUFACTURED_COMPARISONS.json": HERE / "MANUFACTURED_COMPARISONS.json",
        "BASELINE_COMPARISONS.json": HERE / "BASELINE_COMPARISONS.json",
        "prepare_source_probe.py": HERE / "prepare_source_probe.py",
        "run_source_probe.py": HERE / "run_source_probe.py",
        "tests/run_lua_tests.py": ROOT / "tests/run_lua_tests.py",
        "tools/advisor_learning/lifecycle_454.py": ROOT / "tools/advisor_learning/lifecycle_454.py",
        "tools/advisor_learning/lifecycle_reference_454.py": ROOT / "tools/advisor_learning/lifecycle_reference_454.py",
        "tools/advisor_learning/lifecycle_contract.py": ROOT / "tools/advisor_learning/lifecycle_contract.py",
        "tools/advisor_learning/test_lifecycle_454.py": ROOT / "tools/advisor_learning/test_lifecycle_454.py",
        "tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/game.py": ROOT / "tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/game.py",
        "tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/economy.py": ROOT / "tools/advisor_eval/development355/external/jackdaw/jackdaw/engine/economy.py",
        "tools/advisor_learning/simulator_patches.py": ROOT / "tools/advisor_learning/simulator_patches.py",
        "lua51.dll": INSTALL / "lua51.dll",
    }
    manifest = {
        "schema": "golden_source_probe_prepared_v1",
        "source_archive": str(INSTALL / "Balatro.exe"),
        "source_archive_sha256": sha(INSTALL / "Balatro.exe"),
        "source_member_sha256": MEMBERS,
        "dependencies_sha256": {name: sha(path) for name, path in dependencies.items()},
        "case_ids": [case["id"] for case in fixtures["cases"]],
        "source_executed": False,
        "prepared_only": True,
    }
    (HERE / "SOURCE_PROBE_PREPARED.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
