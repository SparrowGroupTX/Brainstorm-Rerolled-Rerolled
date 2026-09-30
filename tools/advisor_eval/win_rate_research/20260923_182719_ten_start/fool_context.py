"""Passive public Fool/last-used context extraction from frozen journal bytes."""

import io
import json
import sys
from collections import Counter
from pathlib import Path


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[3]))
from tools.advisor_eval.read_player_log import parsed, records  # noqa: E402


rows = []
for path in sorted((HERE / "capture" / "frozen").glob("*.brj")):
    for ordinal, (raw, _) in enumerate(records(io.BytesIO(path.read_bytes())), 1):
        event = parsed(raw)
        context = event.get("context") or {}
        if context.get("run_instance") != "observed-game:10":
            continue
        state = context.get("snapshot") or {}
        if not state or (state.get("ante") or 0) < 5:
            continue
        stock = Counter(card.get("key") for card in state.get("consumeables") or [])
        if stock.get("c_fool", 0) == 0:
            continue
        rows.append(
            {
                "sequence": event["sequence"],
                "kind": event["kind"],
                "ante": state.get("ante"),
                "phase": state.get("phase"),
                "last_tarot_planet": state.get("last_tarot_planet"),
                "stock": dict(stock),
                "segment": path.name,
                "ordinal": ordinal,
            }
        )

out = HERE / "fool_context.json"
out.write_text(json.dumps(rows, indent=2) + "\n", encoding="utf-8")
print(
    json.dumps(
        {
            "rows": len(rows),
            "ante8_last_values": dict(Counter(r["last_tarot_planet"] for r in rows if r["ante"] == 8)),
            "last": rows[-1] if rows else None,
        },
        indent=2,
    )
)
