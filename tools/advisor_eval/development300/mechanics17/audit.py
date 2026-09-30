"""Audit the one completed M17 receipt; no source/native execution or retry."""
from pathlib import Path
import hashlib
import json
import sys

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main():
    folder = Path(sys.argv[1]).resolve()
    record = json.loads((folder / "record.json").read_text(encoding="utf-8"))
    registration = json.loads((folder / "registration.json").read_text(encoding="utf-8"))
    assert record["job"] == registration["job"] == "M17"
    assert record["registration_sha256"] == sha(folder / "registration.json")
    assert record["trace_sha256"] == sha(folder / "trace.log")
    assert all(sha(folder / name) == expected for name, expected in registration["files"].items())
    rows = []
    for line in (folder / "trace.log").read_text(encoding="utf-8").splitlines():
        try:
            item = json.loads(line)
            if isinstance(item, dict):
                rows.append(item)
        except json.JSONDecodeError:
            pass
    of = lambda kind: [row for row in rows if row.get("type") == kind]
    verified = of("engine_collection_button_startup_verified")
    blocked = of("engine_probe_blocked")
    menus = of("engine_collection_original_menu_ready")
    armed = of("engine_collection_button_armed")
    stopped = of("engine_episode_stopped")
    actions = of("engine_episode_action") + of("engine_episode_decision") + of("engine_episode_score")
    parse_boundary = len(blocked) == 1 and "unexpected symbol near '='" in blocked[0].get("reason", "") and not menus and not armed and not verified
    passed = record["status"] == "complete" and record["exit_code"] == 0 and not blocked and not actions
    passed = passed and len(verified) == len(menus) == len(armed) == len(stopped) == 2
    if passed:
        assert {row["case"] for row in verified} == {"manual", "auto"}
        for row in verified:
            calls = row["calls"]
            for key in ("search_stand_in", "delete_run", "start_run", "back", "overlay_close", "ui_button"):
                assert calls[key] == 1
            assert calls["advisor_actions"] == calls["native_search"] == row["score_calls"] == 0
            snapshot = row["snapshot"]
            assert snapshot["phase"] == "blind" and snapshot["round"] == 0 and snapshot["ante"] == 1
            assert snapshot["deck_key"] == "b_red" and snapshot["stake"] == 8
            assert snapshot["skip_tags"]["Small"] == "tag_charm" and snapshot["skips"] == 0
            assert row["profile_unchanged"] is True
            assert row["profile_counts"] == {"total": 150, "complete": 0, "missing": 150, "unknown": 0}
            assert row["lifecycle"]["original_main_menu"] is True
            assert row["lifecycle"]["original_controller_update"] is True
            assert row["lifecycle"]["full_game_update"] is False
            assert row["filter_info"]["normal_opening"]["seed"] == "S7PXV521"
        assert all(row["state_complete"] is False for row in menus + armed)
        assert all(row["outcome"] == "censored" and row["decisions"] == 0 for row in stopped)
    audit = {"schema": 1, "job": "M17", "status": "ui_startup_lifecycle_verified" if passed else "ui_startup_not_verified",
        "record_sha256": sha(folder / "record.json"), "trace_sha256": sha(folder / "trace.log"),
        "worker_status": record["status"], "worker_elapsed_seconds": record["elapsed_seconds"],
        "one_use_spent": record["one_use_spent"], "frozen_inputs_verified": True,
        "verified_rows": verified, "menus": menus, "armed": armed, "blocked": blocked, "stopped": stopped,
        "case_finished": of("M17_case_finished"), "actual_advisor_actions": len(actions), "new_native_search_calls": 0,
        "failure_classification": "adapter_preload_serialization_parse_error" if parse_boundary else None,
        "failure_stage": "luaL_loadbuffer of complete host-generated chunk, before lua_pcall" if parse_boundary else None,
        "source_lua_execution_reached": False if parse_boundary else None,
        "product_ui_callback_reached": False if parse_boundary else bool(armed),
        "adapter_defect": "New preload emitter omitted spaces around a long-bracket string index: package.preload[ plus [[name]] lexes as a long-string call, yielding an unexpected '='. Existing emitter uses package.preload[ [[name]] ]." if parse_boundary else None,
        "product_runtime_bug_established": False,
        "full_game_update": False, "full_autoplay_qualified": False, "qualification": False,
        "limits": "Only actual UI callback/product startup with observed S05 runtime stand-in. Existing source display tree, no-input services, font-cache shape, memory logger and settings hook are declared stand-ins. No native search, pack acquisition, blind play, terminal outcome or achievement."}
    with (folder / "audit.json").open("x", encoding="utf-8") as stream:
        json.dump(audit, stream, indent=2)
        stream.write("\n")
    print(json.dumps({"status": audit["status"], "worker_seconds": record["elapsed_seconds"], "blocked": blocked}))

if __name__ == "__main__":
    main()
