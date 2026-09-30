# Candidate validation invocation error — 2026-09-23

The first invocation passed the candidate parent directory instead of its
frozen `policy` subdirectory:

`python tools/advisor_eval/validate_checkpoint.py --policy tools/advisor_eval/runs/auto_arch370_candidate --output tools/advisor_eval/runs/auto_arch370_candidate/validation`

It exited before creating a validation directory or running either suite:

`ValueError: Product manifest is missing required advisor/runtime sources`

The corrected command used
`--policy tools/advisor_eval/runs/auto_arch370_candidate/policy` and passed.
Its full report and raw suite logs are under
`runs/auto_arch370_candidate/validation/`. The first invocation is a command
setup error, not an intermediate fixture/regression failure.
