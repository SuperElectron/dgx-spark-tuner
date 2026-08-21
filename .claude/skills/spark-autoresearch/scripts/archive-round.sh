#!/usr/bin/env bash
set -euo pipefail

exp="${1:?usage: archive-round.sh <experiment-dir> <benchId> [suffix]}"
bench="${2:?usage: archive-round.sh <experiment-dir> <benchId> [suffix]}"
suffix="${3:-}"

dir="$exp/experiements/$bench${suffix:+-$suffix}"
[ -e "$dir" ] && { echo "error: $dir exists — pass a suffix (rebaseline/verify/crash)" >&2; exit 1; }
mkdir -p "$dir"

for f in "$exp"/round-tmp.yaml "$exp"/round-tmp.json "$exp"/round-tmp.csv; do
  [ -f "$f" ] && mv "$f" "$dir/"
done

state="$HOME/.cache/sparkrun/benchmarks/$bench"
[ -d "$state" ] && cp -r "$state"/* "$dir/" || echo "warn: no sparkrun state at $state" >&2

echo "archived $dir"
