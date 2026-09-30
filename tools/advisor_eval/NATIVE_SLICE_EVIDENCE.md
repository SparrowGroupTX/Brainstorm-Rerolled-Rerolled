# Tested native slices

`install_slice.py` now accepts an explicit content-addressed native sidecar with
`--native-evidence PATH`. It never builds, tests, loads, or executes that DLL.
Those actions must already have completed in bounded hidden workers, with their
logs preserved. No game restart/control is performed by either installer.

Preserve the old repository and installed `Immolate-v2.16.dll`. Compute the new
DLL's full lowercase SHA256 and place its bytes at:

`Brainstorm/Immolate-advisor-<64-character-sha256>.dll`

The explicitly tested Core loader must contain one assignment:

```lua
Brainstorm.NATIVE_FILE = "Immolate-advisor-<64-character-sha256>.dll"
```

The Windows branch must actually use `library_name = Brainstorm.NATIVE_FILE`.
The installer verifies this binding and all explicitly supplied Lua companions;
it does not rewrite the loader after testing. Its usual release-version stamping
still changes only the two version strings. The deployment manifest records the
resulting installed hashes separately from pre-stamping tested hashes.

On Windows, the current text-writing path can also normalize line endings in
those two files. The 2.65 installation recorded normalized-byte equality in
`runs/development265_installed/install_normalization.json` and reran validation
against the exact installed raw hashes. Do not assume pre-stamping and installed
policy digests are identical without checking them.

Evidence is JSON with these required fields:

```json
{
  "schema": 1,
  "kind": "advisor_native_slice",
  "dll": {
    "path": "Brainstorm/Immolate-advisor-<sha256>.dll",
    "sha256": "<sha256>"
  },
  "sources": {"Immolate/src/example.cpp": "<sha256>"},
  "tests": {"Immolate/tests/example.cpp": "<sha256>"},
  "runtime_files": {"Brainstorm/Core/Brainstorm.lua": "<sha256>"},
  "build": {
    "status": "complete",
    "exit_code": 0,
    "command": ["cmake", "--build", "<actual-directory>"],
    "timeout_seconds": 300,
    "elapsed_seconds": 12.3,
    "log": {"path": "tools/advisor_eval/runs/<fresh-run>/build.log", "sha256": "<sha256>"}
  },
  "validation": [{
    "status": "complete",
    "exit_code": 0,
    "command": ["<actual-test-command>", "<actual-argument>"],
    "timeout_seconds": 60,
    "elapsed_seconds": 1.2,
    "log": {"path": "tools/advisor_eval/runs/<fresh-run>/test.log", "sha256": "<sha256>"}
  }]
}
```

All three hash maps must be nonempty, and validation must contain at least one
successful bounded receipt. Include every relevant source, test, companion Lua
file and actual validation command, not just the abbreviated examples above.
Paths use forward slashes relative to this repository and must resolve inside it.
Every hash is verified against current bytes before staging. Failed, unsupported
or timed-out receipts do not authorize deployment; keep those artifacts separately.
This is a provenance gate, not independent proof that the supplied tests are
sufficient. Review the concrete native ABI and supported behavior as well.

The installer stages the new sidecar, passes its exact name through the existing
PowerShell `-NativeFile` interface, and preserves existing native artifacts.
PowerShell still backs up the selected complete runtime set and verifies each
installed hash/configuration hash. A copy of the exact evidence JSON and its
digest is attached to the new deployment backup. Subsequent Lua-only slices read
the installed Core selection and retain that same native artifact automatically.
Attempting to change the selected native artifact without matching evidence
fails before runtime/version mutation. Existing Lua-only invocations remain valid.

The literal legacy `Immolate-v2.16.dll` is still an accepted explicit source name
with evidence, but cannot replace a changed existing installed DLL. New builds
must use their content-addressed sidecar. Arbitrary DLL names are rejected.
