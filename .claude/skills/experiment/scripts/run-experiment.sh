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
# Fails hard. Any missing step means the run is not reproducible.

set -euo pipefail

SERIES=""; HYP=""; LABEL=""; RECIPE=""; KEEP_ALIVE=0
OVERRIDES=(); PROBE=()

die() { echo "run-experiment: $*" >&2; exit 1; }
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
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$SERIES" ] || die "--series is required"
[ -n "$HYP" ] || die "--hyp is required"
[ -n "$LABEL" ] || die "--label is required"
[ -d "$SERIES" ] || die "not a directory: $SERIES"

REPO_ROOT="$(git rev-parse --show-toplevel)"
BOX_JSON="${BOX_JSON:-$REPO_ROOT/.claude/box.json}"
[ -f "$BOX_JSON" ] || die "missing $BOX_JSON"
HOST="$(jq -re '.host' "$BOX_JSON")"

RECIPE="${RECIPE:-$SERIES/recipe.yaml}"
[ -f "$RECIPE" ] || die "no recipe at $RECIPE"
HYP_DIR="$SERIES/$HYP"
mkdir -p "$HYP_DIR"

BRANCH="$(git -C "$REPO_ROOT" branch --show-current)"
case "$BRANCH" in
  main|staging|"") die "on branch '$BRANCH' — branch off staging first" ;;
esac

WORK="$(mktemp -d)"
TELEM_PID=""
cleanup() {
  [ -n "$TELEM_PID" ] && kill "$TELEM_PID" 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT INT TERM

say "starting telemetry"
ssh -o BatchMode=yes "$HOST" \
  'while :; do nvidia-smi --query-gpu=clocks.sm,clocks.max.sm,temperature.gpu,power.draw,pstate,memory.used --format=csv,noheader; sleep 1; done' \
  >"$WORK/telemetry.log" 2>/dev/null &
TELEM_PID=$!

say "running benchmark"
sparkrun benchmark perf "$RECIPE" --solo -H "$HOST" \
  "${PROBE[@]+"${PROBE[@]}"}" "${OVERRIDES[@]+"${OVERRIDES[@]}"}" \
  --fresh --no-stop --output "$SERIES/round-tmp.yaml" \
  2>&1 | tee "$WORK/sparkrun-stdout.log"

BENCH_ID="$(grep -oE 'bench_[0-9a-f]{12}' "$WORK/sparkrun-stdout.log" | head -1)"
[ -n "$BENCH_ID" ] || die "no Benchmark ID in sparkrun output"
say "$BENCH_ID"

CLUSTER_ID="$(sparkrun status -H "$HOST" --json \
  | jq -re '[.. | objects | (.cluster_id // .clusterId // empty)] | first')"
say "capturing from $CLUSTER_ID"

sparkrun export running-recipe "$CLUSTER_ID" --json >"$WORK/effective-recipe.json"
sparkrun logs "$CLUSTER_ID" -H "$HOST" -n 100000 >"$WORK/engine-capture.log"

[ "$KEEP_ALIVE" -eq 1 ] || { say "stopping workload"; sparkrun stop "$CLUSTER_ID" -H "$HOST" >/dev/null; }

kill "$TELEM_PID"; TELEM_PID=""

ARCHIVE="$HYP_DIR/${BENCH_ID}-${LABEL}"
[ -e "$ARCHIVE" ] && die "archive exists: $ARCHIVE — use a different --label"
mkdir -p "$ARCHIVE"

for f in "$SERIES"/round-tmp.yaml "$SERIES"/round-tmp.json "$SERIES"/round-tmp.csv; do
  [ -f "$f" ] && mv "$f" "$ARCHIVE/"
done

STATE="$HOME/.cache/sparkrun/benchmarks/$BENCH_ID"
[ -d "$STATE" ] || die "no sparkrun state at $STATE"
cp -r "$STATE"/. "$ARCHIVE/"

cp "$WORK/telemetry.log" "$WORK/engine-capture.log" \
   "$WORK/effective-recipe.json" "$WORK/sparkrun-stdout.log" "$ARCHIVE/"

[ "$RECIPE" = "$SERIES/recipe.yaml" ] || cp "$RECIPE" "$ARCHIVE/$(basename "$RECIPE")"

for f in state.yaml round-tmp.json effective-recipe.json engine-capture.log telemetry.log; do
  [ -s "$ARCHIVE/$f" ] || die "archive incomplete: $f is missing or empty"
done
grep -q "Running:" "$ARCHIVE/engine-capture.log" \
  || die "engine-capture.log has no 'Running:' lines — wrong stream captured"

echo
echo "archive:     $ARCHIVE"
echo "benchmark:   $BENCH_ID"
echo "crash_count: $(grep -oE 'crash_count: [0-9]+' "$ARCHIVE/state.yaml" | grep -oE '[0-9]+')"
echo "engine log:  $(wc -l <"$ARCHIVE/engine-capture.log") lines"
echo "telemetry:   $(wc -l <"$ARCHIVE/telemetry.log") samples"
