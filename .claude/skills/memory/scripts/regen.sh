#!/usr/bin/env bash
# Regenerate the measurement half of the store from the archives. DRY RUN BY DEFAULT.
#
#   regen.sh                    print every proposed [OBSERVATION] and its --meta line
#   regen.sh --summary          counts, coverage and skips only
#   regen.sh --manifest <file>  also write the machine-readable manifest (JSONL)
#   regen.sh --execute --confirm-write --manifest <file>
#
# WHY REGENERATE RATHER THAN MIGRATE
# The 208 legacy records carry only sha256 and entity. Phase 7 showed a metadata
# edit means DELETE + re-POST (no update route), and that 0 of 7 legacy
# [OBSERVATION]s could be completed anyway: each spans several cells or fuses a
# pp figure with a tg one, so no single test/depth/conc exists for it. The
# archives, by contrast, hold the figures at full resolution. So we do not
# repair prose — we re-derive the measurements from the runs that produced them.
#
# ONE MEMORY PER (unit x cell x test_name). Never a pp figure and a tg figure in
# one line: that fusion is exactly what made the legacy records unmigratable. A
# cell at depth>0 yields up to four — ctx_pp, ctx_tg for the context-prefill
# phase and pp<N>, tg<N> for the cell itself. The context phase is emitted under
# its own test name rather than dropped: it is a separately measured quantity at
# the same cell, it is what makes depth cost visible, and the contract already
# names ctx_tg as a test type.
#
# THE UNIT KEY IS THE ARCHIVE DIRECTORY, NOT THE BENCHMARK ID.
# 61 distinct benchmark_id values span 72 dirs, and the repeats are NOT copies:
# bench_c9518e3e96a3 alone appears in R11, two R23 arms and an R25 arm, four
# executions minutes apart with four different figures. sparkrun derives the id
# from the recipe, so re-running a recipe re-uses it. Keying on the id would
# silently discard 11 real measurements, several of them arms of a controlled
# comparison. We key on (unit_path, depth, conc, test): stable on disk, so a
# re-run proposes exactly the same set. A true byte-duplicate would still
# collapse — the guard below drops any second unit agreeing on
# (bench, date, depth, conc, test) — and it reports how many it dropped.
#
# NOTHING IS DEFAULTED. A meta key whose source is absent is omitted, not
# guessed. protocol especially: the archive campaigns predate the protocol
# flags, so most units carry none and must say so by silence. epoch.image
# likewise: nothing in the archives records the digest of the image the box
# ran, so no record here carries one. What the archives do hold is the digest
# sparkrun BUILT FROM, and that goes under epoch.build_source. Epoch fields
# NEST — metadata.epoch.build_source, an "epoch" object — which is what
# remember.sh writes and the only shape recall.sh --filter epoch.*= reads.
#
# ENTITY IS model:<hf-id>, read verbatim from the archive. A generator cannot
# pick round: or flag: — round: is transient and belongs to a round that is
# closed, and flag: asserts which knob the figure is about, which is a judgement
# about an experiment this script cannot see. model: is the widest scope every
# one of these figures is actually true for, and it is durable. Promotion to a
# wider or sharper entity is a human decision, made later, per record.
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel)"
ARCHIVE="$ROOT/.cache/_archive"
RESEARCH="$ROOT/research"
USER_ID="dgx-spark-tuner"
PORT=8888

mode=print manifest="" execute="" confirm=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)  mode=print; shift ;;
    --summary)  mode=summary; shift ;;
    --json)     mode=json; shift ;;
    --manifest) [ $# -ge 2 ] || { echo 'regen: --manifest needs a path' >&2; exit 2; }
                manifest="$2"; shift 2 ;;
    --execute)  execute=1; shift ;;
    --confirm-write) confirm=1; shift ;;
    --help)     sed -n '2,10p' "$0" >&2; exit 0 ;;
    *) echo "regen: unknown argument $1" >&2; exit 2 ;;
  esac
done

[ -d "$ARCHIVE" ] || { echo "regen: no archive at $ARCHIVE" >&2; exit 2; }

plan="$(ARCHIVE="$ARCHIVE" RESEARCH="$RESEARCH" ROOT="$ROOT" python3 - <<'PY'
import json, os, pathlib, re, sys
import yaml

ROOT = pathlib.Path(os.environ["ROOT"])
ARCHIVE = pathlib.Path(os.environ["ARCHIVE"])
RESEARCH = pathlib.Path(os.environ["RESEARCH"])

recs, skips, notes = [], [], []

def load(p):
    try:
        with open(p) as f:
            return yaml.safe_load(f)
    except Exception as e:
        return None

def rel(p):
    return str(pathlib.Path(p).relative_to(ROOT))

def protocol_of(args):
    if not isinstance(args, dict):
        return None
    bits = []
    if args.get("exact_tg"):        bits.append("exact_tg")
    if args.get("extra_body"):      bits.append(str(args["extra_body"]))
    if args.get("no_adapt_prompt"): bits.append("no_adapt_prompt")
    if args.get("post_run_cmd"):    bits.append("cache reset between runs")
    if args.get("book_url"):        bits.append(str(args["book_url"]))
    return ", ".join(bits) or None

def epoch_of(rti):
    """Returned as the NESTED object remember.sh writes: {"build_source": ...}
    goes to metadata.epoch.build_source, never to a flat "epoch.build_source"
    key. recall.sh --filter reads the nested form.

    No epoch.image. The archives record what sparkrun BUILT FROM
    (container_dev_sparkrun_source_digest, an upstream docker.io/eugr/spark-vllm
    digest), never the digest of the image the box actually ran. Those are two
    objects, and epoch.image is defined as the second, so it is unrecoverable
    here and is omitted rather than filled with the first. Only observe, reading
    the running container, can supply epoch.image."""
    e = {}
    if isinstance(rti, dict):
        if rti.get("container_dev_sparkrun_source_digest"):
            e["build_source"] = rti["container_dev_sparkrun_source_digest"]
        if rti.get("build_vllm_commit"):
            e["vllm"] = rti["build_vllm_commit"]
        if rti.get("build_flashinfer_commit"):
            e["flashinfer"] = rti["build_flashinfer_commit"]
    return e

def emit(unit, cell_depth, conc, entries):
    """One record per (cell x test_name). entries are the benchmarks[] at this cell."""
    for b in entries:
        ctx = bool(b.get("is_context_prefill_phase"))
        depth = b.get("context_size", cell_depth)
        if depth != cell_depth:
            notes.append(f"{unit['unit']}: cell file says d{cell_depth}, record says d{depth}")
        for kind in ("pp", "tg"):
            fig = b.get(f"{kind}_throughput") or {}
            mean = fig.get("mean")
            if mean is None:
                continue
            if ctx:
                test = f"ctx_{kind}"
            elif kind == "pp":
                test = f"pp{b.get('prompt_size')}"
            else:
                test = f"tg{b.get('response_size')}"
            vals = fig.get("values") or []
            meta = {"model": unit["model"], "test": test,
                    "depth": str(depth), "conc": str(conc),
                    "bench": unit["bench"], "date": unit["date"]}
            for k in ("quant", "runtime", "protocol"):
                if unit.get(k):
                    meta[k] = unit[k]
            n = unit.get("runs") or (len(vals) or None)
            if n:
                meta["runs"] = str(n)
            if unit["epoch"]:
                meta["epoch"] = dict(unit["epoch"])

            short = unit["model"].split("/")[-1]
            sd = fig.get("std")
            spread = f", sd {sd:.2f}" if isinstance(sd, (int, float)) else ""
            tail = ""
            if kind == "pp":
                ttfr = (b.get("ttfr") or {}).get("mean")
                if isinstance(ttfr, (int, float)):
                    tail = f", ttfr {ttfr:.0f} ms"
            text = (f"[OBSERVATION] {short} {test} @ d{depth} c{conc}: "
                    f"{mean:.2f} t/s{spread}{tail} over {n or len(vals)} runs, "
                    f"measured {unit['date']} in {unit['origin']} ({unit['bench']})")
            recs.append({"key": f"{unit['unit']}|d{depth}|c{conc}|{test}",
                         "unit": unit["unit"], "origin": unit["origin"],
                         "campaign": unit["campaign"], "shape": unit["shape"],
                         "entity": "model:" + unit["model"],
                         "text": text, "meta": meta})

# ---- Shape A: sparkrun bench dirs under .cache/_archive -----------------------
for d in sorted(p for p in ARCHIVE.rglob("bench_*") if p.is_dir()):
    cells = sorted(d.glob("runs/*.json"))
    st = load(d / "state.yaml")
    if not cells:
        skips.append({"unit": rel(d), "why": "crash dir: no per-cell result JSON",
                      "scheduled": len((st or {}).get("schedule") or []),
                      "crash_count": (st or {}).get("crash_count")})
        continue
    if not st or not st.get("benchmark_id"):
        skips.append({"unit": rel(d), "why": "no state.yaml benchmark_id"})
        continue

    rt = (load(d / "round-tmp.yaml") or {}).get("sparkrun_benchmark") or {}
    rti = ((rt.get("cluster") or {}).get("runtime_info")) or {}
    mdl = rt.get("model") or {}
    recipe = rt.get("recipe") or {}
    sess = st.get("sessions") or []
    ended = next((s.get("ended_at") for s in reversed(sess) if s.get("ended_at")), None)
    date = (ended or st.get("updated_at") or st.get("created_at") or "")[:10]
    model = recipe.get("model") or rti.get("container_sparkrun_model")
    if not model:
        model = (json.load(open(cells[0])) or {}).get("model")
    if not model or not date:
        skips.append({"unit": rel(d), "why": "no model or no date recoverable"})
        continue

    parts = d.relative_to(ARCHIVE).parts
    unit = {
        "unit": rel(d), "shape": "archive", "campaign": parts[0],
        "origin": "/".join(x for x in parts if x != "experiments" and x != "_archive"),
        "bench": st["benchmark_id"], "date": date, "model": model,
        "quant": mdl.get("quantization") or mdl.get("dtype"),
        "runtime": recipe.get("runtime") or rti.get("container_sparkrun_runtime"),
        "protocol": protocol_of((rt.get("benchmark") or {}).get("args")),
        "runs": (st.get("base_args") or {}).get("runs"),
        "epoch": epoch_of(rti),
    }
    longterm = (st.get("extras") or {}).get("container_image_longterm_ref")
    if longterm and not unit["epoch"]:
        notes.append(f"{unit['unit']}: no round-tmp.yaml, so no epoch at all; "
                     f"state.yaml pins the run image as {longterm} (a tag, not a "
                     f"digest — not written to epoch.image)")
    for c in cells:
        m = re.match(r"\d+_d(\d+)_c(\d+)\.json$", c.name)
        if not m:
            skips.append({"unit": rel(c), "why": "cell filename is not {i}_d{depth}_c{conc}.json"})
            continue
        data = json.load(open(c))
        emit(unit, int(m.group(1)), int(m.group(2)), data.get("benchmarks") or [])

# ---- Shape B: run dirs carrying id.txt + out/results.yaml ---------------------
run_dirs = sorted(p for p in list(ARCHIVE.rglob("run-*")) + list(RESEARCH.rglob("run-*"))
                  if p.is_dir())
for d in run_dirs:
    idf, res = d / "id.txt", d / "out" / "results.yaml"
    if not idf.exists() or not res.exists():
        skips.append({"unit": rel(d), "why": "prepared but never run: recipe only, no id.txt/results.yaml"})
        continue
    sb = (load(res) or {}).get("sparkrun_benchmark") or {}
    js = ((sb.get("results") or {}).get("json")) or {}
    bench = pathlib.Path(idf.read_text().strip()).name
    rti = ((sb.get("cluster") or {}).get("runtime_info")) or {}
    mdl = sb.get("model") or {}
    recipe = sb.get("recipe") or {}
    args = (sb.get("benchmark") or {}).get("args") or {}
    date = str(sb.get("timestamp") or "")[:10]
    model = recipe.get("model") or js.get("model") or rti.get("container_sparkrun_model")
    if not bench or not model or not date:
        skips.append({"unit": rel(d), "why": "no bench id, model or date in results.yaml"})
        continue

    unit = {
        "unit": rel(d), "shape": "run-dir",
        "campaign": "research" if RESEARCH in d.parents else d.relative_to(ARCHIVE).parts[0],
        "origin": rel(d.parent), "bench": bench, "date": date, "model": model,
        "quant": mdl.get("quantization") or mdl.get("dtype"),
        "runtime": recipe.get("runtime") or rti.get("container_sparkrun_runtime"),
        "protocol": protocol_of(args), "runs": args.get("runs"),
        "epoch": epoch_of(rti),
    }
    bycell = {}
    for b in js.get("benchmarks") or []:
        bycell.setdefault((b.get("context_size", 0), b.get("concurrency", 1)), []).append(b)
    if not bycell:
        skips.append({"unit": rel(d), "why": "results.yaml carries no benchmarks[]"})
        continue
    for (depth, conc), entries in sorted(bycell.items()):
        emit(unit, depth, conc, entries)

# ---- collapse true byte-duplicates -------------------------------------------
seen, kept, dropped = {}, [], []
for r in sorted(recs, key=lambda r: r["key"]):
    m = r["meta"]
    sig = (m["bench"], m["date"], m["depth"], m["conc"], m["test"], r["text"])
    if sig in seen:
        dropped.append({"unit": r["unit"], "why": "byte-duplicate of " + seen[sig]})
        continue
    seen[sig] = r["unit"]
    kept.append(r)

json.dump({"records": kept, "skips": skips, "duplicates": dropped, "notes": notes},
          sys.stdout)
PY
)"
[ -n "$plan" ] || { echo "regen: extraction failed" >&2; exit 1; }

if [ "$mode" = json ]; then jq . <<<"$plan"; fi

if [ "$mode" = print ]; then
  jq -r '.records[] |
    "── \(.entity)  [\(.meta.test) d\(.meta.depth) c\(.meta.conc)]  \(.unit)",
    "   \(.text)",
    "   --meta " + (.meta | [paths(scalars) as $p | {key: ($p|join(".")), value: getpath($p)}] | sort_by(.key)
      | map("\(.key)=" + (if (.value | test("[ ,]")) then "\"\(.value)\"" else .value end))
      | join(" --meta ")),
    ""' <<<"$plan"
fi

echo "════════ SUMMARY ════════"
jq -r '
  def req: ["model","test","depth","conc","bench","date"];
  .records as $r |
  "proposed [OBSERVATION]s : \($r|length)",
  "distinct bench ids      : \([$r[].meta.bench]|unique|length)",
  "distinct units          : \([$r[].unit]|unique|length)",
  "",
  "by campaign             : " + ([$r|group_by(.campaign)[]|"\(.[0].campaign)=\(length)"]|join("  ")),
  "by model                : " + ([$r|group_by(.meta.model)[]|"\(.[0].meta.model)=\(length)"]|join("  ")),
  "by test                 : " + ([$r|group_by(.meta.test)[]|"\(.[0].meta.test)=\(length)"]|join("  ")),
  "by depth                : " + ([$r|group_by(.meta.depth|tonumber)[]|"d\(.[0].meta.depth)=\(length)"]|join("  ")),
  "by conc                 : " + ([$r|group_by(.meta.conc|tonumber)[]|"c\(.[0].meta.conc)=\(length)"]|join("  ")),
  "",
  "all six required present: \([$r[]|select((req - (.meta|keys))|length == 0)]|length) of \($r|length)",
  ([$r[]|select((req - (.meta|keys))|length > 0)
        |"   INCOMPLETE \(.unit) missing \((req - (.meta|keys))|join(" "))"]|join("\n")),
  "",
  "optional coverage:",
  ([ "quant","runtime","runs","protocol","epoch.image","epoch.build_source","epoch.vllm","epoch.flashinfer" ][]
     as $k | "   \($k | . + (" " * (18 - length))) \([$r[]|select(.meta | getpath($k|split(".")))]|length)"),
  "   all three epoch.*  \([$r[]|select(.meta.epoch.build_source and .meta.epoch.vllm and .meta.epoch.flashinfer)]|length)",
  "",
  "date range              : \([$r[].meta.date]|min) .. \([$r[].meta.date]|max)",
  "",
  "── SKIPPED ──",
  ([.skips[]|"   \(.why)"]|group_by(.)|map("  \(length)  \(.[0]|ltrimstr("   "))")|join("\n")),
  ([.skips[]|"   \(.unit)  — \(.why)"]|join("\n")),
  "",
  "duplicates collapsed    : \(.duplicates|length)",
  ([.duplicates[]|"   \(.unit)  \(.why)"]|join("\n")),
  (if (.notes|length) > 0 then "\n── ANOMALIES ──\n" + ([.notes[]|"   \(.)"]|join("\n")) else "" end)
' <<<"$plan"

if [ -n "$manifest" ]; then
  jq -c '.records[]' <<<"$plan" > "$manifest" \
    && echo "regen: manifest of $(wc -l <"$manifest" | tr -d ' ') proposed records at $manifest" >&2
fi

[ -n "$execute" ] || { echo; echo "regen: DRY RUN — nothing written. Store untouched." >&2; exit 0; }

if [ -z "$confirm" ]; then
  echo "regen: REFUSED — --execute needs --confirm-write." >&2
  echo "  This POSTs new memories. It deletes nothing, but it grows the store by" >&2
  echo "  the count above and there is no bulk undo: removing them again means" >&2
  echo "  DELETE per id. Read the header, read the dry run, then pass it." >&2
  exit 3
fi
[ -n "$manifest" ] || { echo "regen: REFUSED — --execute needs --manifest <file>." >&2; exit 3; }

host="$(jq -r '.host // empty' "$ROOT/.claude/box.json" 2>/dev/null)"
[ -n "$host" ] || { echo "regen: no box configured, nothing written" >&2; exit 0; }

while IFS= read -r row; do
  txt="$(jq -r .text <<<"$row")"
  sha="$(printf '%s' "$txt" | shasum -a 256 | cut -d' ' -f1)"
  body="$(jq -c --arg t "$txt" --arg s "$sha" --arg u "$USER_ID" \
    '{messages: [{role: "user", content: $t}], user_id: $u,
      metadata: (.meta + {entity: .entity, schema: "1", sha256: $s}), infer: false}' <<<"$row")"
  st="$(printf '%s' "$body" | ssh -o ConnectTimeout=10 -o BatchMode=yes "$host" \
    "curl -sS --max-time 20 -o /dev/null -w '%{http_code}' -X POST \
     -H 'Content-Type: application/json' --data-binary @- \
     'http://127.0.0.1:${PORT}/memories'" 2>/dev/null)"
  case "$st" in
    2*) echo "regen: written  $(jq -r .key <<<"$row")" >&2 ;;
    *)  echo "regen: NOT written (http ${st:-000})  $(jq -r .key <<<"$row")" >&2 ;;
  esac
done < "$manifest"
exit 0
