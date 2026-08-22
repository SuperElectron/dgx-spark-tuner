#!/usr/bin/env bash
# Run one benchmark experiment and archive it.
#
# Usage:
#   run-experiment.sh --series <dir> --hyp <dir> --label <text> [options]
#
#   --series <dir>    research/<series>            (holds recipe.yaml)
#   --hyp <dir>       experiments/<hypothesisId>   (relative to --series)
#   --label <text>    archive suffix, e.g. shipped, kvauto, mnbt65536
#   --recipe <file>   recipe to run (default: <series>/recipe.yaml)
#   -o key=value      recipe default override (repeatable)
#   -b key=value      probe argument (repeatable), e.g. -b depth=8192,16384
#   --runs <n>        shorthand for -b runs=<n>
#   --keep-alive      leave the workload up for a follow-on --skip-run
#
# Exits non-zero if the archive is missing anything needed to reproduce the run.

set -uo pipefail

SERIES=""; HYP=""; LABEL=""; RECIPE=""; KEEP_ALIVE=0
OVERRIDES=(); PROBE=()

die() { echo "run-experiment: $*" >&2; exit 2; }
say() { echo "==> $*" >&2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --series) SERIES="${2:?}"; shift 2 ;;
    --hyp) HYP="${2:?}"; shift 2 ;;
    --label) LABEL="${2:?}"; shift 2 ;;
    --recipe) RECIPE="${2:?}"; shift 2 ;;
    --runs) PROBE+=(-b "runs=${2:?}"); shift 2 ;;
    --keep-alive) KEEP_ALIVE=1; shift ;;
    -o) OVERRIDES+=(-o "${2:?}"); shift 2 ;;
    -b) PROBE+=(-b "${2:?}"); shift 2 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$SERIES" ] || die "--series is required"
[ -n "$HYP" ] || die "--hyp is required"
[ -n "$LABEL" ] || die "--label is required"
[ -d "$SERIES" ] || die "not a directory: $SERIES"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
BOX_JSON="${BOX_JSON:-$REPO_ROOT/.claude/box.json}"
[ -f "$BOX_JSON" ] || die "missing $BOX_JSON"
HOST="$(jq -r '.host // empty' "$BOX_JSON")"
[ -n "$HOST" ] || die "no .host in $BOX_JSON"

RECIPE="${RECIPE:-$SERIES/recipe.yaml}"
[ -f "$RECIPE" ] || die "no recipe at $RECIPE"
HYP_DIR="$SERIES/$HYP"
mkdir -p "$HYP_DIR" || die "cannot create $HYP_DIR"

BRANCH="$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo "")"
case "$BRANCH" in
  main|staging) die "on branch '$BRANCH' — branch off staging first" ;;
esac

WORK="$(mktemp -d)"
TELEM_PID=""
cleanup() {
  [ -n "$TELEM_PID" ] && kill "$TELEM_PID" 2>/dev/null
  rm -rf "$WORK"
}
trap cleanup EXIT INT TERM

gpu() {
  ssh -n -o BatchMode=yes "$HOST" \
    'nvidia-smi --query-gpu=clocks.sm,temperature.gpu,power.draw --format=csv,noheader' 2>/dev/null
}

say "starting telemetry"
ssh -o BatchMode=yes "$HOST" \
  'while :; do nvidia-smi --query-gpu=clocks.sm,clocks.max.sm,temperature.gpu,power.draw,pstate,memory.used --format=csv,noheader; sleep 1; done' \
  >"$WORK/telemetry.log" 2>/dev/null &
TELEM_PID=$!
gpu >"$WORK/clocks-pre.txt"

say "running benchmark"
sparkrun benchmark perf "$RECIPE" --solo -H "$HOST" \
  "${PROBE[@]+"${PROBE[@]}"}" "${OVERRIDES[@]+"${OVERRIDES[@]}"}" \
  --fresh --no-stop --output "$SERIES/round-tmp.yaml" \
  >"$WORK/sparkrun-stdout.log" 2>&1
BENCH_RC=$?

BENCH_ID="$(grep -oE 'bench_[0-9a-f]{12}' "$WORK/sparkrun-stdout.log" | head -1)"
[ -n "$BENCH_ID" ] || { cat "$WORK/sparkrun-stdout.log" >&2; die "no Benchmark ID in sparkrun output"; }
say "$BENCH_ID (sparkrun exit $BENCH_RC)"

CLUSTER_ID="$(sparkrun status -H "$HOST" --json 2>/dev/null \
  | jq -r '[.. | objects | (.cluster_id // .clusterId // empty)] | first // empty')"

if [ -n "$CLUSTER_ID" ]; then
  say "capturing from $CLUSTER_ID"
  sparkrun export running-recipe "$CLUSTER_ID" --json >"$WORK/effective-recipe.json" 2>/dev/null || true
  sparkrun logs "$CLUSTER_ID" -H "$HOST" -n 100000 >"$WORK/engine-capture.log" 2>/dev/null || true
else
  say "WARNING: no cluster id from sparkrun status"
fi

if ! grep -q "Running:" "$WORK/engine-capture.log" 2>/dev/null; then
  say "falling back to /tmp/sparkrun_serve.log"
  CONTAINER="$(ssh -n -o BatchMode=yes "$HOST" \
    'docker ps --format "{{.Names}}" | grep "^sparkrun" | head -1' 2>/dev/null)"
  [ -n "$CONTAINER" ] && ssh -n -o BatchMode=yes "$HOST" \
    "docker exec $CONTAINER cat /tmp/sparkrun_serve.log" >"$WORK/engine-capture.log" 2>/dev/null || true
fi

if [ "$KEEP_ALIVE" -eq 0 ]; then
  say "stopping workload"
  sparkrun stop "${CLUSTER_ID:-}" -H "$HOST" >/dev/null 2>&1 || true
fi

kill "$TELEM_PID" 2>/dev/null; TELEM_PID=""
gpu >"$WORK/clocks-post.txt"

ARCHIVE="$HYP_DIR/${BENCH_ID}-${LABEL}"
[ -e "$ARCHIVE" ] && die "archive exists: $ARCHIVE — use a different --label"
mkdir -p "$ARCHIVE"

for f in "$SERIES"/round-tmp.yaml "$SERIES"/round-tmp.json "$SERIES"/round-tmp.csv; do
  [ -f "$f" ] && mv "$f" "$ARCHIVE/"
done

STATE="$HOME/.cache/sparkrun/benchmarks/$BENCH_ID"
if [ -d "$STATE" ]; then cp -r "$STATE"/. "$ARCHIVE/"; else say "WARNING: no sparkrun state at $STATE"; fi

for f in telemetry.log clocks-pre.txt clocks-post.txt engine-capture.log \
         effective-recipe.json sparkrun-stdout.log; do
  [ -s "$WORK/$f" ] && cp "$WORK/$f" "$ARCHIVE/"
done

[ "$RECIPE" = "$SERIES/recipe.yaml" ] || cp "$RECIPE" "$ARCHIVE/$(basename "$RECIPE")"

FAIL=0
need() { [ -s "$ARCHIVE/$1" ] || { echo "MISSING: $1" >&2; FAIL=1; }; }
need state.yaml
need round-tmp.json
need effective-recipe.json
need engine-capture.log
grep -q "Running:" "$ARCHIVE/engine-capture.log" 2>/dev/null \
  || { echo "EMPTY CAPTURE: engine-capture.log has no 'Running:' lines" >&2; FAIL=1; }

CRASHES="$(grep -oE 'crash_count: [0-9]+' "$ARCHIVE/state.yaml" 2>/dev/null | grep -oE '[0-9]+')"

echo
echo "archive:     $ARCHIVE"
echo "benchmark:   $BENCH_ID (exit $BENCH_RC)"
echo "crash_count: ${CRASHES:-unknown}"
echo "engine log:  $(wc -l <"$ARCHIVE/engine-capture.log" 2>/dev/null || echo 0) lines"
echo "telemetry:   $(wc -l <"$ARCHIVE/telemetry.log" 2>/dev/null || echo 0) samples"

[ "$FAIL" -eq 0 ] || { echo "INCOMPLETE — do not open a PR" >&2; exit 1; }
echo "complete"
