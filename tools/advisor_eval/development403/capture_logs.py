"""Passively preserve the available 2026-09-26 public BRJ2 session."""

from datetime import datetime, timezone
from hashlib import sha256
from pathlib import Path
import json

HERE = Path(__file__).resolve().parent
SOURCE = Path(r"C:\Users\trevo\AppData\Roaming\Balatro\advisor_player_log_v2")
SESSION = "session-20260926T164021Z-1"
DEST = HERE / "logs1"
CAPTURE = HERE / "capture"


def stable_read(path):
    before = path.stat()
    data = path.read_bytes()
    after = path.stat()
    assert (before.st_size, before.st_mtime_ns) == (after.st_size, after.st_mtime_ns)
    assert len(data) == after.st_size
    return data


def main():
    files = sorted(SOURCE.glob(SESSION + "-*.brj"))
    assert files and all(p.is_file() and p.name.startswith(SESSION + "-") for p in files)
    assert not DEST.exists() and not CAPTURE.exists()
    DEST.mkdir(parents=True)
    CAPTURE.mkdir(parents=True)
    entries = []
    for source in files:
        data = stable_read(source)
        copied = DEST / source.name
        copied.write_bytes(data)
        assert stable_read(copied) == data
        entries.append({"name": source.name, "bytes": len(data),
                        "sha256": sha256(data).hexdigest()})
    for entry in entries:
        source = SOURCE / entry["name"]
        entry["source_still_matched"] = (
            sha256(stable_read(source)).hexdigest() == entry["sha256"]
        )
    manifest = {
        "captured_utc": datetime.now(timezone.utc).isoformat(),
        "source": str(SOURCE), "session": SESSION,
        "scope": "Passive copy of all available public BRJ2 segments before any later user clear; no game or save control.",
        "segments": entries,
        "total_bytes": sum(e["bytes"] for e in entries),
        "all_source_still_matched": all(e["source_still_matched"] for e in entries),
    }
    (CAPTURE / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({"session": SESSION, "segments": len(entries),
                      "bytes": manifest["total_bytes"],
                      "source_matched": manifest["all_source_still_matched"]}))
    assert manifest["all_source_still_matched"]


if __name__ == "__main__":
    main()

