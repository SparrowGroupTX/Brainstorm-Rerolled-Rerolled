# Focused read-only review — 2026-09-23

Independent reviewer `/root/hex_pack_review` inspected frozen run5 anchors
6717/6720/6723/6728/6730, `strategy.lua:base_consumable_value`,
`best_pack_choice`, `pack_advice`, `copy_utility`, `pack_scoring.lua`,
`decision.lua` tactical fallback and `execution.lua`. It confirmed Hex had
a positive generic rating despite foreseeable destruction of Foil ordinary
Yorick and ordinary Perkeo; Ankh shared the warning-only path. The proposed
guard checks every publicly possible survivor and rejects any consequent
non-Eternal Joker destruction; unknown row states abstain. It explicitly
recommended single-Joker, all-Eternal, edition-eligibility, mixed Eternal,
capacity, concealment and immutability fixtures.

After implementation, the same reviewer performed one focused static recheck
of Hex/Ankh and the final-shop copy cap. It found no concrete bypass:
nonpositive utility is returned before copy/pack bonuses, tactical
adjustments only apply to positive candidates, and fallback calls the same
guard. `all_eternal`, edition eligibility and concealed-row behavior matched
the intended conservative scope. No captured-state evaluation or source/game
execution was done by the reviewer. Focused and full validation receipts are
under `../runs/hex369_candidate` and `../runs/hex369_installed_validation`.

Ouija was not certified beneficial as an alternate choice in the actual
Hex/Ouija pack. The repaired advisor may still choose it under its existing
generic rating; its hand-size/rank tradeoff remains an explicit comparison
limitation in WR-009 and `NEXT_PRIORITIES_369.md`. No reviewer conclusion
claims a rescued run or a calibrated win-rate gain.
