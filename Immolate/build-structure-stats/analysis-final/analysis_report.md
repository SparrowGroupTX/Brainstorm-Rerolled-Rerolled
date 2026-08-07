# Balatro seed-structure held-out analysis

## Pooled exact rates

- Charm rate: 6.666718750%
- Soul given Charm: 1.490850353% (theory 1.491026960%)
- Perkeo given Charm+Soul: 19.967139816% (theory 20%)
- judgement given Perkeo vs non-Perkeo: 18.2165982% vs 18.1665353%; RR 1.0028 (95% CI 0.9975-1.0080), p=0.301
- judgement_invisible given Perkeo vs non-Perkeo: 0.0454763% vs 0.0458858%; RR 0.9911 (95% CI 0.8833-1.1121), p=0.879
- telescope given Perkeo vs non-Perkeo: 6.2268524% vs 6.2432350%; RR 0.9974 (95% CI 0.9879-1.0069), p=0.589
- observatory given Perkeo vs non-Perkeo: 0.3858557% vs 0.3954665%; RR 0.9757 (95% CI 0.9380-1.0149), p=0.221
- Perkeo-opening rate across eight disjoint ranges: 0.0197764%-0.0199222%; heterogeneity p=0.688.

## Held-out ranking results (Charm+Soul+Perkeo)

The first four 500M ranges selected each ranking; the final four disjoint 500M ranges measured it. Lifts below are hit-rate lifts in the prioritized region, before any throughput penalty.

| Predictor | Held-out lift | 95% RR CI vs rest | Bonferroni p | Coverage |
|---|---:|---:|---:|---:|
| bucket / tag_seed_hash_256 | 1.0421x | 0.9680-1.1326 | 1 | 100.0% |
| intermediate / tag_seed_hash_16 | 1.0122x | 0.9544-1.0796 | 1 | 100.0% |
| bucket / prefix2 | 1.0060x | 0.9962-1.0173 | 1 | 100.0% |
| character / display_position_1 | 1.0041x | 0.9973-1.0131 | 1 | 100.0% |
| stride / id_mod_4 | 1.0030x | 0.9969-1.0113 | 1 | 100.0% |
| character / display_position_3 | 1.0021x | 0.9947-1.0105 | 1 | 100.0% |
| intermediate / seed_hash_16 | 1.0014x | 0.9417-1.0657 | 1 | 100.0% |
| bucket / id_mod_4096 | 1.0011x | 0.9909-1.0117 | 1 | 100.0% |
| stride / id_mod_4096 | 1.0011x | 0.9909-1.0117 | 1 | 100.0% |
| stride / id_mod_8 | 1.0010x | 0.9918-1.0106 | 1 | 100.0% |
| character / display_position_5 | 1.0009x | 0.9933-1.0090 | 1 | 95.2% |
| character / display_position_0 | 1.0009x | 0.9936-1.0087 | 1 | 100.0% |
| balanced_suffix / rightmost_character | 1.0005x | 0.9876-1.0138 | 1 | 100.0% |
| character / display_position_4 | 0.9991x | 0.9911-1.0068 | 1 | 100.0% |
| stride / id_mod_16 | 0.9989x | 0.9894-1.0082 | 1 | 100.0% |
| character / display_position_2 | 0.9986x | 0.9904-1.0061 | 1 | 100.0% |
| stride / id_mod_2 | 0.9982x | 0.9902-1.0026 | 1 | 100.0% |
| balanced_suffix / second_rightmost_character | 0.9981x | 0.9878-1.0076 | 1 | 100.0% |
| stride / id_mod_32 | 0.9979x | 0.9883-1.0071 | 1 | 100.0% |
| bucket / prefix3 | 0.9978x | 0.9871-1.0081 | 1 | 100.0% |
| balanced_suffix / rightmost_pair | 0.9975x | 0.9841-1.0104 | 1 | 100.0% |
| stride / id_mod_128 | 0.9973x | 0.9867-1.0073 | 1 | 100.0% |
| stride / id_mod_64 | 0.9949x | 0.9844-1.0042 | 1 | 100.0% |
| stride / id_mod_1024 | 0.9925x | 0.9814-1.0020 | 1 | 100.0% |
| stride / id_mod_256 | 0.9917x | 0.9806-1.0011 | 1 | 100.0% |
| stride / id_mod_512 | 0.9913x | 0.9801-1.0006 | 1 | 100.0% |
| bucket / seed_hash_256 | 0.9673x | 0.8886-1.0453 | 1 | 100.0% |

## Clustering and alternative enumeration

- Largest tested sequential-lag ratio for the Perkeo opening was lag 34: 0.8824x expected (139 observed vs 157.5 expected).
- Block 35: Fano 0.9997 +/- 0.0003; zero-block ratio 1.0000.
- Block 1225: Fano 0.9993 +/- 0.0015; zero-block ratio 0.9999.
- Block 4096: Fano 1.0005 +/- 0.0028; zero-block ratio 1.0002.
- Block 42875: Fano 0.9919 +/- 0.0092; zero-block ratio 0.6504.
- Block 65536: Fano 0.9969 +/- 0.0112; zero-block ratio 0.0000.
- Block 1048576: Fano 0.9794 +/- 0.0449; zero-block ratio 0.0000.
- One-character Hamming neighbors: 7387 observed vs 7373.3 expected; ratio 1.0019, z=0.16.
- Best transposed/Gray order selected on training blocks was transpose_120; held-out speedup 1.0160x, paired p=0.0689 (12-order Bonferroni p=0.827).
- Independent validation across the 2B/2B disjoint ranges selected transpose_021; held-out speedup 0.9905x, paired p=0.112 (12-order Bonferroni p=1).
- Independently held-out seed-evaluation time-to-first-hit for learned prefix rankings:
  - display_position_0: 1.0016x, Bonferroni p=1.
  - display_position_1: 1.0026x, Bonferroni p=1.
  - display_position_2: 1.0028x, Bonferroni p=1.
  - prefix2: 1.0021x, Bonferroni p=1.
  - prefix3: 1.0006x, Bonferroni p=1.
- Independently held-out seed-evaluation time-to-first-hit for learned stride rankings:
  - id_mod_2: 1.0027x, Bonferroni p=1.
  - id_mod_4: 0.9945x, Bonferroni p=1.
  - id_mod_8: 1.0058x, Bonferroni p=1.
  - id_mod_16: 0.9719x, Bonferroni p=1.
  - id_mod_32: 1.0266x, Bonferroni p=1.
  - id_mod_64: 0.9843x, Bonferroni p=1.
  - id_mod_128: 1.0068x, Bonferroni p=1.
  - id_mod_256: 1.0348x, Bonferroni p=1.
  - id_mod_512: 1.0197x, Bonferroni p=1.
  - id_mod_1024: 1.0095x, Bonferroni p=1.
  - id_mod_4096: 1.0127x, Bonferroni p=1.

## Practical interpretation

No tested character, prefix/suffix, stride, or intermediate-state ranking survived the global held-out correction. Any theoretical ordering lift is therefore treated as noise, and sparse ordering would additionally sacrifice the current contiguous SIMD throughput.
The block and Hamming tests also show no effect large enough to support safe block skipping. A mathematically exact inverse/preimage method remains qualitatively different and is not ruled out by these statistical negatives.
