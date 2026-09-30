# Isolated Balatro learning prototype

This package is an offline research experiment. It does not change the installed
advisor, start or control Balatro, read saves or player profiles, or award player
achievements. It uses the Python Jackdaw reimplementation pinned at
`92df18c27e26e6d324132942905e41242e4e24bf`. Simulator results are not original-game
validation, actual Gold sticker awards, or evidence of human-level play.

**Experiment closed. No learned model is installed.**
`../advisor_eval/development355/CLOSED.json` records seven completed jobs
(P01, S01, T01, T02, V01, V02, V03); T03 was closed unused. There are no remaining
workers, leases or automatic continuations. Unused capacity cannot be reused,
renamed or replaced. The specialized policy was rejected on development evidence;
final evaluation is complete. The installed advisor remains separate and unchanged.

The final learning objective is **new distinct Gold stickers per run on Red Deck /
Gold Stake with the public Perkeo/Yorick opening situation**. The generic base
environment below remains available as tooling, but it is not the specialized
objective. White Stake or general Balatro training is not the current priority.

The existing original-Lua adapter remains the stronger rules reference. This
prototype evaluates whether a faster simulator and a learned policy are useful
enough to justify further work. Fidelity patches and unsupported boundaries are
separate from model learning; neither removes the need for original-game checks.

## Architecture and boundaries

`experiment.py` freezes the package and simulator into a fresh one-use job and
records their hashes. `train.py` owns bounded CPU simulator workers, CUDA model
inference/updates, separate seed families and evidence files. `environment.py`
owns public observation projection, deterministic candidate generation and
episode semantics. `specialized_environment.py` adds the isolated Red/Gold
post-Soul scaffold, and `objective.py` adds public collection conditioning and
distinct simulated new-sticker accounting. `model.py` consumes only numeric public observations and
candidate descriptions. `heuristic.py` is a disclosed weak public baseline and
optional imitation teacher; it does not call the existing advisor.

Environment imports engine modules directly. It never imports the upstream Gym
wrapper, stock observation encoder, stock action masks, or live bridge. Importing
this package does not initialize an episode. **Constructing `Environment` does**,
so actual runs require separate explicit authority and a newly registered finite
job; this experiment has no remaining authority. Historical quotas are not
reused. Manufactured tests bypass or mock initialization and patch transitions.

`BRAINSTORM_LEARNING_SIM_PATH` selects a frozen simulator package root. Without
an override the path is `tools/advisor_eval/development355/external/jackdaw`.
An already imported Jackdaw from a different path is rejected. Package/runtime
hash verification belongs to the job coordinator, not to a network fetch or
automatic update in this wrapper.

Source-grounded simulator overlays live separately in `simulator_patches.py`.
Their own tests and preregistration describe their exact scope; upstream files
remain unchanged. Known unresolved mechanics must end with `unsupported` rather
than silently adopting a convenient approximation or manufacturing a loss.
The wrapper applies the hash-verified overlay before run initialization and audits
boundaries before observations and both before and after transitions. This
audit-only gate may inspect private state solely to censor the entire episode;
it never supplies private features, action rankings or eligibility hints. The
current gate censors near-expiry perishables, debuffed passive Joker effects,
Mime held-resource repetitions and nondefault perishable lifetime. These are
conservative exclusions, including states that might be harmless under some
next actions. They must remain reported as unsupported, not omitted from results.

## Base interface

```python
Environment(seed: str, deck="b_red", stake=8, max_steps=1200)
observe() -> {
    "global": float32[80],
    "entities": float32[N, 64],
    "candidates": float32[A, 160],
}
step(candidate_index) -> (observation_or_None, reward, terminated, truncated, info)
```

`info` includes `outcome`, `ante`, `blinds_cleared`, `dollars`, `steps` and `won`.
Outcomes are `ongoing`, `win`, `loss`, `unsupported`, `censored`, or `error`.
Unsupported/error/cap stops truncate an episode and do not count as game losses.
Invalid caller indices raise `ValueError`. Initial unsupported observations raise
`UnsupportedState`; the worker converts that into an explicit unsupported record.

No entities or candidates are silently truncated or randomly subsampled. The
limits are **128 current entities and 4,096 candidates**. Overflow is unsupported.
The trainer pads a batch and supplies masks. `CATALOG_SIZE` defines the categorical
embedding vocabulary; IDs are sorted public catalog positions divided by
`CATALOG_SIZE + 1`, with zero reserved for concealed/unknown identity.

The base environment reward is sparse: **1 for an evidenced simulator win, 0 otherwise**.
Any reward shaping or teacher imitation is a separate, explicitly recorded
trainer choice. `blinds_cleared` counts observed play-to-round-evaluation
transitions with a met target, or the simulator's explicit saved result with no
hands remaining. This is simulator evidence, not parity against retail Balatro.

The first Ante-8 Boss win ends the episode. It requires an actual play transition,
target/saved evidence, the win marker, round-evaluation phase and advancement to
Ante 9. A loss state takes precedence over a stray win marker. The upstream
adapter's `GAME_OVER`-only termination is deliberately not inherited; it otherwise
continues into endless mode after a win.

## Specialized Red/Gold interface and objective

```python
SpecializedEnvironment(
    seed: str, deck="b_red", stake=8, max_steps=800, *, goal_spec: dict
)
observe() -> {
    "global": float32[530],
    "entities": float32[N, 67],
    "candidates": float32[A, 163],
}
```

This is a separate wrapper over the base 80/64/160 interface. It appends 150
three-state public collection entries to global features, and three target-status
features to each entity/candidate: `missing`, `complete`, or `unknown`. Base
offsets, concrete actions and public-information safeguards remain unchanged.
Unknown or unverified history is not treated as missing.

T02 and its evaluations used a **fixed 59 complete / 91 missing / 0 unknown**
collection map extracted from existing opt-in public logs, not from a save or
profile read. The observed map timestamp is `2026-09-16T15:10:48Z`; its canonical
SHA-256 is `f5020ea4d8da7f69811712d21be39792861743f340b3daf2896196cd3484fe5d`.
Perkeo, Yorick, Blueprint, Brainstorm and Burnt are already complete in that map.
The frozen map is historical objective context, not a claim about the player's
current collection. Provenance and the full status list are in
`../advisor_eval/development355/SPECIALIZED_PUBLIC_DATA.json` and
`SPECIALIZED_DATA_AUDIT.md` in the same directory.

Every specialized attempt starts from the same public Red/Gold post-Soul shape:
Ante 1, round 0, $4, Small skipped, Big next, ordinary Perkeo then Yorick,
fresh X1 / 23-discard Yorick, and no consumables. The reference is the already
observed YAEARC31 development opening. Hidden cards/RNG come from fresh simulator
initialization. This does **not** reproduce that seed's Charm/Soul rolls or
filtered-opening RNG history, and is not a seed-equivalent replay or a first-shop
checkpoint. No starting cash, growth or inventory earned by a later blind is
imported. Preserved source recipes remain development evidence.

Reward is the number of **distinct known-missing held vanilla Joker identities**
at an evidenced eligible simulator Ante-8 win, otherwise zero. Duplicate copies
count once; already-Gold anchors add no reward. There is no separate win bonus or
reward for merely buying/holding a target. A zero-new-sticker win earns zero.
T02 used gamma 1 and separately declared telescoping blind-progress shaping;
unsupported/error/censored outcomes remain unresolved, not fabricated losses.

Specialized `info` includes `objective="completionist_distinct_v1"`,
`scope="public_conditioned_post_soul_training"`, `goal_digest`, `new_gold_keys`,
`new_gold_count`, `simulated=true`, `actual_awards=0`, and
`seed_equivalent_opening=false`. Synthetic normal-run eligibility flags do not
award a player profile. The base fidelity boundaries and final-boss evidence
requirements still apply. The fixed mask is not updated by simulated wins; this
is not a simulated or real collection campaign.

## Base public features and shared omissions

Global features encode phase, public blind position, ante/round, cash, current
chips/target, hand/discard resources, inventory capacities, remaining population
counts, reroll price, stake, public blind identity, interest cap, observed clears,
step budget, pack choices, last Tarot/Planet identity and twelve hand levels.

Entities are visible hand cards, owned Jokers/consumables, current shop items and
current pack items. Rows include area and public position, catalog/type, rank,
suit, enhancement, edition, seal, cost, stickers, debuff and selected public
ability/growth counters. Pack Tarot/Planet/Spectral/Joker identities are retained.
Extra hand cards, Negative Jokers and expanded consumable inventories stay present
up to the explicit capacity.

Concealed cards expose area/position/presence only; a hand card's forced highlight
is additionally public. The wrapper does not compute hidden hand strength,
read remaining deck identities/order, export discarded card identities, join
physical card IDs, or expose seed/RNG state. Stale shop/pack contents outside
their active phase are omitted. Concealed eligibility is not guessed.

Each candidate includes its action type, targeted public entity, selected-card
aggregate, exact ordered public target positions and visible hand-pattern
features. Feature 159 is `log1p(ordinary poker base estimate)`; this is a public
arithmetic feature, **not an exact score forecast**. It excludes Joker rules,
enhancements, editions, seals, boss effects, Four Fingers/Shortcut/Smeared changes
and other scoring modifiers. A selection containing a hidden card receives no
pattern/score estimate. Detailed numeric offsets are documented in
`environment.py`.

Omitted public information includes full remembered deck composition, most
round-history distinctions, prospective blind/skip-tag details, complete voucher
and tag inventories, full conditional Joker ability state, original-game public
rendered-event beliefs and player history. The base 80/64/160 interface omits the
Gold collection objective; the specialized wrapper supplies the frozen public
status map described above, but not a live profile or complete campaign history.
The policy has no recurrent memory, so redaction also loses previously seen
identity/order information. These are representational limitations, not claims
that the missing information is unavailable to a human.

## Actions and differences from retail

The wrapper covers blind selection/skipping, play/discard, cash out, shop exit,
buy/sell, rerolls, vouchers, boosters, pack picking/skipping, owned consumables,
hand sorting and adjacent hand/Joker swaps: 21 candidate kinds over five active
decision phases. Play/discard selections are unique subsets of one to five cards;
every offered selection includes Cerulean Bell's forced card. Consumed and pack
Tarot/Spectral targets are explicit subsets, without silent default targeting.
Candidate ordering and target tuples are deterministic.

Important limits:

- Plays use current left-to-right hand order; adjacent swaps allow another order.
  Direct arbitrary click-order permutations are not enumerated as play actions.
- No engine-supported buy-and-use or boss-reroll action is available here.
- Joker swaps are available only in hand/shop phases. Hand swaps/sorts are hand
  phase only. Sales are offered in the engine's supported blind/hand/shop/pack
  phases. Owned consumables are offered in blind/hand/shop/round phases.
- Hidden Jokers are represented without identities. Their swaps/sales and
  identity-dependent consumable use are conservatively omitted. Visible Jokers
  can still be sold. Hidden-hand sorting and Aura targeting are omitted.
- Purchasing follows this simulator's cash/slot checks, including Negative
  capacity exceptions. Retail Credit Card borrowing behavior is not provided.
- The base interface accepts ordinary decks and stake 1–8; the specialized wrapper
  accepts only Red Deck / Gold Stake. Challenge definitions exist upstream but
  are outside these constructors.
- Gold Stake comes from the engine's cumulative stake-8 modifiers. The run uses
  synthetic catalog/unlock state. The specialized wrapper additionally uses the
  frozen public missing-sticker map and explicitly conditioned post-Soul shape;
  neither interface reproduces filtered two-Soul seed consumption, seed search,
  checkpoint retry or the complete installed mod behavior.
- Bounds, unsupported mechanics and invalid simulator behavior are retained as
  explicit outcomes. A completed unqualified simulator run does not prove a
  corresponding retail run, award, or player win rate.

## Completed evaluations and next useful work

Both evaluations used the same frozen T02 policy and compared it with the weak
public heuristic, not the installed advisor. Each policy had 32 attempts per job.
V02 used development seeds; V03 used the separate final namespace after policy
selection. Every cohort recorded **zero wins and zero simulated new Gold**.

| Evaluation | Policy | Actual losses | Unsupported | Censored |
|---|---|---:|---:|---:|
| V02 | Learned | 28 | 2 | 2 |
| V02 | Weak heuristic | 23 | 9 | 0 |
| V03 | Learned | 30 | 1 | 1 |
| V03 | Weak heuristic | 21 | 11 | 0 |

Unsupported attempts and capped loops remain in the reported population. Zero
observed wins is not a justified complete-population win-rate estimate while
attempts remain unresolved. These are unqualified simulator results, not retail
or player award evidence.

The V02 learned policy sold both starting anchors before the first blind in all
32 attempts and spent 1,564 of 2,177 decisions reordering Jokers, including two
step-capped loops. T02 supplied no positive terminal sticker examples. Detailed
evidence and limitations are in `../advisor_eval/development355/SPECIALIZED_POSTMORTEM.md`.

Prioritize a stronger verified public teacher and a shorter, qualified curriculum
within the same Red/Gold objective before more sparse-reward training. Useful
control work includes public reorder-cycle safeguards and explicit opening
supervision. Proposed corrections are not established improvements and are not
silently active in the frozen evaluations. More identical training, a larger
network, White Stake training or broad general-game training is not the supported
next step. Any future experiment requires fresh explicit authorization and bounds.

## Manufactured checks

**96 manufactured tests passed before T02; 105 passed in final validation.**
The final receipt and full output are in `../advisor_eval/development355/` as
`test_receipt.json` and `manufactured_tests.log`. These checks do not establish
simulator qualification or winning ability.
These checks establish local contracts, not complete simulator fidelity or
winning ability.

Run `python -B -m unittest tools.advisor_learning.test_environment -v` for public
projection/candidate/terminal checks. These tests construct artificial states,
use pure legality predicates and replace the transition function; they do not
initialize or play simulator episodes. They cover hidden-field poison objects,
seed/RNG and hidden-identity invariance, forced selections, explicit pack targets,
ordered descriptors, overflow, detached arrays, base poker arithmetic, capacity
rules, terminal evidence and baseline loop avoidance. Specialized-wrapper tests
also cover the mocked post-Soul recipe, 530/67/163 augmentation, distinct reward,
eligibility and unchanged censoring. Model, objective, overlay and trainer tests
are separate. The completed throughput/training/evaluation jobs are closed;
manufactured tests do not reopen their episode allowance.
