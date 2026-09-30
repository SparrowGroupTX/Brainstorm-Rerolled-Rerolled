# Challenge Advisor

Current behavior was checked against 2.194.0-alpha source in
[audit 401](tools/advisor_eval/development401/REPORT.md) and the
[continued audit 402](tools/advisor_eval/development402/REPORT.md). The installed release
and validation receipts are in [checkpoint 400](tools/advisor_eval/SESSION_RESET_400.md).
Historical challenge estimates below are not measurements of the current
Red Deck / Gold Stake win-first mode.

Developer context and the next-work plan are in
[ADVISOR_START_HERE.md](ADVISOR_START_HERE.md) and the detailed
[ADVISOR_HANDOFF.md](ADVISOR_HANDOFF.md); the start page identifies the current checkpoint.

The advisor reads the current run and recommends the next decision. It is
enabled by default for challenge runs. It does not depend on the native seed
search, a normal starting deck, Steamodded, a network service, or an API key.

## Controls

- Click **Execute** beside the lower-right badge to carry out the displayed
  recommendation without opening the panel. Each click performs one action:
  play/discard its selected cards, use a consumable with its targets, buy/sell,
  choose from a pack, reroll, reorder cards/Jokers, or advance a blind/shop.
  **Wait** means the game is resolving an action or fresh advice is pending.
  Repeated clicks cannot queue the same recommendation. Separate collection
  controls can start bounded automatic play, as described below.
- Click the **Advisor** badge at the lower right, or press **Ctrl+H**. If you
  customized Brainstorm's modifier key, use that modifier with H instead.
- The panel shows recommended cards, estimated scores, alternatives, and
  context about your challenge, boss, and consumables. **More details** pages
  through longer explanations.
- **Select cards to play/discard** closes the panel and highlights those cards.
  You commit the action with Balatro's usual Play or Discard button.
- Consumable recommendations identify the inventory slot and exact targets.
  **Select consumable targets** highlights those cards; use the consumable
  yourself, then wait for fresh advice before playing.
- Card labels such as `#3 KH` mean the third card from the left, King of Hearts.
  Suits are C/D/H/S. The displayed order matters for card effects.
- **Settings > Brainstorm > Advisor** controls enablement, challenge-only use,
  and the badge. Disable **Challenge runs only** to use it with normal decks.

The **Completionist++ auto-run** page has distinct collection-marathon and
**Clear auto logs + 10 win-first runs** controls. Win-first fixes Red Deck,
Gold Stake and the searched Yorick/Perkeo opening; it can execute advice after
the user explicitly starts it. Its limits are ten starts, 500 actions and
1,800 seconds per run, 30 seconds per search, and 21,600 seconds per session.
Stop/Resume retains the existing session allowances. Sessions are not restored
automatically after restarting the game.

The win-first search accepts either Blueprint or Brainstorm for its copy
requirement. Its later-offer forecast assumes a prescribed route: take both
starting Souls, inspect initial shop stock, and open displayed Buffoon packs
in order without rerolls. It does not establish that the run can afford or
retain those offers. Live advice uses public stock, cash and survival needs;
departing from the searched route can change later offers. There is no
Blueprint-only setting in this collection preset.

Known 2.194 limitation: when every vanilla Joker already has a Gold sticker,
the win-first controller allows continuation but its search request builder
rejects the complete collection. The next search stops before starting a
worker. This was reproduced with manufactured metadata in audit 402; it has
not been patched or attributed to an observed loaded-game stop.

Starting the ten-run mode clears the owned prior auto journals; manual-run
journals are separate and retained. The code does not export a backup first.
The auto and manual archives each have a 10 GiB limit; reaching a limit stops
recording rather than silently rotating away old evidence. The explicit
**Clear auto logs** control starts no run and refuses an active or resumable
session. A public session stop does not establish normal game-process exit.

Advice refreshes after cards, money, Joker counters/order, hand levels,
consumables, or game phase change. While a comparison is running, the badge and
panel show **Comparing moves** without an actionable suggestion. A completed
recommendation is published to the badge, panel, and selection button together.
Opening or closing the panel keeps that recommendation for an unchanged state.
The full state is rechecked before opening, selecting cards, and executing.
Execution verifies the action against the game's live legality handlers. The panel opens
only when requested. The advisor does not change window mode or foreground the
game.

## Decisions it covers

**Hands:** first checks a small list of obvious legal hands. A reliable modeled
clear stops broad calculation, allowing only bounded Glass/Arm conservation and
lasting development checks. This path uses at most 70 scoring calls when a clear
is in the initial shortlist. Expected random overkill does not qualify. Without
a reliable clear it enumerates one-to-five-card subsets (up to 20 held cards),
respecting selection limits and boss restrictions. Hands larger
than 20 receive a bounded legal proposal using original card positions; the
panel discloses that the comparison is incomplete. Estimates
use current hand levels, debuffs, enhancements, seals, editions, held effects,
Joker order, many vanilla Joker effects, and challenge scoring modifiers.
When multiple modeled plays clear the blind, fewer selected cards are generally
favored. Against The Arm, permanent hand-level damage takes priority: a Level 1
Three of a Kind can be chosen over an upgraded Pair when both clear. If every
clearing option loses a level, hand usage, current Joker support, deck rank/suit
composition, and lost base scoring estimate the relative future cost. The
advisor explains that choice. The conservation comparison retains a reliable clear. A separate bounded
investment check can spend a spare discard or nonclearing setup play when the
retained finishing cards still suffice and future development repays the cost.
When another hand is needed, the advisor also considers adding non-scoring
cards to the recommended play. It compares up to 13 combinations using up to
12 paired replacement draws per combination. Each comparison starts with the
same sampled deck order, advances hand counters and supported Joker effects,
and scores the next hand. Extra cards are included when that improves modeled
next-hand progress without lowering current score or expected current income.
The panel identifies these as **Cycle with this play**; the selection button
highlights the scoring cards and cycling cards together.

Cycling preserves the current scoring cards and hand type, retains enhanced,
sealed, editioned, and valuable held cards, and respects effects such as Half
Joker. It can keep a useful pair or flush draw while cycling other cards. It
keeps single-card DNA/Sixth Sense plays and avoids speculative padding against
The Tooth or in Double or Nothing. No cards are added when the hand already
clears, only one hand remains, no useful redraw is available, or the follow-up
state includes unsupported effects. This is a bounded comparison of extra
cards, not a full search across all sacrifices of immediate score.

Play order and Joker order affect estimates. A new pass compares up to 120
permutations of the chosen played cards, preserving the unselected cards in
their existing slots. It can put Photograph/Hanging Chad targets first or
apply additive card Mult before Glass multipliers. Execute rearranges the
hand; fresh advice then selects and plays. It avoids rearranging for useless
overkill or displacing a clearing consumable/Joker-order plan with a losing play.

**Development and copying:** upgrades follow the established deck/hand build,
including Queen-to-King Strength. Win-first Death combines enhancement, edition
and seal value with contextual rank/suit preferences; the best source can require
reordering first. With a retained supported clear it can compare immediate use,
holding and a safe discard for a stronger public-deck source. This does not know
the next draw or search every future transformation. Perkeo values the entire
copying pool, purchase dilution and accumulating Negative copies, preserving useful
last sources. Matching Observatory Planets are compared with using them for levels.
A clear permits at most six consumable rescores and twelve growth scores, including
Yorick progress, dynamic first-discard Burnt upgrades and bounded Death-source
cycling. Final wins, fragile finishes, excessive costs, unsupported draw/order
effects and spent setup allowance stop investment. Glass added to a reserved
scoring card cannot displace a lower-risk clear just for more score. These
strategic utilities remain heuristic, not measured win probabilities.

**Discards:** when the current hand does not clear, ranks up to 16 promising
discard sets across available discard sizes and samples up to 24 draws per set.
Each candidate receives the same sampled deck order, and only complete comparison
rounds count. On the last hand, sampled clear probability takes priority over
average chips; the advisor keeps looking for a survivable redraw instead of
committing a play known to fall short. Detached discard states carry exact Yorick counters/XMult, first-discard Burnt
levels and copy effects, Green/Ramen, Castle, Hit the Road, Mail and Faceless
changes. Ordinary discards include Bell's forced card; unsupported selected
card-generation/destruction triggers are withheld from modeled comparisons.
Golden Needle discards still cost $1
per action and can legally put the balance below zero, matching the game.
For enlarged hands, the shortlist shrinks to leave enough budget for at least
four complete paired samples. If that cannot fit, the advisor keeps its legal
current-play recommendation and explains the skipped comparison. Cycling and
multi-hand continuation remain limited to 12 held cards.

Supported ordinary builds, including those without resource Jokers, can receive
a paired continuation check comparing playing now with leading discards over
at most four remaining hands. It carries cumulative chips, resource losses,
hand history and supported post-play Joker state forward. When the entire
remaining horizon fits, modeled blind survival takes priority over surplus
losing chips. Search reserves budget for complete matched comparisons. Later
plays are greedy; later discards are not searched. Unsupported transitions
invalidate the comparison instead of introducing invented effects.
Each draw searches its playable
hands. Sampling uses the remaining deck composition and a separate deterministic
random generator. The game RNG and actual next-draw order are not used. Search
shares a cap of 140,000 score evaluations with play/cycling analysis and yields
between batches to keep the game responsive. A budget limit is reported. The
advisor waits until the comparison finishes before showing an actionable play
or discard.

The displayed percentage is the fraction of sampled replacement draws whose
best next play has a **supported modeled clear** of this blind. Random means
alone do not count as reliable clears; supported conservative score floors can.
It is not a run-win probability or a calibrated confidence interval. Supported
transitions explicitly sample some outcomes, including Hook discards, Glass
breakage, and selected boss draw effects, using private deterministic streams.
Other random effects use estimates, conservative floors, or an unsupported
result, depending on the modeled family. Advice compares immediate progress,
the cost of consuming a discard, and selected follow-up draws after a play,
not an entire run.

**Shops and packs:** ranks affordable upgrades using hand focus, deck composition,
scoring needs, scaling, income, interest, capacity, and stickers. The panel can
suggest purchases, opening useful pack types, saving money, taking a free reroll,
or making room for an upgrade. Actual stock and exposed pack contents are used;
unopened packs and future shops are not predicted. These decisions can be
carried out with Execute or the game's normal controls.

When the Joker row is full, replacement advice now requires a specific visible
upgrade and a legal sale that makes room and funds the follow-up. It compares
the entire row, including owned combinations and scaled effects, preserves
Eternal and unknown effects, and checks Credit Card and Negative-slot changes.
After the sale it recomputes the purchase; each step takes its own click.
Owned Hermit/Temperance can be used before purchases or sales when their actual
payout helps, with interest, money-sensitive effects and Luxury Tax considered.

For supported Joker purchases and replacements, the advisor also compares actual
before/after scoring over four paired samples of the owned deck. These use a
neutral next blind, fresh hand/discard counters, existing hand levels, known
rank/suit conditions, actual post-purchase cash and modeled hand-size changes.
Each sample searches all plays from up to ten held cards and the current versus
a simple alternative Joker order. Score evidence adjusts strategic ratings;
income, scaling and future synergies retain their separate value. Whole-row
comparisons can reject a replacement that substantially damages current scoring.
Blueprint/Brainstorm targets now receive up to eight deterministic order
layouts on each side, with pins, copy chains, compatibility and editions.
Neither candidate receives credit merely for fixing the old row's order.
Card Sharp, Acrobat, Dusk and Mystic Summit can also receive a discounted,
paired late-hand scenario. The assumed repeat hand is fixed before purchases;
this is conditional scoring capacity, not an activation probability. Unknown
discard paths and blind-start effects still fall back. These samples do not
predict boss survival or run wins. A shared 50,000-score cap applies in shops; if it
cannot complete the comparisons, all score adjustments for that decision are
discarded. Shop work yields across frames like hand search.

When no useful offer is visible, a weak build can receive a paid-reroll
recommendation. It counts eligible, affordable scoring candidates under actual
rarity weights and shop slots, including Overstock and discounted reroll prices.
It reserves purchase cash, rent and near-term costs, preserves interest when
survival pressure permits, and does not borrow or assume an Egg sale. Full rows
only count a narrow set of expendable replacements. Mature scaling Jokers and
Eggs feeding Swashbuckler are protected. Odds shown are approximate chances to
find a relevant offer, not win probabilities. Each click buys one refresh.

Omelette Egg sales now require a specific useful purchase or pack replacement,
with enough money after the sale. Swashbuckler value is recalculated after the
proposed sale. Owned Temperance can be recommended before cashing an Egg, and
Gift Card/Egg resale growth is distinguished from spendable income. Planet and
Joker ratings include current hand, rank, suit and face-card synergies.

The synergy catalog distinguishes partners already owned, visible partners that
can be acquired together, and speculative partners. Supported examples include
Wee/Hanging Chad, Ancient/Hanging Chad, Photograph/Hanging Chad, Baron/Mime,
DNA/Hologram and Fibonacci/Hack. Speculative acquisition estimates use current
eligible rarity pools, actual Joker shop rate and shop capacity, current and
reset reroll prices, free rerolls, reserved purchase money, projected income,
rental drain and a horizon of at most three future shops before Ante 8 ends.
Overstock and reroll vouchers are reflected through their actual changed
capacity/prices. Forecast lines disclose slots, horizon, cash assumptions and
finding probability. These assume survival, approximate independent draws and
exclude future packs, editions and uncertain triggered income. Without pool
metadata, probabilities are unavailable. Speculation receives a capped bonus
and requires existing scoring support plus room for the partner.

**Held consumables:** before publishing hand advice, a bounded pass compares
one supported consumable followed by legal plays, using at most 25,000 score
evaluations within the shared 140,000 ordinary-decision allowance. Qualified
owned-consumable comparisons receive reserved work before broad hand search;
the known-clear development path retains its smaller limits.
Supported actions include all Planets, Black Hole, enhancement and suit Tarots,
Strength, Death, Hermit and Temperance. It checks target direction, removes the
used card before Observatory/edition scoring, updates Fortune Teller and
Constellation, and recomputes relevant deck tallies and boss debuffs. It can
recommend using a card before an otherwise losing play, retains irrelevant
Planets, and respects The Arm's permanent hand cost. Unsupported consumables
are disclosed. A bounded rescue pass can compare a Planet/Black Hole followed
by a supported targeted Tarot when neither single use clears. It evaluates at
most eight pairs within the same 25,000-score budget and accepts only a
deterministic modeled joint clear. Advice executes only the first item and
recalculates afterward; the second step remains a projection. Current clears,
single-item clears, and strong existing survival lines preserve consumables.
Longer sequences and long-term targeting tradeoffs are not fully searched.

**Joker ordering:** compares the current row with bounded alternative orders
using the same detached scorer and hand subsets, including Blueprint/Brainstorm
targets, editions and order-dependent triggers. It recommends a reorder
only for a useful modeled gain, avoids rearranging for overkill alone, and
preserves pinned positions. Ordinary reorder advice is withheld for
hidden/shuffling Jokers. Amber Acorn has a separate bounded public-belief path
that can choose a fixed play or qualified last-hand discard across retained
possible orders; unsupported evidence still withholds an action. The panel
gives the desired left-to-right order by current card
number; Execute applies that order, or you can drag manually. Let the advisor
recalculate afterward. Joker ordering has a local 30,000-score ceiling;
played-card ordering and boss rescue each have a local 10,000 ceiling.
These specialist comparisons consume the remaining ordinary 140,000 total,
rather than adding independent allowances to it. The fast-clear path retains
its separate 70-score total.

Targeted Tarot/Spectral pack choices now specify actual hand targets, including
Death's right-to-left copy direction, Aura's edition restriction, and seals.
Targets use deck/Joker utility and avoid needlessly replacing existing upgrades.
Suit conversions compare target groups, and seals account for supported
retrigger synergies. If Death's best source is on the left and its proposed
copy is better than every legal pair in the current order, the advisor first
recommends moving the source
right; Execute applies that order. Wait for a new recommendation before using
Death. Execute selects the next recommendation's targets and uses its pack
card. You can also select and use it manually.
This is a targeting heuristic, not a search over all future deck transformations.

**Blinds and consumables:** recommends playing versus considering a skip,
preparing for the upcoming boss, and using relevant held consumables. Specific
guidance covers all 20 vanilla challenges, including Jokerless, Golden Needle,
Typecast, Rich Get Richer, Fragile, and Double or Nothing.

An active boss can also prompt a legal Luchador sale, or an expendable Joker
sale against Verdant Leaf, if a detached post-sale comparison produces a
deterministic immediate clear. It removes the sold Joker, applies cash and
surviving effects, preserves permanent debuffs, and restores supported boss
resources/targets. Existing clearing plans keep the Joker. Unknown draws or
extra sale callbacks are withheld. This pass consumes at most 10,000 scores
from the remaining shared ordinary allowance.

## Challenge opening search

For a fresh **Jokerless** challenge, open **Settings > Brainstorm > Challenge
opening** and choose **Search this Jokerless opening**. The search targets a
Small Blind Coupon, a free main-hand Planet, two available Blue seals including
one Steel card in free Standard packs, and a first-shop Telescope. The default
**Four of a Kind + Blue Steel** looks for Mars; **Flush + Blue Steel** looks for
Jupiter. Five of a Kind depends on later deck development and actual hand levels.
A match replaces the fresh run while keeping
its challenge rules. This is a filtered run; it does not guarantee survival.
Each click checks at most one million deterministic seeds against the actual
public unlock/ban catalogs. Stop with the button or existing search hotkey.
The selector retains the three legacy Saturn/Straight patterns. A previously
saved selection remains selected. A bounded search can finish without a match;
another click continues from the next seed in the current search session.

Follow the advisor's individual Execute recommendations: skip Small, clear Big,
use the selected Planet, buy Telescope if affordable, and open Standard packs left to
right. It checks the visible stock and pack contents before choosing Blue seals.
Telescope costs money even with Coupon. When safely possible, finish the round
with Blue seals held and unplayed, leaving consumable space for their Planets. The normal hand advisor
handles the run; the product still performs one action per user click.

Other supported challenges keep the Legendary opening controls below.

In **Settings > Brainstorm > Challenge opening**, choose up to two distinct
Legendary targets (or Any), then **Search this challenge opening**. Your
auto-reroll hotkey also starts/stops it. It works only before the first blind
of a fresh, supported challenge. It replaces that fresh run while retaining
the original challenge definition and rules; it cannot replace a progressed run.

The limited filter requires first Small Blind Charm Tag and at least two
natural Soul rolls in that pack. The existing mod exception allows duplicate
Souls in this single pack; vanilla otherwise suppresses the second Soul. You
still get only two choices. All 19 vanilla challenges with Jokers are supported;
Jokerless uses the separate search above. The ordinary deck filters and their estimates do not
apply. No Legendary is directly granted and no challenge ban is removed.

The advisor guides the searched skip and both visible Soul choices. In The
Omelette it sells an ordinary Egg only when needed to use a visible Soul.
Two Legendaries are not automatically a strong start: Canio needs destruction,
Perkeo needs useful consumables, and Triboulet needs scoring Kings/Queens.
Specific targets let you avoid unsuitable pairs. The estimates for these
filtered starts are kept separate from ordinary fresh-run estimates.

## Limits

This is a heuristic assistant, not a solver or a promise of winning. It does not
simulate multi-round economies, every discard-trigger effect, future card
destruction, all consumable targeting choices, or unknown modded effects.
Unsupported Joker effects are called out in the panel. Random effects and
conditional effects such as The Hook make some score estimates uncertain.
Genuinely concealed cards retain unknown identities. Supported positions use
bounded belief comparisons; unsupported concealed mechanics remain explicit.
Ordinary discarded backs retain their already-revealed identities.

The search works on detached data. It never runs speculative `calculate_joker`,
blind callbacks, or scoring callbacks on live cards. Reading advice does not
change dollars, cards, RNG, seeds, challenge progress, achievement flags, or
saves. Explicitly clicking Execute commits the displayed action through normal
game functions and therefore changes the run just like a manual action. The
panel's selection button only highlights cards. Achievement eligibility remains
the game's decision.

## Validation

The user's 50% and 75% targets apply to every challenge separately. Neither
target has been demonstrated. See [evaluation progress and protocol](tools/advisor_eval/README.md).
The user requested lightweight development checks and rough estimates with
updates. [Fresh-run estimates for all 20 challenges](tools/advisor_eval/ESTIMATES.md)
are subjective, very low confidence, and separate from measured outcomes.
Large qualification campaigns are optional future work, not a prerequisite for
installing a useful tested improvement.
The eventual optimization objective is expected time to a completed challenge,
including failed attempts, so speed/skip policies must be compared using both
win rates and completion time. The current instruction is deterministic work
only: model development and GPU training are set aside unless requested again.

From the repository root run:

```powershell
python tests/run_lua_tests.py
```

The runner uses LuaJIT/Lua from PATH, or the installed Balatro `lua51.dll` on
Windows. Supply `--lua` or `--lua-library` to use another compatible runtime.
The fixtures check scoring mechanics, legal purchases and pack choices,
challenge rules, draw composition, deterministic sampling, snapshot immutability,
budget limits, stale selection protection, stable badge/panel publication,
extra-card cycling and protected held cards, and the overlay input-lock regression.

Game source and assets used for local verification are not distributed with
the advisor. This workspace uses the explicit-file, backed-up installer and
frozen candidate/exact-installed validation described in
[the current release checkpoint](tools/advisor_eval/SESSION_RESET_400.md) and
[mandatory release requirements](ADVISOR_RESUME_PROMPT.md). Preserve current
settings and all native DLLs; a blanket folder copy can include unrelated work.
Installation waits for confirmed normal game exit. Activation requires a
subsequent normal user start.
