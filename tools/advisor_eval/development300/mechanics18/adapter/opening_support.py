"""Exact frozen opening hooks and the real bounded native search, without a game process."""
from __future__ import annotations
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import time
import tomllib


def opening_sources(root, sources):
    root = Path(root) / 'Brainstorm'
    core = (root / 'Core/Brainstorm.lua').read_bytes()
    hook = core[core.index(b'function Brainstorm.createCharmArcanaCard('):core.index(b'function Brainstorm.init()')]
    module = (root / 'Core/challenge_opening.lua').read_bytes()
    patches = tomllib.loads((root / 'lovely.toml').read_text(encoding='utf-8'))['patches']
    relevant = [p['pattern'] for p in patches if 'pattern' in p and
                'Brainstorm.createCharmArcanaCard(' in p['pattern'].get('payload', '')]
    if len(relevant) != 2:
        raise ValueError('Expected exactly the two frozen Charm callsite hooks')
    modified = dict(sources);before = modified['card.lua']
    for patch in relevant:
        if patch['target'] != 'card.lua' or patch['position'] != 'at' or patch['times'] != 1:
            raise ValueError('Unsupported Charm patch contract')
        pattern, payload = patch['pattern'].encode(), patch['payload'].encode()
        expected = pattern.replace(b'create_card(', b'Brainstorm.createCharmArcanaCard(self, ', 1)
        if payload != expected or modified['card.lua'].count(pattern) != 1:
            raise ValueError('Charm patch source mismatch')
        modified['card.lua'] = modified['card.lua'].replace(pattern, payload, 1)
    hashes = {name: hashlib.sha256(value).hexdigest() for name, value in
              [('hook', hook), ('module', module), ('card_before', before), ('card_after', modified['card.lua'])]}
    return modified, module, hook, hashes


def native_library_path(root):
    """Use the frozen product's selected native binary, never a newer local build."""
    product = Path(root) / 'Brainstorm'
    core = (product / 'Core/Brainstorm.lua').read_text(encoding='utf-8')
    declarations = re.findall(r'Brainstorm\.NATIVE_FILE\s*=\s*"([^"\r\n]+)"', core)
    if 'Brainstorm.NATIVE_FILE' in core and len(declarations) != 1:
        raise ValueError('Missing or ambiguous frozen native library declaration')
    name = declarations[0] if declarations else 'Immolate-v2.16.dll'
    if name != 'Immolate-v2.16.dll' and not re.fullmatch(r'Immolate-advisor-[a-f0-9]{64}\.dll', name):
        raise ValueError('Unsupported frozen native library filename')
    path = product / name
    if not path.is_file():
        raise ValueError('Frozen selected native library is missing')
    if name.startswith('Immolate-advisor-') and hashlib.sha256(path.read_bytes()).hexdigest() != name[17:-4]:
        raise ValueError('Frozen native library content differs from its sidecar name')
    return path


LATER_RARE_KEYS = {'j_dna','j_vagabond','j_baron','j_obelisk','j_baseball','j_ancient','j_campfire','j_blueprint',
                  'j_wee','j_hit_the_road','j_duo','j_trio','j_family','j_order','j_tribe','j_stuntman',
                  'j_invisible','j_brainstorm','j_drivers_license','j_burnt'}


def validate_later_request(later):
    if not isinstance(later, dict) or set(later) != {'target_key','deadline','rare_pool_mask'}:
        raise ValueError('Later search requires one target, deadline and explicit live/source Rare profile')
    if later['target_key'] not in LATER_RARE_KEYS or type(later['deadline']) is not int or not 2 <= later['deadline'] <= 8:
        raise ValueError('Later search requires a vanilla Rare target by Ante2..8')
    if not isinstance(later['rare_pool_mask'], str) or not re.fullmatch('[01]{20}', later['rare_pool_mask']):
        raise ValueError('Later search requires a twenty-position Rare availability mask')
    return dict(later)


def validate_later_result(result, later):
    if not isinstance(result, dict):
        raise ValueError('Malformed native later result')
    if result.get('status') in ('error','invalid'):
        return
    expected={'api_version':2,'later_target':later['target_key'],'later_deadline':later['deadline'],
              'later_pool_mask':later['rare_pool_mask'],'later_source':'shop_initial',
              'later_schedule':'first_charm_then_play_all_fixed_rare_pool',
              'later_offer_status':'conditional','later_retention':'not_verified'}
    if any(type(result.get(k)) is not type(v) or result[k]!=v for k,v in expected.items()):
        raise ValueError('Native later result changed its registered target/profile/schedule or claimed retention')
    if result.get('status') == 'found':
        ante,shop,slot=(result.get(k) for k in ('later_found_ante','later_shop','later_slot'))
        if any(type(v) is not int for v in (ante,shop,slot)) or not 1<=ante<=later['deadline'] or not 1<=slot<=2 or not 1<=shop<=(1 if ante==1 else 3):
            raise ValueError('Native later result has an invalid source shop location')
        if result.get('later_edition') not in ('base','foil','holo','polychrome','negative') or type(result.get('later_eternal')) is not bool:
            raise ValueError('Native later result has incomplete offered-card metadata')
        if result.get('challenge_id')=='c_typecast_1' and ante>4:
            raise ValueError('Native later result exceeds the supported acquisition window')
    elif result.get('status') != 'not_found':
        raise ValueError('Unknown native later result status')


def native_search(root, seed, challenge, targets, limit, *, later=None):
    if not re.fullmatch('[1-9A-Z]{1,8}', seed) or not 1 <= limit <= 1000000:
        raise ValueError('Opening search requires a 1..8 character native seed and limit 1..1000000')
    allowed = {'j_caino', 'j_triboulet', 'j_yorick', 'j_chicot', 'j_perkeo'}
    keys = targets.split(',') if targets else []
    if len(keys) > 2 or len(keys) != len(set(keys)) or not set(keys) <= allowed:
        raise ValueError('Use at most two distinct Legendary keys')
    if later is not None:
        later = validate_later_request(later)
    native_path = native_library_path(root)
    directories = []
    previous = {key: os.environ.get(key) for key in ('BRAINSTORM_THREADS', 'BRAINSTORM_SEARCH_LIMIT')}
    started = time.perf_counter()
    try:
        os.environ['BRAINSTORM_THREADS'] = '1';os.environ['BRAINSTORM_SEARCH_LIMIT'] = str(limit)
        if os.name == 'nt':
            directories.append(os.add_dll_directory(str(native_path.resolve().parent)))
            compiler = shutil.which('g++')
            if compiler:
                directories.append(os.add_dll_directory(str(Path(compiler).resolve().parent)))
        native = ctypes.CDLL(str(native_path.resolve()))
        endpoint = native.brainstorm_challenge_opening_v2 if later is not None else native.brainstorm_challenge_opening_v1
        endpoint.argtypes = [ctypes.c_char_p] * 3 + ([ctypes.c_char_p,ctypes.c_int,ctypes.c_char_p] if later is not None else [])
        endpoint.restype = ctypes.c_void_p
        native.free_result.argtypes = [ctypes.c_void_p]
        arguments = [seed.encode(), challenge.encode(), targets.encode()]
        if later is not None: arguments += [later['target_key'].encode(),later['deadline'],later['rare_pool_mask'].encode()]
        pointer = endpoint(*arguments)
        if not pointer:
            raise RuntimeError('Native opening allocation failed')
        try:
            raw = ctypes.string_at(pointer).decode('utf-8')
        finally:
            native.free_result(pointer)
        result = json.loads(raw)
        if later is not None: validate_later_result(result, later)
    finally:
        for key, value in previous.items():
            if value is None: os.environ.pop(key, None)
            else: os.environ[key] = value
        for directory in directories: directory.close()
    return result, raw, {'search_seconds': time.perf_counter() - started, 'search_start': seed,
                         'search_limit': limit, 'threads': 1,
                         'api_version': 2 if later is not None else 1,
                         'later_request': later,
                         'native_file': native_path.name,
                         'native_sha256': hashlib.sha256(native_path.read_bytes()).hexdigest()}
