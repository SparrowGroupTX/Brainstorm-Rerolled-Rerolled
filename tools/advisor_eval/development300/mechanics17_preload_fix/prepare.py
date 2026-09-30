"""Detached serialization correction and parse-only regression; no experiment."""
from pathlib import Path
import ast
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OLD = ROOT / "tools/advisor_eval/runs/gold299_20260914/M17"

def sha(data):
    return hashlib.sha256(data).hexdigest()

def emission(tree, scope):
    matches = [node.args[0] for node in ast.walk(tree) if isinstance(node, ast.Call)
               and isinstance(node.func, ast.Attribute) and node.func.attr == "append"
               and len(node.args) == 1 and isinstance(node.args[0], ast.BinOp)
               and "module.encode()" in ast.unparse(node.args[0])
               and "relative" in ast.unparse(node.args[0])]
    assert len(matches) == 1
    return eval(compile(ast.Expression(matches[0]), "<exact_preload_emitter>", "eval"), scope)

def main():
    adapter = HERE / "adapter"
    adapter.mkdir(exist_ok=False)
    paths = ("engine_probe.py", "engine_probe.lua", "engine_run.lua", "engine_contract.lua", "opening_support.py",
             "benchmark.py", "normal_recipe.py", "normal_terminal.lua", "startup_receipt.py",
             "startup_fixture.lua", "startup_menu_support.lua", "worker.py")
    manifest = {}
    for name in paths:
        raw = (OLD / name).read_bytes()
        changed = raw
        if name == "engine_probe.py":
            before = b"b'package.preload[' + literal(module.encode()) + b']=assert(loadstring('"
            after = b"b'package.preload[ ' + literal(module.encode()) + b' ]=assert(loadstring('"
            assert raw.count(before) == 1
            changed = raw.replace(before, after, 1)
        (adapter / name).write_bytes(changed)
        manifest[name] = {"original_M17_sha256": sha(raw), "candidate_sha256": sha(changed), "changed": raw != changed}
    before_tree = ast.parse((OLD / "engine_probe.py").read_text(encoding="utf-8"))
    after_tree = ast.parse((adapter / "engine_probe.py").read_text(encoding="utf-8"))
    literal_ast = next(node for node in before_tree.body if isinstance(node, ast.FunctionDef) and node.name == "literal")
    namespace = {}
    exec(compile(ast.Module(body=[literal_ast], type_ignores=[]), "<preserved_literal>", "exec"), namespace)
    literal = namespace["literal"]
    statements = [b"-- Compile generated preload snippets only; never execute source or product modules.", b"local checks=0"]
    for relative, module in (("Core/auto_run_product.lua", "probe_auto_run_product"),
                             ("Core/auto_terminal.lua", "probe_auto_terminal"),
                             ("UI/collection_run.lua", "probe_collection_run_ui")):
        content = (OLD / "policy/Brainstorm" / relative).read_bytes()
        scope = {"literal": literal, "relative": relative, "module": module, "content": content}
        before = emission(before_tree, scope)
        after = emission(after_tree, scope)
        statements += [b"assert(not loadstring(" + literal(before) + b"));checks=checks+1",
                       b"assert(loadstring(" + literal(after) + b"));checks=checks+1"]
    # Adversarial closing delimiters force literal() to change its long-string
    # bracket depth. This uses the exact corrected emission expression.
    for content in (b"return ']]'", b"return ']=]'", b"return ']===]'", b"return {eq='=',name='[[x]]'}"):
        scope = {"literal": literal, "relative": "synthetic.lua", "module": "test_preload", "content": content}
        generated = emission(after_tree, scope)
        statements += [b"assert(loadstring(" + literal(generated) + b"));checks=checks+1"]
    statements.append(b"print('M17 preload correction: '..checks..' parse-only checks passed')")
    (HERE / "generated_preload_syntax.lua").write_bytes(b"\n".join(statements) + b"\n")
    with (HERE / "manifest.json").open("x", encoding="utf-8") as stream:
        json.dump({"schema": 1, "original_job": "M17", "original_lease_remains_spent": True,
                   "candidate_only": True, "registration_or_execution": False, "files": manifest,
                   "scope": "Exactly one generated preload indexing separator fix. Future component needs its own parent-approved registered lease; copied worker still rejects any job except spent M17 and must not be run."}, stream, indent=2)
        stream.write("\n")
    print("Prepared detached emitter correction and ten parse-only checks. No source/native experiment.")

if __name__ == "__main__":
    main()
