# Brainstorm Search Performance

## Profiling

The native searcher now supports lightweight runtime profiling through
environment variables:

- `BRAINSTORM_PROFILE=1`
  Prints a summary at the end of each search with:
  - total seeds processed
  - elapsed time
  - seeds/sec
  - rank-prefilter pass/reject counts
  - total and average time for key helper paths

- `BRAINSTORM_THREADS=<n>`
  Overrides the search thread count.

- `BRAINSTORM_SEARCH_LIMIT=<n>`
  Caps the number of seeds examined during a search. This is useful for
  repeatable benchmark runs that should stop after a fixed amount of work.

## What Changed

The current optimization pass focuses on CPU throughput first:

- cached the LuaJIT FFI binding and `Immolate.dll` handle
- freed native result strings after converting them back to Lua
- removed repeated hot-path logging and repeated localization work
- changed the native search callback to reuse a single `Instance` per thread
  instead of copying it per seed
- replaced the RNG node cache with `std::unordered_map`
- cached ante strings and reduced avoidable string copies
- pre-sized pack vectors instead of growing them with repeated `push_back`

## GPU Guidance

The profiler output should help answer whether GPU work is worth pursuing:

- If `rankPrefilter` time is small relative to total `filter` time, a GPU path
  is unlikely to help much.
- If `rankPrefilter` dominates runtime and rejects most seeds, then a GPU
  prototype is only worth exploring for that prefilter stage.
- The full `filter` simulation is still a poor GPU target because it is highly
  branchy, stateful, and string-heavy.

In practice, the best next step after this pass is to profile a few real filter
configurations and see whether the rank prefilter is large enough to justify a
specialized CPU/GPU split.
