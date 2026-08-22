#!/usr/bin/env bash
# Sample GPU clocks/temp/power on the box at 1Hz for the given duration (default 300s),
# writing to the given output file locally. Run alongside a benchmark; archive the
# log with the run. Reads box host from .claude/box.json.
set -euo pipefail
host=$(python3 -c "import json;print(json.load(open('$(git rev-parse --show-toplevel)/.claude/box.json'))['host'])")
dur="${1:-300}"; out="${2:-telemetry.log}"
ssh -o BatchMode=yes "$host" "for i in \$(seq 1 $dur); do nvidia-smi --query-gpu=clocks.sm,clocks.max.sm,temperature.gpu,power.draw,pstate,memory.used --format=csv,noheader; sleep 1; done" > "$out"
echo "telemetry: $(wc -l < "$out") samples -> $out"
