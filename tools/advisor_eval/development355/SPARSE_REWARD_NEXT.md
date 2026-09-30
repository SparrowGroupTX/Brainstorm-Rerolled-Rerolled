# Sparse terminal reward: research and the next useful experiment

Read-only research, 2026-09-16. All355 experiment authority is CLOSED. This is a
proposal, not an implemented curriculum, new allowance or claim of improvement.

The user's target is Red Deck / Gold Stake with Perkeo and Yorick, supplied
opening seeds, and maximum average distinct new Gold stickers per game. The
prototype's constructed opening is not source-equivalent to those seeds.

## What failed here

T02 had6,859 actual losses and no positive terminal reward examples;119 attempts
were unsupported and8 censored. Its potential shaping cancels over complete
episodes. That preserves the terminal objective but supplies no different final
returns among these losses. Temporary progress targets, critic approximation,
entropy and a play-only weak teacher are not reliable strategic supervision.
V02 then showed32/32 opening double-sales and two long reorder stalls. This
does not prove PPO is incapable, or that the correct reward encourages sales.
It shows this initialization/data/training recipe failed within its budget.

## Relevant recent evidence

- **Dreamer4 (2025):** the policy is behavior-cloned before RL, and a frozen
  behavioral prior constrains later updates. Task-relevant successful segments
  receive special sampling. These are applicable training principles; its large
  video model and compute budget are not our implementation plan.
  [Primary paper](https://arxiv.org/html/2509.24527v1).
- **DISCOVER (2025):** choose achievable subgoals relevant to the final goal,
  rather than exploring all novelty equally. Its results concern navigation and
  manipulation; critic generalization remains a stated limitation. Adapting it
  to Balatro requires explicit public goal predicates and validation.
  [Primary paper](https://arxiv.org/html/2505.19850).
- **Cago (NeurIPS2025; arXiv January2026):** demonstrations guide intermediate
  goals just beyond current competence. This motivates adapting the curriculum
  to observed skill instead of advancing solely because a timer expires.
  [Primary paper](https://arxiv.org/abs/2601.08731).
- **SCOUT (July2026 preprint):** reset assistance is paced separately by context.
  Navigation/manipulation results are relevant hypotheses for differing boss or
  opening difficulties, not established Balatro evidence.
  [Primary paper](https://arxiv.org/abs/2607.26417).
- **EfficientZeroV2 (2024):** search improves policy/value training targets and
  reanalysis revisits older data. Our adaptation should use trusted mechanics,
  sampled hidden worlds and matched candidate comparisons, not actual deck RNG.
  [Primary paper](https://arxiv.org/html/2403.00564v2).
- **OptionZero (2025):** temporally extended actions shorten planning horizons.
  For us, an ordering operation can be represented as one deliberate final
  arrangement; execution must still re-observe after consequential game events.
  [Primary paper](https://arxiv.org/html/2502.16634v3).

DreamerV3's Minecraft result includes rewards for12 intermediate item milestones.
It is not diamond-only feedback. This matters when comparing our terminal-only
sticker objective with its sparse-reward achievement.
[Nature2025 paper](https://www.nature.com/articles/s41586-025-08744-2).

AlphaStar's older but relevant recipe began with human-game imitation, followed
by RL. Its structured observations, memory and action composition are useful
analogies. Opponent leagues are not a requirement for single-player Balatro.
[DeepMind primary account](https://deepmind.google/blog/alphastar-mastering-the-real-time-strategy-game-starcraft-ii/).

## Proposed sequence, keeping the user's target

1. Audit and encode reviewed public decisions from the installed advisor and
   human play across all phases. Treat them as fallible labels, never all actions
   from a losing or winning run as automatically optimal. Match exact candidate
   identity, targets, order, inventory and collection status. No save access.
2. Clone useful behavior first and retain a soft behavioral prior during RL.
   Review disagreements and learner-visited states to address compounding errors.
   Permanently banning starter sales would obstruct eventual support retirement.
3. Train short, qualified tasks within Red/Gold Perkeo/Yorick: survive the opening,
   develop Yorick while retaining a finish, prepare Perkeo copies, convert a
   viable late position into a qualifying win, then retire support for a target.
   Use reachable simulated/publicly reconstructed states, vary hidden worlds,
   and extend the horizon only as competence improves. No live checkpoints.
4. Use auxiliary tasks as declared training aids. Full-start evaluation continues
   to count distinct actual terminal new-sticker identities. No credit for
   acquisition alone, excess score, or an unresolved attempt. Maintain a mix of
   ordinary initial states so late-position practice does not hide opening flaws.
5. Add public memory, meaningful action grouping and selective trusted search;
   then measure whether stronger data or larger models improve held-out outcomes.
   BF16 and batching improve throughput, not the missing learning signal.

For a fixed current collection, expected new stickers can be written as the sum,
over missing identities, of P(eligible win AND that identity held at victory).
Linearity requires no independence assumption. This makes the support-versus-
target tradeoff explicit, but estimating those probabilities requires outcome
data and calibration. The current model has neither reliable estimates nor
evidence that it learned this tradeoff. A fixed initial mask also does not
establish generalization as a real player's collection changes.
