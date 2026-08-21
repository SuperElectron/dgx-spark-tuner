#!/usr/bin/env python3
"""Print per-run tg/pp/ttfr from a sparkrun round export (round-tmp.json)."""
import json
import statistics
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "round-tmp.json"
bench = json.load(open(path))["benchmarks"][0]

for key in ("tg_throughput", "pp_throughput", "ttfr"):
    if key not in bench:
        continue
    m = bench[key]
    values = [round(v, 2) for v in m.get("values", [])]
    line = f"{key}: mean {m['mean']:.2f} std {m.get('std', 0):.2f}"
    if values:
        line += f" median {statistics.median(values):.2f} runs {values}"
    print(line)
