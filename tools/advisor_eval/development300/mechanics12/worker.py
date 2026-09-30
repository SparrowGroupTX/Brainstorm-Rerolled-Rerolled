"""M12 registered source startup mechanic; no search or advisor action."""
from pathlib import Path
import json
import sys


def main():
    folder = Path(__file__).resolve().parent
    registration = json.loads((folder/'registration.json').read_text(encoding='utf-8'))
    spent = json.loads((folder/'spent.json').read_text(encoding='utf-8'))
    assert registration['job'] == spent['job'] == 'M12' and registration['timeout_seconds'] == 30
    assert registration['metadata']['maximum_advisor_actions'] == 0
    import engine_probe
    sys.argv = [sys.argv[0], '--deck', 'b_red', '--stake', '8', '--seed', 'STARTUP1',
        '--unlock-profile', 'all_unlocked_discovered_v1', '--policy-root', str(folder/'policy'),
        '--episode', '--test-scenario', 'collection_product_startup']
    return engine_probe.main()


if __name__ == '__main__':
    raise SystemExit(main())
