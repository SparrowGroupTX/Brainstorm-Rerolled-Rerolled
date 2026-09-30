"""Public-only candidate environment over the pinned, offline Jackdaw engine.

No Gym/bridge, source scoring/lookahead, profiles, or live-game interfaces.
Constructing Environment initializes ONE simulator episode: callers must reserve
that episode first. Importing this module only loads code and static catalog data.

observe() returns detached float32 global[80], entities[N,64], candidates[A,160].
step(i) returns (obs|None, sparse_reward, terminated, truncated, info). A run win
earns 1; all other rewards are 0. Unsupported/error/cap outcomes are truncations,
never losses. Raw state, concrete engine actions, seed and RNG stay private.

Entity offsets: 0:7 area one-hot; 7 visible; 8 public slot/128; 9 catalog ID;
10:19 set one-hot; 19 rank/14; 20:24 suit; 24 enhancement ID; 25:29 edition;
29:33 seal; 33 debuff; 34 forced-selection; 35:38 cost/base/sell log1p;
38 eternal; 39 perishable; 40 rental; 41 perish tally/5; 42:64 public ability.
Concealed entities expose only area/slot/presence, and a hand's forced highlight.

Candidate offsets: 0:21 action one-hot; 21:85 target entity; 85:149 mean selected
hand rows; 149:154 ordered target slots (1-based /128); 154 count/5; 155 visible
count/5; 156 ordinary flush; 157 largest rank group/5; 158 ordinary hand type/11;
159 log1p(ordinary poker base estimate). This estimate excludes Joker effects,
enhancements, seals, editions and boss rules; it is not an exact scoring oracle.

Global offsets: 0:6 phase; 6:9 blind position; 9 ante/8; 10 round/24; 11 cash
log1p; 12 chips log1p; 13 blind target log1p; 14 hands/10; 15 discards/10;
16 hands played/10; 17 discards used/10; 18 hand size/20; 19 Joker slots/20;
20 consumable slots/20; 21 deck count/128; 22 discard count/128; 23 reroll log1p;
24 stake/8; 25 public blind ID; 26 interest cap log1p; 27 cleared blinds/24;
28 steps/max_steps; 29 pack choices/5; 30 last Tarot/Planet ID; 31 win ante/8;
32:80 twelve hand types in HAND_NAMES order, [level,chips,mult,played] log1p.

Declared action restriction: plays follow current left-to-right hand order;
adjacent swaps allow other orders. Consumable targets use deterministic unique
subsets, retaining tuple order. No engine-supported boss reroll or buy-and-use
exists. During concealed Jokers, swaps/sales/consumables are conservatively
omitted rather than consulting hidden eligibility. Hidden-hand Aura is omitted.
All collections are variable length; exceeding explicit bounds stops unsupported.
Simulator fidelity to Balatro is NOT established by this wrapper.
"""
from __future__ import annotations

from collections import Counter
from itertools import combinations
import hashlib
import json
import math
import os
from pathlib import Path
import sys
from typing import Any

import numpy as np

GLOBAL_DIM, ENTITY_DIM, CANDIDATE_DIM = 80, 64, 160
MAX_ENTITIES, MAX_CANDIDATES = 128, 4096
PINNED_COMMIT = "92df18c27e26e6d324132942905e41242e4e24bf"
SIM_PATH = Path(os.environ.get("BRAINSTORM_LEARNING_SIM_PATH", str(
    Path(__file__).resolve().parents[1] / "advisor_eval/development355/external/jackdaw"))).resolve()
if not (SIM_PATH / "jackdaw/engine/game.py").is_file():
    raise ImportError("Pinned simulator source unavailable: " + str(SIM_PATH))
sys.path.insert(0, str(SIM_PATH))
from jackdaw.engine import actions as A
from jackdaw.engine.game import step as engine_step
from jackdaw.engine.run_init import initialize_run
from jackdaw.engine.consumables import can_use_consumable, pack_pick_block_reason
from jackdaw.engine.data.hands import HAND_BASE, HandType
import jackdaw
if not Path(jackdaw.__file__).resolve().is_relative_to(SIM_PATH):
    raise ImportError("Already-loaded Jackdaw differs from configured frozen source")
from .simulator_patches import PATCH_ID, apply_patches, audit_state_boundary

_catalog = json.loads((SIM_PATH / "jackdaw/engine/data/centers.json").read_text(encoding="utf-8"))
CATALOG_SIZE = len(_catalog)
_catalog_ids = {key: (i + 1) / (len(_catalog) + 1) for i, key in enumerate(sorted(_catalog))}
HAND_NAMES = tuple(str(h) for h in HandType)
PHASES = ("blind_select", "selecting_hand", "round_eval", "shop", "pack_opening", "game_over")
AREAS = ("hand", "jokers", "consumables", "shop_cards", "shop_vouchers", "shop_boosters", "pack_cards")
SETS = ("Default", "Enhanced", "Joker", "Tarot", "Planet", "Spectral", "Voucher", "Booster", "Back")
SUITS = ("Hearts", "Diamonds", "Clubs", "Spades")
KINDS = ("play", "discard", "select_blind", "skip_blind", "cash_out", "reroll", "next_round",
         "skip_pack", "buy", "sell_joker", "sell_consumable", "use", "voucher", "open",
         "pick", "joker_left", "joker_right", "hand_left", "hand_right", "sort_rank", "sort_suit")
ABILITY_KEYS = ("mult", "x_mult", "t_chips", "h_mult", "h_x_mult", "bonus", "perma_bonus",
                "extra_value", "h_dollars", "p_dollars", "d_size", "h_size", "extra")
EXTRA_KEYS = ("mult", "chips", "xmult", "x_mult", "discards", "yorick_discards", "hands", "rounds", "dollars")


class UnsupportedState(RuntimeError):
    """Explicit environment boundary, not a game loss."""


def _number(value: Any) -> float:
    if not isinstance(value, (int, float, np.number)) or not math.isfinite(float(value)):
        raise UnsupportedState("nonfinite_or_nonnumeric_public_value")
    return float(value)


def _log(value: Any) -> float:
    n = _number(value)
    return math.copysign(math.log1p(abs(n)), n)


def _visible(card: Any) -> bool:
    # Read presentation before identity, base, ability, edition, or cost.
    return getattr(card, "facing", "front") != "back"


def _public_id(value: str) -> float:
    return int.from_bytes(hashlib.sha256(value.encode()).digest()[:3], "big") / 16777216.0 if value else 0.0


def _entity(card: Any, area: int, index: int) -> np.ndarray:
    row = np.zeros(ENTITY_DIM, np.float32)
    row[area], row[8] = 1, (index + 1) / MAX_ENTITIES
    if not _visible(card):
        if area == 0:
            # Forced highlighting is visible even on a concealed card.
            row[34] = bool(getattr(card, "ability", {}).get("forced_selection"))
        return row
    row[7] = 1
    key = getattr(card, "center_key", "")
    row[9] = _catalog_ids.get(key, 0)
    ability = getattr(card, "ability", {}) or {}
    kind = ability.get("set", "Default")
    if kind in SETS:
        row[10 + SETS.index(kind)] = 1
    base = getattr(card, "base", None)
    if base is not None:
        row[19] = _number(base.id) / 14
        suit = str(base.suit)
        if suit in SUITS:
            row[20 + SUITS.index(suit)] = 1
    row[24] = _catalog_ids.get(key, 0) if kind == "Enhanced" else 0
    edition = getattr(card, "edition", None) or {}
    for i, field in enumerate(("foil", "holo", "polychrome", "negative")):
        row[25+i] = bool(edition.get(field))
    seal = getattr(card, "seal", None)
    for i, name in enumerate(("Gold", "Red", "Blue", "Purple")):
        row[29+i] = seal == name
    row[33], row[34] = bool(getattr(card, "debuff", False)), bool(ability.get("forced_selection"))
    for i, field in enumerate(("cost", "base_cost", "sell_cost")):
        row[35+i] = _log(getattr(card, field, 0))
    for i, field in enumerate(("eternal", "perishable", "rental")):
        row[38+i] = bool(getattr(card, field, False))
    row[41] = _number(getattr(card, "perish_tally", 0)) / 5
    for i, field in enumerate(ABILITY_KEYS):
        value = ability.get(field, 0)
        if isinstance(value, (int, float)):
            row[42+i] = _log(value)
    extra = ability.get("extra", {})
    for i, field in enumerate(EXTRA_KEYS):
        value = extra.get(field, 0) if isinstance(extra, dict) else 0
        # Yorick's changing countdown is a top-level ability field in some engines.
        if field == "yorick_discards":
            value = ability.get(field, value)
        if isinstance(value, (int, float)):
            row[55+i] = _log(value)
    return row


def _selection_summary(rows: list[np.ndarray], gs: dict) -> tuple[float, float, float, float]:
    """Public ordinary poker pattern/base only; no engine scoring/evaluation."""
    if not rows or any(r[7] != 1 or r[19] == 0 for r in rows):
        return 0, 0, 0, 0
    ranks = [int(round(float(r[19]) * 14)) for r in rows]
    counts = Counter(ranks)
    groups = sorted(counts.values(), reverse=True)
    flush = len(rows) == 5 and any(all(r[20+s] == 1 for r in rows) for s in range(4))
    unique = sorted(counts)
    straight = len(unique) == 5 and (unique[-1]-unique[0] == 4 or unique == [2,3,4,5,14])
    if groups[0] == 5: h = 0 if flush else 2
    elif groups == [3,2]: h = 1 if flush else 5
    elif straight and flush: h = 3
    elif groups[0] == 4: h = 4
    elif flush: h = 6
    elif straight: h = 7
    elif groups[0] == 3: h = 8
    elif groups.count(2) == 2: h = 9
    elif groups[0] == 2: h = 10
    else: h = 11
    if h in (4,8,10): scoring = [r for r in ranks if counts[r] == groups[0]]
    elif h == 9: scoring = [r for r in ranks if counts[r] == 2]
    elif h == 11: scoring = [max(ranks)]
    else: scoring = ranks
    level = gs.get("hand_levels")
    if level is not None:
        hand = level.get_state(HandType(HAND_NAMES[h]))
        chips, mult = hand.chips, hand.mult
    else:
        data = HAND_BASE[HandType(HAND_NAMES[h])]
        chips, mult = data.s_chips, data.s_mult
    card_chips = sum(11 if r == 14 else min(r, 10) for r in scoring)
    return float(flush), groups[0]/5, h/11, _log((_number(chips)+card_chips)*_number(mult))


class Environment:
    def __init__(self, seed: str, deck: str = "b_red", stake: int = 8, max_steps: int = 1200):
        if not isinstance(seed, str) or not seed or type(stake) is not int or not 1 <= stake <= 8:
            raise ValueError("Explicit seed and stake 1..8 required")
        if type(max_steps) is not int or not 1 <= max_steps <= 10000:
            raise ValueError("max_steps must be 1..10000")
        if deck not in _catalog or _catalog[deck].get("set") != "Back" or deck == "b_challenge":
            raise ValueError("Ordinary deck required; challenges are outside this prototype")
        # Verified in-memory overlay, before any card/run initialization.
        apply_patches(SIM_PATH)
        self._gs = initialize_run(deck, stake, seed)
        self._initialize_tracking(max_steps)

    def _initialize_tracking(self, max_steps: int):
        self.max_steps = max_steps
        self.steps = 0
        self.blinds_cleared = 0
        self._actions: list[Any] = []
        self._done = False
        self._won_latched = False
        self._last_observation = None

    def _info(self, outcome: str, **kwargs) -> dict:
        return {"outcome": outcome, "ante": self._gs.get("round_resets", {}).get("ante", 1),
                "blinds_cleared": self.blinds_cleared, "dollars": self._gs.get("dollars", 0),
                "steps": self.steps, "won": self._won_latched, "simulator_patch": PATCH_ID, **kwargs}

    def observe(self) -> dict[str, np.ndarray]:
        if self._done:
            raise RuntimeError("Episode already ended")
        gs = self._gs
        if reason := audit_state_boundary(gs):
            raise UnsupportedState(reason)
        phase = str(gs.get("phase"))
        if phase not in PHASES or phase == "game_over":
            raise UnsupportedState("no_active_decision_phase")
        if gs.get("won"):
            raise UnsupportedState("win_flag_without_observed_final_boss_transition")
        def available(name):
            if name.startswith("shop_") and phase != "shop": return []
            if name == "pack_cards" and phase != "pack_opening": return []
            return gs.get(name, [])
        if sum(len(available(name)) for name in AREAS) > MAX_ENTITIES:
            raise UnsupportedState("entity_capacity_exceeded")
        rows, area_rows = [], {}
        for a, name in enumerate(AREAS):
            area_rows[name] = [_entity(card, a, i) for i, card in enumerate(available(name))]
            rows.extend(area_rows[name])
        entities = np.asarray(rows, np.float32).reshape(-1, ENTITY_DIM)
        global_row = self._global(phase)
        descriptions: list[np.ndarray] = []
        self._actions = []

        def add(kind: int, action: Any, area: str | None = None, index: int | None = None,
                targets: tuple[int, ...] = ()):
            if len(self._actions) >= MAX_CANDIDATES:
                raise UnsupportedState("candidate_capacity_exceeded")
            if len(targets) > 5 or len(set(targets)) != len(targets):
                raise UnsupportedState("invalid_candidate_target_tuple")
            row = np.zeros(CANDIDATE_DIM, np.float32)
            row[kind] = 1
            if area is not None:
                row[21:85] = area_rows[area][index]
            selected = [area_rows["hand"][i] for i in targets]
            if selected:
                row[85:149] = np.mean(selected, axis=0)
                row[149:149+len(targets)] = [(i+1)/MAX_ENTITIES for i in targets]
                row[154] = len(targets)/5
                row[155] = sum(r[7] for r in selected)/5
                row[156:160] = _selection_summary(selected, gs)
            self._actions.append(action)
            descriptions.append(row)

        self._enumerate(phase, add)
        if not descriptions:
            raise UnsupportedState("no_supported_legal_candidates")
        observation = {"global": global_row, "entities": entities,
                       "candidates": np.asarray(descriptions, np.float32)}
        if not all(np.isfinite(value).all() for value in observation.values()):
            raise UnsupportedState("nonfinite_observation")
        self._last_observation = observation
        return observation

    def _global(self, phase: str) -> np.ndarray:
        gs = self._gs; cr = gs.get("current_round", {}); rr = gs.get("round_resets", {})
        row = np.zeros(GLOBAL_DIM, np.float32); row[PHASES.index(phase)] = 1
        blind_pos = gs.get("blind_on_deck")
        if blind_pos in ("Small", "Big", "Boss"):
            row[6+("Small", "Big", "Boss").index(blind_pos)] = 1
        blind = gs.get("blind")
        row[9:25] = [rr.get("ante",1)/8, gs.get("round",0)/24, _log(gs.get("dollars",0)),
            _log(gs.get("chips",0)), _log(getattr(blind,"chips",0)), cr.get("hands_left",0)/10,
            cr.get("discards_left",0)/10, cr.get("hands_played",0)/10, cr.get("discards_used",0)/10,
            gs.get("hand_size",8)/20, gs.get("joker_slots",5)/20, gs.get("consumable_slots",2)/20,
            len(gs.get("deck",[]))/128, len(gs.get("discard_pile",[]))/128,
            _log(cr.get("reroll_cost",5)), gs.get("stake",1)/8]
        row[25:32] = [_public_id(str(getattr(blind,"name",""))), _log(gs.get("interest_cap",25)),
            self.blinds_cleared/24, self.steps/self.max_steps, gs.get("pack_choices_remaining",0)/5,
            _catalog_ids.get(gs.get("last_tarot_planet"),0), gs.get("win_ante",8)/8]
        levels = gs.get("hand_levels")
        for i, name in enumerate(HAND_NAMES):
            if levels is not None:
                h = levels.get_state(HandType(name))
                row[32+4*i:36+4*i] = [_log(v) for v in (h.level,h.chips,h.mult,h.played)]
        return row

    def _targets(self, card: Any):
        # Public static center config defines the actual target counts.
        key = card.center_key
        cfg = _catalog.get(key, {}).get("config", {}) or {}
        if not isinstance(cfg, dict): cfg = {}
        if key == "c_aura": minimum = maximum = 1
        elif cfg.get("max_highlighted"):
            minimum, maximum = cfg.get("min_highlighted",1), cfg.get("mod_num",cfg["max_highlighted"])
        else:
            yield (); return
        n = len(self._gs.get("hand", []))
        if maximum > 5 or minimum < 0:
            raise UnsupportedState("unsupported_consumable_target_arity")
        for count in range(minimum,min(maximum,n)+1):
            for selection in combinations(range(n),count):
                if key == "c_aura" and any(not _visible(self._gs["hand"][i]) for i in selection):
                    continue
                yield selection

    def _usable(self, card: Any, targets: tuple[int,...], pack: bool) -> bool:
        gs=self._gs
        if pack:
            return pack_pick_block_reason(card,gs,targets) is None
        return can_use_consumable(card,highlighted=[gs["hand"][i] for i in targets],
            hand_cards=gs.get("hand",[]),jokers=gs.get("jokers",[]),consumables=gs.get("consumables",[]),
            consumable_limit=gs.get("consumable_slots",2),joker_limit=gs.get("joker_slots",5),game_state=gs)

    def _enumerate(self, phase: str, add):
        gs=self._gs; cr=gs.get("current_round",{}); hand=gs.get("hand",[])
        jokers=gs.get("jokers",[]); consumables=gs.get("consumables",[])
        hidden_jokers=any(not _visible(c) for c in jokers)
        if phase == "blind_select":
            add(2,A.SelectBlind())
            if gs.get("blind_on_deck","Small") in ("Small","Big"): add(3,A.SkipBlind())
        elif phase == "selecting_hand":
            forced={i for i,c in enumerate(hand) if c.ability.get("forced_selection")}
            for count in range(1,min(5,len(hand))+1):
                for selection in combinations(range(len(hand)),count):
                    if not forced.issubset(selection): continue
                    if cr.get("hands_left",0)>0: add(0,A.PlayHand(selection),targets=selection)
                    if cr.get("discards_left",0)>0: add(1,A.Discard(selection),targets=selection)
            if len(hand)>1:
                # Hidden sort semantics are an engine assumption; omit these to
                # avoid revealing rank through an unqualified sorting side channel.
                if all(_visible(c) for c in hand):
                    add(19,A.SortHand("rank")); add(20,A.SortHand("suit"))
                for i in range(1,len(hand)): add(17,A.SwapHandLeft(i),"hand",i, (i,i-1))
                for i in range(len(hand)-1): add(18,A.SwapHandRight(i),"hand",i, (i,i+1))
        elif phase == "round_eval": add(4,A.CashOut())
        elif phase == "shop":
            cash=gs.get("dollars",0)
            for i,c in enumerate(gs.get("shop_cards",[])):
                if not _visible(c): continue
                kind=c.ability.get("set",""); negative=bool((c.edition or {}).get("negative"))
                full=(kind=="Joker" and len(jokers)>=gs.get("joker_slots",5) or
                      kind in ("Tarot","Planet","Spectral") and len(consumables)>=gs.get("consumable_slots",2))
                if c.cost<=cash and (negative or not full): add(8,A.BuyCard(i),"shop_cards",i)
            for area,kind,constructor in (("shop_vouchers",12,A.RedeemVoucher),("shop_boosters",13,A.OpenBooster)):
                for i,c in enumerate(gs.get(area,[])):
                    if not _visible(c): continue
                    if c.cost<=cash: add(kind,constructor(i),area,i)
            if cr.get("free_rerolls",0)>0 or cash>=cr.get("reroll_cost",5): add(5,A.Reroll())
            add(6,A.NextRound())
        elif phase == "pack_opening":
            if gs.get("pack_choices_remaining",0)>0:
                for i,c in enumerate(gs.get("pack_cards",[])):
                    if not _visible(c): continue
                    # Eligibility involving hidden owned Jokers is not exported.
                    if hidden_jokers and c.ability.get("set") in ("Tarot","Planet","Spectral"): continue
                    for targets in self._targets(c):
                        if self._usable(c,targets,True): add(14,A.PickPackCard(i,targets),"pack_cards",i,targets)
            add(7,A.SkipPack())
        if phase in ("selecting_hand","shop") and not hidden_jokers:
            for i in range(1,len(jokers)):
                if not (getattr(jokers[i],"pinned",False) or getattr(jokers[i-1],"pinned",False)):
                    add(15,A.SwapJokersLeft(i),"jokers",i)
            for i in range(len(jokers)-1):
                if not (getattr(jokers[i],"pinned",False) or getattr(jokers[i+1],"pinned",False)):
                    add(16,A.SwapJokersRight(i),"jokers",i)
        if phase in ("blind_select","selecting_hand","shop","pack_opening") and not gs.get("STOP_USE",0):
            for area,kind in (("jokers",9),("consumables",10)):
                for i,c in enumerate(gs.get(area,[])):
                    if _visible(c) and not getattr(c,"eternal",False): add(kind,A.SellCard(area,i),area,i)
        if phase in ("blind_select","selecting_hand","shop","round_eval") and not hidden_jokers:
            for i,c in enumerate(consumables):
                if not _visible(c): continue
                for targets in self._targets(c):
                    if self._usable(c,targets,False): add(11,A.UseConsumable(i,targets),"consumables",i,targets)

    def step(self, index: int):
        if self._done: raise RuntimeError("Episode already ended")
        if not self._actions: self.observe()
        if isinstance(index, bool) or not isinstance(index,(int,np.integer)) or not 0<=int(index)<len(self._actions):
            raise ValueError("Index must identify a currently offered candidate")
        gs=self._gs; action=self._actions[int(index)]
        before_phase=str(gs.get("phase")); before_ante=gs.get("round_resets",{}).get("ante",1)
        before_blind=gs.get("blind_on_deck"); before_target=getattr(gs.get("blind"),"chips",0)
        before_blind_name=str(getattr(gs.get("blind"),"name",""))
        try:
            if reason := audit_state_boundary(gs):
                raise UnsupportedState(reason)
            self.steps+=1
            engine_step(gs,action)
            # Audit-only whole-episode censorship precedes both model projection
            # and terminal credit. No hidden-dependent choice/mask is returned.
            if reason := audit_state_boundary(gs):
                raise UnsupportedState(reason)
            phase=str(gs.get("phase"))
            cleared=(isinstance(action,A.PlayHand) and before_phase=="selecting_hand" and phase=="round_eval")
            clear_receipt=None
            if cleared:
                score_met=before_target>0 and gs.get("chips",0)>=before_target
                saved=bool(getattr(gs.get("last_score_result"),"saved",False)) and gs.get("current_round",{}).get("hands_left",1)<=0
                if not (score_met or saved):
                    raise UnsupportedState("round_eval_without_score_or_saved_receipt")
                self.blinds_cleared+=1
                clear_receipt={"ante":before_ante,"blind":before_blind,"target":before_target,
                    "blind_name":before_blind_name,"chips":gs.get("chips",0),"threshold_met":score_met,
                    "saved":saved,"after_ante":gs.get("round_resets",{}).get("ante"),
                    "before_phase":before_phase,"after_phase":phase,"scope":"simulator_play_to_round_eval"}
            # A loss state always outranks a stray win marker. This also keeps
            # source-like final-boss accounting quirks from becoming false wins.
            if phase=="game_over":
                self._done=True
                return None,0.0,True,False,self._info("loss")
            if gs.get("won"):
                if not (cleared and before_blind=="Boss" and before_ante==gs.get("win_ante",8)
                        and gs.get("round_resets",{}).get("ante")==before_ante+1):
                    raise UnsupportedState("win_flag_without_final_boss_clear")
                self._won_latched=True; self._done=True
                return None,1.0,True,False,self._info("win",clear_receipt=clear_receipt)
            if self.steps>=self.max_steps:
                self._done=True
                return None,0.0,False,True,self._info("censored",reason="step_limit",clear_receipt=clear_receipt)
            observation=self.observe()
            return observation,0.0,False,False,self._info("ongoing",clear_receipt=clear_receipt)
        except UnsupportedState as exc:
            self._done=True
            return None,0.0,False,True,self._info("unsupported",reason=str(exc))
        except Exception as exc:
            self._done=True
            return None,0.0,False,True,self._info("error",reason=type(exc).__name__+": "+str(exc))
