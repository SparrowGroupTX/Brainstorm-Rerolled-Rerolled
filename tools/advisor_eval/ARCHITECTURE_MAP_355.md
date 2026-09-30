# Navigation after learning prototype 355

Installed runtime architecture and all earlier component maps remain in
`ARCHITECTURE_MAP_354.md` and its referenced map281. Runtime remains2.154.0-alpha.

| Component | Source | Checks / evidence |
|---|---|---|
| Public simulator wrapper, explicit concrete candidates, win latch | `tools/advisor_learning/environment.py` | `test_environment.py`; source omissions in package README |
| Source-grounded simulator repairs and unsupported boundaries | `tools/advisor_learning/simulator_patches.py` | `test_simulator_patches.py`; `development355/SIMULATOR_FIDELITY_AUDIT.md` |
| Candidate-conditioned entity model, catalog embeddings, ordered selected cards | `tools/advisor_learning/model.py` | `test_model.py` |
| PPO collector, CUDA training, bounded process workers | `tools/advisor_learning/train.py` | `test_collector.py`; frozen job configuration, actions, episodes, metrics and summaries |
| Terminal/censor-aware generalized advantages | `tools/advisor_learning/gae.py` | `test_training.py` |
| Weak public teaching/comparison baseline | `tools/advisor_learning/heuristic.py` | Wrapper checks; S01/V01 evidence |
| Public collection conditioning and distinct award objective | `tools/advisor_learning/objective.py` | `test_objective.py`; `development355/AWARD_OBJECTIVE_AUDIT.md` |
| Constructed Red/Gold Perkeo/Yorick post-Soul scaffold | `tools/advisor_learning/specialized_environment.py` | `test_specialized_environment.py`; `SPECIALIZED_DATA_AUDIT.md`; not source-seed equivalent |
| Explicit actor migration, reset value head | `tools/advisor_learning/migration.py` | `test_migration.py`; `jobs/T02/migration.json` |
| Censor-aware offline cohort analysis | `tools/advisor_learning/analyze.py` | `test_analysis.py`; `jobs/V02/analysis.json`; `jobs/V03/analysis.json` |
| One-use freeze/cap/receipt launcher | `tools/advisor_learning/experiment.py` | `development355/EXPERIMENT_355.json`; `jobs/*/receipt.json` |
| Numerical GPU preflight | `tools/advisor_learning/hardware_probe.py` | `jobs/P01/hardware.json` |
| Pinned third-party download, license and hashes | `development355/fetch_simulator.py`; `external/` | `external/provenance.json`; no upstream file edits |
| Runtime fingerprints | `development355/record_runtime.py` | `runtime_provenance.json` |
| Modern game-learning and precision research | `development355/MODERN_GAME_LEARNING.md` | Linked primary papers and official docs |
| Failed specialized learning/postmortem and next curriculum | `development355/SPECIALIZED_POSTMORTEM.md`; `V02_LEARNING_REVIEW.md`; `SPARSE_REWARD_NEXT.md` | Preserved actions/episodes; separate hypotheses from demonstrated results |
| Final selection and closed experiment accounting | `development355/FINAL_POLICY_SELECTION.json`; `close_experiment.py` | `CLOSED.json`; `final_verification.json`; `SESSION_RESET_355.json` |

No product import, live RPC/bridge, installation, native binary change, player
profile/save access or source executable worker is part of this prototype.
Manufactured unit tests never initialize complete simulator episodes. Actual
episodes required the registered experiment launcher. All355 jobs and unused
capacity are now closed; these files confer no continuing experiment authority.
