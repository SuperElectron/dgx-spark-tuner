#!/usr/bin/env python3
"""Print per-run tg/pp/ttfr from a sparkrun round export (round-tmp.json)."""
import json
import statistics
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "round-tmp.json"
with open(path) as fh:
    benchmarks = json.load(fh)["benchmarks"]

for bench in benchmarks:
    if len(benchmarks) > 1:
        keys = ("prompt_size", "response_size", "generation_size", "concurrency", "context_size", "depth")
        cell = {k: bench[k] for k in keys if k in bench}
        if bench.get("is_context_prefill_phase"):
            cell["phase"] = "ctx_prefill"
        print(f"-- {cell}")
    for key in ("tg_throughput", "pp_throughput", "ttfr"):
        if key not in bench:
            continue
        m = bench[key]
        values = [round(v, 2) for v in m.get("values", [])]
        line = f"{key}: mean {m.get('mean', float('nan')):.2f} std {m.get('std', 0):.2f}"
        if values:
            line += f" median {statistics.median(values):.2f} runs {values}"
        print(line)
