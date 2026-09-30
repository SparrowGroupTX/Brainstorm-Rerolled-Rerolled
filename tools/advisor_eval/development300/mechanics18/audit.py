"""Independently audit completed M18 only; never execute or renew a worker."""
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
    assert record["job"] == registration["job"] == "M18"
    assert record["registration_sha256"] == sha(folder / "registration.json")
    assert record["trace_sha256"] == sha(folder / "trace.log")
    assert all(sha(folder / name) == expected for name, expected in registration["files"].items())
    rows = []
    for line in (folder / "trace.log").read_text(encoding="utf-8").splitlines():
        try:
            row = json.loads(line)
            if isinstance(row, dict):
                rows.append(row)
        except json.JSONDecodeError:
            pass
    of = lambda kind: [row for row in rows if row.get("type") == kind]
    verified = of("engine_collection_button_startup_verified")
    menus = of("engine_collection_original_menu_ready")
    armed = of("engine_collection_button_armed")
    blocked = of("engine_probe_blocked")
    stopped = of("engine_episode_stopped")
    finished = of("M18_case_finished")
    actions = of("engine_episode_action") + of("engine_episode_decision") + of("engine_episode_score")
    passed = record["status"] == "complete" and record["exit_code"] == 0 and not blocked and not actions
    passed = passed and len(verified) == len(menus) == len(armed) == len(stopped) == len(finished) == 2
    compact = []
    if passed:
        assert {row["case"] for row in verified} == {"manual", "auto"}
        for row in verified:
            calls = row["calls"]
            for key in ("search_stand_in", "delete_run", "start_run", "back", "overlay_close", "ui_button"):
                assert calls[key] == 1
            assert calls["advisor_actions"] == calls["native_search"] == row["score_calls"] == 0
            assert calls["config_writes"] == 0
            assert calls["settings_changed"] == (1 if row["case"] == "manual" else 2)
            snapshot = row["snapshot"]
            assert snapshot["phase"] == "blind" and snapshot["round"] == 0 and snapshot["ante"] == 1
            assert snapshot["deck_key"] == "b_red" and snapshot["stake"] == 8
            assert snapshot["skip_tags"]["Small"] == "tag_charm" and snapshot["skips"] == 0
            assert row["profile_unchanged"] is True
            assert row["profile_counts"] == {"total": 150, "complete": 0, "missing": 150, "unknown": 0}
            lifecycle = row["lifecycle"]
            for key in ("original_main_menu", "original_options", "original_overlay_callbacks", "original_controller_update", "original_menu_update", "boot_cache_preserved"):
                assert lifecycle[key] is True
            assert lifecycle["calls"]["main_menu"] == 1
            assert lifecycle["calls"]["controller_update"] > 240
            assert lifecycle["full_game_update"] is False and lifecycle["original_boot_timer"] is False
            assert row["filter_info"]["normal_opening"]["seed"] == "S7PXV521"
            assert row["filter_info"]["collection_search"]["future_acquisition_verified"] is False
            for source in row["source_methods"].values():
                assert source.startswith("@installed/")
            compact.append({"case": row["case"], "calls": calls, "source_methods": row["source_methods"],
                            "small_tag": snapshot["skip_tags"]["Small"], "round": 0, "ante": 1,
                            "lifecycle": lifecycle, "profile_counts": row["profile_counts"]})
        assert all(row["state_complete"] is False for row in menus + armed)
        assert all(row["controller_locks"]["frame"] and row["controller_locks"]["frame_set"] and row["calls"]["search_stand_in"] == 0 for row in armed)
        assert all(row["outcome"] == "censored" and row["decisions"] == 0 and row["reason"] == "M18_preblind_ui_startup" for row in stopped)
        assert all(row["exit_code"] == 0 for row in finished)
    audit = {"schema": 1, "job": "M18", "status": "ui_startup_lifecycle_verified" if passed else "ui_startup_not_verified",
        "record_sha256": sha(folder / "record.json"), "trace_sha256": sha(folder / "trace.log"),
        "worker_status": record["status"], "worker_elapsed_seconds": record["elapsed_seconds"],
        "one_use_spent": record["one_use_spent"], "frozen_inputs_verified": True,
        "external_files_unchanged": record["external_files_unchanged"],
        "cases": compact, "menus": menus, "armed": armed, "blocked": blocked, "stopped": stopped,
        "actual_advisor_actions": len(actions), "new_native_search_calls": 0,
        "predecessor": "M17 remains a separate spent parse error before source execution; its evidence was frozen into M18",
        "full_game_update": False, "full_autoplay_qualified": False, "qualification": False,
        "limits": "Only actual UI callback/product startup with observed S05 answer. Source UI display tree, no-input services, font-cache shape, memory logger and settings hook are declared stand-ins. No actual native search, pack acquisition, blind play, terminal outcome or achievement."}
    with (folder / "audit.json").open("x", encoding="utf-8") as stream:
        json.dump(audit, stream, indent=2)
        stream.write("\n")
    print(json.dumps({"status": audit["status"], "worker_seconds": record["elapsed_seconds"], "cases": compact, "blocked": blocked}))

if __name__ == "__main__":
    main()
