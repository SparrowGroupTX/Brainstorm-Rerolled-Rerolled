# 388 candidate checkpoint — 2026-09-25

Repository candidate: **2.186.0-alpha**, validated and uninstalled. Installed
checkpoint: **2.184.0-alpha** (`SESSION_RESET_386.json`, digest
`851a189fe212211b0d7ced23abf3276eb04089e7658536db950adea9feeb3ccc`).
The running user's public journal labels 2.184; exact loaded bytes are not
attested. 2.185 was never installed and is incorporated into this candidate.

Frozen 2.186 policy digest:
`eb996950e48a9ee1685aca6c63c84f540db5a1d2a54fa204e32cc796e9c58cda`.
Changed runtime files relative to installed 2.184:
`Brainstorm/Advisor/{decision,player_journal,search,strategy}.lua`,
`Brainstorm/Core/Brainstorm.lua`, `Brainstorm/steamodded_compat.lua`.
`runs/cash388_candidate/freeze.json` attests 108 runtime/dependency and 295
test hashes. Full validation at `runs/cash388_candidate/validation/` passed
255 Lua fixtures and 392 Python tests with unchanged frozen policy/test hashes.
No exact-installed gate exists because no installation occurred.

This candidate contains the previously frozen 2.185 Yorick comparison and a
late win-first surplus reroll rule plus separate public rejection receipts.
Evidence: `development388/{SCOPE,REPORT}.md`, `capture/manifest.json`,
`analysis/cash_shops.json`, and WR-033 in `WIN_RATE_RESEARCH.md`. Completed
segments 1–7 are frozen under `development387/`; segments 8–20 under
`development388/`. The current ten-start batch is not yet confirmed complete;
the writable tail was excluded. No 2.186 real-game benefit is demonstrated.

Preserve the active batch, logs, current settings and seven native DLLs. After
the user reports normal completion/exit, passively audit the remaining public
segments, verify exact installed baseline/config/DLL/frozen candidate/test
hashes, then use `install_slice.py` with only the six explicit changed runtime
files and backup. Freeze and validate exact installed bytes. Do not launch or
control Balatro through tools; installation alone does not establish activation.
