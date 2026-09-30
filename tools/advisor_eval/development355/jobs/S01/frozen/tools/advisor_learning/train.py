"""Bounded CUDA PPO pilot with explicit public candidates and honest outcomes.

CPU processes execute the simulator only. Every learned forward/backward pass
runs on CUDA. No product imports, saves, live bridge or original executable.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import math
import multiprocessing as mp
import os
from pathlib import Path
import time
import traceback
import numpy as np


def seed_for(namespace, index):
    # Seed families are reproducible and disjoint by role; no favorable search.
    prefixes = {'L355TRAIN': 'T', 'L355DEV': 'D', 'L355FINAL': 'F', 'L355SMOKE': 'S'}
    prefix = next((value for key,value in prefixes.items() if namespace.startswith(key)), None)
    if prefix is None or type(index) is not int or index < 0:
        raise ValueError('Registered namespace and nonnegative integer index required')
    return prefix + hashlib.sha256(f'{namespace}:{index}'.encode()).hexdigest()[:7].upper()


def worker(connection, deck, stake, max_steps):
    from .environment import Environment
    env = None
    while True:
        command, value = connection.recv()
        if command == 'close':
            break
        try:
            if command == 'reset':
                env = Environment(value, deck=deck, stake=stake, max_steps=max_steps)
                connection.send((env.observe(), 0.0, False, False,
                                 {'outcome': 'ongoing', 'ante': 1, 'blinds_cleared': 0, 'steps': 0}))
            elif command == 'step':
                connection.send(env.step(value))
            else:
                raise ValueError(command)
        except Exception as exc:
            kind = 'unsupported' if type(exc).__name__ == 'UnsupportedState' else 'error'
            connection.send((None, 0.0, False, True,
                             {'outcome': kind, 'error': repr(exc), 'traceback': traceback.format_exc()}))
    connection.close()


def pad_numpy(observations):
    if not observations or any(len(o['candidates']) == 0 for o in observations):
        raise ValueError('Nonempty batch and candidate sets required')
    batch = len(observations)
    max_entities = max(1, max(len(o['entities']) for o in observations))
    max_candidates = max(len(o['candidates']) for o in observations)
    g = np.stack([o['global'] for o in observations]).astype(np.float32)
    e = np.zeros((batch, max_entities, observations[0]['entities'].shape[-1]), np.float32)
    c = np.zeros((batch, max_candidates, observations[0]['candidates'].shape[-1]), np.float32)
    em = np.zeros((batch, max_entities), bool)
    cm = np.zeros((batch, max_candidates), bool)
    for i, observation in enumerate(observations):
        ne, nc = len(observation['entities']), len(observation['candidates'])
        e[i, :ne] = observation['entities']
        c[i, :nc] = observation['candidates']
        em[i, :ne] = True
        cm[i, :nc] = True
    return g, e, em, c, cm


def collate(observations):
    return tuple(torch.from_numpy(x).to('cuda') for x in pad_numpy(observations))


def potential(info):
    return 0.2 * min(24, max(0, float(info.get('blinds_cleared', 0))))


def training_reward(info, prior_info, terminal):
    outcome = info.get('outcome', 'ongoing')
    base = 10.0 if outcome == 'win' else -1.0 if outcome == 'loss' else 0.0
    # Potential shaping telescopes to zero at a real terminal. Progress cannot
    # replace terminal success. Censored/unsupported transitions are masked.
    next_potential = 0.0 if terminal else potential(info)
    return base - 0.0005 + 0.997 * next_potential - potential(prior_info)


def wilson(wins, count):
    if not count:
        return None
    z = 1.959963984540054
    p = wins / count
    d = 1 + z*z/count
    center = (p + z*z/(2*count))/d
    half = z * math.sqrt(p*(1-p)/count + z*z/(4*count*count))/d
    return [max(0.0, center-half), min(1.0, center+half)]


def save_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2, allow_nan=False)+'\n', encoding='utf-8')


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--job-dir', type=Path, required=True)
    parser.add_argument('--wall-seconds', type=float, required=True)
    parser.add_argument('--max-transitions', type=int, required=True)
    parser.add_argument('--max-episodes', type=int, required=True)
    parser.add_argument('--mode', choices=['heuristic', 'learn', 'evaluate'], required=True)
    parser.add_argument('--deck', default='b_red')
    parser.add_argument('--stake', type=int, default=8)
    parser.add_argument('--namespace', required=True)
    parser.add_argument('--workers', type=int, default=8, choices=range(1, 9))
    parser.add_argument('--width', type=int, default=384)
    parser.add_argument('--rollout', type=int, default=32)
    parser.add_argument('--epochs', type=int, default=3)
    parser.add_argument('--batch-size', type=int, default=32)
    parser.add_argument('--learning-rate', type=float, default=0.0002)
    parser.add_argument('--imitation-weight', type=float, default=0.3)
    parser.add_argument('--checkpoint', type=Path)
    parser.add_argument('--max-steps', type=int, default=800)
    parser.add_argument('--precision', choices=['bf16', 'fp32'], default='bf16')
    return parser.parse_args()


def main():
    global torch
    args = parse_args()
    started = time.monotonic()
    deadline = started + max(1, args.wall_seconds - 18)
    if args.rollout < 1 or args.rollout > 128 or args.batch_size > 128:
        raise ValueError('Unbounded rollout or batch')
    if min(args.batch_size,args.epochs,args.max_transitions,args.max_episodes,args.wall_seconds) <= 0:
        raise ValueError('Positive bounds required')
    seed_for(args.namespace, 0)
    from .environment import GLOBAL_DIM, ENTITY_DIM, CANDIDATE_DIM, CATALOG_SIZE
    from .heuristic import heuristic_index
    from .gae import compute_gae
    rng = np.random.default_rng(355)
    model = optimizer = None
    checkpoint_hash = None
    device_info = {}
    if args.mode != 'heuristic':
        import torch
        from .model import PublicCandidatePolicy
        torch.set_num_threads(1)
        torch.manual_seed(355)
        torch.use_deterministic_algorithms(True)
        if not torch.cuda.is_available():
            raise RuntimeError('CUDA required; no CPU training fallback')
        free, total = torch.cuda.mem_get_info()
        if free < 8 * 2**30:
            raise RuntimeError('Insufficient GPU headroom')
        torch.cuda.set_per_process_memory_fraction(min(24 * 2**30, free-6 * 2**30)/total)
        torch.backends.cuda.matmul.allow_tf32 = False
        torch.backends.cudnn.allow_tf32 = False
        if args.precision == 'bf16' and not torch.cuda.is_bf16_supported():
            raise RuntimeError('BF16 requested but unsupported')
        model = PublicCandidatePolicy(GLOBAL_DIM, ENTITY_DIM, CANDIDATE_DIM,
                                      width=args.width, catalog_size=CATALOG_SIZE).cuda()
        if args.checkpoint:
            checkpoint_hash = hashlib.sha256(args.checkpoint.read_bytes()).hexdigest()
            saved = torch.load(args.checkpoint, map_location='cuda', weights_only=True)
            if saved['dimensions'] != [GLOBAL_DIM, ENTITY_DIM, CANDIDATE_DIM] or saved['width'] != args.width:
                raise ValueError('Checkpoint architecture or observation dimensions differ')
            if saved.get('environment_sha256') != hashlib.sha256(Path(__file__).with_name('environment.py').read_bytes()).hexdigest():
                raise ValueError('Checkpoint observation implementation changed; explicit migration required')
            if saved.get('model_metadata') != model.metadata():
                raise ValueError('Checkpoint model metadata differs')
            model.load_state_dict(saved['model'])
        optimizer = torch.optim.AdamW(model.parameters(), lr=args.learning_rate, eps=1e-5,
                                     weight_decay=0.0001, fused=True)
        device_info = {'name': torch.cuda.get_device_name(), 'torch': torch.__version__,
                       'precision': args.precision, 'parameters': sum(p.numel() for p in model.parameters()),
                       'input_checkpoint_sha256': checkpoint_hash}
    save_json(args.job_dir / 'configuration.json', {
        'arguments': {k: str(v) if isinstance(v, Path) else v for k,v in vars(args).items()},
        'device': device_info, 'dimensions': [GLOBAL_DIM, ENTITY_DIM, CANDIDATE_DIM],
        'gamma': 0.997, 'gae_lambda': 0.99, 'policy_clip': 0.2,
        'teacher': 'public deterministic heuristic, not existing advisor or expert',
        'simulator_qualified': False})
    context = mp.get_context('spawn')
    workers = []
    for _ in range(min(args.workers, args.max_episodes)):
        parent, child = context.Pipe()
        process = context.Process(target=worker, args=(child, args.deck, args.stake, args.max_steps))
        process.start()
        child.close()
        workers.append({'pipe': parent, 'process': process, 'observation': None, 'active': False})
    episodes = []
    transitions = 0
    begun = 0
    updates = 0
    censored_transitions = 0
    stage_seconds = Counter()
    metrics_file = (args.job_dir / 'metrics.jsonl').open('w', encoding='utf-8')
    episode_file = (args.job_dir / 'episodes.jsonl').open('w', encoding='utf-8')
    action_file = (args.job_dir / 'actions.jsonl').open('w', encoding='utf-8')

    def receive(slot):
        remaining = deadline-time.monotonic()
        if remaining <= 0 or not slot['pipe'].poll(remaining):
            raise TimeoutError('Simulator worker did not reply before soft job deadline')
        return slot['pipe'].recv()

    def finish(slot, info):
        row = {'episode_index': slot['episode_index'], 'seed': slot['seed'],
               'namespace': args.namespace, 'deck': args.deck, 'stake': args.stake,
               'wall_seconds': time.monotonic()-slot['started'], **info}
        episodes.append(row)
        episode_file.write(json.dumps(row, allow_nan=False)+'\n')
        episode_file.flush()
        slot['active'] = False
        slot['observation'] = None

    def start_episode(slot):
        nonlocal begun
        if begun >= args.max_episodes or time.monotonic() >= deadline:
            return
        slot.update(episode_index=begun, seed=seed_for(args.namespace, begun),
                    started=time.monotonic(), active=True, info={'blinds_cleared': 0, 'ante': 1})
        begun += 1
        slot['pipe'].send(('reset', slot['seed']))
        observation, _, terminated, truncated, info = receive(slot)
        slot['observation'], slot['info'] = observation, info
        if terminated or truncated or observation is None:
            finish(slot, info)

    try:
        for slot in workers:
            start_episode(slot)
        while time.monotonic() < deadline and transitions < args.max_transitions:
            trajectories = [[] for _ in workers]
            any_data = False
            for _ in range(args.rollout if args.mode == 'learn' else 1):
                if time.monotonic() >= deadline or transitions >= args.max_transitions:
                    break
                for slot in workers:
                    if not slot['active']:
                        start_episode(slot)
                active = [(i,s) for i,s in enumerate(workers) if s['active']]
                if not active:
                    break
                active = active[:args.max_transitions-transitions]
                observations = [s['observation'] for _,s in active]
                stage_start = time.monotonic()
                if args.mode == 'heuristic':
                    actions = [heuristic_index(o) for o in observations]
                    values = np.zeros(len(active))
                    logprobs = np.zeros(len(active))
                else:
                    with torch.no_grad(), torch.autocast('cuda', dtype=torch.bfloat16,
                                                        enabled=args.precision=='bf16'):
                        logits, value_tensor = model(*collate(observations))
                        distribution = model.distribution(logits.float())
                        action_tensor = distribution.sample() if args.mode=='learn' else logits.argmax(-1)
                        actions = action_tensor.cpu().numpy()
                        logprobs = distribution.log_prob(action_tensor).cpu().numpy()
                        values = value_tensor.reshape(-1).cpu().numpy()
                stage_seconds['policy_and_transfer'] += time.monotonic()-stage_start
                stage_start = time.monotonic()
                for (_, slot), action in zip(active, actions):
                    slot['pipe'].send(('step', int(action)))
                for j, (i, slot) in enumerate(active):
                    observation, _, terminated, truncated, info = receive(slot)
                    transitions += 1
                    any_data = True
                    valid = not truncated and info.get('outcome') not in ('unsupported','error','censored')
                    if not valid:
                        censored_transitions += 1
                    entry = {'observation': slot['observation'], 'action': int(actions[j]),
                             'logprob': float(logprobs[j]), 'value': float(values[j]),
                             'reward': training_reward(info,slot['info'],terminated) if valid else 0.0,
                             'terminal': bool(terminated), 'boundary': bool(terminated or truncated),
                             'valid': valid, 'teacher': int(heuristic_index(slot['observation']))}
                    trajectories[i].append(entry)
                    candidate = entry['observation']['candidates'][entry['action']]
                    action_file.write(json.dumps({'episode_index':slot['episode_index'],
                        'step':info.get('steps'), 'candidate_index':entry['action'],
                        'candidate_kind':int(np.argmax(candidate[:21])),
                        'target_slots':candidate[149:154].tolist(),
                        'candidate_count':len(entry['observation']['candidates']),
                        'base_score_feature':float(candidate[159]),
                        'value':entry['value'], 'outcome':info.get('outcome'),
                        'ante':info.get('ante'), 'blinds_cleared':info.get('blinds_cleared'),
                        'seconds':time.monotonic()-started},allow_nan=False)+'\n')
                    slot['observation'], slot['info'] = observation, info
                    if terminated or truncated or observation is None:
                        finish(slot, info)
                stage_seconds['simulator_wait_and_record'] += time.monotonic()-stage_start
            if not any_data:
                break
            if args.mode == 'learn' and time.monotonic() < deadline:
                stage_start = time.monotonic()
                active = [(i,s) for i,s in enumerate(workers) if s['active']]
                bootstrap = {i: 0.0 for i in range(len(workers))}
                if active:
                    with torch.no_grad(), torch.autocast('cuda', dtype=torch.bfloat16,
                                                        enabled=args.precision=='bf16'):
                        _, last_values = model(*collate([s['observation'] for _,s in active]))
                    bootstrap.update({i: float(v) for (i,_),v in zip(active,last_values.reshape(-1).cpu())})
                data = []
                for i, trajectory in enumerate(trajectories):
                    data.extend(compute_gae(trajectory, bootstrap[i]))
                if data:
                    adv = np.array([d['advantage'] for d in data], np.float32)
                    adv = (adv-adv.mean())/(adv.std()+1e-8)
                    for d,a in zip(data,adv):
                        d['normalized_advantage'] = float(a)
                    losses = []
                    for epoch in range(args.epochs):
                        for offset in range(0,len(data),args.batch_size):
                            if time.monotonic() >= deadline:
                                break
                            if offset == 0:
                                order = rng.permutation(len(data))
                            batch = [data[int(k)] for k in order[offset:offset+args.batch_size]]
                            def tensor(key, dtype=torch.float32):
                                return torch.tensor([d[key] for d in batch], device='cuda', dtype=dtype)
                            with torch.autocast('cuda', dtype=torch.bfloat16, enabled=args.precision=='bf16'):
                                logits, value = model(*collate([d['observation'] for d in batch]))
                            distribution = model.distribution(logits.float())
                            logprob = distribution.log_prob(tensor('action',torch.long))
                            ratio = (logprob-tensor('logprob')).exp()
                            advantages = tensor('normalized_advantage')
                            policy_loss = -torch.minimum(ratio*advantages,ratio.clamp(0.8,1.2)*advantages).mean()
                            value_loss = (value.float().reshape(-1)-tensor('return')).square().mean()
                            entropy = distribution.entropy().mean()
                            imitation = torch.nn.functional.cross_entropy(logits.float(),tensor('teacher',torch.long))
                            loss = policy_loss+0.5*value_loss-0.01*entropy+args.imitation_weight*imitation
                            if not torch.isfinite(loss):
                                raise RuntimeError('Nonfinite learning loss')
                            optimizer.zero_grad(set_to_none=True)
                            loss.backward()
                            torch.nn.utils.clip_grad_norm_(model.parameters(),0.5,error_if_nonfinite=True)
                            optimizer.step()
                            losses.append([float(v.detach()) for v in (policy_loss,value_loss,entropy,imitation)])
                    updates += 1
                    stage_seconds['optimization_and_bootstrap'] += time.monotonic()-stage_start
                    row = {'seconds': time.monotonic()-started,'transitions':transitions,'updates':updates,
                           'episodes':len(episodes),'loss_means':np.mean(losses,axis=0).tolist() if losses else [],
                           'cuda_peak_bytes':torch.cuda.max_memory_allocated(),
                           'stage_seconds':dict(stage_seconds),
                           'outcomes':dict(Counter(e['outcome'] for e in episodes))}
                    metrics_file.write(json.dumps(row)+'\n')
                    metrics_file.flush()
                    print(json.dumps(row),flush=True)
            elif transitions % 100 < args.workers or len(episodes) >= args.max_episodes:
                print(json.dumps({'seconds':time.monotonic()-started,'transitions':transitions,
                                  'episodes':len(episodes),'outcomes':dict(Counter(e['outcome'] for e in episodes))}),flush=True)
    finally:
        for slot in workers:
            if slot['active']:
                finish(slot,{**slot['info'],'outcome':'censored','reason':'job_limit'})
            try:
                slot['pipe'].send(('close',None))
            except (BrokenPipeError,EOFError):
                pass
        for slot in workers:
            slot['process'].join(timeout=2)
            if slot['process'].is_alive():
                slot['process'].terminate()
            slot['pipe'].close()
        metrics_file.close()
        episode_file.close()
        action_file.close()
        if args.mode == 'learn' and model is not None:
            torch.save({'model':model.state_dict(),'dimensions':[GLOBAL_DIM,ENTITY_DIM,CANDIDATE_DIM],
                        'width':args.width,'transitions':transitions,'updates':updates,
                        'environment_sha256':hashlib.sha256(Path(__file__).with_name('environment.py').read_bytes()).hexdigest(),
                        'model_metadata':model.metadata()},args.job_dir/'policy.pt')
        outcomes = Counter(e.get('outcome','unknown') for e in episodes)
        summary = {'mode':args.mode,'simulator_qualified':False,'real_game_win_claim':False,
                   'transitions':transitions,'episodes_started':begun,'outcomes':dict(outcomes),
                   'censored_transitions':censored_transitions,'updates':updates,
                   'elapsed_seconds':time.monotonic()-started,
                   'stage_seconds':dict(stage_seconds),
                   'transition_rate':transitions/max(0.001,time.monotonic()-started),
                   'observed_completion_lower_bound':outcomes['win']/begun if begun else None,
                   'wilson_95_all_started':wilson(outcomes['win'],begun) if outcomes['win']+outcomes['loss']==begun else None,
                   'interval_limit':'Wilson interval emitted only when every started attempt has an actual terminal win/loss. With censoring only an observed completion lower bound is emitted. Development training trajectories change policy and are not a fixed-policy evaluation. This is not a player win rate.',
                   'mean_blinds_cleared':float(np.mean([e.get('blinds_cleared',0) for e in episodes])) if episodes else None,
                   'device':device_info}
        if model is not None:
            summary['cuda_peak_bytes'] = torch.cuda.max_memory_allocated()
        save_json(args.job_dir/'summary.json',summary)
        print(json.dumps(summary,indent=2),flush=True)


if __name__ == '__main__':
    main()
