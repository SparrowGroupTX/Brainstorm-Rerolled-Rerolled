# Development 355 baseline and teacher postmortem

Date: 2026-09-16. Scope: read-only analysis of completed S01/V01 action and episode receipts, and frozen T01 wrapper/heuristic/trainer code. This audit executed no episodes, source-policy runs, training, or replay. It changes no runtime code. T01 was running from its frozen package when this report was prepared; this report makes no claim about its results.

The baseline reaches some later blinds, but its shop, consumable, and discard rules are weak supervision. Applying its labels with fixed weight at every learner state teaches those limitations as well as basic legal progress. The strongest observed interruption is the explicit perishable fidelity boundary, which must remain separate from actual losses. Neither the logs nor this static audit establishes which alternative purchases or discards would have won.

## Recorded results

Both completed jobs used the deterministic public-tensor heuristic on Red Deck / Gold Stake. The simulator remains unqualified against retail; these are offline development trajectories, not a player win-rate estimate.

| Receipt | S01 | V01 |
|---|---:|---:|
| Recorded transitions | 10,000 | 1,207 |
| Episodes started | 265 | 32 |
| Actual terminal wins | 0 | 0 |
| Actual terminal losses | 175 | 21 |
| Unsupported episodes | 83 | 11 |
| Unfinished at job stop | 7 | 0 |
| Highest observed ante | 4 | 3 |
| Highest verified blinds cleared | 10 | 8 |
| Mean verified blinds cleared, all starts | 3.842 | 3.844 |
| Coordinator elapsed seconds | 17.375 | 2.188 |
| Recorded transitions / second | 575.54 | 551.65 |

Unsupported reasons were `fidelity_perishable_expiry_order` for 82 of S01's 83 unsupported episodes and all 11 V01 unsupported episodes. The remaining S01 episode stopped at `candidate_capacity_exceeded`. The seven S01 unfinished episodes are job-stop censoring, not additional simulator losses. No win-rate confidence interval is warranted with these censored episodes.

Actual loss ante counts were S01: 66 at Ante 1, 94 at Ante 2, 12 at Ante 3, and 3 at Ante 4; V01: 9, 11, and 1 at Antes 1–3. The perishable boundary stopped S01 episodes at Ante 2 (38) or Ante 3 (44); the capacity episode ended at Ante 2. These early interruptions materially limit long-horizon evidence.

| Selected action | S01 | V01 |
|---|---:|---:|
| Play | 3,295 | 406 |
| Discard | 2,224 | 264 |
| Select blind | 1,280 | 155 |
| Cash out | 1,018 | 123 |
| Leave shop | 1,017 | 123 |
| Buy card | 920 | 112 |
| Use consumable | 117 | 11 |
| Open booster | 63 | 6 |
| Pick pack card | 64 | 6 |
| Skip pack | 2 | 1 |
| Sell Joker / consumable, reroll, buy voucher, skip blind, reorder, sort | 0 | 0 |

S01 discard sizes were 10 two-card, 310 three-card, 816 four-card, and 1,088 five-card selections; V01 had 40 three-card, 95 four-card, and 129 five-card selections. Neither job selected a one-card discard. These frequencies are consistent with the rule that maximizes the number discarded outside the chosen current best hand; they do not establish that large discards were wrong in the individual states.

Final cash among actual losses averaged $4.18 in S01 and $5.52 in V01; 100/175 and 12/21 loss endpoints respectively had less than $5. This is endpoint cash, not a purchase history or causal evidence of overspending. There were 37 S01 and 8 V01 plays with zero ordinary base-score feature. Zero can mean concealed identity or a limitation of the public estimate; it is not proof that the simulator scored zero.

## What the teacher structurally teaches

The following conclusions come from the frozen heuristic, with action frequencies used only where they directly corroborate behavior.

1. **Fill slots with approximately valued Jokers, then keep them.** An affordable non-rental Joker receives a positive base purchase value of 4, plus a few numeric ability fields, minus 2 for a perishable sticker. Most such candidates beat leaving the shop even when their utility is unknown. Cash cost affects affordability, but does not enter the marginal value except for a rental reserve rule. Sale actions receive no positive score. The observed 920/112 purchases and zero sales confirm the resulting action pattern, but the receipts do not identify individual Jokers or prove a particular bad purchase. This also prevents deliberate retirement of perishables before the supported fidelity boundary; those censored trajectories are not losses.

2. **Use a short, incomplete hand estimate.** The play ranking starts from ordinary visible poker base chips × mult and adds generic visible Joker chips/mult. It omits owned Joker XMult, most conditional effects, copy/order effects, held-card effects, editions, enhancements, seals, and boss effects. Public debuffed Jokers are not filtered from the generic sum. The observation itself lacks some conditional ability fields, including a dedicated `t_mult` scalar. A learned policy can use other represented public features, but imitation penalizes departure from this limited ranking. The baseline's intended fewer-card tie-break is applied when finding the retained hand for discard reasoning, then is lost when raw estimates are assigned to all play scores before the final argmax. This is a static tie-breaking inconsistency, not a demonstrated cause of any loss.

3. **Keep the current best subset and discard its complement when behind an average pace.** Discarding is considered if the current best estimate is less than remaining blind chips divided by remaining hands. It retains that currently best play and chooses the largest legal complementary discard, with a low discarded-base-score tie-break. There is no valuation of competing retained draws, probability of improvement, discard-trigger effects, or survival over the remaining decisions. The large-discard frequencies above follow this rule. This is too narrow to treat as expert discard supervision.

4. **Prefer Planet use and make weak pack choices.** Planet use receives score 100,000, a strong default preference that can be exceeded by an unusually large estimated play. The heuristic does not value holding a Planet for Observatory/Perkeo or future choice. Non-Planet consumable use receives no preference at all. All non-Joker/non-Planet pack picks receive the same score of 1, leaving the first enumerated eligible card/target to win the tie. These are mechanical defaults, not judgments of consumable effect or target quality.

5. **Avoid whole strategic action families.** Reroll, Joker/hand reorder, sorting, blind skipping, and sales stay at the default score of −1,000,000 when ordinary progress actions are present. Both batches selected none. Voucher purchase is implemented only with a $20 reserve after cost, but occurred zero times. This avoids loops in the baseline while providing no useful teaching for those decisions. A fixed imitation objective makes it harder for a learner to explore them on its own.

6. **Treat unknown estimates as numerical ties.** Concealed card identity is intentionally excluded from the model and base-score estimate. The heuristic has no uncertainty policy beyond deterministic ties. A zero estimate or partial visibility should therefore not be interpreted as a high-confidence teacher label.

## What T01's auxiliary objective means

The frozen T01 configuration uses a constant imitation weight of `0.3`. At learner-visited states, the trainer calls `heuristic_index(observation)` and adds cross-entropy against that one label to the PPO/value/entropy loss. There is no phase restriction, confidence gate, or decay of the coefficient. This is supervision on the learner's own state distribution, not just cloning the S01/V01 trajectories.

The trainer excludes the unsupported/error/censored transition itself from eligible training rows. Valid prefixes before a later unsupported state can still be training data; these are partial trajectories, not complete success evidence. The policy also receives the separate progress-shaped objective. Its existence does not make the teacher expert supervision, and the numeric coefficient alone does not show whether imitation dominates PPO gradients.

A clear risk is copying the teacher's no-sale shop policy, indiscriminate positive Joker values, coarse consumable choices, and current-hand-only discard rule. Static code and these logs establish the label behavior; they do **not** establish that removing imitation improves trained results, that imitation caused any T01 failure, or that the eventual learned policy exactly follows its teacher.

## Proposed T02 successor pilot

An initial root proposal for the next finite job was a combined continuation from T01 weights: reduce imitation weight from `0.3` to `0.1`, retain imitation only in hand selection when the teacher chose a **play** action, and train on a 50% White Stake / 50% Gold Stake curriculum. Subsequent user steering superseded the White curriculum: specialize on Red Deck / Gold Stake with the provided Perkeo/Yorick seeds and maximize new Gold stickers per run. The mixed-stake discussion below records the rejected proposal's limitations; it is not authorization or the current training plan. This audit ran no successor experiment.

This removes teacher supervision for purchases, sales, pack choices, consumable use, and discards, while retaining a modest hand-play preference. Play labels still have the omissions listed above. A minimal additional confidence gate should reject labels whose selected-card visible count differs from selected-card count, or whose ordinary base estimate is zero. A stronger source-grounded gate would limit teaching to wholly visible ordinary-card situations without relevant Joker, boss, edition, enhancement, seal, or held-card interactions; that is narrower and requires explicit implementation/verification rather than assuming that visibility alone proves scoring fidelity.

The existing public stake feature allows the policy to condition on the curriculum's stake. White Stake may provide longer supported trajectories and more success/progress examples; that is a hypothesis, not an observed benefit. Track stake-specific starts, actual outcomes, unsupported reasons, verified clears, and returns. Do not pool White results into a Gold success claim. Keep the perishable and all other fidelity boundaries unchanged for Gold; removing them to extend runs would conceal simulator uncertainty.

Because this successor changes both supervision and training distribution, and resumes weights already influenced by T01's teacher, a better later result would not isolate which change helped. It is a combined successor pilot, not an A/B proof. Retain frozen configuration/provenance, finite preregistered caps, separate seed namespaces, and Gold evaluation receipts. Do not reuse a development comparison to claim independent retail validation.

If a later question specifically concerns the effect of the auxiliary teacher, the smallest interpretable continuation would keep stake distribution and all other settings fixed while changing only its weight/gating. That would still need its own authorized finite comparison; this report does not create one.

## Minimum useful public audit data for a future job

The current action rows contain episode/step, selected candidate index and kind, target slots, candidate count, ordinary base-score feature, value, outcome, ante, verified clears, and elapsed time. They omit the public item identities/prices, hand descriptors, money trajectory, blind chips/target, alternative candidate descriptors, and separate teacher choice/confidence. Consequently this report cannot identify a particular wasteful purchase, discarded rank combination, sticker-retirement opportunity, or actual-score miss. Seed-based replay would be a new episode execution and was not used.

For a future registered run, a small bounded sample of decision rows should record: phase and stake; public cash and blind chips/target before/after; visible hand/inventory identities and stickers; chosen and teacher action descriptors; selected-card visibility and base estimate; the teacher-label eligibility decision; and a few compared public candidate estimates. Keep absent/concealed identities absent and exclude seed, RNG, hidden deck order, or engine-private targets from model inputs and teaching. Aggregate imitation coverage/loss by phase and chosen action kind, and retain per-reason censor counts. Such logging makes the next postmortem reviewable without needing replay or attributing a loss to an unobserved decision.

Do not select only successful prefixes for teacher data, relabel unsupported episodes as losses, or suppress fidelity censoring to obtain apparent longer trajectories. More ambitious teaching should use separately verified local mechanics labels, starting with neutral fully visible hand-ranking situations, rather than elevating the entire heuristic to an expert.

## Evidence identity

Paths are relative to this directory. SHA-256 values identify the reviewed receipts and frozen teacher/trainer, and do not confer simulator qualification.

| File | SHA-256 |
|---|---|
| `jobs/S01/summary.json` | `B23806E6EFD00768CC7BED3B727D163B20DDBD5B8C1E31F8E06F857FADDD908B` |
| `jobs/S01/actions.jsonl` | `CF98D13F59A130EFEB602DC1163F60A41E4C69CC792EF78B083004575B1A708F` |
| `jobs/S01/episodes.jsonl` | `D578B8DEAE3B5CBC916E773005B3E5B0FE62FDC4E0416370610C6C6336D0BC66` |
| `jobs/V01/summary.json` | `0CC145748E837FDADAEF1CD3C7BE08A0D7FA8CF0EA1A0C9504BEC02149D3385C` |
| `jobs/V01/actions.jsonl` | `CF0CBED4C64458517BA006D9C5DE3062CC605902CE84B3AD8ED232F185E82773` |
| `jobs/V01/episodes.jsonl` | `6318B9E62985B2EB5F0D650AB00AF34B5B57A9C9C6CCB363716A8E1D81BBCFF7` |
| `jobs/T01/frozen/tools/advisor_learning/heuristic.py` | `EC8E4704C8B83E4E3D7C2D6233A04A332F993DFA0F5A9A4842338D695BB466F7` |
| `jobs/T01/frozen/tools/advisor_learning/train.py` | `CBC71F2A6A780766A812F11944808F915F82AF5D1FDC65BA75C5FE6737EB3062` |
