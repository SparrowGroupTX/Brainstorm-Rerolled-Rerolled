# Already-Gold Eternal Droll purchase — passive audit 349

Scope: read-only bounded observation-journal prefixes, with no policy evaluation, replay, source/native worker, seed search, simulation, save/profile read or game control. The original logs remain untouched. The append-active segment is frozen only through sequence 864, `2026-09-16T06:41:47Z`; no later outcome is inferred.

Two segments from `session-20260916T063659Z-1` contain 2,477,702 frozen bytes and 864 decoded events without errors. All 646 versioned events identify **Brainstorm v2.148.0-alpha**, confirming that installation is loaded in this session.

## Confirmed action

At sequence **85**, `2026-09-16T06:37:27Z` (01:37:27 CDT), the advisor requests **Buy Droll Joker ($4)** from shop index 2. This is a shop purchase, not a pack choice. The physical card is `card:337`, `j_droll`, ordinary edition, Eternal true, and its contemporaneous collection record is `complete`.

Public context at the decision:

- Seed `M4BVSY11`, Ante 1, round 1, $5; next blind Psychic, 600 chips.
- Owned row: Perkeo, Yorick, Eternal Brainstorm, all already Gold. Three of five Joker slots occupied; no missing Joker carried.
- All hand levels are 1; Pair played twice, Full House once, Flush never played. The public 52-card population has four of every rank.
- Other visible Joker: Loyalty Card, $1, missing Gold, **Eternal and Rental**. Its observed disadvantages must not be erased when considering it as an alternative.
- Perkeo has no consumable to copy, as explicitly acknowledged by advice.

The advice acknowledges that Droll's Eternal slot is permanent, then explains its base-Mult support. It reports a complete paired opening estimate of **137 → 137** across four deck samples, with a copy-target order shortlist (2/5 layouts), and says that the observed whole-blind policy comparison clears only some composition worlds. The decision used **48,774 score evaluations** and was not marked truncated. The journal does not expose the complete whole-blind endpoint values here, so unchanged opening scores do **not** establish zero benefit in that longer comparison.

Collection-specific acquisition and final-shop comparison families decline this state because it is outside their winning-Ante/final-boss scope. Retention review is inapplicable because this is not a sale-first action. Their logged reasons and the full recorded advice are preserved.

## Actual acquisition, with queued-event timing preserved

Callback sequence 86 returns true. The first `state_after_actions` at 87 still shows $5 and the original three Jokers; its own journal wording warns that queued effects may remain pending. The next `auto_run/action_observed` at **88** shows the same Droll card held and **$1**, directly establishing the $4 purchase. The advisor then leaves the shop (90) and selects Psychic (95).

No terminal or stop event occurs in this frozen prefix. Neither survival improvement nor a later win/loss is attributed to this purchase.

## Bound receipts

- `report.json`: SHA-256 `0df19b1309c28aec2bd2172358782ea1add009bb5c97b533908729f784ca9694`.
- `settled_purchase.json`: SHA-256 `e5c52122e48650ce67d8dcbfb4e34d9c288005269233459371906edeac2f20dc`.
- Both bind exact segment prefixes and decoded/stored-frame anchors. Original public event bytes 85–88, 90 and 95 are preserved separately.
