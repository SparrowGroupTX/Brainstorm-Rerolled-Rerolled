# Suspect-decision review queue

Heuristic review hypotheses, not confirmed mistakes or win estimates.

6224 supplied events; 79 flags; 0 omitted by the ranked output cap.

| Rule | Flags |
| --- | ---: |
| Visible copy offer closed without acquisition | 0 |
| Visible Invisible Joker opportunity closed | 0 |
| Chosen Joker has lower recorded pack merit | 0 |
| Purchase after sale differs from its explicit plan | 0 |
| Fewer than five cards discarded | 65 |
| Round cleared with discards remaining | 13 |
| Durable engine sold without a structured funded continuation | 0 |
| Revealed free permanent Planet upgrade skipped | 0 |
| Non-Jupiter Fool stock retained with active Perkeo | 0 |
| Selected pack merit conflicts with complete opening-score evidence | 1 |

Review one example per family first; these are context groups, not established common causes.

| Rule | Context family | Count | Example action sequences |
| --- | --- | ---: | --- |
| short_discard | growth_present_five_unproved | 65 | 87, 195, 208 |
| pack_score_merit_conflict | pack_score_merit_conflict | 1 | 1822 |
| unused_discards_at_clear | growth_present_safety_unproved | 12 | 2584, 3089, 3283 |
| unused_discards_at_clear | final_boss_no_later_round_growth | 1 | 4735 |

Projected decision contexts, reasons, scope and exact segment/ordinal/hash anchors are in report.json.
Review missing-receipt, suppression and unconfirmed counts before interpreting coverage.

| Priority | Run | Action sequence | Rule | Flag ID |
| ---: | --- | ---: | --- | --- |
| 65 | 3 | 1822 | pack_score_merit_conflict | 46aaeb3c9d43704b859d |
| 40 | 3 | 2584 | unused_discards_at_clear | a16540df145932430970 |
| 40 | 3 | 3089 | unused_discards_at_clear | 5c26e548e01b96df8e32 |
| 40 | 3 | 3283 | unused_discards_at_clear | 997a993fb72ff8cd1e22 |
| 40 | 3 | 3421 | unused_discards_at_clear | feec106be7c0d42317da |
| 40 | 3 | 3571 | unused_discards_at_clear | 998c2882a983c9a39495 |
| 40 | 3 | 3740 | unused_discards_at_clear | eeb78288be50ef91875b |
| 40 | 3 | 3909 | unused_discards_at_clear | a3f1c55bee073fa5d123 |
| 40 | 3 | 4061 | unused_discards_at_clear | 184116ab9a99f2c6f2f3 |
| 40 | 3 | 4213 | unused_discards_at_clear | 3bc0b3c523e26b7cff16 |
| 40 | 3 | 4380 | unused_discards_at_clear | a228345ae0f531f5ec03 |
| 40 | 3 | 4583 | unused_discards_at_clear | 1f5619c45639e7df684c |
| 40 | 4 | 5154 | unused_discards_at_clear | e0eee96a36f3c42068b0 |
| 35 | 1 | 87 | short_discard | 96714ade2296275e832c |
| 35 | 1 | 195 | short_discard | 52fa2ef953ad816d5c70 |
| 35 | 1 | 208 | short_discard | 64c8a011146939433331 |
| 35 | 1 | 222 | short_discard | d90d2b8f8905983f260f |
| 35 | 2 | 350 | short_discard | 068e4f7444ebd541effb |
| 35 | 2 | 363 | short_discard | ba404041fdba399b8ae7 |
| 35 | 2 | 377 | short_discard | 7a8a34ccb8c3259394e8 |
| 35 | 2 | 468 | short_discard | 160eafeb7a688f3dd40f |
| 35 | 2 | 482 | short_discard | 08fbb8f27dca95a86723 |
| 35 | 2 | 495 | short_discard | 7c335650e830b706ba53 |
| 35 | 2 | 592 | short_discard | b94e393f661c14fe5cec |
| 35 | 2 | 663 | short_discard | 241e1a1b24a32f43dd74 |
| 35 | 2 | 690 | short_discard | d75acb3b591cc3afc56c |
| 35 | 2 | 785 | short_discard | 8d08e42a0f2e2f095aa6 |
| 35 | 2 | 798 | short_discard | a66b8d166af3a5b81063 |
| 35 | 2 | 811 | short_discard | cd76ad1394177a86d2c5 |
| 35 | 2 | 917 | short_discard | 5b8433ecc345976779dc |
| 35 | 2 | 946 | short_discard | 419258e6909717641bab |
| 35 | 2 | 1042 | short_discard | f7ead5319bdeb260f24e |
| 35 | 3 | 1345 | short_discard | 47ae604ac1cd9534f3af |
| 35 | 3 | 1358 | short_discard | 6d156ed228d646f9466a |
| 35 | 3 | 1427 | short_discard | ecef61e221d2a7e1f71c |
| 35 | 3 | 1440 | short_discard | 66763d0067d71d63deb2 |
| 35 | 3 | 1571 | short_discard | bbd9fce55e2ffe603e79 |
| 35 | 3 | 1584 | short_discard | d598b4850f85058b5dba |
| 35 | 3 | 1597 | short_discard | 08de149313217ccd08b5 |
| 35 | 3 | 1701 | short_discard | 2602a0f73b7a5b1a3500 |
| 35 | 3 | 1766 | short_discard | 12765130006ae8bbbf6e |
| 35 | 3 | 1883 | short_discard | 78c2f6175eb65e2f772f |
| 35 | 3 | 1897 | short_discard | 04f026cd76f9d376191f |
| 35 | 3 | 2147 | short_discard | 482d1773d86dc500e6be |
| 35 | 3 | 2174 | short_discard | eeadffc94ff8157235be |
| 35 | 3 | 2311 | short_discard | 6edf6cfbcf3e32198d7e |
| 35 | 3 | 2385 | short_discard | c539cbf3b53c3c53de54 |
| 35 | 3 | 2398 | short_discard | 0ec0edd381ec3ff150d6 |
| 35 | 3 | 2411 | short_discard | b67537e25d067f0e0866 |
| 35 | 3 | 2858 | short_discard | 3af14380b003b00094fb |
| 35 | 3 | 2871 | short_discard | ee201bd67aae69829206 |
| 35 | 3 | 3704 | short_discard | fa774033613e8e766925 |
| 35 | 3 | 4177 | short_discard | a6bf41ec063fd3bdd202 |
| 35 | 3 | 4345 | short_discard | 964626603619f2b89b38 |
| 35 | 3 | 4548 | short_discard | db91f6338b6e3dbe5328 |
| 35 | 3 | 4698 | short_discard | 6037c3dca2a662aabaa2 |
| 35 | 4 | 4846 | short_discard | 6181cd3325e86568af10 |
| 35 | 4 | 4962 | short_discard | bb3d4012f8740f67d816 |
| 35 | 4 | 4975 | short_discard | ed0529d0e2d1d55807af |
| 35 | 4 | 5002 | short_discard | da3676d8309e2f069ab3 |
| 35 | 4 | 5092 | short_discard | a808d1d6fbac39c2753a |
| 35 | 4 | 5200 | short_discard | bb15e5806c467db74d54 |
| 35 | 4 | 5215 | short_discard | b20e154d85ab058242dd |
| 35 | 4 | 5229 | short_discard | cb541b7ff3b9f9c3d337 |
| 35 | 4 | 5307 | short_discard | 54ba1bf055875fd39adf |
| 35 | 4 | 5322 | short_discard | 488b8ad0d406ee550094 |
| 35 | 4 | 5335 | short_discard | 2b4c90a1ca206d32dd6d |
| 35 | 5 | 5465 | short_discard | 4a45bdb08b9eaead3ae0 |
| 35 | 5 | 5478 | short_discard | ff6337e99142e9da4d62 |
| 35 | 5 | 5505 | short_discard | 2ef32e746c237bd3a6c9 |
| 35 | 5 | 5595 | short_discard | 45aa464b4e0240c53a61 |
| 35 | 5 | 5718 | short_discard | 85b006fc1388440063ad |
| 35 | 5 | 5731 | short_discard | 61b4046bbea9cee3baae |
| 35 | 5 | 5789 | short_discard | 8597ea982f12383abcff |
| 35 | 5 | 5803 | short_discard | 9de0d6f748412ed7b35c |
| 35 | 5 | 5816 | short_discard | e9080c6d7af6bdc97bf1 |
| 35 | 5 | 5906 | short_discard | 20791708968fd26b95b1 |
| 35 | 5 | 5920 | short_discard | 46f7d9561767c1975acc |
| 5 | 3 | 4735 | unused_discards_at_clear | e499d528fccb06bf8c8d |
