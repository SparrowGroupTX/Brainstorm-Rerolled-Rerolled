# 389 candidate checkpoint — 2026-09-25

Repository candidate **2.187.0-alpha** is frozen, full-gate-validated and
**not installed**. Installed baseline is **2.184.0-alpha**
(`SESSION_RESET_386.json`, digest
`851a189fe212211b0d7ced23abf3276eb04089e7658536db950adea9feeb3ccc`).
The active user's completed public segments 1–20 label loaded 2.184 with
win-first profile; exact loaded bytes and ten-start completion are unconfirmed.

Final candidate digest:
`ac7d4dc9574f4a9bdcafdaee142a3a8f1f81cd79f4b8aa7a93d6c8398f2bebd8`.
`runs/filler389_verified_candidate/freeze.json` contains exact hashes for
108 runtime/dependency and 296 test files. Changed runtime files relative to
installed 2.184 are `Brainstorm/Advisor/{decision,player_journal,search,strategy}.lua`,
`Brainstorm/Core/Brainstorm.lua`, and `Brainstorm/steamodded_compat.lua`.
`runs/filler389_verified_candidate/validation/` passed 256 Lua fixtures and
392 Python tests with policy/test hashes unchanged. No exact-installed gate
exists because no installation occurred.

The candidate incorporates the earlier uninstalled 2.185 and 2.186 fixes and
adds temporary Stone/suit/off-plan Planet filler valuation, Negative surplus
sale, and funded visible replacement with exact capacity and settlement
guards. Scope, failed intermediate gate, corrective regression and limits are
in `development389/{SCOPE,REPORT}.md` and WR-034 in `WIN_RATE_RESEARCH.md`.
Preserve the first failed gate at `runs/filler389_candidate/validation/` and
the intermediate candidate at `runs/filler389_final_candidate/`; they are
superseded, not release evidence. Do not install 2.185 or 2.186 separately.

Preserve the current user-started batch, all settings, journals and seven
native DLLs. Once the user reports normal batch completion and game exit,
audit the remaining completed public segments, verify exact installed
baseline/config/DLL and final frozen candidate/test hashes, then use
`install_slice.py` with only the six explicit changed files and backup. Freeze
and validate exact installed bytes after release. Installation alone does not
establish activation or real-game gain. No native DLL changes in this slice.
