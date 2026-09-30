"""Public collection conditioning and distinct simulated new-Gold accounting.

No save/profile access. A simulator reward never changes the player's collection.
"""
from __future__ import annotations
import hashlib
import json
import numpy as np

SCHEMA = 'completionist_distinct_v1'
GLOBAL_DIM, ENTITY_DIM, CANDIDATE_DIM = 530, 67, 163
STATUS_ORDER = ('missing','complete','unknown')


class CompletionGoal:
    def __init__(self, status_by_key, catalog_keys, *, verified=True):
        self.keys = tuple(catalog_keys)
        if len(self.keys) != 150 or self.keys != tuple(sorted(set(self.keys))):
            raise ValueError('Exactly150 sorted distinct vanilla Joker keys required')
        if set(status_by_key) != set(self.keys):
            raise ValueError('Complete explicit collection status mapping required')
        if any(value not in STATUS_ORDER for value in status_by_key.values()):
            raise ValueError('Unknown collection-status vocabulary')
        self.status = dict(status_by_key) if verified else {k:'unknown' for k in self.keys}
        self.verified = bool(verified)
        self.digest = hashlib.sha256(json.dumps(self.status,sort_keys=True,separators=(',',':')).encode()).hexdigest()
        self.features = np.asarray([[float(self.status[k]==s) for s in STATUS_ORDER] for k in self.keys],np.float32)
        self._lookup = None
        self._catalog_signature = None

    @classmethod
    def from_spec(cls, spec):
        if spec.get('schema') != SCHEMA:
            raise ValueError('Explicit Completionist objective schema required')
        return cls(spec['status_by_key'],spec['joker_keys'],verified=spec.get('verified_collection') is True)

    def augment(self, observation, catalog_ids):
        signature = tuple(sorted(catalog_ids.items()))
        if self._catalog_signature != signature:
            if not set(self.keys).issubset(catalog_ids):
                raise ValueError('Goal catalog differs from simulator catalog')
            size = len(catalog_ids)
            self._lookup = np.zeros((size+1,3),np.float32)
            for key, status in self.status.items():
                index = int(round(catalog_ids[key]*(size+1)))
                self._lookup[index,STATUS_ORDER.index(status)] = 1
            self._catalog_signature = signature
        e,c,g = observation['entities'],observation['candidates'],observation['global']
        if g.shape != (80,) or e.shape[-1] != 64 or c.shape[-1] != 160:
            raise ValueError('Expected base public observation schema')
        def status_rows(rows,offset):
            visible = rows[:,offset+7]>0
            indices = np.rint(rows[:,offset+9]*(len(catalog_ids)+1)).astype(np.int64)
            indices = np.clip(indices,0,len(catalog_ids))
            result = self._lookup[indices].copy()
            result[~visible] = 0
            # A face-down owned Joker's identity is unavailable; its status is
            # unknown even though the full collection ledger is public.
            result[(~visible)&(rows[:,offset+1]>0),2] = 1
            return result
        return {'global':np.concatenate((g,self.features.reshape(-1))).astype(np.float32),
                'entities':np.concatenate((e,status_rows(e,0)),axis=1).astype(np.float32),
                'candidates':np.concatenate((c,status_rows(c,21)),axis=1).astype(np.float32)}

    def missing_held(self, held_keys, eligible, won):
        if eligible is not True or won is not True or not self.verified:
            return []
        return sorted({key for key in held_keys if self.status.get(key)=='missing'})


def sticker_training_reward(info, prior_info, terminal):
    """Undiscounted new-sticker objective plus telescoping progress shaping.

No reward for merely acquiring/holding a target and no bonus for a zero-new
sticker win. Shaping vanishes over a full episode. Unresolved transitions must
be excluded by the collector, not passed here as fabricated terminals.
"""
    before = 0.05*float(prior_info.get('blinds_cleared',0))
    after = 0.0 if terminal else 0.05*float(info.get('blinds_cleared',0))
    award = float(info.get('new_gold_count',0)) if terminal and info.get('outcome')=='win' else 0.0
    return award+after-before
