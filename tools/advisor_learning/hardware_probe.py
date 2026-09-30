"""A finite GPU-only numerical preflight, not a training benchmark claim."""
import argparse
import json
import time
from pathlib import Path
import torch


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--job-dir', type=Path, required=True)
    parser.add_argument('--wall-seconds', type=float)
    parser.add_argument('--max-transitions', type=int)
    parser.add_argument('--max-episodes', type=int)
    args = parser.parse_args()
    if not torch.cuda.is_available():
        raise RuntimeError('CUDA unavailable; CPU training fallback prohibited')
    device = torch.cuda.get_device_properties(0)
    free, total = torch.cuda.mem_get_info()
    if free < 8 * 2**30:
        raise RuntimeError('Insufficient free GPU memory with required headroom')
    torch.cuda.set_per_process_memory_fraction(min(24 * 2**30, free - 6 * 2**30) / total)
    torch.manual_seed(355)
    x = torch.randn(1024, 512, device='cuda')
    w = torch.randn(512, 512, device='cuda') * 0.02
    reference = x @ w
    records = {}
    for dtype in [torch.float32, torch.bfloat16]:
        start = time.perf_counter()
        with torch.autocast('cuda', dtype=dtype, enabled=dtype != torch.float32):
            for _ in range(20):
                value = x @ w
        torch.cuda.synchronize()
        records[str(dtype)] = {'20_matmuls_seconds': time.perf_counter() - start,
                               'rms_error': float((value.float()-reference).square().mean().sqrt().item()),
                               'finite': bool(torch.isfinite(value).all().item())}
    result = {'torch': torch.__version__, 'cuda': torch.version.cuda,
              'device': device.name, 'compute_capability': [device.major, device.minor],
              'free_bytes_before': free, 'total_bytes': total,
              'bf16_supported': torch.cuda.is_bf16_supported(),
              'allocated_peak_bytes': torch.cuda.max_memory_allocated(), 'checks': records,
              'training_done': False, 'simulation_episodes': 0}
    (args.job_dir / 'hardware.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
