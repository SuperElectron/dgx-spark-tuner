#!/usr/bin/env bash
# One-line JSON snapshot of the box for the ledger's env fingerprint.
set -euo pipefail

GPU="$(nvidia-smi --query-gpu=temperature.gpu,memory.used,memory.total,driver_version \
  --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')"
IFS=, read -r TEMP MEM_USED MEM_TOTAL DRIVER <<< "${GPU:-,,,}"

python3 - "$TEMP" "$MEM_USED" "$MEM_TOTAL" "$DRIVER" <<'PY'
import json, subprocess, sys, time
temp, mem_used, mem_total, driver = sys.argv[1:5]

def num(s):
    return int(s) if s and s.isdigit() else None  # GB10 reports [N/A] for GPU mem

mem = open("/proc/meminfo").read().splitlines()
avail_kb = next(int(l.split()[1]) for l in mem if l.startswith("MemAvailable"))
digest = subprocess.run(
    ["docker", "inspect", "--format", "{{index .RepoDigests 0}}", "vllm-bench"],
    capture_output=True, text=True).stdout.strip() or None
engines = subprocess.run(
    ["docker", "ps", "--filter", "name=vllm-", "--format", "{{.Names}}"],
    capture_output=True, text=True).stdout.split()
print(json.dumps({
    "ts": int(time.time()),
    "gpu_temp_c": num(temp),
    "gpu_mem_used_mib": num(mem_used),
    "gpu_mem_total_mib": num(mem_total),
    "driver": driver or None,
    "host_mem_available_gib": round(avail_kb / 1048576, 1),
    "engines": engines,
    "bench_image": digest,
}))
PY
