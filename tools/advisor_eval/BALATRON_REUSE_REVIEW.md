**Balatron reuse and RTX 5090 feasibility — 2026-09-10**

The deterministic update was deployed first: v2.13.0-alpha, 13 installed Lua
files verified against the tested source, configuration hash preserved, with
backup `advisor-20260910-140432` in the installed mod's `deployment-backups`.
All 15 Lua fixtures and 15 benchmark-protocol tests passed. The update loads
at the next normal game restart. No running game was manipulated.

This investigation is read-only research. No training, dependency installation,
downloaded-code execution, GPU workload, or supervisor launch was performed.
The existing continuation remains focused on deterministic improvements.

**Recommendation:** reuse selected Balatron components and investigate an
existing native simulator before building one. The highest-value optimization
is fast, accurate experience collection. FP8/FP4 is a later, measured choice.
Balatron does not supply an already strong challenge-playing checkpoint.

The Balatron source inspected was commit
[`f91a948bb6075390a361d9d7e37c4ff4c42ceb3d`](https://github.com/jarmstrong158/Balatron/tree/f91a948bb6075390a361d9d7e37c4ff4c42ceb3d),
dated August 12, 2026. Its July 30 development report records 5 wins in a
600-seed White Stake evaluation (0.83%), versus 1% for the earlier baseline.
This is the author's historical evaluation, not a benchmark reproduced here
or an assertion about every later revision. It is far below the requested
75% on every challenge. [Reported evaluation](https://github.com/jarmstrong158/Balatron/blob/f91a948bb6075390a361d9d7e37c4ff4c42ceb3d/DECISIONS.md#L1987-L2034).

| Component | What is already present | Reuse assessment |
|---|---|---|
| Training | PPO, separate policy/value trunks, phase heads, Joker attention, imitation mechanisms | Useful starting code; learning quality still needs work |
| Collection | Concurrent live Balatro instances through HTTP/JSON-RPC | Replace the live-game transport/presentation bottleneck for high throughput |
| Tactics | Hand scoring, targeting, order heuristics, strategic planning | Borrow narrowly and compare against the original game |
| Precision and execution | CPU FP32 defaults, NumPy buffers, tensor conversion in minibatch loops | No active BF16/FP8/FP4 autocast, compile, GPU-buffer or CUDA-graph path found in the inspected training code |
| Checkpoints | Save, resume and partial shape migration | No published weights found to resume today |
| Challenges | Normal/recovery starts hardcode Red Deck and White Stake | Rules, observations, actions and reward objective need adaptation |

The current collector gathers environment tasks concurrently, then updates
the policy synchronously. Buffers are preallocated, but update minibatches
are repeatedly converted from NumPy to tensors. These are concrete places to
optimize once environment stepping is fast. [Collector](https://github.com/jarmstrong158/Balatron/blob/f91a948bb6075390a361d9d7e37c4ff4c42ceb3d/training/train.py#L647-L658),
[buffer/update path](https://github.com/jarmstrong158/Balatron/blob/f91a948bb6075390a361d9d7e37c4ff4c42ceb3d/agent/ppo.py#L138-L159),
[minibatches](https://github.com/jarmstrong158/Balatron/blob/f91a948bb6075390a361d9d7e37c4ff4c42ceb3d/agent/ppo.py#L512-L541).

Balatron's README contains an older 5,000 steps/hour description and a
three-instance measurement of 433 steps/minute (25,980/hour). These describe
different reported configurations; neither is a 5090 measurement. Faster
network arithmetic alone cannot remove waiting for live game actions.
[Throughput descriptions](https://github.com/jarmstrong158/Balatron/blob/f91a948bb6075390a361d9d7e37c4ff4c42ceb3d/README.md#L334-L396).

Continuing an existing model is technically possible. A faster environment,
batching or BF16 does not inherently invalidate learned weights if observation
and action meanings remain identical. However, no tracked weights or linked
checkpoint downloads were found; the only release contains a win video.
The repository explicitly ignores checkpoints and its local 54 MB baseline.
[Ignored artifacts](https://github.com/jarmstrong158/Balatron/blob/f91a948bb6075390a361d9d7e37c4ff4c42ceb3d/.gitignore),
[release](https://github.com/jarmstrong158/Balatron/releases/tag/the-win).

If weights become available, preserve compatible encoders/trunks and explicitly
map any changed inputs or outputs. The loader restores full state for matching
models and reuses compatible tensors on shape changes, but padding columns is
not a semantic remapping. Adding slots shifts the meaning of subsequent input
fields and target indices. With changed challenge rewards, restarting optimizer
state and recalibrating the value head may be appropriate; this requires an
experiment, not an assumption that loading succeeded means transfer succeeded.
[Checkpoint implementation](https://github.com/jarmstrong158/Balatron/blob/f91a948bb6075390a361d9d7e37c4ff4c42ceb3d/agent/ppo.py#L862-L959).

Challenge adaptation is more than adding a challenge ID. The current 850-feature
encoder has fixed capacities of five Jokers, two consumables, three shop cards
and twelve hand cards. Its projected economy adds normal interest and blind
rewards unconditionally: those are false income features for Omelette. Action
legality also contains a fixed five-Joker limit. Challenge modifiers, variable
capacity, pinned/eternal restrictions and the fastest-completion objective need
explicit representation. [Encoder layouts](https://github.com/jarmstrong158/Balatron/blob/f91a948bb6075390a361d9d7e37c4ff4c42ceb3d/environment/game_state.py#L35-L98),
[economy](https://github.com/jarmstrong158/Balatron/blob/f91a948bb6075390a361d9d7e37c4ff4c42ceb3d/environment/game_state.py#L1133-L1177),
[action limits](https://github.com/jarmstrong158/Balatron/blob/f91a948bb6075390a361d9d7e37c4ff4c42ceb3d/environment/action_space.py#L1289-L1298).

Its MIT license permits reuse with the copyright and permission notice retained
in copies or substantial portions. No upstream code was incorporated in this
pass. [License](https://github.com/jarmstrong158/Balatron/blob/f91a948bb6075390a361d9d7e37c4ff4c42ceb3d/LICENSE).

Our seed-search engine contributes useful pieces, but it cannot simply become
a training environment. `Immolate/src/instance.hpp` and `functions.hpp` supply
RNG streams, pool locks and item generation. The timeline in `immolate.cpp`
tracks selected acquisitions and Invisible Joker age; it assumes blinds have
been completed and does not score hands or pay purchase costs. Lines 3900–3904
explicitly reject `Challenge_Deck`. Its hundreds of millions/billions of seeds
per second measure narrow opening predicates, not game actions or episodes.
The diagnostic CUDA opening gate was slower than the CPU implementation for
that measured workload. See the local
[seed-search measurements](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/Immolate/build-contrarian-seed-cracking-20260806/REPORT.md).

Use Immolate as an RNG/generation parity reference and, where compatible, as a
native implementation of those components. Keep a faithful full-game engine
for scoring, money, triggers, deck changes, bosses and terminal outcomes.
Our original-Lua adapter is a promising oracle/initial environment, but it is
not fully qualified. Its timings include the advisor's expensive search—up to
195,000 score evaluations per decision—so they cannot establish raw environment
throughput. A trained policy should not need to repeat that entire teacher
search on every training step. [Current adapter evidence](C:/Users/trevo/Documents/GitHub/Brainstorm-Rerolled-Rerolled/tools/advisor_eval/engine_probe_report.md).

A relevant alternative already implements much of the desired systems work:
[jahankazimi078/balatroagent](https://github.com/jahankazimi078/balatroagent).
Its author reports approximately 10,200 end-to-end steps/second on a contended
RTX 4070, using a Rust vector environment, BF16, compilation, GPU buffers,
pinned staging and fused Adam. That is not independently reproduced, does not
establish challenge strength, and is not a speed prediction for this machine.
Its documented action contract still lacks Joker ordering, clamps selectable
hands to ten cards, and automatically supplies pack-consumable targets.
These conflict with requirements of this advisor and must be addressed.
[Training and limitations](https://raw.githubusercontent.com/jahankazimi078/balatroagent/master/train/README.md),
[performance configuration](https://raw.githubusercontent.com/jahankazimi078/balatroagent/master/train/configs/m3_fast.yaml).
Its run initialization is also designed around Red Deck/White Stake.
[Run source](https://raw.githubusercontent.com/jahankazimi078/balatroagent/master/sim/core/src/run.rs).

For the 5090, use this optimization order:

1. Validate a persistent headless reset/step environment, then measure engine,
   observation encoding, inference and update time separately.
2. Batch many independent runs; use compact card IDs/flags and contiguous
   arrays instead of repeated JSON/object reconstruction. Keep game arithmetic
   and RNG at the precision required for rule parity.
3. Keep rollout tensors on the GPU where useful, batch inference, use fixed
   tensor shapes, compile the learner and remove redundant transfers.
4. Establish an FP32 reference, then compare BF16 training while retaining
   sensitive probability/loss arithmetic in FP32.
5. Try FP8 only when matrix multiplication is a measured bottleneck; treat FP4
   as an additional numerical experiment, not an automatic multiplier.

The RTX 5090 is SM120, which differs from B200's SM100. Native low-precision
hardware exists, but training-kernel support varies. Transformer Engine v2.18
permits ordinary FP8 on SM120 while rejecting its MXFP8 training recipe there;
NVFP4 availability is not categorically excluded, but complete forward/backward
operator support must be checked. TorchAO documents that quantization overhead
can slow small matrix shapes. [NVIDIA hardware table](https://developer.nvidia.com/cuda/gpus),
[versioned precision support](https://github.com/NVIDIA/TransformerEngine/blob/v2.18/transformer_engine/pytorch/quantization.py#L136-L236),
[quantized training performance](https://docs.pytorch.org/ao/stable/workflows/training.html#performance).

Efficient samples also matter: retain exact tactical rules/search, learn
long-horizon build/economy value, and use imitation plus a challenge-balanced
curriculum. Optimize expected time to success, including failed attempts, and
evaluate all twenty challenges independently on fresh seeds. This is my design
recommendation, not a claim that more training will necessarily overcome the
current policy's limitations.

The following is conditional arithmetic, not a measured training budget or
prediction of the samples needed to reach 75%:

| Sustained complete training pipeline | 100 million transitions | 1 billion transitions |
|---|---:|---:|
| 1,000 transitions/second | 27.8 hours | 277.8 hours |
| 10,000 transitions/second | 2.8 hours | 27.8 hours |

These are approximate machine allocation hours before setup and independent
evaluation; active GPU compute time may be lower. The relation is
`hours = transitions / (3600 × measured end-to-end transitions/second)`.
Do not multiply a transitions/second figure by a raw GPU-TFLOPS ratio.

My rough engineering planning allowance is several days to port useful isolated
ideas, roughly 2–6 weeks for a credible fast challenge-aware training/evaluation
prototype, and potentially 1–3 months or longer for a serious attempt at high
performance across all twenty challenges. These are uncertain effort estimates,
not delivery commitments. Once that infrastructure works, tens to a few hundred
5090 allocation hours across multiple experiments is a plausible planning
budget. Neither the sample requirement nor a 75% per-challenge outcome is known.

The immediate next research step would be a source/parity and throughput audit
of the native simulator candidate against our original-game oracle. It could
save substantial implementation effort. It should precede committing to a new
simulator or investing in FP4 kernels. No model work was started by this review.
