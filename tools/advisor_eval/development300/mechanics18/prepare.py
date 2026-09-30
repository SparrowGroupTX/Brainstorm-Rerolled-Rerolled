"""Prepare distinct M18 inputs from corrected M17 draft; no registration/run."""
from pathlib import Path
import ast
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
FIX = HERE.parent / "mechanics17_preload_fix"
PREVIOUS = HERE.parent / "mechanics17"

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def once(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new, 1)

def main():
    adapter = HERE / "adapter"
    adapter.mkdir(exist_ok=False)
    provenance = {}
    for path in (FIX / "adapter").iterdir():
        if not path.is_file():
            continue
        raw = path.read_bytes()
        candidate = raw.replace(b"M17", b"M18")
        (adapter / path.name).write_bytes(candidate)
        provenance[path.name] = {"corrected_M17_draft_sha256": sha(raw), "M18_sha256": sha(candidate)}
    register = (PREVIOUS / "register.py").read_text(encoding="utf-8").replace("M17", "M18")
    register = register.replace("fallback307_installed", "gold308_installed").replace("installed307", "installed308").replace("2.107.0-alpha", "2.108.0-alpha")
    register = once(register, '    files["frozen_product_record.json"] = record_path', '''    prior = ROOT / "tools/advisor_eval/runs/gold299_20260914/M17"
    for name in ("audit.json", "record.json", "registration.json", "spent.json", "trace.log"):
        files["evidence/M17/" + name] = prior / name
    for name in ("generated_preload_syntax.lua", "validation.json", "manifest.json"):
        files["evidence/preload_fix/" + name] = HERE.parent / "mechanics17_preload_fix" / name
    files["frozen_product_record.json"] = record_path''')
    register = once(register, '        "full_game_update": False, "qualification": False,',
        '        "predecessor": "M17 remains spent error before source execution; M18 is a distinct approved component with corrected preload serialization",\n'
        '        "preload_validation": "Ten frozen compile-only checks; original malformed snippets reject and corrected snippets parse",\n'
        '        "full_game_update": False, "qualification": False,')
    (HERE / "register.py").write_text(register, encoding="utf-8", newline="\n")
    for name in ("syntax.lua", "test_preparation.py"):
        text = (PREVIOUS / name).read_text(encoding="utf-8").replace("M17", "M18").replace("mechanics17/", "mechanics18/")
        if name == "test_preparation.py":
            text = text.replace('for name, expected in original.items():\n        check(hashlib.sha256((ROOT / "tools/advisor_eval/runs/gold299_20260914/M12" / name).read_bytes()).hexdigest() == expected)',
                'for name, expected in original.items():\n        check(hashlib.sha256((HERE / "adapter" / name).read_bytes()).hexdigest() == expected["M18_sha256"])')
        (HERE / name).write_text(text, encoding="utf-8", newline="\n")
    record_path = ROOT / "tools/advisor_eval/runs/gold308_installed/record.json"
    record = json.loads(record_path.read_text(encoding="utf-8"))
    assert record["version"] == "2.108.0-alpha"
    with (HERE / "parent_evidence_hashes.json").open("x", encoding="utf-8") as stream:
        json.dump(provenance, stream, indent=2)
        stream.write("\n")
    with (HERE / "target_policy.json").open("x", encoding="utf-8") as stream:
        json.dump({"record": record_path.relative_to(ROOT).as_posix(), "record_sha256": sha(record_path.read_bytes()),
                   "policy_digest": record["policy"]["policy_digest"], "version": record["version"]}, stream, indent=2)
        stream.write("\n")
    print("M18 distinct worker/preparation ready; no registration or execution.")

if __name__ == "__main__":
    main()
