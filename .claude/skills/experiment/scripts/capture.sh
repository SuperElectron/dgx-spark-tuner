#!/usr/bin/env bash
# Copy a sparkrun archive into a run directory and summarise it.
#
#   capture.sh <bench-id> <out-dir> [regime]
#
# Writes provenance.txt and summary.txt into <out-dir>.
# Exits 1 if the archive is incomplete.
set -euo pipefail

bench="${1:?usage: capture.sh <bench-id> <out-dir> [regime]}"
out="${2:?usage: capture.sh <bench-id> <out-dir> [regime]}"
regime="${3:-unstated}"

src="$HOME/.cache/sparkrun/benchmarks/$bench"
[ -d "$src" ] || { echo "no archive at $src" >&2; exit 1; }
mkdir -p "$out"

# Identical recipes hash to the same bench id, so an archive can belong to a
# different run directory. Reading it would attribute another run's figures.
run_dir="$(cd "$(dirname "${out%/}")" && pwd)"
if [ -f "$src/state.yaml" ]; then
  owner="$(python3 -c "import yaml,sys;print((yaml.safe_load(open(sys.argv[1])) or {}).get('recipe_qualified_name',''))" "$src/state.yaml")"
  case "$owner" in
    */"$(basename "$run_dir")"/recipe.yaml|"") ;;
    *) echo "archive $bench belongs to $owner, not $run_dir" >&2; exit 1 ;;
  esac
fi

# Anything a prior run left behind would be read as this run's.
rm -rf "$out/runs" "$out/progress" "$out/progress.jsonl" "$out/telemetry.jsonl" \
       "$out/summary.txt" "$out/provenance.txt" "$out/state.yaml" \
       "$out/consolidated.json"

for f in state.yaml consolidated.json; do
  [ -f "$src/$f" ] && cp "$src/$f" "$out/$f" || echo "note: $f absent"
done
[ -d "$src/runs" ] && cp -R "$src/runs" "$out/runs" || echo "note: runs/ absent"

{
  echo "bench_id  $bench"
  echo "regime    $regime"
  echo "captured  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  [ -s "$out/results.yaml" ] && python3 - "$out/results.yaml" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))["sparkrun_benchmark"]
ri = (d.get("cluster") or {}).get("runtime_info") or {}
rc = d.get("recipe") or {}
for k in ("vllm", "build_vllm_commit", "build_flashinfer_commit",
          "build_source", "build_build_date", "torch", "cuda"):
    if ri.get(k): print(f"{k:<26}{ri[k]}")
for k in ("container", "runtime", "recipe_version"):
    if rc.get(k): print(f"{k:<26}{rc[k]}")
PY
  # --skip-run leaves runtime_info empty; the engine log carries the epoch anyway.
  [ -s "$out/engine-capture.log" ] && python3 - "$out/engine-capture.log" <<'PY'
import re, sys
log = open(sys.argv[1], errors="replace").read()
v = re.search(r"version (\d[\w.+]*)", log)
if v: print(f"{'vllm_version':<26}{v.group(1)}")
f = re.search(r"flashinfer_autotune_cache/([\d.]+)/", log)
if f: print(f"{'flashinfer_version':<26}{f.group(1)}")
PY
  true
} > "$out/provenance.txt"

missing=0
for f in results.yaml engine-capture.log; do
  [ -s "$out/$f" ] || { echo "INCOMPLETE: $f missing or empty" >&2; missing=1; }
done
# show-run.sh finds the archive through this pointer.
echo "$src" > "$(dirname "${out%/}")/id.txt"

[ "$missing" -eq 0 ] || { echo "captured $bench -> $out (INCOMPLETE)"; exit 1; }

python3 - "$out" "$bench" "$regime" > "$out/summary.txt" <<'PY'
import ast, csv, glob, io, json, os, re, sys, yaml

out, bench, regime = sys.argv[1], sys.argv[2], sys.argv[3]
d = yaml.safe_load(open(f"{out}/results.yaml"))["sparkrun_benchmark"]
ri = (d.get("cluster") or {}).get("runtime_info") or {}
log = open(f"{out}/engine-capture.log", errors="replace").read()

def num(v):
    try: return float(v)
    except (TypeError, ValueError): return 0.0

print(f"bench      {bench}")
print(f"regime     {regime}")
ver = re.search(r"version (\d[\w.+]*)", log)
fiv = re.search(r"flashinfer_autotune_cache/([\d.]+)/", log)
print(f"epoch      vllm {ri.get('build_vllm_commit') or (ver.group(1) if ver else '?')}  "
      f"flashinfer {ri.get('build_flashinfer_commit') or (fiv.group(1) if fiv else '?')}")

print("\ncells")
for r in csv.DictReader(io.StringIO(d["results"]["csv"])):
    m, s = num(r["t_s_mean"]), num(r["t_s_std"])
    print(f"  {r['test_name']:<28}{m:>10.2f}  sd {s:>7.2f}  cv {(s/m*100 if m else 0):>5.1f}%")

# Served vs declared: the only check on the recipe not made from the recipe.
nd = re.search(r"non-default args: (\{.*?\})\n", log)
rp = os.path.join(os.path.dirname(out.rstrip("/")), "recipe.yaml")
print()
if not nd:
    print("served     NOT FOUND — cannot check")
elif not os.path.isfile(rp):
    print(f"served     {nd.group(1)}")
    print(f"declared   no recipe.yaml beside {out}")
else:
    served = ast.literal_eval(nd.group(1))
    decl = (yaml.safe_load(open(rp)) or {}).get("defaults") or {}
    bad = [f"{k}: recipe {v} -> served {served.get(k)}"
           for k, v in decl.items() if k in served and str(served[k]) != str(v)]
    bad += [f"{k}: declared, absent from served"
            for k in decl if k not in served and k not in ("host", "port", "image")]
    if bad:
        print("served     MISMATCH — figures are void")
        for b in bad: print(f"           {b}")
    else:
        print(f"served     matches recipe defaults ({len(decl)} fields)")

q = re.findall(r"Running: (\d+) reqs, Waiting: (\d+) reqs", log)
print(f"queue      max running {max((int(a) for a,_ in q), default=0)}, "
      f"max waiting {max((int(b) for _,b in q), default=0)}, {len(q)} frames"
      if q else "queue      no frames sampled")
hits = [num(x) for x in re.findall(r"Prefix cache hit rate: ([\d.]+)%", log)]
print(f"cache      max {max(hits, default=0.0):.1f}% over {len(hits)} samples")
cg = re.search(r"'cudagraph_capture_sizes': (\[[^\]]*\])", log)
print(f"cudagraph  {cg.group(1) if cg else '?'}")

# The repeats behind each mean. A mean of a rate overweights the fast samples,
# so the median and the spread are what a decision rule should read.
print("\ntg repeats")
for f in sorted(glob.glob(f"{out}/runs/*.json")):
    try: b = json.load(open(f))["benchmarks"]
    except Exception: continue
    for c in b:
        v = sorted(num(x) for x in (c.get("tg_throughput") or {}).get("values") or [])
        if not v: continue
        med = v[len(v)//2] if len(v) % 2 else (v[len(v)//2-1]+v[len(v)//2])/2
        name = "ctx_tg" if c.get("is_context_prefill_phase") else f"tg{c.get('response_size')}"
        tag = f"{name} @ d{c.get('context_size')} (c{c.get('concurrency')})"
        print(f"  {tag:<24}median {med:>9.2f}  " + " ".join(f"{x:.2f}" for x in v))

rows = []
for line in (open(f"{out}/telemetry.jsonl") if os.path.isfile(f"{out}/telemetry.jsonl") else []):
    try: t = json.loads(line)
    except Exception: continue
    hs = t["hosts"]
    h = hs[0] if isinstance(hs, list) else list(hs.values())[0]
    if h.get("telemetry"): rows.append(h["telemetry"])
busy = [r for r in rows if num(r.get("gpu_util_pct")) >= 50]
peak = lambda k: max((num(r.get(k)) for r in rows), default=0.0)
clocks = {num(r.get("gpu_clock_mhz")) for r in busy}
if not rows:
    print("\nbox        no telemetry captured — box state under load is unknown")
else:
    print(f"\nbox        {len(rows)} frames, {len(busy)} busy")
    print(f"  gpu      util {peak('gpu_util_pct'):.0f}%  power {peak('gpu_power_w'):.1f} W  "
          f"temp {peak('gpu_temp_c'):.0f} C")
    print(f"  mem      {peak('mem_used_mb'):.0f} MB  swap {peak('swap_used_mb'):.0f} MB")
    print(f"  clock    {sorted(c for c in clocks if c)}"
          + ("   <-- constant: unmeasured, not in-band" if len(clocks) == 1 else ""))
PY

cat "$out/summary.txt"
