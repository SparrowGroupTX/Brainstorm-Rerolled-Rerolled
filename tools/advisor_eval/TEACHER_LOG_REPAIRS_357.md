# Teacher logs and repairs 357

The final loaded 2.156 teacher batch is preserved in actual public journals.
At the final 2026-09-16 18:40:50 UTC cutoff, seven runs had started: four verified
losses, two verified Ante 8 wins and one unfinished opening. HUD Stop was clicked
at sequence11887, and the user reported closing the game. Both wins earned zero
new Gold stickers, consistent with this win-first pilot. This is selected searched-opening
development data, including previously studied seeds, not an unseen cohort or a
population win-rate estimate. No new games or policy evaluations were run by tools.

`development357/logs2/manifest.json` binds 28,190,754 bytes of original BRJ files,
copied read-only. All 11,891 events decoded and passed the teacher linker with no
missing callback or accepted-but-unobserved action at the cutoff. There are 1,872
full observations, 3,232 advice records and 1,122 callback request/result pairs.
Expanded decoded data is 210,023,740 bytes; the compact indexes are navigation,
not replacements for the preserved original records. No live logs were modified.
The earlier partial capture remains unchanged under logs1.

| Seed | Audited outcome at cutoff | Score / target | Cash at result |
| --- | --- | ---: | ---: |
| M4BVSY11 | Ante 6 Serpent loss | 112,910 / 120,000 | $109 |
| YVYN2Z11 | Ante 8 Verdant Leaf win | 674,187 / 400,000 | $138 |
| S7PXV521 | Ante 2 House loss | 648 / 2,000 | $5 |
| RH45AD21 | Ante 7 Big loss | 130,932 / 165,000 | $242 |
| YAEARC31 | Ante 8 Amber Acorn loss | 147,894 / 400,000 | $5 |
| I8VUSV31 | Ante 8 Crimson Heart win | 1,503,126 / 400,000 | $207 |
| X8XU8Y31 | User-stopped unfinished opening | No terminal outcome | Not applicable |

Later rental settlement changes the last two cash figures to $239 and $2.
YAEARC31's incidental won field remains a loss: GAME_OVER, zero hands and the
unmet target are explicit. The unfinished seventh run is not imputed as a loss.

The confirmed execution defect is S7PXV521's duplicate purchase of physical
Droll card:683 at sequences 4561 and 4570. A previously queued Judgement debit
was mistaken for completion of the first Droll purchase. It then opened another
pack using still-stale cash, reaching -$8. The repair must wait for the actual
shop transaction's settlement, not any changed state fingerprint. The installed
repair observes queued blocking base events and exact card transfer/debit before
allowing acknowledgement or another dispatch. Known vanilla purchases have no
offsetting cash bonus. A manual income action during an outstanding purchase
can conservatively leave its cash receipt unresolved; this edge is not qualified.
This sequence
and downstream actions are contaminated for straightforward imitation labels.

The teacher-specific regression is RH45AD21's expired rental Trio. Removing the
optional sticker objective also removed the metadata used by exact dead-rental
disposal. It remained through five shops and the loss. The repair admits the
existing public collection_progress ledger only under the exact teacher profile;
all existing sale, copy-target, inventory, cash, boss and unknown-effect guards
remain. Missing-sticker trades remain disabled. This is not a measured rescue.

Strategic problems remain. In RH45AD21 the last Venus, then the last Death, were
consumed despite already having clearing plays; Perkeo retained only Hermit and
accumulated cash. There are zero shop rerolls in the five completed recorded
runs, and none in the sixth. The Acorn policy played four Pairs and left three discards unused, because
its public hidden-order comparison covers immediate plays rather than future
discards/consumables. Correctly recording the visible boss does not make the
current teacher jointly plan across all upcoming blinds. These require bounded
whole-inventory and future-resource comparisons, not arbitrary forced actions.

The final win used17Magicians but peaked at18held, and ended with14Magicians plus
2Hermits. During Ante6 it still had40plain cards in a50-card public population.
The first loss used21Empress and ended with4. No consumable sales occurred in the
six finished runs. There is real surplus use/copying work to do, but the logs do
not support saying that the advisor never uses Tarot cards. A separate repair
will address supported score-floor development; this release changes no Tarot
valuation and does not imply a measured consumable-policy improvement.

One suspected mistake was correct: selling Perkeo at Verdant Leaf disabled the
boss and preceded the verified winning hand. Do not make starters unsellable.

Detailed evidence and exact sequence/BRJ/SHA anchors are in
`development357/shop_review/POSTMORTEM.md`, `report.json`, and
`development357/retirement_review/COMPONENT.md`. The teacher is not an expert
corpus; review or weight actions before imitation, retain failures and incomplete
evidence, and never punish every earlier action solely because the run lost.

Release2.157.0-alpha passed full candidate and exact-installed regression:
228Lua fixtures and391Python tests, unchanged frozen policy/test hashes.
Installation at2026-09-16T13:50:23.2473719-05:00 verified89deployment and105frozen
runtime/dependency files. Policy digest:
`5ed630a82938e90071e92c83611d42bf84b593b7717a3e429031122e2fe44331`.
Backup: `deployment-backups/advisor-20260916-135022` below the installation.
Current settings and all seven native DLLs were preserved. Normal restart
activation is pending; no new gameplay or repaired-policy outcome was observed.
