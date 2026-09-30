# 386 — win-first resource commitments (validated candidate, not installed)

The user-started ten-start batch was still running at inspection. The frozen
read-only prefix is completed public BRJ2 segments 1–16 of
`session-20260925T174440Z-1`; `capture/manifest.json` fixes original hashes and
13,054 consecutive events, and `capture/selected_advice.json` indexes relevant
public advice with exact raw-event anchors. The active writable tail was not
read or changed. All 1,930 teacher observations in this prefix say
`perkeo_yorick_win_v1`, with loaded label 2.183.0-alpha. This is a partial
selected batch, not a completed win-rate measurement or a loaded-byte hash.

Observed-game:5 reached 28 physical **Negative Strength** cards by Ante 8
(advice 9077, 9148), with only intermittent Strength uses. The Perkeo copy
valuation has no finite Strength capacity; the shop stock manager omits
Strength, so it cannot sell a redundant copy. The full 52-card rank population
at 9001 has no committed rank under the current profile threshold. The same
prefix has an affordable Blueprint at advice 9434 ($11 cash, $10 Blueprint,
Perkeo/Yorick owned), but the selected $4 unopened Buffoon Pack reduced cash
below Blueprint's price; 9456/9479 leave the offer unbought. This supports a
specific visible-offer opportunity cost, not a claim about unopened contents.
At advice 6813, an Eternal Green Joker improved the paired opening from about
540 to 688 against 1,500, while occupying a permanent ordinary slot; 9999
chose Eternal Supernova with paired opening about 8,616 to 9,518 against 4,800.
Other Eternal commons sometimes crossed an immediate target, so a blanket ban
would discard potentially useful rescues. Recommendations were followed by
auto-run requests/callbacks; exact semantic settlement is established only by
subsequent public observations, not callback return alone.

Acceptance for this one coherent shop-resource slice:

1. Give win-first Strength a bounded useful-stock capacity based on public
   rank commitment and remaining horizon; repeated Negative copies retain
   physical probability but stop earning unlimited direct utility. In the
   shop, review surplus Strength for sale using the same full-inventory,
   capacity, cash and action-cost comparison as other stock. Preserve a useful
   last copy, and never force use without a supported current-hand target.
2. Reject an early ordinary-slot Eternal common in win-first mode unless a
   complete supported same-world next-blind comparison establishes an actual
   survival rescue. Keep Negative and later-ante cases separate, and retain
   existing general collection admission and legality checks. Apply to shop
   offers and pack choices through the shared admission function.
3. When the preferred opening has no durable copy Joker, avoid spending on an
   unopened booster that makes a visible affordable nonperishable Blueprint or
   Brainstorm unaffordable if the copy candidate remains competitive and is
   not survival-dominated. Do not invent pack contents or override a supported
   survival-protecting comparison.

Manufactured checks must cover rank-committed and uncommitted Strength pools,
Negative capacity, last-source retention, incomplete/adverse Eternal evidence,
valid rescue, Blueprint-vs-pack affordability and higher-value pack controls.
Existing frozen score limits and all public-information protections remain.
Ordinary discard search currently keeps held inventory but does not plan future
Tarot/Planet use after redraw; this is a separate bounded joint-planning task,
not an inferred safe-discard probability for this repair.

The repository now contains **2.184.0-alpha candidate bytes** in three changed
runtime files: `Advisor/strategy.lua` and the two version headers. The running
game and installed directory remain **2.183.0-alpha**. The candidate gives
Strength a finite direct-stock credit only when the public whole-deck rank
population is qualified; otherwise it retains the previous unknown scope.
Negative physical copies still enter the exact random Perkeo pool. A shop
review can sell excess Strength one action at a time without inventing use
targets. The same shared Joker admission now requires a complete paired
four-world sampled rescue for early ordinary-slot Eternal commons, including
pack choices. A bounded, credit-aware copy-before-unknown-pack tie break uses
already-admitted visible candidates and keeps survival-dominated candidates
excluded. The result includes a concise reason; it does not assume pack
contents or future shop offers.

`tests/advisor_win_first_resources386.lua` passes 68 manufactured checks.
It covers repeated Negative sales and capacity conservation, last-source
retention, rank/unknown contrasts, complete versus partial/uncertain/unpaired
Eternal evidence, actual pack admission, visible Blueprint affordability,
Credit Card room, full slots, perishable offers, other profiles and a
survival-dominated Blueprint. The independent read-only review found a
credit-floor omission in the first draft; it was fixed and the same reviewer
confirmed no remaining blocker in one focused recheck. No captured game
state was evaluated through strategy or scorer.

Frozen candidate `runs/resources386_candidate/freeze.json` has policy digest
`851a189fe212211b0d7ced23abf3276eb04089e7658536db950adea9feeb3ccc`,
108 runtime/dependency files and 295 test files. The exact frozen candidate
gate at `runs/resources386_candidate/validation/` passed **255 Lua fixtures
and 392 Python tests**, with unchanged policy and test hashes. This is local
defect correction, not evidence of full-run benefit. Installed-byte validation
has not been run because nothing was installed. The repository version header
is therefore ahead of the still-running product; preserve this distinction
when the batch is analyzed.

No game/save/profile was accessed or controlled by tools. Existing settings,
seven native DLLs and all journals remain untouched. After the user normally
ends the current batch, recheck the exact installed baseline, current config
and native hashes, then install only the three explicit files with
`install_slice.py` and run the exact-installed gate. Any source/test change
after this frozen candidate requires a new freeze and candidate validation.

## 2026-09-25 release addendum

The user-started batch ended before installation. A read-only capture verified
all 27 public segments and 22,754 consecutive events: ten starts, three
verified wins, six verified losses and one unsupported retirement, all with
loaded 2.183 label and win-first snapshots. Exact raw bytes and lifecycle
anchors are in `completed/manifest.json`, `logs1/` and
`logs_complete_tail/`. This is an outcome census, not a complete causal
analysis or evidence of 2.184 benefit.

`preinstall.json` verifies the prior 2.183 installation, current settings
hash, seven DLLs, frozen candidate and all 295 tests. The three explicit Lua
files were installed as 2.184.0-alpha at
2026-09-25T13:45:28.1516366-05:00 with backup
`deployment-backups/advisor-20260925-134527`. The exact installed policy
froze with the same candidate digest and passed 255 Lua fixtures/392 Python
tests. All 92 deployment and 108 runtime/dependency hashes matched; config
and seven DLLs stayed unchanged. See `SESSION_RESET_386.md`/`.json` and
`runs/resources386_final/final_verification.json`. Activation remains
unconfirmed until normal user restart.
