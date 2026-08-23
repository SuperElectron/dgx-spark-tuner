#!/usr/bin/env bash
# Dump everything one run produced, labelled, in one pass.
#
#   show-run.sh <run-dir>
#
# Reads the run directory and the sparkrun archive it points at through
# id.txt. Ordered so the short files that say whether the run is usable come
# before the long ones that say what it measured.
#
# consolidated.json is not dumped: it is byte-identical to results.yaml's
# results.json, which is dumped.
set -euo pipefail

run="${1%/}"
state="$(cat "$run/id.txt")"

show() {
  echo
  echo "════════════════════════════════════════════════════════════════"
  echo "FILE: $1"
  echo "HOLDS: $2"
  echo "════════════════════════════════════════════════════════════════"
  cat "$1"
}

show "$state/state.yaml" \
  "start here. benchmark_id for the row, base_args and schedule for what was probed, crash_count and failed_indices for whether the run is usable at all, and each session's started_at/ended_at — everything before the first started_at is model load, not measurement"

show "$run/recipe.yaml" \
  "what this run declared: the serve command, the defaults filled into it, and the probe grid under benchmark:"

show "$run/out/engine-capture.log" \
  "what vLLM actually booted with. The 'non-default args:' line against recipe.yaml's defaults is the only independent check that the run served the config under test — if they disagree the figures are void. ERROR and WARNING lines say what it objected to"

for log in "$state"/runs/*.log; do
  show "$log" \
    "llama-benchy's narration for one cell. Load-bearing lines: 'Coherence test' and 'Average latency'"
done

show "$run/out/results.yaml" \
  "the measurement. results.json holds every probe value behind each mean; cluster.runtime_info pins cuda, torch, vllm, flashinfer and the container digest, which is what makes two runs comparable or not; recipe.hash confirms two runs that should differ actually did. recipe.text repeats recipe.yaml above"

for json in "$state"/runs/*.json; do
  show "$json" \
    "raw per-request timings for one cell — the individual requests behind results.json's values"
done

show "$run/out/telemetry.jsonl" \
  "one frame per 0.25s of host telemetry: gpu_util_pct, gpu_clock_mhz, gpu_power_w, gpu_temp_c, mem_used_pct, mem_available_mb, swap_used_mb. queried_at is epoch seconds — window it against state.yaml's session times or the model load skews every statistic. Empty fields are unavailable on this box, not zero"
