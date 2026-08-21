#!/usr/bin/env bash
set -euo pipefail

exp="${1:?usage: archive-round.sh <experiment-dir> <benchId> [suffix]}"
bench="${2:?usage: archive-round.sh <experiment-dir> <benchId> [suffix]}"
suffix="${3:-}"

dir="$exp/experiments/$bench${suffix:+-$suffix}"
[ -e "$dir" ] && { echo "error: $dir exists — pass a suffix (rebaseline/verify/crash)" >&2; exit 1; }
mkdir -p "$dir"

for f in "$exp"/round-tmp.yaml "$exp"/round-tmp.json "$exp"/round-tmp.csv; do
  if [ -f "$f" ]; then mv "$f" "$dir/"; fi
done

state="$HOME/.cache/sparkrun/benchmarks/$bench"
if [ -d "$state" ]; then
  cp -r "$state"/. "$dir/"
else
  echo "warn: no sparkrun state at $state" >&2
fi

echo "archived $dir"
