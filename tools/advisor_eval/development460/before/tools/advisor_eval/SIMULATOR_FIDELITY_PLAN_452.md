# Simulator fidelity: accepted direction and implementation plan

Plan established at452; current status at459 is in the compact
[fresh-chat handoff](FRESH_CHAT_HANDOFF_459.md), including the qualification matrix
for repairs453–458. The goal is accurate simulation for Balatro RL training.
The prepared458 source probe is unexecuted and awaiting explicit approval.
The broader lifecycle, RNG and sequence gates below remain prospective.
Read the [resume contract](../../ADVISOR_RESUME_PROMPT.md) before execution decisions.
The pre459 plan is preserved in [before459](development459/before/SIMULATOR_FIDELITY_PLAN_452.md).

## Objective and definition of success

Build a simulator whose decision-relevant behavior matches the user's actual
Red Deck/Gold Stake, Perkeo/Yorick, win-first configuration closely enough to
support reliable counterfactuals and eventually model training. For deterministic
rules, aim for exact state transitions under the same starting state/action/random
outcomes. For stochastic rules, additionally qualify conditional distributions,
dependencies and random-stream consumption. Reproducing a particular source seed
is a separate, stronger property; do not imply it from distributional agreement.

Graphics, audio and animation rendering need not be reproduced. Their event queue,
settlement order and gameplay side effects do. The user's searched opening and
mod/version configuration matter. A synthetic post-Soul row with Perkeo and Yorick
is not automatically drawn from the same conditional population as the filtered
opening search. Keep that initialization question explicit in every result.

Finite tests cannot prove every possible interaction. Replace vague "basically
accurate" claims with a versioned supported-mechanics contract, independent test
coverage, mismatch records and held-out sequence agreement. Declared unsupported
states stay visible; censoring them changes the training/evaluation population.

## Architecture decision to make, not assume

There are two candidate implementations: the broad Python Jackdaw wrapper and
the narrower production-Lua continuation machinery. There are independent original-
source reference harnesses, but none is a universally qualified whole-game oracle.

Recommended approach:

- Define a small language-neutral canonical state/action/event contract first.
  It should accept candidate/reference traces without depending on one engine's
  class layout or policy feature encoder.
- Use original game logic as the independent reference where practical and
  explicitly authorized. Preserve callback/event semantics when isolating it.
  Harness stubs must themselves be tested, especially event scheduling, card
  creation, passive effects and terminal evidence.
- Reuse already-qualified production rule components where that reduces duplicated
  implementation, but distinguish candidate implementation from reference. Calling
  the same scorer from both sides is not independent parity evidence.
- Keep the pinned upstream355 simulator and closed artifacts immutable. Put new
  overlays/adapters/fixtures in a new coherent slice with exact hashes. Do not
  mutate the frozen dependency to make old provenance appear unchanged.
- Choose the runtime/language after measuring the cost of the first qualified
  lifecycle slice. Do not rewrite the whole engine, optimize kernels or pick a
  bigger neural model before correcting semantics.

## First milestone: lifecycle fidelity

The current Lua continuation stops immediately at a supported blind clear and
records `round_rewards_modeled=false`. Full-game learning needs what happens next.
The Python engine supplies those phases but known errors remain in event ordering,
passive debuffs/expiration and held-card repetitions. This makes lifecycle work a
better next target than another broad policy adjustment.

Begin with one bounded round-end slice, then extend through the complete cycle:

| Stage | Required semantics and important examples |
|---|---|
| First discard | Burnt fires before per-card discard effects; Blueprint/Brainstorm can copy it; Hook exclusions; Yorick grows per discarded card, not per click |
| Refill/play | Physical card conservation, automatic hand sort, forced cards, visibility, score order, random effects and destruction |
| Round end | Held Gold/Blue Seal/Red Seal/Mime repetition, exact Joker callback order, rental, Perishable expiry and passive removal |
| Cash-out | Actual money before/after rental and rewards, correct interest base/cap, remaining-hand income, no duplicate payments |
| Shop | Purchase/sale cost and slots, Negative capacity, vouchers/tags, packs and legal choices, reroll cost and stock generation |
| Leave shop | Perkeo copies in actual row/callback order; copy effects; later copies sample the expanded pool; independent card ability state |
| Next blind | Reset/advance counters, transient state, hand/discard size, blind restrictions, Boss visibility and actual start effects |

Do not use this table as an assumed event ordering specification. Derive the
actual ordering from source and independently observed traces. In particular,
round-end callbacks, rent/expiry and later cash-out bonuses must not be casually
batched into convenient groups.

### First coherent implementation deliverable

1. Freeze the reference/candidate definitions and record the selected fixture
   family before implementation. Start with a small row where a Perishable Joker
   expires, a rental changes cash and a passive effect changes capacity. Include
   a separate held-card repetition case; do not silently mix all mechanics at once.
2. Implement canonical state comparison and event tracing plus strict pure
   manufactured tests. Demonstrate that the comparator catches a deliberately
   wrong event order and reports the first discrepancy without mutating inputs.
3. Reproduce one concrete lifecycle mismatch, minimize it and repair its supported
   cause. Add both positive and negative controls and a held-out composition/order
   case. Keep unsupported guards for every still-unqualified adjacent path.
4. Where an independently executed original-source comparison is needed, prepare
   the exact bounded proposal first. This chat did not allocate such execution.
   Do not reopen old harness jobs or label a hand-written expectation source parity.
5. Deliver the comparison evidence, fix, preserved failure and current qualification
   matrix. Tooling-only work does not require installing a product update.

This is one meaningful lifecycle slice, not permission to spend a turn building a
generic framework without validating a real discrepancy. Conversely, do not claim
the entire cycle qualified after its first slice.

## Canonical state and event contract

Compare all fields that can change future legal actions, rewards or public
observations. Preserve exact card identity relationships and order where meaningful.
Implementation addresses and unordered dictionary iteration are not game state.

Suggested state domains:

- Phase, ante/round/blind identity, target/chips, eligibility, verified terminal
  evidence and required queued effects still pending.
- Cash, debt allowance, rental rate, interest limits, current reroll price,
  resources remaining/used, hand/selection/slot limits and pending card buffers.
- Hand, draw pile, discard pile, destroyed/created cards; physical identities,
  bases, enhancements, editions, seals, debuffs and persistent ability counters.
- Ordered Jokers, relevant copy relationships, stickers/lifetimes, passive
  contributions, per-round and accumulated growth counters.
- Ordered consumable inventory with exact Negative capacity, usable targets,
  last Tarot/Planet, hand levels/played history, vouchers and active tags.
- Visible shop/pack offers and legal actions for the current phase; generation
  context, card pools and restrictions in private test state where needed.
- Public information and remembered beliefs, including Acorn. Keep private
  generator/RNG/deck-order state in a separate harness channel.

Each event should identify its phase/context, triggering object/copy source,
affected physical objects, ordered mutations, before/after resources and random
draw references. Compare after meaningful callbacks as well as settled boundaries.
Final-state equality can conceal compensating errors. A settled observation alone
does not prove every queued effect completed.

Comparator output should contain: case ID, exact manifests, supported/unsupported
classification, first divergent event/field, expected/actual value, short common
prefix, minimization status and a deterministic reproduction specification.
Never dump hidden reference fields into policy observations or runtime journals.

## Deterministic mechanics, RNG and observations are separate gates

**Gate A: prescribed-outcome transition parity.** Supply the same explicit event
outcomes and manufactured state to both implementations. Compare score, resources,
inventory, ordering and next legal actions. Injecting outcomes isolates rule bugs
from generator differences; it is not natural-seed evidence.

**Gate B: RNG semantics.** Validate which event consumes which stream, call order,
pool membership, sampling/replacement, probabilities and correlations. Match
shuffle and creation semantics, including Perkeo's changing pool. Matching only
individual marginal frequencies can miss action-dependent correlations. Publish
separate source-seed-equivalence and distributional-fidelity statuses.

**Gate C: observation parity.** An engine may know hidden state; the policy must
not. Poison/private-field invariance tests should establish that hidden identities,
draw order, seeds and future results do not alter emitted public features or
candidate eligibility. Maintain legitimate public memory/beliefs rather than
either leaking secrets or unnecessarily erasing previously known information.

**Gate D: uninterrupted sequence parity.** Run the same action sequence from an
equivalent initial state through multiple rounds, including losing and unsupported
paths. Stop comparison at the first mismatch, not after an apparently similar
win rate. Use held-out fixtures/seeds only under an explicitly authorized scope.

## Qualification matrix and acceptance

Record rows for each mechanic and combination, with statuses such as known mismatch,
implemented-unverified, manufactured-tested, independent-transition-qualified,
sequence-qualified and unsupported. Every qualified row names exact source/runtime
hashes, fixture/trace hashes and its limits. A dependency change invalidates only
the evidence that depends on those bytes; never erase the historical receipt.

For a selected family, acceptance requires:

- All declared comparisons completed; no silent omission of the awkward case.
- Exact deterministic fields/order, or a narrowly justified numeric comparison
  that cannot conceal a score-threshold or branch difference.
- Physical population/capacity/cash conservation and legal-action agreement.
- Independent expected behavior, adverse/negative controls and held-out cases.
- Unsupported/timeout/error/abandonment outcomes retained separately from losses.
- No private information in policy features and no real save/profile access.
- Original mismatch fails against the old candidate and passes the repair;
  adjacent supported behavior remains intact.

Do not set an arbitrary "99.9% matches" threshold that permits a strategically
catastrophic case. Classify severity and exposure. A learned agent can repeatedly
exploit a rare advantageous simulator error. After training, surprising strategies
should generate new parity probes before promotion.

## Later training readiness

The intended consumer is a Balatro RL model. After qualification, define the
training environment's reset/step, legal actions, public observations, win-first
reward and termination/truncation contract. A fresh encoder/candidate contract is
required. The old355 numeric network does not consume today's structured public
journals; its imitation labels come from `heuristic_index`, not current advisor
decisions, and its reward targets new Gold stickers rather than win-first play.

Curate semantically completed decisions; mark suspect/unreviewed labels; keep
failures and partial runs without inventing outcomes. Split by whole run/session
and repeated seed/opening families. Keep policy version and distribution shifts
visible; do not leak terminal outcomes or seed identifiers into features.

A small supervised pilot is optional interface work, not a prerequisite or a
replacement for the user's RL objective. Qualified simulator comparisons/RL can
try to improve beyond the teacher. Exact scoring/legality and fallback logic
can remain outside the learned component. A simulator win is not
loaded-game improvement; deployment needs separate frozen evaluation and actual
user-started evidence. An accurate simulator also does not by itself fix sparse
reward, poor exploration, missing public features or inappropriate objectives.

## Experiment registration, when a concrete job is proposed

Record the hypothesis and a falsifier, exact supported state/transition family,
fixture or seed partition, candidate/reference/environment/profile hashes,
public/private schema, maximum workers, total cases/transitions/episodes, per-worker
and coordinator time, CPU/GPU limits, artifact bytes, failure/stop policy, and
one-use consumption accounting. Unused historical capacity stays closed.

No numeric budget is fabricated here. Prefer the smallest discriminating test;
prepare fixtures and expected outcomes before asking for any distinct permission
still required by the resume contract. Do not turn the user into an approver of
routine edits or re-ask the accepted project direction.

## Research context, not project evidence

Simulation can support learning, but policies can exploit environment-model
inaccuracies: [World Models](https://worldmodels.github.io/). Logged-data policy
improvement also risks overvaluing unfamiliar actions:
[Conservative Q-Learning](https://arxiv.org/abs/2006.04779). Sequential imitation
can compound errors as a learner reaches states its teacher data did not cover:
[DAgger paper](https://proceedings.mlr.press/v15/ross11a.html).
These motivate validation design; none proves our simulator or policy is qualified.
