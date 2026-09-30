# Modern game learning for Balatro

Research date: 2026-09-16. Primary sources only. This report recommends experiments; it does not report new training, installations, speed measurements, or validated Balatro results.

The user has explicitly authorized **RTX 5090 GPU training**, with a model as large as is useful. The earlier CPU-first training recommendation is superseded. Use the Ryzen 9950X3D to supply simulator experience and the RTX 5090 for batched inference and learning. Start precision evaluation with **BF16 autocast and FP32 sensitive calculations** using the installed `torch 2.9.0.dev20250801+cu128`; current documentation does not prove every newer feature works in that nightly.

## Recommended direction

Build a structured, recurrent policy and value model, initialize it from useful demonstrations or search, then improve it with reinforcement learning in a qualified full-game simulator. Add bounded, chance-aware search at consequential decisions and distill its improvements back into the policy. A larger model is appropriate when it improves held-out win rate per elapsed training time; neither the fruit-fly neuron analogy nor the GPU's memory capacity is a useful model-size target by itself.

This is an engineering synthesis, not a published Balatro recipe. Its most relevant ingredients are modern memory training, stable value targets, fresh online experience after imitation, and search-generated supervision. Video generation and opponent leagues have much lower immediate relevance: our inputs can be structured, the rules can be simulated, and Balatro is a single-player stochastic game.

Three problems must be handled separately:

- **Memory / partial observability:** preserve useful public history, deck changes, purchases, played/discarded cards, and prior decisions. A recurrent model cannot reveal unrevealed draw order or future shops.
- **Credit assignment:** teach that spending money or discards now changes later survival. A longer context alone does not provide a useful learning target for early actions.
- **Planning:** compare possible futures using a simulator or learned dynamics. More search is useful only when its model, information boundary, and value estimates are sound.

## What the 2024–2026 evidence supports

### DreamerV3: stable targets and learned state, before wholesale world modeling

The 2025 Nature paper uses a recurrent world model, replay, imagined trajectories, and actor–critic learning across more than 150 tasks. Its practical contributions include signed-log input transforms, categorical value predictions with exponentially spaced bins and two-hot targets, return scaling, and zero initialization of reward/value output layers. These address large and changing signal magnitudes. The authors report single-A100 training runs and publish an implementation. [Paper](https://www.nature.com/articles/s41586-025-08744-2), [official implementation](https://github.com/danijar/dreamerv3).

**Application:** use a recurrent latent state and stable numeric targets. Begin with a bounded probability-of-winning head; use transformed/distributional targets for genuinely unbounded auxiliary quantities. A direct simulator already supplies transitions and rewards, so a learned world model must earn its complexity by reducing end-to-end cost without damaging decisions. DreamerV3 is mature research code, but its JAX stack is not a drop-in component for the installed PyTorch environment.

### Dreamer 4: impressive long horizons, very different training cost

The September 2025 paper learns from offline Minecraft data using video world-model pretraining, behavior cloning, and reinforcement learning in imagination. It handles tasks involving more than 20,000 low-level actions. However, the reported system has 2 billion parameters, trained on 256–1,024 TPU-v5p devices; single-GPU interactive inference is a separate claim. Evaluation uses a sequence of task prompts and reports diamonds in 0.7% of episodes. The paper separates relevant successful sequences for behavior cloning from uniformly sampled dynamics data to avoid optimistic generations. [Paper](https://arxiv.org/html/2509.24527v1), [author project](https://danijar.com/project/dreamer4/).

**Application:** borrow staged learning, balanced experience, policy priors, and multi-step auxiliary prediction. Do not interpret the result as evidence that reproducing a large video world model on one 5090 is the fastest route to Balatro. Predicting exact card effects from compact state is a different problem from predicting pixels.

### EfficientZero V2: search can manufacture better supervision

EfficientZero V2 (2024) combines learned dynamics, sampled Gumbel search, self-supervised temporal consistency, and updated search-based policy/value targets. Reanalysis refreshes targets from older experience using the current target model. It evaluates discrete Atari actions and continuous-control benchmarks under limited environment data. Its computation comparison used a server with eight RTX 3090s, so sample efficiency should not be confused with low wall-clock cost on one GPU. [Paper, including training pipeline and computation appendix](https://arxiv.org/html/2403.00564v2).

**Application:** first use the qualified exact simulator for a small set of candidate actions, and train on the resulting improved action distribution and leaf value estimates. This captures the policy-improvement loop without first learning every game mechanic. Reanalyse a bounded subset of difficult old states. Search should receive the same observations as the player and sample hidden futures conditional on those observations; a deterministic rollout of the real hidden seed would produce an oracle.

### OptionZero: useful temporal abstraction, with observation boundaries

OptionZero (ICLR 2025) extends MuZero with learned action sequences and corresponding dynamics, allowing search to cover more time under a fixed simulation budget. Its experiments concern 26 Atari games, and code is linked by the authors. [Paper](https://arxiv.org/html/2502.16634v3), [author project](https://rlg.iis.sinica.edu.tw/papers/optionzero/).

**Application:** compress forced transitions and consider phase-level values, such as the value after leaving a shop or finishing a blind. Do not blindly commit to multi-action plans across a new draw, shop offer, pack, or boss reveal. Those observations can change the best action. Start with reversible search abstractions; learning an option system adds another optimization problem.

### Memory learning: a cheap auxiliary experiment before an enormous context

The NeurIPS 2024 lambda-discrepancy paper trains recurrent value estimates with different TD-lambda settings and uses their disagreement as an auxiliary memory-learning signal. It improves recurrent baselines on the paper's partially observed tasks. Its formal result concerns the specified value-estimation setting; ordinary neural-network disagreement in a finite training run is not proof of hidden-state aliasing. [Conference paper and abstract](https://proceedings.neurips.cc/paper_files/paper/2024/hash/73073ccb3bc559fd001e66b9079d6d5e-Abstract-Conference.html), [author project and code links](https://lambda-discrepancy.github.io/).

Memo (October 2025) trains periodic summary tokens to retain history more economically than full-context attention. It emphasizes propagating gradients through summaries and refreshing cached representations during policy updates. Results concern navigation and memory benchmarks; the authors explicitly leave broader length extrapolation unresolved. [Paper](https://arxiv.org/html/2510.19732v1).

**Application:** compare an explicit public-history feature baseline, a GRU/LSTM, and a bounded event-history transformer. Add lambda-discrepancy or learned summaries only if memory probes and decision tests expose a failure. Maintain sequence order, reset memory at run boundaries, and avoid treating stale hidden states or transformer caches as current-policy representations after updates.

### Recent card-game evidence: action representation is transferable, headline rates are not

A May 2026 Big 2 preprint compares PPO, Monte Carlo Q, SARSA, and Q-learning under the same setup. It uses visible public history and a variable legal-action set, and reports PPO ahead of those baselines within its budget. It does not compare with search-augmented or opponent-modeling agents, and its multiplayer self-play results are not Balatro evidence. [Paper](https://arxiv.org/html/2605.28863v1).

Mahjax (May 2026) implements vectorized Riichi Mahjong in JAX and demonstrates GPU-parallel simulation. Its reported throughput uses eight A100s and is specific to that implementation and game. [Paper](https://arxiv.org/abs/2605.20577).

**Application:** encode the content of each legal action, not an arbitrary action index with changing meaning. Card identities, order, selected subsets, phase, and Joker interactions matter. Mahjax supports investing in efficient environment execution, but it does not provide a reusable Balatro engine or predict our throughput. Neither source establishes that a particular PPO configuration solves full Balatro.

### Imitation to RL: refresh experience before aggressive optimization

WSRL (ICLR 2025; preprint December 2024) studies the transition from offline pretraining to online RL. It collects fresh experience with the pretrained policy before fine-tuning; its experiments show that this warmup can reduce the initial distribution-shift problem without retaining the whole offline dataset. The experiments use continuous-control/robotics tasks and SAC-family training, not PPO card-game agents. [Paper](https://arxiv.org/html/2412.07762v1), [official code](https://github.com/zhouzypaul/wsrl).

**Application:** first clone a competent teacher, then collect current-policy trajectories and fit/calibrate the critic before large policy changes. Revisit learner-induced mistakes rather than endlessly replaying only successful teacher games. Keep teacher data for supervised auxiliary updates if useful, but do not insert arbitrary old trajectories into a nominally on-policy PPO objective. The official TorchRL PPO tutorial reuses each newly collected batch for several optimization epochs and then refreshes it. [PPO tutorial](https://docs.pytorch.org/rl/main/tutorials/coding_ppo.html).

## Chess and StarCraft analogies, with their limits

AlphaZero supplies the policy/value-plus-search template, and MuZero supplies learned decision-relevant dynamics. Chess's fully visible deterministic position does not justify searching Balatro with privileged future draws. Use chance sampling and a visible-information belief state instead. [DeepMind's primary overview](https://deepmind.google/research/alphazero-and-muzero/).

AlphaStar is an older reference, not a 2025 breakthrough. Its useful lessons are structured entity inputs, imitation before RL, and training from game outcomes. AlphaStar Unplugged (2023) further studies offline RL in a partially observable, long-horizon game. The released repository is tested on Python 3.9/Linux, not this Windows/PyTorch stack. Opponent leagues and Nash mixtures address competitive play; they are unnecessary for single-player Balatro. [AlphaStar account](https://deepmind.google/blog/alphastar-mastering-the-real-time-strategy-game-starcraft-ii/), [Unplugged paper](https://arxiv.org/abs/2308.03526), [official repository](https://github.com/google-deepmind/alphastar).

Similarly, cooperative multi-agent value decomposition is not automatically appropriate for splitting one player's shop, discard, and play decisions. They are coupled decisions of one agent. Shared representations with phase-specific heads or multiple prediction horizons are a more direct initial design. This is an architectural recommendation, not a claim of a published Balatro result.

## Concrete architecture and credit-assignment proposal

These are starting hypotheses to compare, not fixed optimum hyperparameters.

1. **Observation encoder:** entity embeddings for playing cards, Jokers, consumables, offers, and public run state; retain positional information wherever ordering affects outcomes. Include deck/stake/challenge settings and all observable counters. Normalize ordinary counts and use signed-log transforms for extreme numeric features. Do not truncate valid Joker/card states silently.
2. **Action head:** phase/type selection followed by conditionally masked targets, card subsets, and ordering choices, or a shared scorer over complete legal candidates. A sampled candidate set must be logged as an approximation; it must not silently remove strategically important legal choices.
3. **Memory:** a recurrent core or compact causal event transformer over meaningful decisions. Test roughly 5–20M parameters first against a smaller control, then expand toward 50–100M only if the learning curves and batched GPU utilization justify it. These ranges are design choices, not measured capacity requirements. The model should be free to grow if it continues buying useful learning.
4. **Value:** predict eventual run success and optional blind/ante survival at distinct horizons. Keep diagnostics for calibration and outcome prediction, not only policy loss. A binary final outcome makes the main target bounded; raw chip magnitude should not dominate it. Auxiliary score/economy targets need explicit weighting and ablation.
5. **Temporal targets:** keep complete episode outcomes and contiguous sequence training. Bootstrap across rollout chunk boundaries, but not true terminal loss/win. If the objective is undiscounted run win rate, evaluate gamma=1 as a baseline; gamma=0.99 makes a reward 500 decisions away worth only about 0.0066 of its immediate value. A small discount per UI action can accidentally reward shorter runs. Sequence length, TD horizon, GAE lambda, and memory retention are different controls.
6. **Curriculum:** cover all phases and both failed and successful runs; retain broad starting-state diversity while increasing difficult stakes/challenges only when the agent can learn there. Keep the actual target setting in training throughout any curriculum. Teacher/search actions must use the visible-information contract.
7. **Search:** begin at costly shop choices, discards, consumable use, and uncertain blind outcomes. Sample multiple possible futures, batch leaf evaluation on the GPU, compare a modest candidate set, and log added latency. Distill improved choices. Search depth and sample count are experiment variables rather than promises of monotonic gains.

Memory probes should distinguish remembering a publicly seen card or purchase from predicting an unrevealed random outcome. Counterfactual tests should ask whether changing money, a Joker, a known boss, or remaining discards changes the policy sensibly. Such checks can expose representation errors before a large training run.

## RTX 5090 precision and memory decisions

| Choice | Recommendation for this project | Reason and limitation |
|---|---|---|
| BF16 mixed precision | First GPU training configuration | Apply autocast to supported dense/attention work; retain FP32 optimizer master state and sensitive probability/value calculations. Validate against an FP32 reference batch. |
| FP16 mixed precision | Fallback experiment | Same two-byte storage as BF16 but smaller exponent range; requires careful gradient scaling. FP16's largest finite value is 65,504, unsuitable for untransformed large game scores. |
| FP8 | Later, only if large GEMMs dominate | Specialized quantization/scaling recipes and software support are required. Conversion overhead and reduced precision can erase gains for small batches; it does not make all training state one byte. |
| FP4 / NVFP4 | Do not use as the initial training path | Hardware marketing and inference capability do not establish a supported training implementation on this GPU. |

PyTorch's AMP recipe explicitly warns that small, CPU-bound networks may not speed up and recommends avoiding excessive synchronization and many tiny GPU operations. The choice here remains GPU training; the response to an undersupplied GPU is to improve batching/production and measure useful scale. [AMP recipe](https://docs.pytorch.org/tutorials/recipes/recipes/amp_recipe.html), [versioned AMP documentation](https://docs.pytorch.org/docs/2.8/amp.html).

RTX 5090 has compute capability 12.0. The reviewed Transformer Engine 2.19 NVFP4 page lists **training on SM10.0/10.3**, while separately listing inference on SM10.0+. TorchAO 0.17's current workflow table lists stable rowwise FP8 training for H100/B200, prototype MXFP8 training for B200, and NVFP4 training as planned. These are reasons to verify exact support, not infer it from the word Blackwell. No installation is recommended for the first experiment. [NVIDIA GPU capabilities](https://developer.nvidia.com/cuda/gpus), [Transformer Engine NVFP4](https://docs.nvidia.com/deeplearning/transformer-engine/features/low_precision_training/nvfp4/nvfp4.html), [TorchAO workflow matrix](https://docs.pytorch.org/ao/stable/workflows/index.html).

Keep masked logits, log probabilities, importance ratios, entropy reductions, return/advantage computation, and main loss accumulation in FP32 initially. BF16 should not be used as a substitute for sound feature scaling or reliable reward definitions. Compare invalid-action counts, nonfinite values, gradients, and policy outputs against an FP32 reference before relying on it.

Model weights are only part of memory. A rough FP32 Adam accounting is 16 bytes per parameter for weights, gradients, and two moments: 20M parameters imply about 320MB before activations, temporary buffers, extra model copies, and allocator overhead. This arithmetic does not predict peak VRAM. Long sequences, entity attention, replay, and multiple actor copies can dominate.

- Store bounded, contiguous typed observations/actions/masks/rewards and episode metadata; avoid retaining entire Python engine graphs for every transition. Keep a separate, bounded state cache only where exact search/reanalysis requires it.
- Run collection inference without autograd. Avoid one process-local model copy per simulator worker where a central batched inference service suffices. Benchmark worker counts and avoid CPU thread oversubscription.
- Batch host-to-device transfers. Pinned buffers/nonblocking copies require measurement; pinning each batch synchronously in the main thread can be slower. [PyTorch transfer guide](https://docs.pytorch.org/tutorials/intermediate/pinmem_nonblock.html).
- Use `zero_grad(set_to_none=True)` where compatible. Activation checkpointing saves activation memory by recomputing; apply it only when the measured memory constraint warrants that cost. [PyTorch tuning guide](https://docs.pytorch.org/tutorials/recipes/recipes/tuning_guide.html).
- Consider compilation only for stable tensor kernels after the eager GPU path works. Track cold-start cost, recompiles, and end-to-end throughput. Dynamic Python engine objects are not the intended compilation target. [Compilation caching guidance](https://docs.pytorch.org/tutorials/recipes/torch_compile_caching_tutorial.html).

## Experiment order and qualification gates

The simulator remains a prerequisite. Jackdaw at the pinned commit `92df18c27e26e6d324132942905e41242e4e24bf` is a candidate, not a declaration of retail parity. Its author reports extensive live/offline validation but documents remaining RNG/pool issues. Confirm that the selected API exposes the requested stake/challenge and complete legal actions; the convenience Gym wrapper's action/card-combination caps are material. [Repository](https://github.com/TylerFlar/jackdaw-balatro), [author's validation discussion](https://tylerflar.com/projects/jackdaw/).

1. Establish a reproducible GPU BF16 learner, exact visible observations, complete legal-action contract, and an FP32 correctness reference. Measure simulator, encoding, transfer, inference, backward, and evaluation time separately.
2. Train an entity policy/value baseline using teacher/search data when available. Evaluate on unseen seeds in the exact target deck/stake/challenge; do not optimize only teacher agreement.
3. Add contiguous-memory PPO fine-tuning with fresh rollouts and calibrated terminal-value targets. Compare equal elapsed-time and equal environment-step budgets. Keep a held-out test set separate from model-selection seeds.
4. Test selective simulator planning plus distillation, then model size, memory length, and one auxiliary objective at a time. Compare plan-assisted and policy-only play separately.
5. Attempt learned dynamics, replay-heavy off-policy learning, learned options, or compressed-memory transformers only when a diagnosed bottleneck justifies them. A BF16 larger model is a reasonable experiment; an unmeasured low-bit stack or a wholesale algorithm rewrite is not an efficiency result.

Record full-run win rate with uncertainty, invalid/incomplete-run rate, survival by ante, and elapsed training/inference cost. Evaluate multiple training seeds when feasible. Claiming improvement requires the same mechanics, information access, deck/stake/challenge, and held-out evaluation protocol. None of the cited papers establishes a Balatro win rate, and the public fruit-fly claim remains insufficiently specified for a Gold Stake or Jokerless comparison.

## Current scope update: Red/Gold, new stickers, and fidelity before scale

The user's specialized target is now Red Deck / Gold Stake with observed Perkeo/Yorick openings, maximizing **new distinct Gold stickers per started run**. The authorized public objective snapshot contains 59 complete and 91 missing identities; Perkeo, Yorick, Blueprint, Brainstorm and Burnt are already complete. A binary win target or rewards for those anchor identities alone would optimize the wrong objective. Use the frozen observed missing mask for the main target and identify synthetic augmentations separately. [Award objective audit](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/development355/AWARD_OBJECTIVE_AUDIT.md).

The static audit found coupled expiration issues: ordinary expiry appears locally simple, but debuff alters candidate Wheel/Ectoplasm/Hex target pools and Swashbuckler scoring incorrectly; Negative, passive and rental representations add further boundaries. The operational decision is **keep the current expiry censors**, leave the frozen T02 run unchanged, and require a separately registered source-validation job before any relaxation. Source-worker budget remains zero. Increasing network size cannot fix mislabeled mechanics or absent trustworthy terminal outcomes.

The [perishable refinement report](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/development355/PERISHABLE_EXPIRY_REFINEMENT.md) provides a concrete next-check matrix: Burnt pre-discard/copy order; Perkeo event-pool/capacity/RNG order; expiry and blind-refresh effects; known exclusion counterexamples; exact original Gold award ownership/timing; and seeded/filtered/challenge eligibility. It also specifies a teacher bridge from current-version, fingerprint-matched advisor recommendations in authorized public journals, lossless action mapping, whole-run/seed splits, and separation of recommendations, observed behavior and verified outcomes. This is a better-grounded starting teacher than the prototype heuristic within the existing advisor's validated scope, without claiming global optimality or full-engine qualification.

These are future bounded validation/data tasks, not extra experiments launched by this research report. The currently authorized GPU run can supply optimization and throughput diagnostics; it cannot establish superiority over the existing advisor or actual sticker awards.
