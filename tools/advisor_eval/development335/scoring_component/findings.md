The candidate hoists five immutable enhancement, blind-name and suit-order
lookup tables, skips computing the lowest held card when the existing Joker
flags contain no active Raised Fist, and returns numeric nominal values
without eagerly calculating unused rank defaults. Nonnumeric nominal fallback
resolves rank once. It introduces no new state cache.
The former map expressions constructed fresh tables; their contents are
constant strings and are never written or exposed to callers. Each suit list
retains its exact original order.

The lowest-held-card result has only two readers, both conditional on a
resolved Joker named Raised Fist. `flags` and `score_row` use the same `name`
resolver. A copy resolves only through nondebuffed cards to its target, so a
resolved Raised Fist implies a nondebuffed Raised Fist exists in the row and
sets the same flag. An incompatible copy target cannot remove the original
active Fist. Unknown keys with an explicit Raised Fist name still set the
flag. Name overrides, debuffs and copy cycles preserve their existing routes.

Final component evidence: `fixture_receipt3.json`, 3,402 checks across 476
complete comparison cases, 0.359 seconds with a 60-second process cap. This is
a pure manufactured fixture, not a search, source attempt or live benchmark.

| Instrumented operation | Baseline | Candidate |
|---|---:|---:|
| Full score calls | 2,217 | 2,217 |
| Lowest-held-card visits | 11,232 | 1,778 |
| Enhancement helper calls | 97,041 | 57,556 |
| Rank helper calls | 41,945 | 11,914 |
| Nominal helper calls | 7,765 | 7,765 |
| Enhancement-map allocations | 86,259 | 1 |
| Blind-name-map allocations | 2,195 | 1 |
| Classification suit-list allocations | 186 | 1 |
| Seeing Double suit-list allocations | 33 | 1 |
| Flower Pot suit-list allocations | 33 | 1 |

The five candidate allocations occur at module load. Counters wrap the literal
constructors in fixture-loaded source, after the literal arguments are
constructed; they do not inspect or modify the loaded game. Helper and scan
counts are inserted at unique function/loop sites. Uninstrumented checks
confirm counter transparency. Output comparisons include expected score,
floor, ceiling and unsupported guards, complete warnings/uncertainty, ordered
transition cards/states/creation, retained consumable order and Observatory,
Lucky events and Glass population loss. The fixture checks same-table input
changes through raw scoring and new prepared scopes; existing prepared caches
still require immutable per-decision inputs. Nominal coverage includes numeric,
zero, negative, base-provided, nonnumeric, false, absent, NaN and infinite values
across Ace, ordinary and Stone cards, plus in-place changes between calls.
The exact `c.nominal or base.nominal` precedence and numeric NaN/Inf behavior
are preserved. Earlier candidate bytes and evidence remain separately saved.

Baseline scoring SHA-256:
`b77a211cf2480d55008dc96e993b66d380a92e4e466d44f58b25a9e9bc0a11cf`

Candidate scoring SHA-256:
`f625c294eb5ba9cf0b6da5eb8f871c58be0835aecf92396c09151becef1c80e9`

Final fixture SHA-256:
`0ca66e94cade5acaf8174e30e33c389c6f3b6bfa8d823f03dd244b7456e582c7`

No production source or existing fixture was modified by this component.
The standalone fixture currently loads the component's baseline and staged
candidate paths. Full release/regression/install validation belongs to root.
Nothing here establishes live latency/FPS improvement or gameplay outcomes.
