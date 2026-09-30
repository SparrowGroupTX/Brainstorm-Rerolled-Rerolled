"""Sequential bounded adapter smoke checks; never a win-rate campaign."""
import json
from pathlib import Path
import subprocess
import sys


def main():
    records = []
    for challenge in range(1, 21):
        result = subprocess.run(
            [sys.executable, str(Path(__file__).with_name("engine_probe.py")),
             "--challenge", str(challenge)], capture_output=True, text=True,
            timeout=60, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        lines = result.stdout.splitlines()
        record = {"challenge_index": challenge, "exit_code": result.returncode,
                  "setup": next((line for line in lines if line.startswith("PROBE authentic challenge initialization")), None),
                  "opening": next((line for line in lines if line.startswith("PROBE authentic opening blind")), None),
                  "errors": [json.loads(line) for line in lines if line.startswith('{"type": "engine_probe_blocked"')]}
        records.append(record)
        print(json.dumps(record), flush=True)
    return int(any(record["exit_code"] for record in records))


if __name__ == "__main__":
    raise SystemExit(main())
