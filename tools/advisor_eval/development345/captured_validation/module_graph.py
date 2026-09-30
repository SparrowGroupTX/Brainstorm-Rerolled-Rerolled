"""Pure derivation of a frozen runtime initialization graph; no runtime execution."""
def module_setup(raw):
    """Preserve installed policy edges; replace only the product filesystem loader."""
    text = raw.decode('utf-8')
    boundary = '\nfunction A.defaults()'
    if text.count(boundary) != 1:
        raise ValueError('Unknown frozen runtime initialization boundary')
    prefix = text.split(boundary)[0]
    start = prefix.index('local function module(name)')
    end = prefix.index('\nA.snapshot, A.scoring, A.search, A.strategy')
    loader = "local function module(name)\n  assert(package.preload['probe_policy_'..name], 'Missing frozen module '..name)\n  return require('probe_policy_'..name)\nend\n"
    prefix = prefix[:start] + loader + prefix[end:]
    omitted = []
    for line in ("A.execution = module('execution')",
                 "A.retry_memory, A.retry_policy, A.retry_journal = module('retry_memory'), module('retry_policy'), module('retry_journal')",
                 'A.retry_generation, A.state_epoch = 0, 0',
                 'A.opening = Brainstorm.ChallengeOpening',
                 'A.jokerless_opening = Brainstorm.JokerlessOpening'):
        if prefix.count(line) != 1:
            raise ValueError('Unknown frozen live/retry line: ' + line)
        prefix = prefix.replace(line, '-- Detached captured comparison omits: ' + line)
        omitted.append(line)
    if 'function A.defaults' in prefix or 'A.snapshot.capture(' in prefix or 'A.decision.run(' in prefix:
        raise ValueError('Module setup reached product capture or evaluation')
    return prefix.encode(), omitted

