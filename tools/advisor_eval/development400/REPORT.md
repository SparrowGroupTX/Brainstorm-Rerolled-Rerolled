# 400 — Blueprint acquisition and selective Death development

2026-09-26. **2.194.0-alpha is installed and both full gates passed.** It
includes the preserved, previously uninstalled 2.193 Acorn repair. The user
explicitly confirmed normal game exit before release. Exact installed receipt:
`../SESSION_RESET_400.json`; the prior 2.192 baseline is preserved in
`SESSION_RESET_397.json`. Activation awaits the user's next normal game start.

## Evidence and actual loaded status

`capture/manifest.json` and `capture/verification.json` preserve 27 stable,
hashed BRJ2 segments from `session-20260926T143842Z-1`: 54,029,064 bytes,
23,431 consecutive events. The public loaded label is 2.192, with 3,463
win-first observations; this is not exact loaded-byte attestation. Ten starts
ended in four wins (3, 6, 7, 8), five losses (1, 2, 4, 5, 10), and one
unsupported stop (9). `session_stopped` 23430 says `run_limit`. This selected
cohort does not establish a population win rate or a 50% result. No 2.194
loaded-game outcome exists.

`audit_public.py` only parses these copied public records. It does not run
captured states through policy or scorer. `analysis/copy_opportunities.json`
links each offer to observations, advice, requested actions, callbacks and
later ownership. `death_actions.json` preserves the selected cards and advice;
`settlements.json` preserves post-action markers. Physical changes in subsequent
public observations, not callback success alone, establish execution.

## WR-050: visible copies and unopened Joker packs

There were nine distinct visible Blueprint/Brainstorm offers: five later owned
and four passed. All nine were financially reachable directly or after one
legal sale; that is not a claim that every endpoint had supported survival.

| Start / card | Public observation and decision chain | Supported cause / limit |
| --- | --- | --- |
| 2 / Brainstorm 597 | 2940: $16, four Jokers. Buffoon opened 2947, Certificate fills the slot, shop left 2977. | Perishable/owned-copy conditions exclude the old narrow protector. After Certificate, replacement evidence is unsupported; do not claim a proven safe purchase at that later state. |
| 4 / Brainstorm 1062 | 7310: $70, full row with sellable Odd Todd. Advice 7370 has four complete paired finishing worlds, all four after-endpoints clear, ratio 1.846; merit -11.945 rejects as insufficient gain. Leave 7373, blind 7377. | Additive replacement merit rejects already-supported acquisition. |
| 6 / Eternal Blueprint 1470 | 10598: $17; consumable sale 10604 gives $21. Advice 10612/10660 compares selling Trading Card: all four supported finishing worlds clear, ratio 3, merit -5.445. Packs 10615/10638; leave 10663 at $13; same row at 10667. | Rating/merit and restrictive exception, not an execution failure. The prior $20 after-cash and first-copy restrictions excluded a useful endpoint. |
| 10 / Blueprint 2729 | 22562: $9, four Jokers and $2 sale victims. Advice 22566's Crafty sale endpoint has four supported finishing clears, ratio 2, merit -55.948. Packs 22569/22591; leave 22625. | This replacement comparison was complete even though other shop work truncated. Do not attribute the miss solely to the aggregate cap. |

Acquired contrasts: card 588 first owned at 2831, 736 at 3942, 1769 at 13503,
2157 at 17193, and 2512 at 20503. All are retained in the opportunity file.
There were 44 visible Buffoon offers, 18 opened and 26 unopened. Examples of
funded full-row offers before any Blueprint were observations 838 ($28,
Mega $8), 951 ($40, normal $4), 8179 ($67), 11003 ($37), and 23328 ($48).
Unopened contents are unknown; these are exploration opportunities, not
missed known Blueprint spawns.

The repair adds an early, focused visible-copy family before broad shop
work. It compares the direct purchase and legal non-core one-sale endpoints
with four shared public worlds and four relevant order candidates. Every
evaluation debits the existing 50,000 shop allowance. A supported endpoint
can override negative additive merit when all worlds finish safely without
regressing progress, the useful copy target is known, and real rental/paid
discard costs remain funded. Rental and Eternal copies are allowed. Expired,
hidden, unsupported, incomplete, protected-victim and unaffordable cases
remain guarded. Pack reveals use the same supported priority; sale and
purchase/choice remain separate freshly observed actions.

When seeking Blueprint with a useful target, known vanilla Buffoon packs get
strong exploration preference if there is a vacancy or a legal non-core
replacement and cash after opening retains $15 plus current rental/paid
discard costs. No Joker is sold before reveal. Poor packs that consume this
reserve are declined. Optional spending below the floor incurs a penalty;
a complete known scoring rescue is exempt. The $15 floor improves practical
readiness and is not a guarantee of every future edition/price or spawn.

## WR-051: source choice and use-versus-draw

Twenty Death actions (ten pack, ten held) have post-action markers and later
public card changes matching the selected right-hand source. The audit found
selection/sequencing problems, not reversed execution:

- Action 5493 copies Mult Ace of Diamonds into Steel Jack of Spades while a
  Steel King of Clubs and two Glass sources are visible.
- Action 6163 overwrites a Glass Ace of Spades with Steel Jack of Diamonds.
- Held Death 7250 uses plain King of Spades on a plain Six of Diamonds with
  four hands, three discards, two Negative Deaths and a supported ~3,738 clear
  against 2,000. Public deck includes one Glass Six of Hearts in 45 cards.
  Observation 7255 confirms the copy; settlement 7257 and advice 7258 precede
  the five-card Yorick discard 7261. This proves a missing option comparison,
  not that the unobserved draw would have found Glass.
- Tactical contrasts stay valid: 7077's plain Eight of Spades into Seven of
  Hearts enables a 1,576 Flush against 1,500; 12684's Jack of Spades into
  Glass Nine of Hearts supports a needed clear. Rank priors must not veto them.

Win-first source value now combines enhancement, edition and seal, using the
user's order: Glass > Polychrome > Steel > Foil > Holo > Mult > Bonus;
Red/Blue seals receive the strongest seal bonuses. Rank priors are King,
Queen, Ace, Ten, Jack; suit tie-breaks are Clubs, Spades, Diamonds, Hearts.
Actual Joker/hand/deck context can outweigh these priors. All directed
target/source pairs are compared, including a stronger source on the left.
An owned Death can recommend only a reorder first, prove the reordered clear,
then reobserve before using it. Optional use keeps physical Glass exposure
guards and the six-evaluation development limit.

With a held usable Death and a known 105% clear, growth compares use-now,
hold and qualified discards using the exact expected maximum source utility
over the unordered public deck. It retains the clear's cards and an unplayed
recipient, includes inventory, action, cash/interest costs and exact Yorick/
Burnt growth, and charges the existing budget. Independent exhaustive small
deck enumeration verifies the distribution calculation. Unknown/missing
population or IDs, hidden cards, forced selections, unsafe end states and
incomplete budgets decline fishing. The ordinary and fast-clear paths both
arbitrate fishing before optional Death use. This is safe-clear development,
not a full deficit-discard/consumable tree or guaranteed draw.

Compact `copy_death_review` journal receipts expose successful focused copy
acquisition and scalar attempt/work summaries, selected optional Death
development/fishing, and final action without sampled card worlds. **Audit 401
correction:** failed focused replacement details are not retained by this
scalar projection, and fishing rejection/no-gain, tactical Death and pack Death
do not all have structured source receipts. Public observations/actions still
permit selected-card reconstruction; missing receipts are unknown. See
`../development401/REPORT.md`. Existing settlement links remain authoritative.

## Validation and boundaries

New fixtures: `tests/advisor_blueprint_priority400.lua` (34 checks) and
`tests/advisor_death_selection400.lua` (44 checks). They exercise actual
production scorer/finisher paths, low cash and sale funding, Rental/Eternal,
pack capacity, ID/order permutations, incomplete worlds/budgets, contextual
rank/property stacks, reverse source, Glass and exact public draw expectation.
The old `advisor_copy_acquisition378.lua` integration expectation now accepts
a complete supported negative-merit acquisition; its old helper guard unit
assertions remain. Existing survival, inventory and tactical regressions pass.

The first full freeze remains at `runs/copydeath400_candidate/`: Lua found
the reserve suppressing an early-voucher supported rescue. The exemption was
corrected for any unresolved partial-risk baseline reaching sampled-safe;
the original regression and new fixtures then passed. The final combined
freeze is **`runs/copydeath400_candidate2/freeze.json`**, digest
**`97711915fc9705a40f7d0c4f2ac04ed5a6de2210c1efdc34f1eadf9226b61980`**.
It has 109 runtime/dependency files and 305 test files. Full gate:
**265 Lua fixtures and 392 Python tests passed**, policy/tests unchanged,
39.875 / 11.687 seconds respectively. All intermediate failures are preserved.

One read-only reviewer performed one substantive review and one focused
recheck; `REVIEW.md` records its findings and repairs. No extra reviewer or
parallel implementer was used. No game control, live gameplay, captured-state
policy/scorer replay, save/profile access, hidden search, source-game execution,
training or new experiment occurred. Existing score caps and closed budgets
remain. All tracked/untracked work, current config, public journals and seven
native DLLs are preserved.

Release navigation and the explicit ten-file delta are in
`../CANDIDATE_CHECKPOINT_400.md`. After the user confirmed normal exit,
`preinstall.json` verified the absent process, exact installed baseline,
unchanged current config/seven DLLs, final candidate/tests and all captured
source journals; no newer segments existed. `install_slice.py` installed
exactly ten changed paths at **2026-09-26T11:16:25.3787960-05:00**, with backup
`C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm\deployment-backups\advisor-20260926-111624`.
The full exact-installed gate also passed **265 Lua / 392 Python**, in
41.766 / 11.890 seconds, with unchanged runtime/test hashes.
`final_verification.json` and `runs/copydeath400_final/final_verification.json`
under the evaluation directory verify all 93 deployment/109 runtime and 305
test files, current config, seven DLLs and copied public journals. No 2.194
activation or loaded-game benefit is claimed; only a normal user restart can
activate the installed bytes.
