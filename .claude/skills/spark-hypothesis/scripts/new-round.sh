#!/usr/bin/env bash
# Add the next round to an experiment.
#
#   new-round.sh <experiment-dir>
#
# Numbers itself from the rounds already there.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dir="${1:?usage: new-round.sh <experiment-dir>}"
dir="${dir%/}"

last="$(find "$dir" -maxdepth 1 -type d -name 'h[0-9]*' | sort -V | tail -1)"
next="h$(( ${last##*/h} + 1 ))"

mkdir "$dir/$next"
sed "s|h<N>|$next|" "$here/HYPOTHESIS.md" > "$dir/$next/HYPOTHESIS.md"

echo "created $dir/$next"
echo "next: write the hypothesis, method and decision rule in $dir/$next/HYPOTHESIS.md"
