"""Versioned, public-only inputs for real Advisor teacher observations.

This adapter imports no simulator or model and does not read game/profile files.
It accepts the journal's explicitly redacted snapshot contract, not raw engine
state. Exact public values and categorical keys survive JSON encoding. The
small numeric route projection is a new interface, not a checkpoint migration
or a claim that the frozen 355 network consumed this information.
"""
from __future__ import annotations

from collections.abc import Mapping
import json
import math


SCHEMA = "brainstorm_public_context_v1"
SNAPSHOT_SCHEMA = "brainstorm_public_snapshot_v1"
PROJECTION_SCHEMA = "brainstorm_public_route_features_v1"
LABELS = ("Small", "Big", "Boss")
STATES = ("Upcoming", "Select", "Current", "Defeated", "Skipped", "Hide")
CARD_AREAS = ("hand", "deck", "jokers", "consumeables", "playing_cards",
              "shop_jokers", "shop_vouchers", "shop_booster", "pack_cards")
CARD_FIELDS = ("key", "name", "rank", "nominal", "suit", "enhancement", "edition",
               "seal", "debuff", "ability", "base", "cost", "base_cost", "sell_cost",
               "rarity", "blueprint_compat", "vampired", "pinned", "copy_source",
               "tarot_hold_source", "face_down")
PUBLIC_FIELDS = (
    "phase", "challenge", "round", "ante", "deck_key", "stake", "opening_pack",
    "hands", "modifiers", "dollars", "bankrupt_at", "rental_rate", "win_ante",
    "consumeable_buffer", "chips", "hands_left", "discards_left", "hands_played",
    "discards_used", "hands_played_total", "starting_deck_size", "consumeable_usage_total",
    "consumeable_usage", "current_round", "probabilities", "joker_limit", "consumable_limit",
    "hand_limit", "hand_size", "blind_on_deck", "pack_choices", "pack_type", "reroll_cost",
    "interest_cap", "skips", "unused_discards", "round_bonus", "interest_amount",
    "last_tarot_planet", "used_vouchers", "first_used_hand_level", "route_tags", "active_tags",
    "skip_tags", "drawpile_identity_redacted_for_concealment",
    "teacher_profile",
)
ACTIVE_BLIND_FIELDS = ("key", "name", "disabled", "chips", "boss", "hands_sub", "discards_sub",
                       "mult", "hands", "only_hand", "prepped", "block_play", "debuff")
RESET_FIELDS = ("ante", "blind_ante", "hands", "discards", "reroll_cost")
FORBIDDEN_FIELDS = frozenset({"seed", "pseudorandom", "rng", "rng_state", "draw_order"})
ROUTE_FEATURE_NAMES = (
    "role_small", "role_big", "role_boss", "entry_known",
    "ante_log1p", "ante_known", "chips_log1p", "chips_known",
    "mult_log1p", "mult_known", "dollars_log1p", "dollars_known",
    "boss", "boss_known", "identity_known", "state_known",
    *("state_" + state.lower() for state in STATES), "state_other", "restrictions_known",
)


def _plain(value, depth=0):
    """Detached bounded JSON values; no arbitrary object conversion/hooks."""
    if depth > 24:
        raise ValueError("Public context exceeds nesting bound")
    if value is None or type(value) in (bool, str, int):
        return value
    if type(value) is float:
        if not math.isfinite(value):
            raise ValueError("Nonfinite public context")
        return value
    if isinstance(value, Mapping):
        if len(value) > 10000:
            raise ValueError("Public context mapping exceeds bound")
        if any(type(key) is not str for key in value):
            raise ValueError("JSON public context requires string map keys")
        if FORBIDDEN_FIELDS.intersection(key.lower() for key in value):
            raise ValueError("RNG/seed/order field inside public feature data")
        return {key: _plain(item, depth + 1) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        if len(value) > 10000:
            raise ValueError("Public context sequence exceeds bound")
        return [_plain(item, depth + 1) for item in value]
    raise ValueError("Public context must contain JSON values only")


def _known(source, key, kind=None):
    value = source.get(key)
    present = key in source and value is not None
    if present and kind is not None:
        if kind == "number":
            if type(value) not in (int, float) or not math.isfinite(value):
                raise ValueError("Expected finite public number: " + key)
        elif not isinstance(value, kind) or kind is int and type(value) is not int:
            raise ValueError("Unexpected public value type: " + key)
    return {"known": present, "value": _plain(value) if present else None}


def _array(value, name):
    # Lua JSON writes empty tables as {}, including empty card rows.
    if value == {}:
        return []
    if not isinstance(value, list):
        raise ValueError("Expected public card array: " + name)
    return value


def _cards(snapshot):
    deck = _array(snapshot.get("deck", []), "deck")
    deck_ids = {c.get("id") for c in deck if isinstance(c, Mapping) and isinstance(c.get("id"), str)}
    concealed = snapshot.get("drawpile_identity_redacted_for_concealment") is True
    areas, references = {}, {}
    for area in CARD_AREAS:
        if area not in snapshot or snapshot[area] is None:
            areas[area] = {"known": False, "value": None}
            continue
        cards, refs = [], []
        for slot, card in enumerate(_array(snapshot[area], area), 1):
            if not isinstance(card, Mapping):
                raise ValueError("Expected public card object")
            ref = card.get("id")
            if ref is not None and not isinstance(ref, str):
                raise ValueError("Public card reference must be a string")
            known_composition = area == "deck" or area == "playing_cards" and ref in deck_ids
            hidden = (card.get("identity_redacted") is True or card.get("unknown") is True
                      or card.get("concealed") is True or known_composition and concealed
                      or card.get("face_down") is True and not known_composition)
            features = {} if hidden else {key: _plain(card[key]) for key in CARD_FIELDS if key in card}
            cards.append({"slot": slot, "identity_known": not hidden, "features": features})
            refs.append(ref)
        if area in {"deck", "playing_cards"}:
            # Composition collections are unordered; physical IDs never choose
            # a neural feature order. Keep reference pairing in separate metadata.
            ordered = sorted(zip(cards, refs), key=lambda pair: json.dumps(
                {"identity_known": pair[0]["identity_known"], "features": pair[0]["features"]},
                sort_keys=True, separators=(",", ":")))
            cards, refs = [pair[0] for pair in ordered], [pair[1] for pair in ordered]
            for slot, card in enumerate(cards, 1):
                card["slot"] = slot
        areas[area] = {"known": True, "value": cards}
        references[area] = refs
    return areas, references


def _collection(snapshot):
    field = "collection_progress" if snapshot.get("collection_progress") is not None else "completionist_goal"
    source = snapshot.get(field)
    if source is None:
        return {"known": False, "value": None}
    if not isinstance(source, Mapping) or source.get("schema") != 1 or source.get("goal") != "gold_stickers":
        raise ValueError("Unsupported public collection ledger")
    targets, seen = [], set()
    for target in _array(source.get("targets", []), "collection targets"):
        if not isinstance(target, Mapping) or not isinstance(target.get("key"), str):
            raise ValueError("Collection target requires a public catalog key")
        key, status = target["key"], target.get("status")
        if key in seen or status not in {"missing", "complete", "unknown"}:
            raise ValueError("Duplicate or invalid public collection status")
        seen.add(key)
        targets.append({"key": key, "status": status, "status_known": status != "unknown",
                        "reason": _known(target, "reason", str)})
    value = {"source": field, "role": "progress_only" if field == "collection_progress" else "objective",
             "targets": sorted(targets, key=lambda row: row["key"])}
    # Never include profile_id or read a profile. These are already supplied,
    # public collection statuses; absent target keys stay absent, never missing.
    for key in ("counts", "metadata_status", "catalog_status", "stake_status", "stake_reason",
                "held_keys", "held_target_keys", "held_unknown_keys", "held_status", "held_scope", "eligibility"):
        value[key] = _known(source, key)
    return {"known": True, "value": value}


def encode_public_context(snapshot, *, snapshot_schema):
    """Adapt only an explicitly journal-redacted public snapshot.

    ``features`` are policy inputs. ``action_references`` are detached physical
    card IDs for joining ordered targets to actions, and must not be embedded as
    policy features. Route rows are Small/Big/Boss of the captured visible route;
    no future ante targets/identities are calculated or filled in from catalogs.
    """
    if snapshot_schema != SNAPSHOT_SCHEMA or not isinstance(snapshot, Mapping):
        raise ValueError("Explicit journal public snapshot schema required")
    route = snapshot.get("route_blinds") or {}
    states = snapshot.get("blind_states") or {}
    choices = snapshot.get("blind_choices") or {}
    if not all(isinstance(item, Mapping) for item in (route, states, choices)):
        raise ValueError("Public route tables must be mappings")
    rows = []
    for label in LABELS:
        source = route.get(label)
        if source is not None and not isinstance(source, Mapping):
            raise ValueError("Public route blind must be a mapping")
        row = {"label": label, "entry_known": source is not None}
        source = dict(source or {})
        # Already observed fallback metadata only; never guess the boss, target
        # or restrictions from ante, stake, scalar hashes, or static catalogs.
        if "key" not in source and label in choices:
            source["key"] = choices[label]
        if "state" not in source and label in states:
            source["state"] = states[label]
        if "ante" not in source and "route_ante" in snapshot:
            source["ante"] = snapshot["route_ante"]
        for key, kind in (("key", str), ("name", str), ("state", str), ("ante", "number"),
                          ("chips", "number"), ("mult", "number"), ("dollars", "number"), ("boss", bool)):
            row[key] = _known(source, key, kind)
        row["restrictions"] = _known(source, "debuff", Mapping)
        rows.append(row)
    cards, refs = _cards(snapshot)
    active = snapshot.get("blind") or {}
    resets = snapshot.get("round_resets") or {}
    if not isinstance(active, Mapping) or not isinstance(resets, Mapping):
        raise ValueError("Public active blind/reset state must be mappings")
    features = {"state": {key: _known(snapshot, key) for key in PUBLIC_FIELDS},
                "route_blinds": rows,
                "active_blind": {key: _known(active, key) for key in ACTIVE_BLIND_FIELDS},
                "round_resets": {key: _known(resets, key) for key in RESET_FIELDS},
                "cards": cards,
                "gold_collection": _collection(snapshot)}
    return {"schema": SCHEMA, "snapshot_schema": SNAPSHOT_SCHEMA,
            "features": features, "action_references": refs}


def context_from_teacher_observation(event):
    """Bridge a full teacher journal event, never its advice or provenance."""
    if (not isinstance(event, Mapping) or event.get("schema") != 1
            or event.get("collection_schema") != "teacher_collection_v1"
            or event.get("kind") != "teacher_observation"):
        raise ValueError("A full versioned teacher_observation event is required")
    context = event.get("context")
    if not isinstance(context, Mapping):
        raise ValueError("Missing teacher observation context")
    return encode_public_context(context.get("snapshot"), snapshot_schema=context.get("snapshot_schema"))


def project_route_features(context):
    """Lossless companion keys/restrictions plus named numeric [3,24] rows.

    Numeric unknowns are zero only with a separate zero known flag. Exact chip
    targets remain in the structured context; logarithms are a neural projection.
    Categorical identities remain strings for a separately versioned vocabulary,
    avoiding ordinal or hash-scalar identity collisions. This does not adapt 355.
    """
    if context.get("schema") != SCHEMA:
        raise ValueError("Wrong public context schema")
    rows = context["features"]["route_blinds"]
    if [row.get("label") for row in rows] != list(LABELS):
        raise ValueError("Expected ordered Small/Big/Boss route")
    values, keys, restrictions = [], [], []
    for index, row in enumerate(rows):
        features = [float(index == i) for i in range(3)] + [float(row["entry_known"])]
        for name in ("ante", "chips", "mult", "dollars"):
            field = row[name]
            number = field["value"] if field["known"] else 0
            features.extend((math.copysign(math.log1p(abs(number)), number), float(field["known"])))
        state = row["state"]["value"]
        features.extend((float(row["boss"]["value"] or False), float(row["boss"]["known"]),
                         float(row["key"]["known"]), float(row["state"]["known"])))
        features.extend(float(state == name) for name in STATES)
        features.extend((float(row["state"]["known"] and state not in STATES),
                         float(row["restrictions"]["known"])))
        values.append(features)
        keys.append(row["key"]["value"])
        restrictions.append(_plain(row["restrictions"]))
    return {"schema": PROJECTION_SCHEMA, "feature_names": list(ROUTE_FEATURE_NAMES),
            "values": values, "identity_keys": keys, "restrictions": restrictions}
