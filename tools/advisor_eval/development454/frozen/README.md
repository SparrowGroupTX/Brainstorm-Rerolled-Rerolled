# Retained 454 integration bytes

`simulator_patches.py` is the exact pre-455 integration module used by the
one-use 454 source comparison. Its SHA-256 is
`3d01d58efa59b82fe203bc1c9f3c362a2794db2b940caae5845b588dfc90f9c5`,
matching `../SOURCE_PROBE_PREPARED.json`. Slice 455 advances the live integration
module, so the 454 prepared-manifest check against that live path now detects
expected dependency drift. The original 454 lease, raw output and comparison
receipt remain unchanged. This snapshot preserves the exact old dependency
bytes for historical reconstruction; it is not an executable renewal of the
consumed source lease.
