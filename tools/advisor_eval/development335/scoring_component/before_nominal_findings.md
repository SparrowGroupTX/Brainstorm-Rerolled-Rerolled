The candidate hoists five immutable enhancement, blind-name and suit-order
lookup tables, and skips computing the lowest held card when the existing
Joker flags contain no active Raised Fist. It introduces no new state cache.
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

Final component evidence: `fixture_receipt2.json`, 2,938 checks across 410
complete comparison cases, 0.328 seconds with a 60-second process cap. This is
a pure manufactured fixture, not a search, source attempt or live benchmark.

| Instrumented operation | Baseline | Candidate |
|---|---:|---:|
| Full score calls | 1,896 | 1,896 |
| Lowest-held-card visits | 8,985 | 1,778 |
| Enhancement helper calls | 82,133 | 61,326 |
| Enhancement-map allocations | 72,014 | 1 |
| Blind-name-map allocations | 1,874 | 1 |
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
still require immutable per-decision inputs.

Baseline scoring SHA-256:
`b77a211cf2480d55008dc96e993b66d380a92e4e466d44f58b25a9e9bc0a11cf`

Candidate scoring SHA-256:
`547b4977cf310be54cf35df3f955cc747f54ee3fad6231b4ac414da8586fa686`

Final fixture SHA-256:
`e877bc012ee4be1d0a5f9a0225cfaae1dcb09bc168683033e57d60f8d8ccd7bb`

No production source or existing fixture was modified by this component.
The standalone fixture currently loads the component's baseline and staged
candidate paths. Full release/regression/install validation belongs to root.
Nothing here establishes live latency/FPS improvement or gameplay outcomes.
