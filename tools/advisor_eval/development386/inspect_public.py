"""Print bounded public-event windows from frozen raw bytes; never invoke policy."""

import io
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT))
from tools.advisor_eval.read_player_log import parsed, records

targets = {int(arg) for arg in sys.argv[1:]}
for path in sorted((HERE / "logs1").glob("*.brj")):
    for raw, _ in records(io.BytesIO(path.read_bytes())):
        event = parsed(raw)
        sequence = event["sequence"]
        if not any(abs(sequence - target) <= 5 for target in targets):
            continue
        if event["kind"] == "performance_window":
            continue
        context = event.get("context") or {}
        snapshot = context.get("snapshot") or {}
        advice = context.get("advice") or {}
        held = snapshot.get("consumeables") or []
        strength = [card for card in held if card.get("key") == "c_strength"]
        details = event.get("details") or {}
        if event["kind"] == "auto_run":
            details = {"event": details.get("event"), "run_id": details.get("run_id"),
                       "action": details.get("action") or
                       (details.get("last_action") or {}).get("action"),
                       "callback_status": (details.get("last_action") or {}).get("callback_status")}
        elif event["kind"] in ("action_requested", "action_callback_result"):
            details = {"input": details.get("input"), "outcome_kind": details.get("outcome_kind"),
                       "action_sequence": details.get("action_sequence")}
        else:
            details = {}
        print(sequence, event["kind"], "advice_sequence", event.get("advice_sequence"),
              "observation_id", event.get("observation_id"),
              "details", details,
              "title", advice.get("title"), "action", advice.get("action"),
              "strength", len(strength),
              "strength_negative", sum(bool((card.get("edition") or {}).get("negative"))
                                        if isinstance(card.get("edition"), dict) else
                                        card.get("edition") == "negative" for card in strength),
              "strength_sell_values", sorted(set(card.get("sell_cost") for card in strength)),
              "joker_compat", [(j.get("key"), j.get("blueprint_compat"))
                               for j in snapshot.get("jokers") or []],
              "boosters", [(c.get("key"), c.get("cost")) for c in snapshot.get("shop_booster") or []])
